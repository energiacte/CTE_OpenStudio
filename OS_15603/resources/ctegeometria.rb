# coding: utf-8

module CTEgeo
  def self.getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  def self.zonashabitables(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnVectorOfString("#{zonashabitablesquery}"))
  end

  def self.superficiehabitable(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{zonashabitablesquery})"))
  end

  def self.volumenhabitable(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Volume) FROM  (#{zonashabitablesquery})"))
  end

  def self.zonasnohabitables(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnVectorOfString("#{zonasnohabitablesquery}"))
  end

  def self.superficienohabitable(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{zonasnohabitablesquery})"))
  end

  def self.volumennohabitable(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Volume) FROM (#{zonasnohabitablesquery})"))
  end

  def self.superficiesexternas(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnVectorOfString(superficiesexternasquery))
  end

  def self.superficiescontacto(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnVectorOfString(superficiescontactoquery))
  end

  def self.areaexterior(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(GrossArea) FROM (#{superficiesexternasquery})"))
  end

  def self.areainterior(sqlFile)
    return getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(GrossArea) FROM (#{superficiescontactoquery})"))
  end


  def self.zonashabitablesquery
    # Zonas habitables
    return "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE zl.Name NOT LIKE 'CTE_N%' "
  end

  def self.zonasnohabitablesquery
    # Zonas no habitables
    return "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE zl.Name LIKE 'CTE_N%' "
  end

  def self.superficiesquery
    # Superficies de las zonas habitables
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, GrossArea,
    ExtBoundCond, surf.ZoneIndex
FROM
    Surfaces surf
    INNER JOIN ( #{zonashabitablesquery} ) AS zones
        ON surf.ZoneIndex = zones.ZoneIndex"
  end

  def self.superficiescandidatasquery
    # Superficies que podrían formar parte de la envolvente térmica
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{superficiesquery}) AS surf
    WHERE (surf.ClassName NOT IN ('Window', 'Internal Mass')) "
  end

  def self.superficiesexternasquery
    # Superficies exteriores de la envolvente térmica que son exteriores
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{superficiescandidatasquery})
    WHERE (ExtBoundCond IN (-1, 0)) "
  end

  def self.superficiesinternasquery
    # Superficies interiores de los espacios habitables
    return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM (#{superficiescandidatasquery})
      WHERE (ExtBoundCond NOT IN (-1, 0))"
  end

  def self.superficiescontactoquery
    # Superficies interiores de la envolvente térmica
    return "
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
    INNER JOIN  ( #{zonashabitablesquery} ) AS zones
    ON surf.ZoneIndex = zones.ZoneIndex
    WHERE (surf.ClassName == 'Window' AND surf.ExtBoundCond == 0) "
  end

end
