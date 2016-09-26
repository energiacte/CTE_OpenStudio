# coding: utf-8

require_relative "resources/cte_lib_measures_ventresidencial.rb"
require_relative "resources/cte_lib_measures_zoneairbalance.rb"
require_relative "resources/cte_lib_measures_groundtemperature.rb"
require_relative "resources/cte_lib_measures_horarioestacional.rb"     
require_relative "resources/cte_lib_measures_recuperadorcalor.rb"          

class CTE_Workspace < OpenStudio::Ruleset::WorkspaceUserScript

  def name
    return "Aplica las medidas al Workspace"
  end

  def description
    return "Asegura que los objetos ZoneVentilation:DesignFlowRate usan el horario CTER24B_HVEN y añade objetos ZoneAirBalance:OutdoorAir."
  end

  def modeler_description
    return "Recorre objetos ZoneVentilation:DesignFlowRate y comprueba horario. Añade a todos los objetos Zone un objeto ZoneAirBalance:OutdoorAir."
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    # Heat Recovery Type
    recuperador_chs = OpenStudio::StringVector.new
    recuperador_chs << 'Ninguno'
    recuperador_chs << 'Sensible'
    recuperador_chs << 'Entálpico'
    recuperador = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('recuperador', recuperador_chs, true)
    recuperador.setDisplayName("Recuperador de calor")
    recuperador.setDefaultValue('Ninguno')
    args << recuperador   
    
    #Sensible Heat Recovery Effectiveness 
    sensible_effectiveness = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sensible_effectiveness", true)
    sensible_effectiveness.setDisplayName("efectividad de la recuperación sensible")
    sensible_effectiveness.setUnits("")
    sensible_effectiveness.setDefaultValue(0.7)
    args << sensible_effectiveness
    
    #Latent Heat Recovery Effectiveness 
    latente_effectiveness = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("latente_effectiveness", true)
    latente_effectiveness.setDisplayName("efectividad de la recuperación latente")
    latente_effectiveness.setUnits("")
    latente_effectiveness.setDefaultValue(0.65)
    args << latente_effectiveness
    
    return args
  end

  def es_residencial()
    return true
  end

  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    runner.registerInitialCondition("CTE: aplicando medidas de Workspace")

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      runner.registerError("Parámetros incorrectos")
      return false
    end
    
    num_part = '6'

    if es_residencial
      runner.registerInfo("[1/#{num_part}] - Corrección de horarios de ventilación en objetos
                                ZoneVentilation:DesignFlowRate es CTER24B_HVEN")
      result = cte_ventresidencial(workspace, runner, user_arguments)
      return result unless result == true
    end

    string_objects = []

    runner.registerInfo("[2/#{num_part}] - Introducción de balance de aire exterior")
    result = cte_addAirBalance(runner, workspace, string_objects)
    return result unless result == true

    runner.registerInfo("[3/#{num_part}] - Fija la temperatura del terreno")
    result = cte_groundTemperature(runner, workspace, string_objects)            
    return result unless result == true


    runner.registerInfo("[4/#{num_part}] - Incorpora objetos definidos en cadenas al workspace")
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      workspace.addObject(object)
    end
    
    runner.registerInfo("[5/#{num_part}] - Introduce el cambio de hora los últimos domingos de marzo y octubre")
    result = cte_horarioestacional(runner, workspace)
    return result unless result == true
    
        
    runner.registerInfo("[6/#{num_part}] - Introduce, en su caso, los recuperadores de calor")
    result = cte_recuperadorcalor(runner, workspace, user_arguments)
    return result unless result == true
    
    
    return true
  end

end #end the measure

#this allows the measure to be use by the application
CTE_Workspace.new.registerWithApplication
