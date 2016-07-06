require "#{File.dirname(__FILE__)}/comun"

module CTEgeo

def self.zonashabitables(sqlFile)
  log = 'CTEgeo' 
  zonashabitablessearch = sqlFile.execAndReturnVectorOfString("#{zonashabitablesquery}")
  zonashabitables = Comun.verificabusqueda(log, 'zonas habitables', zonashabitablessearch, zonashabitablesquery)
  return  zonashabitables
end

def self.zonasnohabitables(sqlFile)
  log = 'CTEgeo' 
  zonasnohabitablessearch = sqlFile.execAndReturnVectorOfString("#{zonasnohabitablesquery}")
  zonasnohabitables = Comun.verificabusqueda(log, 'zonas no habitables', zonasnohabitablessearch, zonasnohabitablesquery)
  return zonasnohabitables
end

def self.superficiehabitable(sqlFile)
  log = 'CTEgeo'  
  superficiehabitablequery = "SELECT SUM(FloorArea) FROM (#{zonashabitablesquery}) "
  superficiehabitablesearch = sqlFile.execAndReturnFirstDouble(superficiehabitablequery)
  resultado = Comun.verificabusqueda(log, 'superficie habitable',  superficiehabitablesearch, superficiehabitablequery)  
  return resultado   
end

def self.superficienohabitable(sqlFile)
  log = 'CTEgeo'  
  superficienohabitablequery = "SELECT SUM(FloorArea) FROM (#{zonasnohabitablesquery}) "
  superficienohabitablesearch = sqlFile.execAndReturnFirstDouble(superficienohabitablequery)
  superficienohabitable = Comun.verificabusqueda(log, 'superficie no habitable',  superficienohabitablesearch, superficienohabitablequery)  
  return superficienohabitable   
end

def self.superficiescandidatas(sqlFile)
  log = 'CTEgeo'
  superficiescandidatassearch = sqlFile.execAndReturnVectorOfString(superficiescandidatasquery)
  superficiescandidatas = Comun.verificabusqueda(log, 'superficies candidatas', superficiescandidatassearch, superficiescandidatasquery)
  return superficiescandidatas  
end

def self.superficiesexternas(sqlFile)
  log = 'CTEgeo'
  superficiesexternassearch = sqlFile.execAndReturnVectorOfString(superficiesexternasquery)
  superficiesexternas = Comun.verificabusqueda(log, 'superficies externas', superficiesexternassearch, superficiesexternasquery)
  return superficiesexternas
end

def self.superficiesinternas(sqlFile,  log = 'CTEgeo')
  superficiesinternassearch = sqlFile.execAndReturnVectorOfString(superficiesinternasquery)
  superficiesinternas = Comun.verificabusqueda(log, 'superficies internas',superficiesinternassearch,superficiesinternasquery )
  return superficiesinternas
end

def self.superficiescontacto(sqlFile,  log = 'CTEgeo')  
  superficiescontactosearch = sqlFile.execAndReturnVectorOfString(superficiescontactoquery)
  superficiescontacto = Comun.verificabusqueda(log, 'superficies de contacto', superficiescontactosearch, superficiescontactoquery)
  return superficiescontacto
end

def self.volumenhabitable(sqlFile)
  log = 'CTEgeo' 
  volumenhabitablequery = "SELECT SUM(Volume) FROM  (#{zonashabitablesquery})"
  volumenhabitablesearch = sqlFile.execAndReturnFirstDouble(volumenhabitablequery)
  volumenhabitable = Comun.verificabusqueda(log, 'volumen habitable', volumenhabitablesearch, volumenhabitablequery)
  return volumenhabitable
end

def self.volumennohabitable(sqlFile,  log = 'CTEgeo') 
  volumennohabitablequery = "SELECT SUM(Volume) FROM (#{CTEgeo.zonasnohabitablesquery})"
  volumennohabitablesearch = sqlFile.execAndReturnFirstDouble(volumennohabitablequery)
  volumennohabitable = Comun.verificabusqueda(log, 'volumen no habitable', volumennohabitablesearch, volumennohabitablequery)
  return volumennohabitable
end

def self.areaexterior(sqlFile, log = 'CTEgeo')  
  areaexteriorquery = "SELECT SUM(GrossArea) FROM (#{superficiesexternasquery})"
  areaexteriorsearch = sqlFile.execAndReturnFirstDouble(areaexteriorquery)
  areaexterior = Comun.verificabusqueda(log, 'area exterior de la envolvente', areaexteriorsearch, areaexteriorquery)
  return areaexterior
