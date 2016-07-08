# coding: utf-8
# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class AjusteVentilacionConHorarioVerano < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Ventilacion nocturna en verano"
  end

  # human readable description
  def description
    return "Establece la ventilacion nocturna de 4 ren/h en verano para las zonas habitables y el caudal de diseno indicado el resto del tiempo

El valor del caudal de diseno de ventilacion se define en ren/h."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Recalcula los horarios de ventilacion para mantener a 4 las renovaciones en verano y variar el resto. Se aplica a todas las zonas habitables. De uso de momento unicamente para residencial."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    design_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("design_flow_rate", true)
    design_flow_rate.setDisplayName("Caudal de diseno de ventilacion del edificio [ren/h]")
    design_flow_rate.setUnits("ren./h") # XXX: estas unidades estan bien?
    args << design_flow_rate

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    f = 'log_ajusteVentilacionVerano'
    msg(f, "__argumentos leidos:\n")
    design_flow_rate = runner.getDoubleArgumentValue('design_flow_rate',user_arguments)
    msg(f," design_flow_rate #{design_flow_rate}\n")
    msg(f, "__ fin argumentos\n\n")

    conjuntodereglasalocalizar = "CTER24B_HVEN"
    msg(f, "__localizar #{conjuntodereglasalocalizar}__\n")

    scheduleRulesets = model.getScheduleRulesets
    ventilationRuleset = ''
    scheduleRulesets.each do | scheduleRuleset |
        if scheduleRuleset.name.get == conjuntodereglasalocalizar
            ventilationRuleset = scheduleRuleset
            msg(f, "  localizado un elemento\n\n")
        end
    end

    msg(f, "  localizado: #{ventilationRuleset.name.get}\n")
    msg(f, "  tiene #{ventilationRuleset.scheduleRules.count} reglas\n\n")

    msg(f, "__lo modificamos__\n")
    ventilationRuleset.scheduleRules.each  do |rule|
        rule.remove
    end
    nuevoValor = design_flow_rate/4

    def aplicalasemana(scheduleRule)
        scheduleRule.setApplyMonday(true)
        scheduleRule.setApplyTuesday(true)
        scheduleRule.setApplyWednesday(true)
        scheduleRule.setApplyThursday(true)
        scheduleRule.setApplyFriday(true)
        scheduleRule.setApplySaturday(true)
        scheduleRule.setApplySunday(true)
    end

    diaInvierno1 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno1.setName("dia de invierno")
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaInvierno1.addValue(time_24h, nuevoValor)
    inviernoRule1 = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaInvierno1)
    inviernoRule1.setName("regla invierno 1")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5) , 31 )
    inviernoRule1.setStartDate(startDate)
    inviernoRule1.setEndDate(endDate)
    aplicalasemana(inviernoRule1)

    diaVerano = OpenStudio::Model::ScheduleDay.new(model)
    diaVerano.setName("dia de verano")
    time_8h =  OpenStudio::Time.new(0, 8, 0, 0)
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaVerano.addValue(time_8h, 1)
    diaVerano.addValue(time_24h, nuevoValor)
    veranoRule = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaVerano)
    veranoRule.setName("regla de verano")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(6), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30)
    veranoRule.setStartDate(startDate)
    veranoRule.setEndDate(endDate)
    aplicalasemana(veranoRule)

    diaInvierno2 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno2.setName("dia de invierno")
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaInvierno2.addValue(time_24h, nuevoValor)
    inviernoRule2 = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaInvierno2)
    inviernoRule2.setName("regla invierno 2")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(10), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(12) , 31 )
    inviernoRule2.setStartDate(startDate)
    inviernoRule2.setEndDate(endDate)
    aplicalasemana(inviernoRule2)


    msg(f, "__las reglas de ventilación ya procesado___\n")
    ventilationRuleset.scheduleRules.each  do |rule|
        msg(f, "  #{rule.name}\n")
        msg(f, "  #{rule}\n")
        day_sch = rule.daySchedule
        msg(f, "    times = #{day_sch.times}\n")
        msg(f, "    values = #{day_sch.values}\n\n\n")
    end
    msg(f, "__fin__\n")

    return true # OS necesita saber que todo acabó bien

  end

  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end

end # end the measure

# register the measure to be used by the application
AjusteVentilacionConHorarioVerano.new.registerWithApplication
