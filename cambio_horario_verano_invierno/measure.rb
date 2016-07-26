# coding: utf-8
class CambioHorarioVeranoInvierno < OpenStudio::Ruleset::WorkspaceUserScript

  def name
    return "Cambio horario verano invierno"
  end

  # human readable description
  def description
    return "Cambia la hora los ultimos domingos de marzo y octubre"
  end

  # human readable description of modeling approach
  def modeler_description
    return "En caso de existir cambia los valores del objeto RunPeriodControl_DayLightSavingTime, en caso
            contrario crea el objeto con los valores adecuados"
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end

  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    dayligthSavings = workspace.getObjectsByType("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
    if not dayligthSavings.empty?
        dayligthSavings.each do | dayligthSaving |
            runner.registerInfo("Se ha localizado y modificado una definición de horario de verano")
            dayligthSaving.setString(0, "Last Sunday in March")
            dayligthSaving.setString(1, "Last Sunday in October")
        end
    else
        #tableStyle = ops.IdfObject(ops.IddObjectType("RunPeriodControl_DayLightSavingTime".to_IddObjectType))
      dayligthSaving = OpenStudio::IdfObject.new("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
      runner.registerInfo("Se ha añadido una definición de horario de verano")
      dayligthSaving.setString(0, "Last Sunday in March")
      dayligthSaving.setString(1, "Last Sunday in October")
      workspace.addObject(dayligthSaving)
    end
    return true
  end

end #end the measure

#this allows the measure to be use by the application
CambioHorarioVeranoInvierno.new.registerWithApplication
