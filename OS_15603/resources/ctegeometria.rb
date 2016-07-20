# coding: utf-8

module CTEgeo

  # Métodos auxiliares ------------------------------------------------
  def self.msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end

  def self.verificaBusqueda(log, nombre,  search, query)
    if search.empty?
      msg(log, "     #{nombre}: *#{query}*\n búsqueda vacía\n")
      return false
    else
      msg(log, "     #{nombre}: correcto\n")
      return search.get
    end
  end
  # Fin métodos auxiliares ---------------------------------------------

  def self.zonashabitables(sqlFile)
    search = sqlFile.execAndReturnVectorOfString("#{zonashabitablesquery}")
    return (if search.empty? then false else search.get end)
  end

  def self.superficiehabitable(sqlFile)
    query = "SELECT SUM(FloorArea) FROM (#{zonashabitablesquery}) "
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
  end

  def self.volumenhabitable(sqlFile)
    query = "SELECT SUM(Volume) FROM  (#{zonashabitablesquery})"
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
  end

  def self.zonasnohabitables(sqlFile)
    search = sqlFile.execAndReturnVectorOfString("#{zonasnohabitablesquery}")
    return (if search.empty? then false else search.get end)
  end

  def self.superficienohabitable(sqlFile)
    query = "SELECT SUM(FloorArea) FROM (#{zonasnohabitablesquery}) "
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
  end

  def self.volumennohabitable(sqlFile,  log = 'CTEgeo')
    query = "SELECT SUM(Volume) FROM (#{CTEgeo.zonasnohabitablesquery})"
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
  end

  def self.superficiescandidatas(sqlFile)
    search = sqlFile.execAndReturnVectorOfString(superficiescandidatasquery)
    return (if search.empty? then false else search.get end)
  end

  def self.superficiesexternas(sqlFile)
    log = 'CTEgeo'
    superficiesexternassearch = sqlFile.execAndReturnVectorOfString(superficiesexternasquery)
    superficiesexternas = verificaBusqueda(log, 'superficies externas', superficiesexternassearch, superficiesexternasquery)
    return superficiesexternas
  end

  def self.superficiesinternas(sqlFile,  log = 'CTEgeo')
    superficiesinternassearch = sqlFile.execAndReturnVectorOfString(superficiesinternasquery)
    superficiesinternas = verificaBusqueda(log, 'superficies internas',superficiesinternassearch,superficiesinternasquery )
    return superficiesinternas
  end

  def self.superficiescontacto(sqlFile,  log = 'CTEgeo')
    superficiescontactosearch = sqlFile.execAndReturnVectorOfString(superficiescontactoquery)
    superficiescontacto = verificaBusqueda(log, 'superficies de contacto', superficiescontactosearch, superficiescontactoquery)
    return superficiescontacto
  end

  def self.areaexterior(sqlFile, log = 'CTEgeo')
    areaexteriorquery = "SELECT SUM(GrossArea) FROM (#{superficiesexternasquery})"
    areaexteriorsearch = sqlFile.execAndReturnFirstDouble(areaexteriorquery)
    areaexterior = verificaBusqueda(log, 'area exterior de la envolvente', areaexteriorsearch, areaexteriorquery)
    return areaexterior
  end

  def self.areainterior(sqlFile, log = 'CTEgeo')
    areainteriorquery = "SELECT SUM(GrossArea) FROM (#{superficiescontactoquery})"
    areainteriorsearch = sqlFile.execAndReturnFirstDouble(areainteriorquery)
    areainterior = verificaBusqueda(log, 'area interior de la envolvente', areainteriorsearch, areainteriorquery)
    return  areainterior
  end


  def self.zonashabitablesquery
    zonashabitablesquery =  "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE zl.Name NOT LIKE 'CTE_N%' "
    zonashabitablesquery
  end

  def self.zonasnohabitablesquery
    zonasnohabitablesquery =  "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE zl.Name LIKE 'CTE_N%'  "
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