end

def self.areainterior(sqlFile, log = 'CTEgeo')
  areainteriorquery = "SELECT SUM(GrossArea) FROM (#{superficiescontactoquery})"
  areainteriorsearch = sqlFile.execAndReturnFirstDouble(areainteriorquery)
  areainterior = Comun.verificabusqueda(log, 'area interior de la envolvente', areainteriorsearch, areainteriorquery)
  return  areainterior
end





def self.zonashabitablesquery
    zonashabitablesquery =  "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex) 
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex) 
WHERE zl.Name != 'CTE_NOHABITA' AND zl.Name != 'CTE_N' AND zl.Name != 'CTE_NOHABITABLE' "
    zonashabitablesquery
  end

  def self.zonasnohabitablesquery
    zonasnohabitablesquery =  "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex) 
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex) 
WHERE zl.Name == 'CTE_NOHABITA' OR zl.Name == 'CTE_N' OR zl.Name == 'CTE_NOHABITABLE'  "
    zonasnohabitablesquery
  end 
  
  def self.superficiesquery
    superficiesquery =  "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, GrossArea,
    ExtBoundCond, surf.ZoneIndex ZoneIndex
FROM 
    Surfaces surf 
    INNER JOIN ( #{zonashabitablesquery} ) AS zones
        ON surf.ZoneIndex = zones.ZoneIndex"
    superficiesquery
  end

    def self.superficiescandidatasquery
        superficiescandidatasquery = "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, 
    GrossArea, ExtBoundCond, ZoneIndex
FROM 
    (#{superficiesquery}) AS surf
    WHERE surf.ClassName <> 'Window' AND surf.ClassName <> 'Internal Mass' "
    superficiescandidatasquery
    end
  
  def self.superficiesexternasquery
    superficiesexternasquery = "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, 
    GrossArea, ExtBoundCond, ZoneIndex
FROM 
    (#{superficiescandidatasquery})
    WHERE ExtBoundCond = -1 OR ExtBoundCond = 0 "
    superficiesexternasquery
  end
  
  def self.superficiesinternasquery
      superficiesinternasquery = "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, 
    GrossArea, ExtBoundCond, ZoneIndex
FROM (#{superficiescandidatasquery})
      WHERE ExtBoundCond <> -1 AND ExtBoundCond <> 0"
      superficiesinternasquery
  end
  
  def self.superficiescontactoquery
    superficiescontactoquery = "
SELECT 
    surf.SurfaceIndex SurfaceIndex, SurfaceName SurfaceName, 
    ConstructionIndex, ClassName, Area, GrossArea, ExtBoundCond, 
    surf.ZoneIndex ZoneIndex
FROM (  SELECT 
            SurfaceIndex 
        FROM 
            (#{superficiesinternasquery})  ) AS internas
    INNER JOIN Surfaces surf ON surf.ExtBoundCond = internas.SurfaceIndex
    INNER JOIN (#{zonasnohabitablesquery}) AS znh ON surf.ZoneIndex = znh.ZoneIndex"
    superficiescontactoquery
  end 
  
  def self.murosexterioresenvolventequery
    murosexterioresquery = "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, 
    GrossArea, ExtBoundCond, ZoneIndex
FROM 
    (#{superficiesexternasquery}) AS surf 
    WHERE surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0 "
    murosexterioresquery
  end
 
  def self.cubiertassexterioresenvolventequery
    cubiertasexterioresquery = "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, 
    GrossArea, ExtBoundCond, ZoneIndex
FROM 
    (#{superficiesexternasquery}) AS surf 
    WHERE surf.ClassName == 'Roof' AND surf.ExtBoundCond == 0 "
    cubiertasexterioresquery
  end
  
  def self.suelosterrenoenvolventequery
    suelosterrenoquery = "
SELECT 
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, 
    GrossArea, ExtBoundCond, ZoneIndex 
FROM 
    (#{superficiesexternasquery}) AS surf 
    WHERE surf.ClassName == 'Floor' AND surf.ExtBoundCond == -1 "
    suelosterrenoquery
  end
  
  def self.huecosenvolventequery
    huecosenvolvente = "
SELECT 
    * 
FROM Surfaces surf 
    INNER JOIN  ( #{zonashabitablesquery} ) AS zones 
    ON surf.ZoneIndex = zones.ZoneIndex 
    WHERE surf.ClassName == 'Window' AND surf.ExtBoundCond == 0 "
    huecosenvolvente
  end

end
