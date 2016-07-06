# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class VentilacionEnRenovacionesHora < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return " Ventilacion en renovaciones hora"
  end
  # human readable description
  def description
    return "Anade ZoneVentilation:DesignFlowRate a cada zona."
  end
  # human readable description of modeling approach
  def modeler_description
    return "This is simple implementation ment to expose the object to users. More complex use case specific versions will likely be developed in the future that may add multiple zone ventilation objects as well as zone mixing objects."
  end
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new    
    return args
  end
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    log = 'log_ventilacionEnRenovacionesHora'
    
    scheduleRulesets = model.getScheduleRulesets
    vent_sch = ''
    scheduleRulesets.each do | scheduleRuleset |
        if scheduleRuleset.name.get == 'CTER24B_HVEN'
            vent_sch = scheduleRuleset
        end
    end    
    
    zones = model.getThermalZones
    msg(log, " #{zones}\n")
    zones.each do | zone |
      spaces = zone.spaces()
      space = spaces[0]
      nombreTipo = space.spaceType.get.name.get
      msg(log, " nombre del tipo: #{nombreTipo}\n")
      if nombreTipo.start_with?('CTE_H') or nombreTipo.start_with?('CTE_A')
        # add zone ventilation object
        vent_type = 'Natural'        
        zone_ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zone_ventilation.addToThermalZone(zone)
        zone_ventilation.setVentilationType(vent_type)
        zone_ventilation.setDesignFlowRateCalculationMethod("AirChanges/Hour")
        zone_ventilation.setAirChangesperHour(4)
        zone_ventilation.setConstantTermCoefficient(1)
        zone_ventilation.setTemperatureTermCoefficient(0)
        zone_ventilation.setVelocityTermCoefficient(0)
        zone_ventilation.setVelocitySquaredTermCoefficient(0)
		zone_ventilation.setMinimumIndoorTemperature(-100)
        zone_ventilation.setDeltaTemperature(-100)
        zone_ventilation.setSchedule(vent_sch)
        
        runner.registerInfo("Creating zone ventilation design flow rate object with ventilation type of #{}")
      end

    end
    
    msg(log, "__ fin fichero de ventilación\m")

    return true

  end
  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end
  
end

# register the measure to be used by the application
VentilacionEnRenovacionesHora.new.registerWithApplication
