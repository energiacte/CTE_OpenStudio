# coding: utf-8

module CTEgeo
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

  def self.volumennohabitable(sqlFile)
    query = "SELECT SUM(Volume) FROM (#{CTEgeo.zonasnohabitablesquery})"
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
  end

  def self.superficiescandidatas(sqlFile)
    search = sqlFile.execAndReturnVectorOfString(superficiescandidatasquery)
    return (if search.empty? then false else search.get end)
  end

  def self.superficiesexternas(sqlFile)
    search = sqlFile.execAndReturnVectorOfString(superficiesexternasquery)
    return (if search.empty? then false else search.get end)
  end

  def self.superficiesinternas(sqlFile)
    search = sqlFile.execAndReturnVectorOfString(superficiesinternasquery)
    return (if search.empty? then false else search.get end)
  end

  def self.superficiescontacto(sqlFile)
    search = sqlFile.execAndReturnVectorOfString(superficiescontactoquery)
    return (if search.empty? then false else search.get end)
  end

  def self.areaexterior(sqlFile)
    query = "SELECT SUM(GrossArea) FROM (#{superficiesexternasquery})"
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
  end

  def self.areainterior(sqlFile)
    query = "SELECT SUM(GrossArea) FROM (#{superficiescontactoquery})"
    search = sqlFile.execAndReturnFirstDouble(query)
    return (if search.empty? then false else search.get end)
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
