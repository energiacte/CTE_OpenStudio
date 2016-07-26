# coding: utf-8

    # Queries para localizar superficies y elementos
    # ExtBoundCond: 0=exterior, -1=terreno, numero=otra superficie
    # Clases en https://github.com/NREL/EnergyPlus/blob/f8be4f0d31d5988a52c515ac5e0076a7b8b0a322/src/EnergyPlus/DataSurfaces.cc#L442
    # ClassName puede ser ['Wall', 'Floor', 'Roof', 'Window', 'Door', 'Glass Door', 'TubularDaylightDome', 'TubularDaylighDiffuser', 'Internal Mass', 'Shading', 'Detached Shading:Building', 'Detached Shading:Fixed', 'Invalid/Unknown']
module CTE_Query
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
    INNER JOIN ( #{ CTE_Query::ZONASHABITABLES } ) AS zones
        ON surf.ZoneIndex = zones.ZoneIndex"

  # XXX: No está claro que Internal Mass sea un SurfaceType
  ENVOLVENTE_SUPERFICIES_EXTERIORES = "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
    WHERE (surf.ClassName NOT IN ('Internal Mass', 'Shading') AND surf.ExtBoundCond IN (-1, 0)) "


  ENVOLVENTE_SUPERFICIES_INTERIORES = "
SELECT
    surf.SurfaceIndex AS SurfaceIndex, SurfaceName,
    ConstructionIndex, ClassName, Area, GrossArea, ExtBoundCond,
    surf.ZoneIndex AS ZoneIndex
FROM (  SELECT
            SurfaceIndex
        FROM
            (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
            WHERE (surf.ClassName NOT IN ('Internal Mass', 'Shading') AND ExtBoundCond NOT IN (-1, 0))
            ) AS internas
    INNER JOIN Surfaces surf ON surf.ExtBoundCond = internas.SurfaceIndex
    INNER JOIN (#{ CTE_Query::ZONASNOHABITABLES }) AS znh ON surf.ZoneIndex = znh.ZoneIndex"

  def CTE_Query.getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  def CTE_Query.zonasHabitables(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ZONASHABITABLES))
    return (result != false) ? result : []
  end

  def CTE_Query.superficieHabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{ CTE_Query::ZONASHABITABLES })"))
    return (result != false) ? result : 0
  end

  def CTE_Query.volumenHabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Volume) FROM  (#{ CTE_Query::ZONASHABITABLES })"))
    return (result != false) ? result : 0
  end

  def CTE_Query.zonasNoHabitables(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ZONASNOHABITABLES))
    return (result != false) ? result : []
  end

  def CTE_Query.superficieNoHabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{ CTE_Query::ZONASNOHABITABLES })"))
    return (result != false) ? result : 0
  end

  def CTE_Query.volumenNoHabitable(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Volume) FROM (#{ CTE_Query::ZONASNOHABITABLES })"))
    return (result != false) ? result : 0
  end

  def CTE_Query.envolventeSuperficiesExteriores(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES))
    return (result != false) ? result : []
  end

  def CTE_Query.envolventeSuperficiesInteriores(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES))
    return (result != false) ? result : []
  end

  def CTE_Query.envolventeAreaExterior(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Area) FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })"))
    return (result != false) ? result : 0
  end

  def CTE_Query.envolventeAreaInterior(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Area) FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES })"))
    return (result != false) ? result : 0
  end
end
