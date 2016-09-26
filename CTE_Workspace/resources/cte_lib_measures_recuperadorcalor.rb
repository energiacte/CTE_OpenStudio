# coding: utf-8

def cte_recuperadorcalor(runner, workspace, user_arguments)

    runner.registerInitialCondition("CTE: Recuperadores de calor")
    tipoRecuperadorDeCalor = runner.getStringArgumentValue('recuperador', user_arguments)
    
    if tipoRecuperadorDeCalor == 'Ninguno' 
      runner.registerInfo("  no se ha encontrado recuperador")
      return true
    end
    #latente_effectiveness
    #~ recuperadorDeCalor = runner.getOptionalWorkspaceObjectChoiceValue('recuperador',user_arguments, workspace)
    efect_sensible = runner.getDoubleArgumentValue('sensible_effectiveness', user_arguments)
    efect_latente = runner.getDoubleArgumentValue('latente_effectiveness', user_arguments)
    
    runner.registerInfo(" Tipo de recuperador: #{tipoRecuperadorDeCalor}")
    runner.registerInfo(" Efectividad de la recuperación sensible: #{efect_sensible}")
    runner.registerInfo(" Efectividad de la recuperación latente: #{efect_latente}")    
    
    idfObjects = workspace.getObjectsByType("ZoneHVAC_IdealLoadsAirSystem".to_IddObjectType)
    runner.registerInfo("No se han encontrado ZoneHVAC_IdealLoadsAirSystem") if idfObjects.empty? 
    idfObjects.each do | obj |        
      obj.setString(23, tipoRecuperadorDeCalor)
      obj.setString(24, efect_sensible.to_s)
      obj.setString(25, efect_latente.to_s)
    end
    
  return true
end
