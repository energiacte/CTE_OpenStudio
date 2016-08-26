# coding: utf-8

require_relative "resources/cte_lib_measures_ventresidencial.rb"
require_relative "resources/cte_lib_measures_zoneairbalance.rb"
require_relative "resources/cte_lib_measures_groundtemperature.rb"
require_relative "resources/cte_lib_measures_horarioestacional.rb"                            

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

    if es_residencial
      runner.registerInfo("[1/5] - Corrección de horarios de ventilación en objetos
                                ZoneVentilation:DesignFlowRate es CTER24B_HVEN")
      result = cte_ventresidencial(workspace, runner, user_arguments)
      return result unless result == true
    end

    string_objects = []

    runner.registerInfo("[2/5] - Introducción de balance de aire exterior")
    result = cte_addAirBalance(runner, workspace, string_objects)
    return result unless result == true

    runner.registerInfo("[3/5] - Fija la temperatura del terreno")
    result = cte_groundTemperature(runner, workspace, string_objects)            
    return result unless result == true


    runner.registerInfo("[4/5] - Incorpora objetos definidos en cadenas al workspace")
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      workspace.addObject(object)
    end
    
    runner.registerInfo("[5/5] - Introduce el cambio de hora los últimos domingos de marzo y octubre")
    result = cte_horarioestacional(runner, workspace)
    return result unless result == true
    
    return true
  end

end #end the measure

#this allows the measure to be use by the application
CTE_Workspace.new.registerWithApplication
