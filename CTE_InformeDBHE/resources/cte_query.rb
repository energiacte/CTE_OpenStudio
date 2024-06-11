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
  ZONAS ||= "
SELECT
    ZoneIndex, ZoneName, CeilingHeight, Volume, FloorArea
FROM 
    Zones
WHERE
    ZoneName in "

  ZONASHABITABLES ||= "#{CTE_Query::ZONAS} %s" # hay que añadirle la lista de las zonas habitables

  ZONASNOHABITABLES ||= "#{CTE_Query::ZONAS} %s" # hay que añadirle la lista de las zonas no habitables

  INDICE_ZONAS ||= "
  SELECT
      ZoneIndex
  FROM 
      Zones
  WHERE
      ZoneName in "

  #   ZONASHABITABLES ||= "
  # SELECT
  #     ZoneIndex, ZoneName, CeilingHeight, Volume, FloorArea, ZoneListIndex, Name
  # FROM Zones
  #     LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
  #     LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
  # WHERE
  #     zl.Name NOT LIKE 'CTE_N%'
  # "

  #   ZONASNOHABITABLES ||= "
  # SELECT
  #     ZoneIndex, ZoneName, CeilingHeight, Volume, FloorArea, ZoneListIndex, Name
  # FROM
  #     Zones
  #     LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
  #     LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
  # WHERE
  #     zl.Name LIKE 'CTE_N%'
  # "

  #CTE_Query.listaZonasHabitables(model) POR CTE_Query::ZONASHABITABLES

  ZONASHABITABLES_SUPERFICIES ||= "
