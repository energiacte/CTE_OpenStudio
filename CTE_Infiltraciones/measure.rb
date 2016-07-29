# coding: utf-8
# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class CTE_Infiltraciones < OpenStudio::Ruleset::ModelUserScript
  TO4PA = 0.11571248 # pow(4/100., 0.67), de 100 a 4 pascales
  C_OP = { 'Nuevo'     => 16 * TO4PA,
           'Existente' => 29 * TO4PA }
  C_PU = 60 * TO4PA # Permeabilidad puertas a 4Pa
  C_HU = { 'Clase 1' => 50 * TO4PA,
           'Clase 2' => 27 * TO4PA,
           'Clase 3' => 9 * TO4PA,
           'Clase 4' => 3 * TO4PA }

  # human readable name
  def name
    return "Infiltraciones CTE"
  end

  # human readable description
  def description
    return "Calculo de infiltraciones segun CTE"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Se modelan las infiltraciones usando el método ELA y las permeabilidades y parámetros del documento de condic. técnicas"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    tipoEdificio = OpenStudio::StringVector.new
    tipoEdificio << 'Nuevo'
    tipoEdificio << 'Existente'
    tipo = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("tipoEdificio", tipoEdificio, true)
    tipo.setDisplayName("¿Edificio nuevo o existente?")
    tipo.setDefaultValue('Nuevo')
    args << tipo

    claseVentana = OpenStudio::StringVector.new
    claseVentana << 'Clase 1'
    claseVentana << 'Clase 2'
    claseVentana << 'Clase 3'
    claseVentana << 'Clase 4'
    permeabilidad = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("permeabilidadVentanas", claseVentana, true)
    permeabilidad.setDisplayName("Permeabilidad de la carpintería.")
    permeabilidad.setDefaultValue('Clase 1')
    args << permeabilidad

    coefStack = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("coefStack", true)
    coefStack.setDisplayName("Coeficiente de Stack")
    coefStack.setDefaultValue(0.00029)
    args << coefStack

    coefWind = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("coefWind", true)
    coefWind.setDisplayName("Coeficiente de Viento")
    coefWind.setDefaultValue(0.000231)
    args << coefWind

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

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

    runner.registerInfo("Tipo de Edificio: #{ tipoEdificio }")
    runner.registerInfo("Clase de Ventanas: #{ claseVentana }")

    spaces = model.getSpaces
    runner.registerInfo("Número de espacios del modelo: #{ spaces.count }")
    runner.registerInfo("Coeficientes de fugas de opacos a 4Pa: #{ C_OP }")
    runner.registerInfo("Coeficientes de fugas de puertas a 4Pa: #{ C_PU }")
    runner.registerInfo("Coeficientes de fugas de huecos a 4Pa: #{ C_HU }")

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
      q_total = 4 ** 0.67 * (0.50 * C_OP[tipoEdificio] * areaOpacos + # 50% opacos
                             0.50 * C_HU[claseVentana] * areaVentanas + # 50% huecos
                             0.50 * C_PU * areaPuertas + # 50% puertas
                             # microventilación al 50% de apertura
                             0.50 * c_ven * areaVentanas / (4 ** 0.5))

      areaEquivalente = 1.0758287 * q_total # area ELA en cm2
      runner.registerInfo("ELA ('#{ space.name }'): #{ areaEquivalente.round(2) } cm2 a 4Pa")

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

end # end the measure

# register the measure to be used by the application
CTE_Infiltraciones.new.registerWithApplication
