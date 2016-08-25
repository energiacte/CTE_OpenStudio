# coding: utf-8

require_relative "resources/cte_lib_measures_ventresidencial.rb"
require_relative "resources/cte_lib_measures_zoneairbalance.rb"

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
      runner.registerInfo("[1/3] - Corrección de horarios de ventilación en objetos 
                                ZoneVentilation:DesignFlowRate es CTER24B_HVEN")
      result = cte_ventresidencial(workspace, runner, user_arguments)
      return result unless result == true                     
    end
    
    string_objects = []
    
    runner.registerInfo("[2/3] - Introducción de balance de aire exterior")
    result = cte_addAirBalance(runner, workspace, string_objects)      
    return result unless result == true           
    
    runner.registerInfo("[3/3] - Incorpora objetos definidos en cadenas al workspace")
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      workspace.addObject(object)
    end
      
    return true
  end

end #end the measure

#this allows the measure to be use by the application
CTE_Workspace.new.registerWithApplication
