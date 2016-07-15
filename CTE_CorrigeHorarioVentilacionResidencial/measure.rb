# coding: utf-8

class CTE_CorrigeHorarioVentilacionResidencial < OpenStudio::Ruleset::WorkspaceUserScript
  # OpenStudio convierte los horarios de ventilación de los objetos ZoneVentilation:DesignFlowRate a Always_On a EPlus
  # Esto sucede cuando se usa un objeto OutdoorAir, que es necesario cuando no se usan sistemas ideales

  CTE_SCHEDULE_NAME = "CTER24B_HVEN"

  def name
    return "Corrige horario de ventilacion a CTER24B_HVEN"
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end

  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    f = 'log_ajustarVentilacion'

    idfFlowRates = workspace.getObjectsByType("ZoneVentilation_DesignFlowRate".to_IddObjectType)

    if not idfFlowRates.empty?
        idfFlowRates.each do | idfFlowRate |
            msg(f, "\n __ proceso de renombrado de schedules __\n")
            msg(f, "  idfFlowRates[0].class ----------------------> #{idfFlowRate.class}\n")
            msg(f, "  inital value: idfFlowRates[0].getString(2) -> #{idfFlowRate.getString(2)}\n")
            result = idfFlowRate.setString(2, CTE_SCHEDULE_NAME) # Correccion de nombre de horario
            msg(f, "  succesfully written? -----------------------> #{result}\n")
            msg(f, "  final value --------------------------------> #{idfFlowRate.getString(2)}\n")
        end
    else
        msg(f, "No hay objetos ZoneVentilation_DesignFlowRate \n")
    end

    msg(f, "\n __ fin del renombrado __\n")

    ### TODO: Esto no parece funcionar

    # # ZoneAirBalance:OutdoorAir,
    # # LIVING ZONE Balance 1,   !- Name
    # # LIVING ZONE,             !- Zone Name
    # # Quadrature,              !- Air Balance Method
    # # 0.00,                    !- Induced Outdoor Air Due to Unbalanced Duct Leakage {m3/s}
    # # INF-SCHED;               !- Induced Outdoor Air Schedule Name

    # # array to hold new IDF objects needed
    # string_objects = []

    # idfZones = workspace.getObjectsByType("Zone".to_IddObjectType)
    # if not idfZones.empty?
    #   idfZones.each do | idfZone |
    #     msg(f, "\n zona:#{idfZone}\n")
    #     nombreZona = idfZone.getString(0)
    #     msg(f, "\n zona1:#{idfZone.getString(0)}\n")

    #     string_objects << "
    #       ZoneAirBalance:OutdoorAir,
    #       #{nombreZona} Balance aire exterior, !- Name
    #       #{nombreZona},            !- Zone Name
    #       Quadrature,               !- Air Balance Method
    #       0.00,                     !- Induced Outdoor Air Due to Unbalanced Duct Leakage {m3/s}
    #       CTER24B_HINF;             !- Induced Outdoor Air Schedule Name
    #       "
    #   end
    # end

    # # add all of the strings to workspace
    # # this script won't behave well if added multiple times in the workflow. Need to address name conflicts
    # string_objects.each do |string_object|
    #   idfObject = OpenStudio::IdfObject::load(string_object)
    #   object = idfObject.get
    #   wsObject = workspace.addObject(object)
    # end


   return true
   end

  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end

end #end the measure

#this allows the measure to be use by the application
CTE_CorrigeHorarioVentilacionResidencial.new.registerWithApplication
