# coding: utf-8
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

class VentilacionResidencialCTE < OpenStudio::Ruleset::ModelUserScript
  # Ventilacion Residencial CTE:
  # 1 - Redefine el horario de ventilación con caudal de diseño y ventilación nocturna en verano, CTER24B_HVEN (disponible en plantilla)
  # 2 - Incorpora objetos ZoneVentilation:DesignFlowRate a zonas habitables, con horario CTER24B_HVEN

  def name
    return "Ventilacion residencial CTE"
  end

  def description
    return "Condiciones de ventilacion e infiltraciones para uso residencial segun CTE.

Usa el modelo simple con ventilacion nocturna de 4 ren/h en verano para las zonas habitables y el caudal de diseno indicado en ren/h el resto del tiempo.
Esta medida necesita otra complementaria de EPlus que corrige los horarios de las zonas si es necesario.
"
  end

  def modeler_description
    return "Define objetos ZoneVentilation:DesignFlowRate en cada zona habitable para modelar el aire exterior, con un horario que impone 4 ren/h en verano y el caudal de diseno el resto del tiempo."
  end

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    design_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("design_flow_rate", true)
    design_flow_rate.setDisplayName("Caudal de diseno de ventilacion del edificio [ren/h]")
    design_flow_rate.setUnits("1/h")
    args << design_flow_rate

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    runner.registerInitialCondition("CTE: Definición de condiciones de ventilación de espacios habitables en edificios residenciales.")

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      runner.registerError("Parametros incorrectos")
      return false
    end

    # ------------------------------------------------------------------------------------------------------------------------------------
    # 1 - Redefine el horario de ventilación con caudal de diseño y ventilación nocturna en verano, CTER24B_HVEN (disponible en plantilla)
    # ------------------------------------------------------------------------------------------------------------------------------------
    design_flow_rate = runner.getDoubleArgumentValue('design_flow_rate', user_arguments)
    runner.registerInfo("[1/2] Definiendo horario con ventilación nocturna en verano (4ren/h) y caudal de diseño: #{design_flow_rate} [ren/h]")
    frac_general_ventilacion = design_flow_rate / 4
    frac_nocheverano_ventilacion = 1
    runner.registerInfo("* Fracción de ventilación nocturna en verano: #{frac_nocheverano_ventilacion} [ren/h].")
    runner.registerInfo("* Fracción de ventilación con caudal de diseño: #{frac_general_ventilacion} [ren/h].")

    conjuntodereglasalocalizar = "CTER24B_HVEN"
    runner.registerInfo("* Localizando en el modelo el horario '#{conjuntodereglasalocalizar}' definido en la plantilla")

    # Esto localiza la primera regla
    scheduleRulesets = model.getScheduleRulesets
    ventilationRuleset = ''
    scheduleRulesets.each do | scheduleRuleset |
      if scheduleRuleset.name.get == conjuntodereglasalocalizar
        ventilationRuleset = scheduleRuleset
        runner.registerInfo("+ Localizado conjunto de horarios '#{conjuntodereglasalocalizar}' con #{ventilationRuleset.scheduleRules.count} reglas existentes")
        ventilationRuleset.scheduleRules.each do |rule|
          runner.registerInfo("- Eliminada regla '#{rule.name.get}'")
          rule.remove
        end
        break
      end
    end

    if not ventilationRuleset
      runner.registerError("ERROR: No se ha encontrado el conjunto de horarios '#{conjuntodereglasalocalizar}'. Ha usado la plantilla para modelado CTE?")
      return false
    end

    def aplica_horario_a_semana(scheduleRule)
        scheduleRule.setApplyMonday(true)
        scheduleRule.setApplyTuesday(true)
        scheduleRule.setApplyWednesday(true)
        scheduleRule.setApplyThursday(true)
        scheduleRule.setApplyFriday(true)
        scheduleRule.setApplySaturday(true)
        scheduleRule.setApplySunday(true)
    end

    runner.registerInfo("* Definiendo reglas de ventilación")

    diaInvierno1 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno1.setName("Dia tipo invierno")
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaInvierno1.addValue(time_24h, frac_general_ventilacion)
    inviernoRule1 = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaInvierno1)
    inviernoRule1.setName("Regla de ventilacion invierno 1")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5) , 31 )
    inviernoRule1.setStartDate(startDate)
    inviernoRule1.setEndDate(endDate)
    aplica_horario_a_semana(inviernoRule1)

    diaVerano = OpenStudio::Model::ScheduleDay.new(model)
    diaVerano.setName("Dia de verano")
    time_8h =  OpenStudio::Time.new(0, 8, 0, 0)
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaVerano.addValue(time_8h, frac_nocheverano_ventilacion) # Fraccion de ventilacion == 1 durante la noche en verano
    diaVerano.addValue(time_24h, frac_general_ventilacion) # Fraccion de ventilacion genérica
    veranoRule = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaVerano)
    veranoRule.setName("Regla de ventilacion verano")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(6), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30)
    veranoRule.setStartDate(startDate)
    veranoRule.setEndDate(endDate)
    aplica_horario_a_semana(veranoRule)

    diaInvierno2 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno2.setName("Dia tipo de invierno")
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaInvierno2.addValue(time_24h, frac_general_ventilacion)
    inviernoRule2 = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaInvierno2)
    inviernoRule2.setName("Regla de ventilacion invierno 2")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(10), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(12) , 31 )
    inviernoRule2.setStartDate(startDate)
    inviernoRule2.setEndDate(endDate)
    aplica_horario_a_semana(inviernoRule2)

    runner.registerInfo("* Incorporando reglas de ventilación al conjunto '#{conjuntodereglasalocalizar}'")
    ventilationRuleset.scheduleRules.each do |rule|
      day_sch = rule.daySchedule
      runner.registerInfo("+ Regla '#{rule.name}' (#{rule.handle.to_s}):")
      #runner.registerInfo("Objeto: #{rule}")
      runner.registerInfo("+ Valores: #{day_sch.values}")
    end

    # ------------------------------------------------------------------------------------------------------------------------------------
    # 2 - Incorpora objetos ZoneVentilation:DesignFlowRate a zonas habitables, con horario CTER24B_HVEN
    # ------------------------------------------------------------------------------------------------------------------------------------

    # TODO: traer de otra medida
    runner.registerInfo("[2/2] Incorporando objetos ZoneVentilation:DesignFlowRate a espacios habitables")

    zones = model.getThermalZones
    runner.registerInfo("* Localizada(s) #{ zones.count } zona(s) térmica(s)")
    zoneVentilationCounter = 0
    zones.each do | zone |
      zoneName = zone.name.get
      if zone.useIdealAirLoads
        # Las zonas con Ideal Air Loads incorporan ya su objeto ZoneVentilation:DesignFlowRate
        runner.registerInfo("+ La zona '#{ zoneName }' usa equipos ideales.")
        next
      end
      spaces = zone.spaces()
      runner.registerInfo("+ Localizado(s) #{ spaces.count } espacio(s) en la zona '#{ zoneName }'")
      # Solamente usamos el primer espacio de la zona? suponemos que solo hay uno?
      spaces.each do |space|
        spaceName = space.name.get
        spaceType = space.spaceType.get.name.get
        if spaceType.start_with?('CTE_HR') or spaceType.start_with?('CTE_AR')
          zoneVentilationCounter += 1
          # TODO: permitir usar tipo 'Exhaust' para obtener consumo de ventiladores
          # TODO: necesita diferencia de presión del ventilador y rendimiento total del ventilador
          zone_ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
          zone_ventilation.addToThermalZone(zone)
          zone_ventilation.setVentilationType('Natural')
          zone_ventilation.setDesignFlowRateCalculationMethod("AirChanges/Hour")
          zone_ventilation.setAirChangesperHour(4) # 4 ren/h
          zone_ventilation.setConstantTermCoefficient(1)
          zone_ventilation.setTemperatureTermCoefficient(0)
          zone_ventilation.setVelocityTermCoefficient(0)
          zone_ventilation.setVelocitySquaredTermCoefficient(0)
		  zone_ventilation.setMinimumIndoorTemperature(-100)
          zone_ventilation.setDeltaTemperature(-100)
          zone_ventilation.setSchedule(ventilationRuleset)
          runner.registerInfo("- Creando objeto ZoneVentilation:DesignFlowRate en espacio '#{ spaceName }' del tipo '#{ spaceType }' en la zona '#{ zoneName }'")
        else
          runner.registerInfo("- El espacio '#{ spaceName }' de la zona '#{ zoneName }' no es habitable (tipo: '#{ spaceType }')")
        end
      end
    end
    runner.registerInfo("* Creado(s) #{ zoneVentilationCounter } objeto(s) ZoneVentilation:DesignFlowRate. ")

    runner.registerFinalCondition("CTE: Finalizada definición de condiciones de ventilación de espacios habitables en edificios residenciales.")
    return true # OS necesita saber que todo acabó bien

  end # end run
end # end the measure

VentilacionResidencialCTE.new.registerWithApplication