WITH
    zonashabitables AS (#{CTE_Query::ZONASHABITABLES})
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, GrossArea, Azimuth,
    ExtBoundCond, surf.ExtWind, surf.ZoneIndex AS ZoneIndex
FROM
    Surfaces surf
    INNER JOIN zonashabitables AS zones USING (ZoneIndex)
"

  #   # XXX: No está claro que Internal Mass sea un SurfaceType
  ENVOLVENTE_SUPERFICIES_EXTERIORES ||= "
WITH
    superficieshabitables AS (#{CTE_Query::ZONASHABITABLES_SUPERFICIES})
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area, Azimuth, 
    GrossArea, ExtBoundCond, ZoneIndex, ExtWind
FROM
    superficieshabitables
WHERE
    ClassName NOT IN ('Internal Mass', 'Shading')
    AND ExtBoundCond IN (-1, 0)
    AND SurfaceName NOT LIKE '%%_pt%%'
"

  ENVOLVENTE_SUPERFICIES_INTERIORES ||= "
WITH
    superficieshabitables AS (#{CTE_Query::ZONASHABITABLES_SUPERFICIES}),
    zonasnohabitables AS (#{CTE_Query::ZONASNOHABITABLES}),
    superficiesinternasindex AS (
        SELECT
            SurfaceIndex
        FROM
            superficieshabitables
        WHERE
            ClassName NOT IN ('Internal Mass', 'Shading')
            AND ExtBoundCond NOT IN (-1, 0)
            AND SurfaceName NOT LIKE '%%_pt%%'
     )
SELECT
    surf.SurfaceIndex AS SurfaceIndex, SurfaceName,
    ConstructionIndex, ClassName, Area, GrossArea, Azimuth, ExtBoundCond,
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

  
#   def CTE_Query.envolvente_superficies_exteriores(model, sqlFile)

#   end

#   def CTE_Query.envolvente_exterior_construcciones(model, sqlFile)
#     ENVOLVENTE_EXTERIOR_CONSTRUCCIONES ||= "
# WITH superficiesexteriores AS ( #{CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES})
# SELECT
#     *
# FROM
#     superficiesexteriores
#     LEFT OUTER JOIN Constructions cons USING(ConstructionIndex)
# "
#   end

  def CTE_Query.tipos_zonas(model)
    zonas_por_tipos = { "habitable" => [], "no_habitable" => [] }

    model.getSpaceTypes.each do |space_type| # array de espacios del mismo tipo
      if not space_type.spaces.empty? # se quedan solo los arrays con contenido
        # el tipo de espacio empieza por CTE_NO si es no habitable
        kind = space_type.nameString.start_with?("CTE_NO")? "no_habitable": "habitable"
        space_type.spaces.each do |space|
          name = space.thermalZone.empty? ? space.name.get : space.thermalZone.get.nameString
          zonas_por_tipos[kind] << name
        end
      end
    end
    return zonas_por_tipos
  end

  def CTE_Query.indiceZonasHabitables(model, sqlFile)
    zonasHabitables = CTE_Query.zonasHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    sqlQuery = ZONAS + cadena_campos
    sqlQuery = sqlQuery % zonasHabitables
    result = sqlFile.execAndReturnVectorOfDouble("#{sqlQuery}")
    return (result != false) ? result : 0
  end

  def CTE_Query.listaZonasHabitables(model)
    zonasHabitables = CTE_Query.zonasHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    cadena = cadena_campos % zonasHabitables
    return cadena
  end

  def CTE_Query.listaZonasHabitablesYNoHabitables(model)
    zonasHabitables = CTE_Query.listaZonasHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    zonasNoHabitables = CTE_Query.listaZonasNoHabitables(model)
    return [zonasHabitables, zonasNoHabitables]
  end

  def CTE_Query.listaZonasNoHabitables(model)
    zonasNoHabitables = CTE_Query.zonasNoHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasNoHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    cadena = cadena_campos % zonasNoHabitables
    return cadena
  end

  def CTE_Query.zonasHabitables(model)
    # devuelve un array de strings que se puede usar directamente para una busqueda SQL con WHERE IN (array)
    #  {"habitable"=>["Thermal Zone: P1", "Thermal Zone: P2", "Thermal Zone: BAJA 1"], "no_habitable"=>["Thermal Zone: SOTANO 1"]}
    zonasHabitables = CTE_Query.tipos_zonas(model)["habitable"].map { |string| '\'' + string.upcase + '\'' }
    return zonasHabitables
  end

  def CTE_Query.zonasNoHabitables(model)
    zonasNoHabitables = CTE_Query.tipos_zonas(model)["no_habitable"].map { |string| '\'' + string.upcase + '\'' }
    return zonasNoHabitables
  end

  def getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  # def CTE_Query.superficieHabitable(sqlFile)
  #   result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{CTE_Query::ZONASHABITABLES})"))
  #   return (result != false) ? result : 0
  # end

  # sqlFile.execAndReturnFirstDouble("
  #   # SELECT
  #   #   SUM(FloorArea)
  #   # FROM Zones
  #   #   LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
  #   #   LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
  #   # WHERE zl.Name NOT LIKE 'CTE_N%' ").get

  

  def CTE_Query.superficieHabitable(model, sqlFile)
    zonasHabitables = CTE_Query.zonasHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    sqlQuery = ZONAS + cadena_campos
    sqlQuery = sqlQuery % zonasHabitables
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{sqlQuery})"))
    return (result != false) ? result : 0
  end

  def CTE_Query.getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  def CTE_Query.envolventeExteriorConstrucciones(model, sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES % listaZonasHabitables(model)))
    return (result != false) ? result : []
  end

  def CTE_Query.volumenHabitable(model, sqlFile)
    zonasHabitables = CTE_Query.zonasHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    sqlQuery = ZONAS + cadena_campos
    sqlQuery = sqlQuery % zonasHabitables
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(CeilingHeight * FloorArea) FROM (#{sqlQuery})"))
    return (result != false) ? result : 0
  end

  def CTE_Query.superficieNoHabitable(model, sqlFile)
    zonasNoHabitables = CTE_Query.zonasNoHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasNoHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    sqlQuery = ZONAS + cadena_campos
    sqlQuery = sqlQuery % zonasNoHabitables
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(FloorArea) FROM (#{sqlQuery})"))
    return (result != false) ? result : 0
  end

  def CTE_Query.volumenNoHabitable(model, sqlFile)
    zonasNoHabitables = CTE_Query.zonasNoHabitables(model) #Array para introducir en el WHERE IN de la búsqueda sql
    cadena_campos = ["%s"] * zonasNoHabitables.length
    cadena_campos = "(#{cadena_campos.join(", ")})"
    sqlQuery = ZONAS + cadena_campos
    sqlQuery = sqlQuery % zonasNoHabitables
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(CeilingHeight * FloorArea) FROM (#{sqlQuery})"))
    return (result != false) ? result : 0
    # result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(CeilingHeight * FloorArea) FROM (#{CTE_Query::ZONASNOHABITABLES})"))
    # return (result != false) ? result : 0
  end

  def CTE_Query.envolventeSuperficiesExteriores(model, sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES % "#{listaZonasHabitables(model)}"))
    return (result != false) ? result : []
  end

  def CTE_Query.envolventeSuperficiesInteriores(model, sqlFile)    
    result = getValueOrFalse(sqlFile.execAndReturnVectorOfString(CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES % listaZonasHabitablesYNoHabitables(model)))
    return (result != false) ? result : []
  end

  def CTE_Query.envolventeAreaExterior(model, sqlFile)
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Area) FROM (#{CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES % listaZonasHabitables(model)})"))
    return (result != false) ? result : 0
  end

  def CTE_Query.envolventeAreaInterior(model, sqlFile)
    # necesita las zonas habitables y las no habitables
    result = getValueOrFalse(sqlFile.execAndReturnFirstDouble("SELECT SUM(Area) FROM (#{CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES % listaZonasHabitablesYNoHabitables(model)})"))
    return (result != false) ? result : 0
  end

  def CTE_Query.query_envolvente_superficies_exteriores(model, sqlFile)
    return "#{CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES % listaZonasHabitables(model)}"
  end

  def CTE_Query.query_envolvente_superficies_interiores(model, sqlFile)
    return "#{CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES % listaZonasHabitablesYNoHabitables(model)}"
  end

  def CTE_Query.query_zonashabitables_superficies(model, sqlFile)
    return "#{CTE_Query::ZONASHABITABLES_SUPERFICIES % listaZonasHabitables(model)}"
  end

  def CTE_Query.query_zonashabitables(model, sqlFile)
    return "#{CTE_Query::ZONASHABITABLES % listaZonasHabitables(model)}"
  end

  def CTE_Query.query_envolvente_exterior_construcciones(model, sqlFile)
    return "#{CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES % listaZonasHabitables(model)}"
  end

end
