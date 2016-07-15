# coding: utf-8

CTE_SCHEDULE_NAME = "CTER24B_HVEN"

class CTE_CorrigeHorarioVentilacionResidencial < OpenStudio::Ruleset::WorkspaceUserScript
  # OpenStudio convierte los horarios de ventilación de los objetos ZoneVentilation:DesignFlowRate a Always_On a EPlus
  # Esto sucede cuando se usa un objeto OutdoorAir, que es necesario cuando no se usan sistemas ideales

  def name
    return "Corrige horario de ventilacion a CTER24B_HVEN"
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end

  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    runner.registerInitialCondition("Cambio de horarios en todos los elementos ZoneVentilation_DesignFlowRate a #{ CTE_SCHEDULE_NAME }")

    idfObjects = workspace.getObjectsByType("ZoneVentilation_DesignFlowRate".to_IddObjectType)
    if idfObjects.empty?
      runner.registerInfo("No se han encontrado objetos ZoneVentilation_DesignFlowRate")
    else
      runner.registerInfo("Se han encontrado #{ idfObjects.size } objetos ZoneVentilation_DesignFlowRate")
      changeCounter = 0
      idfObjects.each do | obj |
        currentSchedule = obj.getString(2)
        if currentSchedule == CTE_SCHEDULE_NAME then continue end
        changeCounter += 1
        runner.registerInfo("Cambiando horario #{ currentSchedule } para clase #{ object.class }")
        result = obj.setString(2, CTE_SCHEDULE_NAME) # Correccion de nombre de horario
        if not result
          runner.registerInfo("ERROR al modificar el nombre del horario")
        end
      end
    end

    runner.registerInfo("Se han renombrado #{ changeCounter } de #{ idfObjects.size } objetos")

    ### TODO: Esto necesita que se muestren los valores de Zone combined airflow ... en lugar de valores de zona en el report.
    # SELECT AVG(data.VariableValue) FROM ReportVariableData AS data WHERE ReportVariableDataDictionaryIndex = 160;
    # ReportVariableDataDictionary vale para buscar el Combined Air... que en este archivo era 160.

    # ZoneAirBalance:OutdoorAir,
    # LIVING ZONE Balance 1,   !- Name
    # LIVING ZONE,             !- Zone Name
    # Quadrature,              !- Air Balance Method
    # 0.00,                    !- Induced Outdoor Air Due to Unbalanced Duct Leakage {m3/s}
    # INF-SCHED;               !- Induced Outdoor Air Schedule Name

    # array to hold new IDF objects needed
    string_objects = []

    idfZones = workspace.getObjectsByType("Zone".to_IddObjectType)
    if not idfZones.empty?
      idfZones.each do | idfZone |
        nombreZona = idfZone.getString(0)
        runner.registerInfo("Añadiendo Objeto ZoneAirBalance:OutdoorAir a zona #{ nombreZona }")

        string_objects << "
          ZoneAirBalance:OutdoorAir,
          #{nombreZona} OutdoorAir Balance, !- Name
          #{nombreZona},            !- Zone Name
          Quadrature,               !- Air Balance Method
          0.00,                     !- Induced Outdoor Air Due to Unbalanced Duct Leakage {m3/s}
          CTER24B_HINF;             !- Induced Outdoor Air Schedule Name
          "
      end
    end

    # add all of the strings to workspace
    # this script won't behave well if added multiple times in the workflow. Need to address name conflicts
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      workspace.addObject(object)
    end

    runner.registerFinalCondition("Cambiados horarios y añadidos objetos ZoneAirBalance:OutdoorAir")

    return true
  end

end #end the measure

#this allows the measure to be use by the application
CTE_CorrigeHorarioVentilacionResidencial.new.registerWithApplication
