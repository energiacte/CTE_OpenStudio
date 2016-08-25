# coding: utf-8

def cte_ventresidencial(workspace, runner, user_arguments)

runner.registerInitialCondition("CTE: Ventilacion en uso residencial")

    # --------------------------------------------------------------------------------------------------------
    # **** 1 - Corrección de horarios de ventilación en objetos ZoneVentilation:DesignFlowRate es CTER24B_HVEN
    # --------------------------------------------------------------------------------------------------------
    runner.registerInfo("[1/2] - Cambio de horarios en objetos ZoneVentilation_DesignFlowRate a #{ CTE_SCHEDULE_NAME }")
    idfObjects = workspace.getObjectsByType("ZoneVentilation_DesignFlowRate".to_IddObjectType)
    if idfObjects.empty?
      runner.registerInfo("* No se han encontrado objetos ZoneVentilation_DesignFlowRate")
    else
      runner.registerInfo("* Encontrado(s) #{ idfObjects.size } objeto(s) ZoneVentilation_DesignFlowRate")
      changeCounter = 0
      idfObjects.each do | obj |
        currentSchedule = obj.getString(2)
        if currentSchedule == CTE_SCHEDULE_NAME then continue end
        changeCounter += 1
        runner.registerInfo("- Cambiando horario #{ currentSchedule } del objeto '#{ obj.getString(0) }'")
        result = obj.setString(2, CTE_SCHEDULE_NAME) # Correccion de nombre de horario
        if not result
          runner.registerInfo("ERROR al modificar el nombre del horario")
        end
      end
      runner.registerInfo("* Cambiado(s) #{ changeCounter } horario(s) de #{ idfObjects.size } objeto(s) ZoneVentilation_DesignFlowRate")
    end
  return true
end
