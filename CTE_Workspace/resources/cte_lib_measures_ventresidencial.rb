# coding: utf-8

  # 1 - Corrección de horarios de ventilación nocturna y caudal de diseño (HS3)
  # OpenStudio genera un objeto ZoneVentilation:DesignFlowRate con horario Always_On cuando se introducen
  # sistemas ideales. Puesto que usamos objetos ZoneVentilation:DesignFlowRate para introducir el caudal
  # de diseño de aire de renovación (HS3) y la ventilación noctura, debemos cambiar el horario Always_On
  # por uno que cuando se use con fracción 1 nos de 4 ren/h en horario nocturno de verano y el caudal
  # de diseño el resto del tiempo (CTER24B_HVEN).
  # Corrección de horarios de ventilación en objetos ZoneVentilation:DesignFlowRate es CTER24B_HVEN
  
CTE_SCHEDULE_NAME = "CTER24B_HVEN"

def cte_ventresidencial(workspace, runner, user_arguments)

    runner.registerInitialCondition("CTE: Ventilacion en uso residencial")
    runner.registerInfo(" Cambio de horarios en objetos ZoneVentilation_DesignFlowRate a #{ CTE_SCHEDULE_NAME }")
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
