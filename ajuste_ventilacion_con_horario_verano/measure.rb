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

El valor del caudal de diseno de ventilacion se define en ren/h.

Esta medida necesita otra complementaria que fija en 4ren/h la ventilacion de las zonas, ya que esta solamente ajusta la fraccion de ventilacion en el horario
"
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
      runner.registerError("Parametros incorrectos")
      return false
    end

    runner.registerInitialCondition("CTE: Incorporacion de Ventilacion Nocturna en verano en espacios habitables residenciales (CTER24B_HVEN).")

    design_flow_rate = runner.getDoubleArgumentValue('design_flow_rate',user_arguments)
    runner.registerInfo("Caudal de ventilacion de diseno: #{design_flow_rate} [ren/h]")

    conjuntodereglasalocalizar = "CTER24B_HVEN"
    runner.registerInfo("Localizando conjunto de horarios #{conjuntodereglasalocalizar}")

    # Esto localiza solamente la ultima regla. Se podría hacer un break
    scheduleRulesets = model.getScheduleRulesets
    ventilationRuleset = ''
    scheduleRulesets.each do | scheduleRuleset |
      if scheduleRuleset.name.get == conjuntodereglasalocalizar
        ventilationRuleset = scheduleRuleset
        runner.registerInfo("Conjunto de horarios localizado, con #{ventilationRuleset.scheduleRules.count} reglas")
        break
      end
    end

    if not ventilationRuleset
      runner.registerError("No se ha encontrado un conjunto de horarios adecuado")
      return false
    end

    ventilationRuleset.scheduleRules.each  do |rule|
      runner.registerInfo("Eliminando regla '#{rule.name.get}' del conjunto de horarios")
      rule.remove
    end

    frac_general_ventilacion = design_flow_rate / 4
    frac_nocheverano_ventilacion = 1

    runner.registerInfo("Cambiando fraccion de ventilacion a #{frac_general_ventilacion}, y a #{frac_nocheverano_ventilacion} de noche en verano.")

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
    diaInvierno1.addValue(time_24h, frac_general_ventilacion)
    inviernoRule1 = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaInvierno1)
    inviernoRule1.setName("regla ventilacion invierno 1")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5) , 31 )
    inviernoRule1.setStartDate(startDate)
    inviernoRule1.setEndDate(endDate)
    aplicalasemana(inviernoRule1)

    diaVerano = OpenStudio::Model::ScheduleDay.new(model)
    diaVerano.setName("dia de verano")
    time_8h =  OpenStudio::Time.new(0, 8, 0, 0)
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaVerano.addValue(time_8h, frac_nocheverano_ventilacion) # Fraccion de ventilacion == 1 durante la noche en verano
    diaVerano.addValue(time_24h, frac_general_ventilacion) # Fraccion de ventilacion genérica
    veranoRule = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaVerano)
    veranoRule.setName("regla de ventilacion verano")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(6), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30)
    veranoRule.setStartDate(startDate)
    veranoRule.setEndDate(endDate)
    aplicalasemana(veranoRule)

    diaInvierno2 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno2.setName("dia de invierno")
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaInvierno2.addValue(time_24h, frac_general_ventilacion)
    inviernoRule2 = OpenStudio::Model::ScheduleRule.new(ventilationRuleset, diaInvierno2)
    inviernoRule2.setName("regla ventilacion invierno 2")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(10), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(12) , 31 )
    inviernoRule2.setStartDate(startDate)
    inviernoRule2.setEndDate(endDate)
    aplicalasemana(inviernoRule2)

    ventilationRuleset.scheduleRules.each  do |rule|
      day_sch = rule.daySchedule
      runner.registerInfo("Regla '#{rule.name}' (#{rule.handle.to_s}):")
      #runner.registerInfo("Objeto: #{rule}")
      runner.registerInfo("Valores: #{day_sch.values}")
    end

    return true # OS necesita saber que todo acabó bien

  end # end run

end # end the measure

# register the measure to be used by the application
AjusteVentilacionConHorarioVerano.new.registerWithApplication
