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

require 'set'
require 'digest/md5'

RESISTENCIA_PT ||= 1.0
ALTURA_SUPERFICIE_PT ||= 2.0

def verticeID(point3d, origen_espacio)
  # Id de vértice

  # los puntos de una superficie están en coordenadas locales respecto al origen del espacio
  # para convertir un punto en un vector hay que restarle cero
  punto_cero = OpenStudio::Point3d.new(0, 0, 0)
  vector_local = point3d - punto_cero
  v_glob = vector_local + origen_espacio

  return Digest::MD5.hexdigest("#{v_glob.x.round(2)} #{v_glob.y.round(2)} #{v_glob.z.round(2)}")
end


def creaConstruccionPT(model, nombre, ttl)
  # Crea construcción para PT con un material genérico ("materialPT")
  # y un nombre que es (tipo)+_PSI(valor psi con dos decimales)

  # Crear un nuevo material
  material = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
  material.setName('materialPT')
  material.setThermalResistance(RESISTENCIA_PT)
  material.setThermalAbsorptance(0.9)
  material.setSolarAbsorptance(0.7)
  material.setVisibleAbsorptance(0.7)

  # Creamos una nueva construccion
  layers = OpenStudio::Model::MaterialVector.new
  layers << material
  nombreconstruction = nombre + '_' + "PSI#{ttl.round(2)}"
  construction = OpenStudio::Model::Construction.new(model)
  construction.setName(nombreconstruction)
  standards_info = construction.standardsInformation
  standards_info.setIntendedSurfaceType('')
  standards_info.setStandardsConstructionType('')

  construction.setLayers(layers)

  return construction
end

def getExteriorVertices(runner, spaces)
  # Set de IDs de los vértices exteriores de las superficies de los espacios

  runner.registerInfo('PTS: localizando vertices exteriores')
  vertices_exteriores = Set.new
  spaces.each do |space|
    # tiene que ser un vector porque lo voy a sumar
    origen = OpenStudio::Vector3d.new(space.xOrigin, space.yOrigin, space.zOrigin)
    space.surfaces.each do |surface|
      next unless surface.surfaceType == 'Wall' && surface.outsideBoundaryCondition == 'Outdoors'

      surface.vertices.each do |point3d|
        vertices_exteriores << verticeID(point3d, origen)
      end
    end
  end
  return vertices_exteriores
end

def getFloors(runner, spaces)
  # Diccionario por espacios que contiene un diccionario que devuelve una lista de de forjados
  # (superficies de suelo o techo) para cada tipo de puente térmico de frente de forjado
  runner.registerInfo('-- captura de forjados por tipo (getFloors) --')
  forjados_espacios = {}
  spaces.each do |space|
    forjados_espacios[space.name.to_s] = {
      ptFrenteForjado: [],
      ptForjadoExterior: [],
      ptSoleraTerreno: [],
      ptForjadoCubierta: [],
      ptContornoHuecos: []
    }

    space.surfaces.each do |surface|
      next if surface.surfaceType == 'Wall'

      type = surface.surfaceType
      out_condition = surface.outsideBoundaryCondition
      # forjados interiores:
      if %w[Floor RoofCeiling].include?(type) && out_condition == 'Surface'
        forjados_espacios[space.name.to_s][:ptFrenteForjado] << surface
      # suelos exteriores
      elsif type == 'Floor' && out_condition == 'Outdoors'
        forjados_espacios[space.name.to_s][:ptForjadoExterior] << surface
      # suelos en contacto con el terreno
      elsif type == 'Floor' && out_condition == 'Ground'
        forjados_espacios[space.name.to_s][:ptSoleraTerreno] << surface
      # cubiertas
      elsif type == 'RoofCeiling' && out_condition == 'Outdoors'
        forjados_espacios[space.name.to_s][:ptForjadoCubierta] << surface
      elsif type == 'Floor' && out_condition == 'Adiabatic'
        # no consdieramos estos
      else
        runner.registerWarning("No se incluye puente térmico para la superficie '#{surface.name}': #{type} -> #{out_condition}")
      end
    end
  end
  return forjados_espacios
end

