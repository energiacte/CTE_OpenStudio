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
#
# Horarios de infiltración:
# - espacios no habitables y en habitables no acondicionados: permanente
# - espacios habitables acondicionados: horario específico
#
# Nivel de infiltraciones usando el modelo ELA (Effective Leakage Area):
# - fugas por opacos + fugas por huecos + (residencial) fugas por aireadores
#
# En residencial se considera una infiltración adicional por los aireadores,
# y consideramos que la podemos aproximar por ventanas en posición de microventilación.
#
# DUDA: Esta última superficie:
# - ¿tiene sentido añadirla o es redundante con la ventilación?

TO4PA ||= 0.11571248 # pow(4/100., 0.67), de 100 a 4 pascales
C_OP ||= { 'Nuevo'     => 16 * TO4PA,
           'Existente' => 29 * TO4PA }
C_PU ||= 60 * TO4PA # Permeabilidad puertas a 4Pa
C_HU ||= { 'Clase 1' => 50 * TO4PA,
           'Clase 2' => 27 * TO4PA,
           'Clase 3' => 9 * TO4PA,
           'Clase 4' => 3 * TO4PA }

def cte_horario_de_infiltracion(runner, space, horario_always_on)
    # spaceName = space.name.get
    spaceType = space.spaceType.get.name.get
    habitable = !spaceType.start_with?('CTE_N')

    if habitable
      # Habitable
      thermalZone = space.thermalZone.get
      idealLoads = thermalZone.useIdealAirLoads
      if !idealLoads
        listaDeEquipos = thermalZone.zoneConditioningEquipmentListName
        if listaDeEquipos.empty?
          # Habitable no acondicionado
          horarioInfiltracion = horario_always_on
        else
          # Equipos reales + habitable acondicionado
          horarios =  space.defaultScheduleSet.empty?  ?
                      space.spaceType.get.defaultScheduleSet.get :
                      space.defaultScheduleSet.get
          horarioInfiltracion = horarios.infiltrationSchedule.get
        end
      else
        # Equipos ideales + habitable acondicionado
        horarios =  space.defaultScheduleSet.empty?  ?
                    space.spaceType.get.defaultScheduleSet.get :
                    space.defaultScheduleSet.get
        horarioInfiltracion = horarios.infiltrationSchedule.get
      end
    else
      # No habitable
      horarios = space.defaultScheduleSet.get
      horarioInfiltracion = horario_always_on
    end
    return horarioInfiltracion
end


#Se modelan las infiltraciones usando el método ELA y las permeabilidades
# y parámetros del documento de condic. técnicas
def cte_infiltracion(model, runner, user_arguments) #copiado del residencial

  # busca el horario para hacer always_on
  horario_always_on = model.getScheduleRulesets
                      .find { |h| h.name.get == 'CTER24B_HINF' } || false

  #hay que tomar el horario del espacio -> zona -> tipo de zona

  tipoEdificio = runner.getStringArgumentValue('CTE_Tipo_edificio', user_arguments)
  claseVentana = runner.getStringArgumentValue('CTE_Permeabilidad_ventanas', user_arguments)
  coefStack = runner.getDoubleArgumentValue('CTE_Coef_stack', user_arguments)
  coefWind = runner.getDoubleArgumentValue('CTE_Coef_wind', user_arguments)

  runner.registerValue("CTE Tipo de Edificio (Nuevo/Existente)", tipoEdificio)
  runner.registerValue("CTE Clase de permeabilidad de Ventanas", claseVentana)

  spaces = model.getSpaces
  runner.registerValue("CTE Coeficientes de fugas de opacos a 4Pa", C_OP[tipoEdificio].round(4))
  runner.registerValue("CTE Coeficientes de fugas de puertas a 4Pa", C_PU.round(4))
  runner.registerValue("CTE Coeficientes de fugas de huecos a 4Pa", C_HU[claseVentana].round(4))

  runner.registerInfo("** Superficies para ELA **")
  # XXX: pensar como interactúa con los espacios distintos a los acondicionados
  # ELA_total para comprobaciones
  ela_total = 0.0
  spaces.each do |space|
    horarioInfiltracion = cte_horario_de_infiltracion(runner, space, horario_always_on)
    areaOpacos = 0
    areaVentanas = 0
    areaPuertas = 0
    # TODO: filtrar superficies NoMass, que son superficies auxiliares
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == 'Outdoors' and surface.windExposure == 'WindExposed'
        surfArea = surface.netArea
        areaOpacos += surfArea
        # runner.registerInfo("- '#{ surface.name }', #{ surface.surfaceType }, #{ surfArea.round(2) }")
        surface.subSurfaces.each do |subsur|
          subSurfArea = subsur.grossArea
          # runner.registerInfo("- '#{subsur.name}', #{ subsur.subSurfaceType }, #{ subSurfArea.round(2) }")
          if ['FixedWindow', 'OperableWindow', 'SkyLight'].include?(subsur.subSurfaceType)
            areaVentanas += subSurfArea
          elsif ['Door', 'GlassDoor', 'OverheadDoor'].include?(subsur.subSurfaceType)
            areaPuertas += subSurfArea
          else
            runner.registerWarning("Subsuperficie '#{ subsur.name }' con tipo desconocido '#{ subsur.subSurfaceType }' en superficie '#{ surface.name }' del espacio '#{ space.name }'")
          end
        end
      end
    end

    #runner.registerInfo("Infiltraciones: '#{ space.name }' / '#{ horarioInfiltracion.name.get }' - ELA [m2]: opacos: #{ areaOpacos.round(2) }, huecos #{ areaVentanas.round(2) }, puertas #{ areaPuertas.round(2) }\n")

    usoEdificio = runner.getStringArgumentValue('CTE_Uso_edificio',
                                                user_arguments)
    # Superficie bocas admisión, según modelo simplificado en residencial
    if claseVentana != 'Clase 1' and usoEdificio == 'Residencial'
      # Superficie igual a lo que falta para microventilación
      c_ven = C_HU['Clase 1'] - C_HU[claseVentana]
    else
      c_ven = 0.0
    end

    # q_total en m3/h a 4 Pa
    q_total = 4.0 ** 0.67 * (C_OP[tipoEdificio] * areaOpacos +
                             C_HU[claseVentana] * areaVentanas +
                             C_PU * areaPuertas +
                             # microventilación al 50% de apertura
                             0.50 * c_ven * areaVentanas / (4.0 ** 0.5))

    areaEquivalente = 1.0758287 * 0.50 * q_total # area ELA en cm2 con el 50% del área expuesta
    runner.registerValue("CTE ELA ('#{ space.name }')", areaEquivalente.round(2), "cm2 a 4Pa")

    # Elimina todos los objetos ELA que pueda haber
    space.spaceInfiltrationEffectiveLeakageAreas.each{ |ela| ela.remove }

    # E inserta los nuevos
    ela = OpenStudio::Model::SpaceInfiltrationEffectiveLeakageArea.new(model)
    ela.setSpace(space)
    ela.setStackCoefficient(coefStack)
    ela.setWindCoefficient(coefWind)
    ela.setSchedule(horarioInfiltracion)
    ela.setEffectiveAirLeakageArea(areaEquivalente)
    ela.setName("CTE_ELA_#{ space.name }")

    ela_total += areaEquivalente
  end
  runner.registerValue("cte_ela_total_espacios", ela_total, "cm2 a 4 Pa")

  return true # OS necesita saber que todo acaba bien
end
