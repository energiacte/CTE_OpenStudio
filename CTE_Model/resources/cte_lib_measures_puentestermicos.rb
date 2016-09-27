# coding: utf-8
# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require 'set'
require 'digest/md5'

RESISTENCIA_PT = 1.0
ALTURA_SUPERFICIE_PT = 2.0


def verticeID(point3d, origenEspacio)
  # los puntos de una superficie están en coordenadas locales respecto al origen del espacio
  # para convertir un punto en un vector hay que restarle cero
  puntoCero = OpenStudio::Point3d.new(0, 0, 0)
  vectorLocal = point3d - puntoCero
  vGlob = vectorLocal + origenEspacio

  return Digest::MD5.hexdigest("#{vGlob.x.round(2)} #{vGlob.y.round(2)} #{vGlob.z.round(2)}")
end

def generarHashEspacioPTForjados()
  return {:ptFrenteForjado   => Array.new,
          :ptForjadoExterior => Array.new,
          :ptSoleraTerreno   => Array.new,
          :ptForjadoCubierta => Array.new,
          :ptContornoHuecos  => Array.new}
end



def creaConstruccionPT(model, nombre, ttl)
  # Crear un nuevo material
  material = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
  material.setName("materialPT")
  material.setThermalResistance(RESISTENCIA_PT)
  material.setThermalAbsorptance(0.9)
  material.setSolarAbsorptance(0.7)
  material.setVisibleAbsorptance(0.7)

  # Creamos una nueva construccion
  layers = OpenStudio::Model::MaterialVector.new
  layers << material
  nombreconstruction = nombre + "_PSI#{ttl.round(2)}"
  construction = OpenStudio::Model::Construction.new(model)
  construction.setName(nombreconstruction)
  standards_info = construction.standardsInformation
  standards_info.setIntendedSurfaceType("")
  standards_info.setStandardsConstructionType("")

  construction.setLayers(layers)

  return construction
end

def getExteriorVertices(runner, spaces) # hacer un set
  runner.registerInfo("-- captura de vertices exteriores (getExteriorVertices)--")
  verticesExteriores = Set.new
  spaces.each do | space |
    # tiene que ser un vector porque lo voy a sumar
    origen = OpenStudio::Vector3d.new(space.xOrigin, space.yOrigin, space.zOrigin)
    ver = false
    ver = true if space.name.get == "ACCESO"
    runner.registerInfo("  space: #{space.name.get}") if ver
    space.surfaces.each do | surface |
      if surface.surfaceType == 'Wall' and
             surface.outsideBoundaryCondition == 'Outdoors'
        runner.registerInfo("   surface: #{surface.name}") if ver
        surface.vertices.each do | point3d |
          verticesExteriores << verticeID(point3d, origen)
        end
      end
    end
  end
  return verticesExteriores
end

def getFloors(runner, spaces)
  runner.registerInfo("-- captura de forjados por tipo (getFloors) --")
  forjadosEspacios = {}
  spaces.each do | space |
    forjadosEspacios[space.name.to_s] = generarHashEspacioPTForjados
    space.surfaces.each do | surface |
      next if surface.surfaceType == 'Wall'
      type = surface.surfaceType
      outCondition = surface.outsideBoundaryCondition
      # forjados interiores:
      if (type == 'Floor' or type == 'RoofCeiling') and outCondition == 'Surface'
        forjadosEspacios[space.name.to_s][:ptFrenteForjado] << surface
      # suelos exteriores
      elsif type == 'Floor' and outCondition == 'Outdoors'
        forjadosEspacios[space.name.to_s][:ptForjadoExterior] << surface
      # suelos en contacto con el terreno
      elsif type == 'Floor' and outCondition == 'Ground'
        forjadosEspacios[space.name.to_s][:ptSoleraTerreno] << surface
      # cubiertas
      elsif type == 'RoofCeiling' and outCondition == 'Outdoors'
        forjadosEspacios[space.name.to_s][:ptForjadoCubierta] << surface
      elsif type == 'Floor' and outCondition == 'Adiabatic'
        # no consdieramos estos
      else
        runner.registerWarning("No se incluye puente térmico para la superficie '#{surface.name}': #{surface.surfaceType} -> #{surface.outsideBoundaryCondition}")
      end
    end
  end
  return forjadosEspacios
