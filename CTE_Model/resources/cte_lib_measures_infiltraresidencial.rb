# coding: utf-8

TO4PA = 0.11571248 # pow(4/100., 0.67), de 100 a 4 pascales
C_OP = { 'Nuevo'     => 16 * TO4PA,
         'Existente' => 29 * TO4PA }
C_PU = 60 * TO4PA # Permeabilidad puertas a 4Pa
C_HU = { 'Clase 1' => 50 * TO4PA,
         'Clase 2' => 27 * TO4PA,
         'Clase 3' => 9 * TO4PA,
         'Clase 4' => 3 * TO4PA }

#Se modelan las infiltraciones usando el método ELA y las permeabilidades y parámetros del documento de condic. técnicas
def cte_infiltraresidencial(model, runner, user_arguments)
  horarios = model.getScheduleRulesets
  horarioInfiltracion = false
  horarios.each do | horario |
    if horario.name.get == 'CTER24B_HINF'
      horarioInfiltracion = horario
      break
    end
  end

  if not horarioInfiltracion
    runner.registerError("No se ha encontrado el horario de infiltraciones CTE24B_HINF en el modelo.")
    return false
  end

  tipoEdificio = runner.getStringArgumentValue('tipoEdificio', user_arguments)
  claseVentana = runner.getStringArgumentValue('permeabilidadVentanas', user_arguments)
  coefStack = runner.getDoubleArgumentValue('coefStack', user_arguments)
  coefWind = runner.getDoubleArgumentValue('coefWind', user_arguments)

  runner.registerValue("CTE Tipo de Edificio (Nuevo/Existente)", tipoEdificio)
  runner.registerValue("CTE Clase de permeabilidad de Ventanas", claseVentana)

  spaces = model.getSpaces
  runner.registerValue("CTE Coeficientes de fugas de opacos a 4Pa", C_OP[tipoEdificio].round(4))
  runner.registerValue("CTE Coeficientes de fugas de puertas a 4Pa", C_PU.round(4))
  runner.registerValue("CTE Coeficientes de fugas de huecos a 4Pa", C_HU[claseVentana].round(4))

  runner.registerInfo("** Superficies para ELA **")
  spaces.each do |space|
    runner.registerInfo("* Espacio '#{ space.name }'")
    areaOpacos = 0
    areaVentanas = 0
    areaPuertas = 0
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == 'Outdoors'
        surfArea = surface.netArea
        areaOpacos += surfArea
        runner.registerInfo("- '#{ surface.name }', #{ surface.surfaceType }, #{ surfArea.round(2) }")
        surface.subSurfaces.each do |subsur|
          subSurfArea = subsur.grossArea
          runner.registerInfo("- '#{subsur.name}', #{ subsur.subSurfaceType }, #{ subSurfArea.round(2) }")
          if ['FixedWindow', 'OperableWindow', 'SkyLight'].include?(subsur.subSurfaceType)
            areaVentanas += subSurfArea
          elsif ['Door', 'GlassDoor', 'OverheadDoor'].include?(subsur.subSurfaceType)
            areaPuertas += subSurfArea
          else
            runner.registerWarning("Subsuperficie '#{ subsur.name }' con tipo desconocido '#{ subsur.subSurfaceType }' en superficie '#{ surface.name }' del espacio '#{ space.name }'")
          end
        end
      end
    end

    runner.registerInfo("-- Totales [m2]: opacos: #{ areaOpacos.round(2) }, huecos #{ areaVentanas.round(2) }, puertas #{ areaPuertas.round(2) }\n")

    c_ven = 0.0 # Superficie bocas admisión
    if claseVentana != 'Clase 1'
      c_ven = C_HU['Clase 1'] - C_HU[claseVentana]
    end

    # q_total en m3/h a 4 Pa
    q_total = 4 ** 0.67 * (C_OP[tipoEdificio] * areaOpacos +
                           C_HU[claseVentana] * areaVentanas +
                           C_PU * areaPuertas +
                           # microventilación al 50% de apertura
                           0.50 * c_ven * areaVentanas / (4 ** 0.5))

    areaEquivalente = 1.0758287 * q_total * 0.50 # area ELA en cm2 al 50% de exposición
    runner.registerValue("CTE ELA ('#{ space.name }')", areaEquivalente.round(2), "cm2 a 4Pa")

    # Elimina todos los objetos ELA que pueda haber
    space.spaceInfiltrationEffectiveLeakageAreas.each{ |ela| ela.remove }

    # E inserta los nuevos
    ela = OpenStudio::Model::SpaceInfiltrationEffectiveLeakageArea.new(model)
    ela.setSpace(space)
    ela.setStackCoefficient(coefStack)
    ela.setWindCoefficient(coefWind)
    ela.setSchedule(horarioInfiltracion)
    ela.setEffectiveAirLeakageArea(areaEquivalente)
    ela.setName('CTE_ELA_#{ space.name }')
  end

  return true # OS necesita saber que todo acaba bien
end