def getSpaceByName(_runner, model, name)
  model.getModelObjectsByName(name, true).each do |objeto|
    return objeto.to_Space.get if objeto.iddObjectType.valueDescription == 'OS:Space'
  end
end

def medicionPTForjados(runner, model)
  # Calcula una lista de tuplas (nombre de espacio, diccionario de PTs por tipo)
  # el diccionario de PTs indica la longitud de cada tipo de puente térmico que existe
  # para ese espacio
  runner.registerInfo('PTs: midiendo forjados')
  vertices_exteriores = getExteriorVertices(runner, model.getSpaces)
  forjados_por_espacios = getFloors(runner, model.getSpaces)
  salida = []
  forjados_por_espacios.each do |space_name, forjados_por_tipo|
    space = getSpaceByName(runner, model, space_name)
    origen = OpenStudio::Vector3d.new(space.xOrigin, space.yOrigin, space.zOrigin)
    long_hash = {}
    forjados_por_tipo.each do |tipo, forjados|
      longitud_puente = 0
      forjados.each do |forjado|
        vertice_previo = forjado.vertices[-1]
        forjado.vertices.each do |vertice_actual|
          es_exterior = vertices_exteriores.include?(verticeID(vertice_actual, origen))
          es_previo = vertices_exteriores.include?(verticeID(vertice_previo, origen))
          if es_previo && es_exterior # los dos son exteriores
            coef = tipo == :ptFrenteForjado ? 0.5 : 1.0
            longitud_puente += coef * (vertice_actual - vertice_previo).length
          end
          vertice_previo = vertice_actual
        end
      end
      long_hash[tipo] = longitud_puente.to_f
    end
    salida << [space_name, long_hash]
  end
  return salida
end

def getPerimeter(sub_surface)
  # Calcula el perímetro de una superficie (un hueco en este caso)
  vertices = sub_surface.vertices
  verticesp = vertices + [vertices[0]]
  long = 0
  (0..vertices.count - 1).each do |cnt|
    long += (verticesp[cnt + 1] - verticesp[cnt]).length
  end
  return long
end

def medicionPTContornoHuecos(runner, model)
  # Lista de tuplas (nombre espacio, perímetro de contornos de huecos)
  runner.registerInfo('PTs: midiendo contornos de huecos')
  salida = []
  model.getSpaces.each do |space|
    long = 0
    space.surfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        long += getPerimeter(subs_urface) if sub_surface.subSurfaceType.include?('Window')
      end
    end
    salida << [space.name.to_s, long]
  end
  return salida
end

def ttlinealusuario(runner, user_arguments)
  # Devuelve valores de TTL definidos por el usuario, por tipo
  psi_forjado_cubierta = runner.getStringArgumentValue('CTE_Psi_forjado_cubierta', user_arguments).to_f
  psi_frente_forjado = runner.getStringArgumentValue('CTE_Psi_frente_forjado', user_arguments).to_f
  psi_solera_terreno = runner.getStringArgumentValue('CTE_Psi_solera_terreno', user_arguments).to_f
  psi_forjado_exterior = runner.getStringArgumentValue('CTE_Psi_forjado_exterior', user_arguments).to_f
  psi_contorno_huecos = runner.getStringArgumentValue('CTE_Psi_contorno_huecos', user_arguments).to_f

  {
    ptForjadoCubierta: psi_forjado_cubierta,
    ptFrenteForjado: psi_frente_forjado,
    ptSoleraTerreno: psi_solera_terreno,
    ptForjadoExterior: psi_forjado_exterior,
    ptContornoHuecos: psi_contorno_huecos
  }
end

def getSpaceBarycenter(space)
  # Devuelve coordenadas del baricentro de la primera superficie de tipo Floor del espacio
  # devuelve el primer Floor que encuentre, independientemente de su OutBoundCond
  surface = space.surfaces.find { surface.surfaceType == 'Floor' }

  baricentro = OpenStudio::Vector3d.new(0, 0, 0)
  cero = OpenStudio::Point3d.new(0, 0, 0)
  surface.vertices.each do |v|
    baricentro += (v - cero)
  end
  n = surface.vertices.count

  [baricentro.x / n, baricentro.y / n, baricentro.z / n]
end