end


def getSpaceByName(runner, model, spaceName)
  model.getModelObjectsByName(spaceName, true).each do | objeto |
      if objeto.iddObjectType.valueDescription == "OS:Space"
          return objeto.to_Space.get
      end
    end
end

def medicionPTForjados(runner, model)
  runner.registerInfo("-- medición de forjados (medicionPTForjados) -- ")
  verticesExteriores = getExteriorVertices(runner, model.getSpaces)
  forjadosPorEspacios = getFloors(runner, model.getSpaces)
  salida = []
  forjadosPorEspacios.each do | spaceName, forjadosPorTipo |
    runner.registerInfo("PTs: procesando #{spaceName}")
    space = getSpaceByName(runner, model, spaceName)
    origen = OpenStudio::Vector3d.new(space.xOrigin, space.yOrigin, space.zOrigin)
    longHash = Hash.new
    forjadosPorTipo.each do | tipo, forjados |
      longitudPuente = 0
      forjados.each do | forjado |
        verticePrevio = forjado.vertices[-1]
        forjado.vertices.each do | verticeActual |
          esExterior = verticesExteriores.include?(verticeID(verticeActual, origen))
          esPrevioExterior = verticesExteriores.include?(verticeID(verticePrevio, origen))
          if esPrevioExterior and esExterior  # los dos son exteriores
            coef = (tipo == :ptFrenteForjado) ? 0.5 : 1.0
            longitudPuente += coef * (verticeActual-verticePrevio).length
          end
          verticePrevio = verticeActual
        end
      end
      longHash[tipo] = longitudPuente.to_f
    end
    salida << [spaceName, longHash]
  end
  return salida
end

def getPerimeter(subSurface)
  vertices = subSurface.vertices
  verticesp = vertices + [vertices[0]]
  long = 0
  for cnt in 0..vertices.count-1
    long += (verticesp[cnt+1] - verticesp[cnt]).length
  end
  return long
end

def medicionPTContornoHuecos(runner, model)
  salida = []
  model.getSpaces.each do | space |
    long = 0
    space.surfaces.each do | surface |
      surface.subSurfaces.each do | subSurface |
        if subSurface.subSurfaceType.include?('Window')
          long += getPerimeter(subSurface)
        end
      end
    end
    salida << [space.name.to_s, long]
  end
  runner.registerInfo("Puentes térmicos de contorno de huecos: #{salida}")
  return salida
end

def ttlinealusuario(runner, user_arguments)
  psiForjadoCubierta = runner.getStringArgumentValue('psiForjadoCubierta', user_arguments).to_f
  psiFrenteForjado = runner.getStringArgumentValue('psiFrenteForjado', user_arguments).to_f
  psiSoleraTerreno = runner.getStringArgumentValue('psiSoleraTerreno', user_arguments).to_f
  psiForjadoExterior = runner.getStringArgumentValue('psiForjadoExterior', user_arguments).to_f
  psiContornoHuecos = runner.getStringArgumentValue('psiContornoHuecos', user_arguments).to_f
  ttl_puentesTermicos = {
      :ptForjadoCubierta => psiForjadoCubierta,
      :ptFrenteForjado => psiFrenteForjado,
      :ptSoleraTerreno => psiSoleraTerreno,
      :ptForjadoExterior => psiForjadoExterior,
      :ptContornoHuecos => psiContornoHuecos
      }
  return ttl_puentesTermicos
end

