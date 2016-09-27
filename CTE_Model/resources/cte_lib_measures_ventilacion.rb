# -*- coding: utf-8 -*-
#
# Copyright (c) 2016 Ministerio de Fomento
#                    Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author(s): Rafael Villar Burke <pachi@ietcc.csic.es>,
#            Daniel Jiménez González <dani@ietcc.csic.es>
#            Marta Sorribes Gil <msorribes@ietcc.csic.es>

HORARIOVENTILACIONRESIDENCIAL = "CTER24B_HVEN"

# Ventilacion Residencial CTE:
# 1 - Redefine el horario de ventilación con caudal de diseño y ventilación nocturna en verano, CTER24B_HVEN (disponible en plantilla)
# 2 - Incorpora objetos ZoneVentilation:DesignFlowRate a zonas habitables, con horario CTER24B_HVEN
# Condiciones de ventilacion e infiltraciones para uso residencial segun CTE:
# Usa el modelo simple con ventilacion nocturna de 4 ren/h en verano para las zonas habitables y el caudal de diseno indicado en ren/h el resto del tiempo.
# Esta medida necesita otra complementaria de EPlus que corrige los horarios de las zonas si es necesario.

def cte_ventresidencial(model, runner, user_arguments)
  runner.registerInfo("CTE: Definición de condiciones de ventilación de espacios habitables en edificios residenciales.")

  # ------------------------------------------------------------------------------------------------------------------------------------
  # 1 - Redefine el horario de ventilación con caudal de diseño y ventilación nocturna en verano, CTER24B_HVEN (disponible en plantilla)
  # ------------------------------------------------------------------------------------------------------------------------------------
  design_flow_rate = runner.getDoubleArgumentValue('design_flow_rate', user_arguments)
  heat_recovery = runner.getDoubleArgumentValue('heat_recovery', user_arguments)
  return false if heat_recovery > 1.0
  
  runner.registerInfo("[1/2] Definiendo horario con ventilación nocturna en verano (4ren/h) y caudal de diseño: #{design_flow_rate*heat_recovery} [ren/h]")
  frac_general_ventilacion = design_flow_rate * heat_recovery / 4
  frac_nocheverano_ventilacion = 1
  runner.registerValue("CTE Fracción de ventilación nocturna en verano", frac_nocheverano_ventilacion, "[ren/h]")
  runner.registerValue("CTE Fracción de ventilación con caudal de diseño", frac_general_ventilacion, "[ren/h]")

  runner.registerInfo("* Localizando en el modelo el horario '#{HORARIOVENTILACIONRESIDENCIAL}' definido en la plantilla")
  # Esto localiza la primera regla
  scheduleRulesets = model.getScheduleRulesets
  ventilationRuleset = ''
  scheduleRulesets.each do | scheduleRuleset |
    if scheduleRuleset.name.get == HORARIOVENTILACIONRESIDENCIAL
      ventilationRuleset = scheduleRuleset
      runner.registerInfo("+ Localizado conjunto de horarios '#{HORARIOVENTILACIONRESIDENCIAL}'. Eliminando #{ventilationRuleset.scheduleRules.count} reglas existentes")
      ventilationRuleset.scheduleRules.each do |rule|
        rule.remove
      end
      break
    end
  end

  if not ventilationRuleset
    runner.registerError("ERROR: No se ha encontrado el conjunto de horarios '#{HORARIOVENTILACIONRESIDENCIAL}'. Ha usado la plantilla para modelado CTE?")
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

  runner.registerInfo("* Incorporando reglas de ventilación al conjunto '#{HORARIOVENTILACIONRESIDENCIAL}'")
  ventilationRuleset.scheduleRules.each do |rule|
    runner.registerInfo("+ Regla '#{ rule.name }' (#{ rule.daySchedule.values }):")
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
    zoneIsIdeal = zone.useIdealAirLoads ? true : false
    spaces = zone.spaces()
    runner.registerInfo("+ Localizado(s) #{ spaces.count } espacio(s) en la zona '#{ zoneName }'")
    # Solamente usamos el primer espacio de la zona? suponemos que solo hay uno?
    spaces.each do |space|
      spaceName = space.name.get
      spaceType = space.spaceType.get
      spaceTypeName = spaceType.name.get
      # Las zonas con Ideal Air Loads incorporan un objeto ZoneVentilation:DesignFlowRate si la
      # plantilla define para ese tipo de espacio un objeto 'Design Specification Outdoor Air'
      if zoneIsIdeal and not spaceType.isDesignSpecificationOutdoorAirDefaulted
          runner.registerInfo("- El espacio '#{ spaceName }' de la zona '#{ zoneName }' tiene sistemas ideales y ZoneVentilation:DesignFlowRate definido en el tipo '#{ spaceTypeName }")
          next
      end
      if spaceTypeName.start_with?('CTE_HR') or spaceTypeName.start_with?('CTE_AR')
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
        runner.registerInfo("- Creando objeto ZoneVentilation:DesignFlowRate en espacio '#{ spaceName }' del tipo '#{ spaceTypeName }' en la zona '#{ zoneName }'")
      else
        runner.registerInfo("- El espacio '#{ spaceName }' de la zona '#{ zoneName }' no es habitable (tipo: '#{ spaceTypeName }')")
      end
    end
  end
  runner.registerInfo("* Creado(s) #{ zoneVentilationCounter } objeto(s) ZoneVentilation:DesignFlowRate. ")
  runner.registerInfo("CTE: Finalizada definición de condiciones de ventilación de espacios habitables en edificios residenciales.")
  return true # OS necesita saber que todo acabó bien

end # end run