def creaSuperficiePT(model, space, area, cons_pt, direccion)
  # Crea una superficie desplazada 100m en y respecto al baricentro del espacio
  # con un alto fijo y una superficie dada y la construcción de PT indicada
  # La dirección modifica el sentido en el que se genera el ancho.
  x, y, z = getSpaceBarycenter(space)
  alto = ALTURA_SUPERFICIE_PT
  ancho = area / alto
  ancho = -1 * ancho unless direccion.include?('+')
  x2 = x
  y2 = y
  x2 += ancho if direccion.include?('x')
  y2 += ancho if direccion.include?('y')
  # Move surfaces 100m to the north (y)
  vertices = []
  vertices << OpenStudio::Point3d.new(x, y + 100, z - alto)
  vertices << OpenStudio::Point3d.new(x2, y2 + 100, z - alto)
  vertices << OpenStudio::Point3d.new(x2, y2 + 100, z)
  vertices << OpenStudio::Point3d.new(x, y + 100, z)
  superficie = OpenStudio::Model::Surface.new(vertices, model)
  superficie.setSunExposure('NoSun')
  superficie.setWindExposure('NoWind')
  superficie.setOutsideBoundaryCondition('Exterior')
  superficie.setSpace(space)
  superficie.setConstruction(cons_pt)

  return superficie
end

def setThermalBridges(runner, model, ptForjados, ptHuecos, ttl_puentesTermicos, construcciones)
  # Genera las superficies correspondientes a los PTs del edificio, tanto de frentes de forjado
  # como de contornos de huecos

  # Superficies de PTs de forjados
  direccion = {
    ptFrenteForjado: 'x+',
    ptForjadoCubierta: 'x-',
    ptForjadoExterior: 'y+',
    ptSoleraTerreno: 'x-'
  }
  ptForjados.each do |space_name, long_hash|
    space = getSpaceByName(runner, model, space_name)
    long_hash.each do |key, longitud|
      next if longitud == 0.0

      area = longitud * ttl_puentesTermicos[key] * RESISTENCIA_PT
      sup_pt = creaSuperficiePT(model, space, area, construcciones[key], direccion[key])
      sup_pt.setName("#{space_name}_#{key}")
    end
  end

  # Superficies de PTs de huecos
  ptHuecos.each do |space_name, longitud|
    next if longitud == 0.0

    space = getSpaceByName(runner, model, space_name)
    area = longitud * ttl_puentesTermicos[:ptContornoHuecos] / 1.0
    sup_pt = creaSuperficiePT(model, space, area, construcciones[:ptContornoHuecos], 'y-')
    sup_pt.setName("#{space_name}_ptContornoHuecos")
  end
end

def cte_puentestermicos(model, runner, user_arguments)
  # Genera superficies que representan los PTs
  # Estas superficies tienen una construcción PT_tipo
  # y un nombre de superficie que es (nombre espacio)_(ptTipo)

  # Medición de PTs de forjados
  ptForjados = medicionPTForjados(runner, model)
  # Medición de PTs de huecos
  ptHuecos = medicionPTContornoHuecos(runner, model)

  # Calcula construcciones correspondientes a TTL definidas por el usuario
  ttl_puentesTermicos = ttlinealusuario(runner, user_arguments)
  construcciones = {
    ptForjadoCubierta: creaConstruccionPT(model, 'PT_ForjadoCubierta', ttl_puentesTermicos[:ptForjadoCubierta]),
    ptFrenteForjado: creaConstruccionPT(model, 'PT_FrenteForjado', ttl_puentesTermicos[:ptFrenteForjado]),
    ptSoleraTerreno: creaConstruccionPT(model, 'PT_SoleraTerreno', ttl_puentesTermicos[:ptSoleraTerreno]),
    ptForjadoExterior: creaConstruccionPT(model, 'PT_ForjadoExterior', ttl_puentesTermicos[:ptForjadoExterior]),
    ptContornoHuecos: creaConstruccionPT(model, 'PT_ContornoHuecos', ttl_puentesTermicos[:ptContornoHuecos])
  }

  # Genera superficies correspondientes a los PTs
  setThermalBridges(runner, model, ptForjados, ptHuecos, ttl_puentesTermicos, construcciones)

return true
end
