# coding: utf-8

module CTEgeo

  module Query
    ZONASHABITABLES = "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE zl.Name NOT LIKE 'CTE_N%' "

    ZONASNOHABITABLES = "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE zl.Name LIKE 'CTE_N%' "

      ZONASHABITABLES_SUPERFICIES = "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, GrossArea,
    ExtBoundCond, surf.ZoneIndex AS ZoneIndex
FROM
    Surfaces surf
    INNER JOIN ( #{ CTEgeo::Query::ZONASHABITABLES } ) AS zones
        ON surf.ZoneIndex = zones.ZoneIndex"

  end


  def self.getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  def self.zonasHabitables(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString("#{ CTEgeo::Query::ZONASHABITABLES }"))
    return (result != false) ? result : []
  end

  def self.superficieHabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{ CTEgeo::Query::ZONASHABITABLES })"))
    return (result != false) ? result : 0
  end

  def self.volumenHabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Volume) FROM  (#{ CTEgeo::Query::ZONASHABITABLES })"))
    return (result != false) ? result : 0
  end

  def self.zonasNoHabitables(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString("#{ CTEgeo::Query::ZONASNOHABITABLES }"))
    return (result != false) ? result : []
  end

  def self.superficienohabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{ CTEgeo::Query::ZONASNOHABITABLES })"))
    return (result != false) ? result : 0
  end

  def self.volumennohabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Volume) FROM (#{ CTEgeo::Query::ZONASNOHABITABLES })"))
    return (result != false) ? result : 0
  end

  def self.superficiesexternas(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(superficiesexternasquery))
    return (result != false) ? result : []
  end

  def self.superficiescontacto(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(superficiescontactoquery))
    return (result != false) ? result : []
  end

  def self.areaexterior(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(GrossArea) FROM (#{superficiesexternasquery})"))
    return (result != false) ? result : 0
  end

  def self.areainterior(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(GrossArea) FROM (#{superficiescontactoquery})"))
    return (result != false) ? result : 0
  end

  def self.superficiesexternasquery
    # Superficies exteriores de la envolvente térmica que son exteriores
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{ CTEgeo::Query::ZONASHABITABLES_SUPERFICIES }) AS surf
    WHERE (surf.ClassName NOT IN ('Window', 'Internal Mass') AND surf.ExtBoundCond IN (-1, 0)) "
  end

  def self.superficiescontactoquery
    # Superficies interiores de la envolvente térmica
    return "
SELECT
    surf.SurfaceIndex AS SurfaceIndex, SurfaceName,
    ConstructionIndex, ClassName, Area, GrossArea, ExtBoundCond,
    surf.ZoneIndex AS ZoneIndex
FROM (  SELECT
            SurfaceIndex
        FROM
            (#{ CTEgeo::Query::ZONASHABITABLES_SUPERFICIES }) AS surf
            WHERE (surf.ClassName NOT IN ('Window', 'Internal Mass') AND ExtBoundCond NOT IN (-1, 0))
     ) AS internas
    INNER JOIN Surfaces surf ON surf.ExtBoundCond = internas.SurfaceIndex
    INNER JOIN (#{ CTEgeo::Query::ZONASNOHABITABLES }) AS znh ON surf.ZoneIndex = znh.ZoneIndex"
  end

  def self.murosexterioresenvolventequery
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{superficiesexternasquery}) AS surf
    WHERE (surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0) "
  end

  def self.cubiertassexterioresenvolventequery
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{superficiesexternasquery}) AS surf
    WHERE (surf.ClassName == 'Roof' AND surf.ExtBoundCond == 0) "
  end

  def self.suelosterrenoenvolventequery
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{superficiesexternasquery}) AS surf
    WHERE (surf.ClassName == 'Floor' AND surf.ExtBoundCond == -1) "
  end

  def self.huecosenvolventequery
    # XXX: No incluye lucernarios!
    return "
SELECT
    *
FROM Surfaces surf
    INNER JOIN  ( #{ CTEgeo::Query::ZONASHABITABLES } ) AS zones
    ON surf.ZoneIndex = zones.ZoneIndex
    WHERE (surf.ClassName == 'Window' AND surf.ExtBoundCond == 0) "
  end

end
