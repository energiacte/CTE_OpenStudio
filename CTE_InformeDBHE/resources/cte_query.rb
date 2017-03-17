# -*- coding: utf-8 -*-
#
# Copyright (c) 2016 Ministerio de Fomento
#                    Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author(s): Rafael Villar Burke <pachi@ietcc.csic.es>,
#            Daniel Jiménez González <dani@ietcc.csic.es>
#            Marta Sorribes Gil <msorribes@ietcc.csic.es>

# Queries para localizar superficies y elementos
# ExtBoundCond: 0=exterior, -1=terreno, numero=otra superficie
# Clases en https://github.com/NREL/EnergyPlus/blob/f8be4f0d31d5988a52c515ac5e0076a7b8b0a322/src/EnergyPlus/DataSurfaces.cc#L442
# ClassName puede ser ['Wall', 'Floor', 'Roof', 'Window', 'Door', 'Glass Door', 'TubularDaylightDome', 'TubularDaylighDiffuser', 'Internal Mass', 'Shading', 'Detached Shading:Building', 'Detached Shading:Fixed', 'Invalid/Unknown']
module CTE_Query
  ZONASHABITABLES ||= "
SELECT
    ZoneIndex, ZoneName, CeilingHeight, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE
    zl.Name NOT LIKE 'CTE_N%'
"

  ZONASNOHABITABLES ||= "
SELECT
    ZoneIndex, ZoneName, CeilingHeight, Volume, FloorArea, ZoneListIndex, Name
FROM
    Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
WHERE
    zl.Name LIKE 'CTE_N%'
"

  ZONASHABITABLES_SUPERFICIES ||= "
WITH
    zonashabitables AS (#{ CTE_Query::ZONASHABITABLES })
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, GrossArea,
    ExtBoundCond, surf.ExtWind, surf.ZoneIndex AS ZoneIndex
FROM
    Surfaces surf
    INNER JOIN zonashabitables AS zones USING (ZoneIndex)
"

  # XXX: No está claro que Internal Mass sea un SurfaceType
  ENVOLVENTE_SUPERFICIES_EXTERIORES ||= "
WITH
    superficieshabitables AS (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES })
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex, ExtWind
FROM
    superficieshabitables
WHERE
    ClassName NOT IN ('Internal Mass', 'Shading')
    AND ExtBoundCond IN (-1, 0)
    AND SurfaceName NOT LIKE '%_pt%'
"


  ENVOLVENTE_SUPERFICIES_INTERIORES ||= "
WITH
    superficieshabitables AS (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }),
    zonasnohabitables AS (#{ CTE_Query::ZONASNOHABITABLES }),
    superficiesinternasindex AS (
        SELECT
            SurfaceIndex
        FROM
            superficieshabitables
        WHERE
            ClassName NOT IN ('Internal Mass', 'Shading')
            AND ExtBoundCond NOT IN (-1, 0)
            AND SurfaceName NOT LIKE '%_pt%'
     )
SELECT
    surf.SurfaceIndex AS SurfaceIndex, SurfaceName,
    ConstructionIndex, ClassName, Area, GrossArea, ExtBoundCond,
    surf.ZoneIndex AS ZoneIndex
FROM
    superficiesinternasindex AS internas
    INNER JOIN Surfaces surf ON surf.ExtBoundCond = internas.SurfaceIndex
    INNER JOIN zonasnohabitables AS znh USING (ZoneIndex)
"

  ENVOLVENTE_EXTERIOR_CONSTRUCCIONES ||= "
WITH superficiesexteriores AS ( #{CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES})
SELECT
    *
FROM
    superficiesexteriores
    LEFT OUTER JOIN Constructions cons USING(ConstructionIndex)
"

  def CTE_Query.getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  def CTE_Query.envolventeExteriorConstrucciones(sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES))
    return (result != false) ? result : []
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
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(CeilingHeight * FloorArea) FROM  (#{ CTE_Query::ZONASHABITABLES })"))
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
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(CeilingHeight * FloorArea) FROM (#{ CTE_Query::ZONASNOHABITABLES })"))
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