def getSpaceBarycenter(space)
  # devuelve el primero Floor que encuentre, independientemente de su OutBoundCond
  space.surfaces.each do | surface |
    baricentro = OpenStudio::Vector3d.new(0,0,0)
    cero  = OpenStudio::Point3d.new(0,0,0)
    if surface.surfaceType == 'Floor'
      #~ baricentro = surface.vertices[0]
      surface.vertices.each do | v |
        baricentro = baricentro + (v - cero)
      end
      nPuntos = surface.vertices.count
      #~ puts ("#{surface.vertices[0].x} #{surface.vertices[0].z}")
      return baricentro.x / nPuntos, baricentro.y / nPuntos, baricentro.z / nPuntos
    end
  end
end

  def creaSuperficiePT(model, space, area, construccionPT, direccion)
    x,y,z = getSpaceBarycenter(space)
    alto = ALTURA_SUPERFICIE_PT
    ancho = area/alto
    ancho = -1 * ancho unless direccion.include?('+')
    x2 = x
    y2 = y
    x2 += ancho if direccion.include?('x')
    y2 += ancho if direccion.include?('y')
    vertices = []
    vertices << OpenStudio::Point3d.new(x, y, z - 50 - alto)
    vertices << OpenStudio::Point3d.new(x2, y2, z - 50 - alto)
    vertices << OpenStudio::Point3d.new(x2, y2, z - 50)
    vertices << OpenStudio::Point3d.new(x, y, z - 50)
    superficie = OpenStudio::Model::Surface.new(vertices, model)
    superficie.setSunExposure('NoSun')
    superficie.setWindExposure('NoWind')
    superficie.setOutsideBoundaryCondition('Exterior')
    superficie.setSpace(space)
    superficie.setConstruction(construccionPT)
    return superficie
  end


  def setThermalBridges(runner, model, ptForjados, ptHuecos, ttl_puentesTermicos, construcciones)
    # para forjados
    direccion = {
      :ptFrenteForjado => 'x+',
      :ptForjadoCubierta => 'x-',
      :ptForjadoExterior => 'y+',
      :ptSoleraTerreno => 'x-'}
    ptForjados.each do | spaceName, longHash|
      space = getSpaceByName(runner, model, spaceName)
      longHash.each do | key, longitud |
         next if longitud == 0.0
         area = longitud * ttl_puentesTermicos[key] * RESISTENCIA_PT
         superficiePT = creaSuperficiePT(model, space, area, construcciones[key], direccion[key])
         superficiePT.setName("#{spaceName}_#{key.to_s}")
      end
    end

    # para huecos
    ptHuecos.each do | spaceName, longitud |
      next if longitud == 0.0
      space = getSpaceByName(runner, model, spaceName)
      area = longitud * ttl_puentesTermicos[:ptContornoHuecos] / 1.0
      superficiePT = creaSuperficiePT(model, space, area, construcciones[:ptContornoHuecos], 'y-')
      superficiePT.setName("#{spaceName}_ptContornoHuecos")
    end
  end

def cte_puentestermicos(model, runner, user_arguments)
  ttl_puentesTermicos = ttlinealusuario(runner, user_arguments)

  ptForjados = medicionPTForjados(runner, model)

  ptHuecos = medicionPTContornoHuecos(runner, model)

  construcciones = {
      :ptForjadoCubierta => creaConstruccionPT(model, "PT_ForjadoCubierta", ttl_puentesTermicos[:ptForjadoCubierta]),
      :ptFrenteForjado => creaConstruccionPT(model, "PT_FrenteForjado", ttl_puentesTermicos[:ptFrenteForjado]),
      :ptSoleraTerreno => creaConstruccionPT(model, "PT_SoleraTerreno", ttl_puentesTermicos[:ptSoleraTerreno]),
      :ptForjadoExterior => creaConstruccionPT(model, "PT_ForjadoExterior", ttl_puentesTermicos[:ptForjadoExterior]),
      :ptContornoHuecos =>creaConstruccionPT(model, "PT_ContornoHuecos", ttl_puentesTermicos[:ptContornoHuecos])
    }

    setThermalBridges(runner, model, ptForjados, ptHuecos, ttl_puentesTermicos, construcciones)

  return true
end
