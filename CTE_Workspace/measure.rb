# coding: utf-8

require_relative "resources/cte_lib_measures_ventresidencial.rb"

CTE_SCHEDULE_NAME = "CTER24B_HVEN"

class CTE_Workspace < OpenStudio::Ruleset::WorkspaceUserScript
  # 1 - Corrección de horarios de ventilación nocturna y caudal de diseño (HS3)
  # OpenStudio genera un objeto ZoneVentilation:DesignFlowRate con horario Always_On cuando se introducen
  # sistemas ideales. Puesto que usamos objetos ZoneVentilation:DesignFlowRate para introducir el caudal
  # de diseño de aire de renovación (HS3) y la ventilación noctura, debemos cambiar el horario Always_On
  # por uno que cuando se use con fracción 1 nos de 4 ren/h en horario nocturno de verano y el caudal
  # de diseño el resto del tiempo (CTER24B_HVEN).

  # 2 - Introducción de objetos de balance de aire exterior
  # En lugar de una red de flujos, la consideración de las infiltraciones se está haciendo mediante
  # el método ELA, (ZoneInfiltration:...), de forma desacoplada a la ventilación (ZoneVentilation:DesignFlowRate).
  # Para tener en cuenta la interacción entre ambos componentes se usa el objeto de ZoneAirBalance:OutdoorAir,
  # que realiza una combinación cuadrática de ambas componentes Q^2 = Q_v^2 + Q_i^2
  # Al realizar este cambio, los resultados de aire exterior se muestran en variables separadas del tipo:
  #  HVAC,Sum,Zone Combined Outdoor Air...


  def name
    return "Ventilacion residencial CTE (EP)"
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
      result = cte_ventresidencial(workspace, runner, user_arguments)
      return result unless result == true
      
      
    # ****


    # -------------------------- Array de cadenas con objetos IDF
    string_objects = []


    # --------------------------------------------------------------------------------------------------------
    # **** 2 - Introducción de balance de aire exterior
    # --------------------------------------------------------------------------------------------------------
    runner.registerInfo("[2/2] - Introducción de objetos ZoneAirBalance:OutdooAir")
    idfZones = workspace.getObjectsByType("Zone".to_IddObjectType)
    if idfZones.empty?
      runner.registerInfo("* No se han encontrado objetos Zone a los que añadir un objeto ZoneAirBalance:OutdoorAir")
    else
      runner.registerInfo("* Encontrado(s) #{ idfZones.size } objeto(s) Zone")
      idfZones.each do | idfZone |
        nombreZona = idfZone.getString(0)
        runner.registerInfo("- Definido objeto ZoneAirBalance:OutdoorAir para la zona '#{ nombreZona }'")

        string_objects << "
          ZoneAirBalance:OutdoorAir,
          #{nombreZona} OutdoorAir Balance, !- Name
          #{nombreZona},            !- Zone Name
          Quadrature,               !- Air Balance Method
          0.00,                     !- Induced Outdoor Air Due to Unbalanced Duct Leakage {m3/s}
          CTER24B_HINF;             !- Induced Outdoor Air Schedule Name
          "
      end
      runner.registerInfo("* Cambiado(s) #{ idfZones.size } objeto(s) Zone")
    end
    # ****


    # -------------------------- Incorpora objetos definidos en cadenas al workspace (Debe hacerse de una vez)
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      workspace.addObject(object)
    end

    runner.registerFinalCondition("Finalizada la configuración de la ventilación residencial")
    
    end
    return true
  end

end #end the measure

#this allows the measure to be use by the application
CTE_Workspace.new.registerWithApplication
