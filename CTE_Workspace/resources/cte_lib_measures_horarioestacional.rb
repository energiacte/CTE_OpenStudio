# coding: utf-8

def cte_horarioestacional(runner, workspace)
  dayligthSavings = workspace.getObjectsByType("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
  if not dayligthSavings.empty?
    dayligthSavings.each do | dayligthSaving |
      runner.registerInfo("  Se ha localizado y modificado una definición de horario de verano")
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
