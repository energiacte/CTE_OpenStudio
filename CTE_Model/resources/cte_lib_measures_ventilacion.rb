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
HORARIOVENTILACIONNOCTURNO = "CTER24B_HVNOC"


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
  q_ven_real = design_flow_rate * (1 - heat_recovery)
  q_ven_noct = 4 - q_ven_real
  runner.registerValue("CTE caudal de ventilación nocturna en verano", q_ven_noct, "[ren/h]")
  runner.registerValue("CTE caudal de ventilación reducido con caudal de diseño y recuperación", q_ven_real, "[ren/h]")

  scheduleRulesets = model.getScheduleRulesets
  runner.registerInfo("* Localizando en el modelo el horario '#{HORARIOVENTILACIONRESIDENCIAL}' de la plantilla")
  scheduleRuleRES = scheduleRulesets.detect { |sch| sch.name.get == HORARIOVENTILACIONRESIDENCIAL}
  runner.registerInfo("* Localizando en el modelo el horario '#{HORARIOVENTILACIONNOCTURNO}' de la plantilla")
  scheduleRuleNOC = scheduleRulesets.detect { |sch| sch.name.get == HORARIOVENTILACIONNOCTURNO }


  # ------------------------------------------------------------------------------------------------------------------------------------
  # 2 - Incorpora objetos ZoneVentilation:DesignFlowRate a zonas residenciales,
  #     con horario CTER24B_HVEN y CTE24B_HVNOC para caudal de diseño y ventilación nocturna, respectivamente
  # ------------------------------------------------------------------------------------------------------------------------------------

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
        zoneVentilationCounter += 2
        # TODO: permitir usar tipo 'Exhaust' para obtener consumo de ventiladores
        # TODO: necesita diferencia de presión del ventilador y rendimiento total del ventilador
        zone_ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zone_ventilation.addToThermalZone(zone)
        zone_ventilation.setVentilationType('Natural')
        zone_ventilation.setDesignFlowRateCalculationMethod("AirChanges/Hour")
        zone_ventilation.setAirChangesperHour(q_ven_noct) # 4 ren/h
        zone_ventilation.setConstantTermCoefficient(1)
        zone_ventilation.setTemperatureTermCoefficient(0)
        zone_ventilation.setVelocityTermCoefficient(0)
        zone_ventilation.setVelocitySquaredTermCoefficient(0)
        zone_ventilation.setMinimumIndoorTemperature(-100)
        zone_ventilation.setDeltaTemperature(-100)
        zone_ventilation.setSchedule(scheduleRuleNOC)
        runner.registerInfo("- Creando objeto ZoneVentilation:DesignFlowRate NOCTURNO en espacio '#{ spaceName }' del tipo '#{ spaceTypeName }' en la zona '#{ zoneName }'")

        zone_ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zone_ventilation.addToThermalZone(zone)
        zone_ventilation.setVentilationType('Exhaust')
        zone_ventilation.setDesignFlowRateCalculationMethod("AirChanges/Hour")
        zone_ventilation.setAirChangesperHour(q_ven_real) #
        zone_ventilation.setConstantTermCoefficient(1)
        zone_ventilation.setTemperatureTermCoefficient(0)
        zone_ventilation.setVelocityTermCoefficient(0)
        zone_ventilation.setVelocitySquaredTermCoefficient(0)
        zone_ventilation.setMinimumIndoorTemperature(-100)
        zone_ventilation.setDeltaTemperature(-100)
        zone_ventilation.setSchedule(scheduleRuleRES)
        runner.registerInfo("- Creando objeto ZoneVentilation:DesignFlowRate NORMAL en espacio '#{ spaceName }' del tipo '#{ spaceTypeName }' en la zona '#{ zoneName }'")


      else
        runner.registerInfo("- El espacio '#{ spaceName }' de la zona '#{ zoneName }' no es habitable (tipo: '#{ spaceTypeName }')")
      end
    end
  end
  runner.registerInfo("* Creado(s) #{ zoneVentilationCounter } objeto(s) ZoneVentilation:DesignFlowRate. ")
  runner.registerInfo("CTE: Finalizada definición de condiciones de ventilación de espacios habitables en edificios residenciales.")
  return true # OS necesita saber que todo acabó bien

end # end run
