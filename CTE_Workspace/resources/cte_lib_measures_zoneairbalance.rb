# coding: utf-8

  # 2 - Introducción de objetos de balance de aire exterior
  # En lugar de una red de flujos, la consideración de las infiltraciones se está haciendo mediante
  # el método ELA, (ZoneInfiltration:...), de forma desacoplada a la ventilación (ZoneVentilation:DesignFlowRate).
  # Para tener en cuenta la interacción entre ambos componentes se usa el objeto de ZoneAirBalance:OutdoorAir,
  # que realiza una combinación cuadrática de ambas componentes Q^2 = Q_v^2 + Q_i^2
  # Al realizar este cambio, los resultados de aire exterior se muestran en variables separadas del tipo:
  #  HVAC,Sum,Zone Combined Outdoor Air...

def cte_addAirBalance(runner, workspace, string_objects)
  runner.registerInfo(" Introducción de objetos ZoneAirBalance:OutdooAir")
  idfZones = workspace.getObjectsByType("Zone".to_IddObjectType)
  if idfZones.empty?
    runner.registerInfo("* No se han encontrado objetos Zone a los que añadir un objeto ZoneAirBalance:OutdoorAir")
  else
    runner.registerInfo("* Encontrado(s) #{ idfZones.size } objeto(s) Zone")
    idfZones.each do | idfZone |
      nombreZona = idfZone.getString(0)
      runner.registerInfo("- Definido objeto ZoneAirBalance:OutdoorAir para la zona '#{ nombreZona }'")
      string_objects << "
        ZoneAirBalance:OutdoorAir,
        #{nombreZona} OutdoorAir Balance, !- Name
        #{nombreZona},            !- Zone Name
        Quadrature,               !- Air Balance Method
        0.00,                     !- Induced Outdoor Air Due to Unbalanced Duct Leakage {m3/s}
        CTER24B_HINF;             !- Induced Outdoor Air Schedule Name
        "
    end
    runner.registerInfo("* Cambiado(s) #{ idfZones.size } objeto(s) Zone")
  end
  return true
end
