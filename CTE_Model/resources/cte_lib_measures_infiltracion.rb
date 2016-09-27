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

TO4PA = 0.11571248 # pow(4/100., 0.67), de 100 a 4 pascales
C_OP = { 'Nuevo'     => 16 * TO4PA,
         'Existente' => 29 * TO4PA }
C_PU = 60 * TO4PA # Permeabilidad puertas a 4Pa
C_HU = { 'Clase 1' => 50 * TO4PA,
         'Clase 2' => 27 * TO4PA,
         'Clase 3' => 9 * TO4PA,
         'Clase 4' => 3 * TO4PA }

def cte_horario_de_infiltracion(runner, space, horario_allways_on)
    spaceName = space.name.get
    spaceType = space.spaceType.get.name.get
    habitable = !spaceType.start_with?('CTE_N')
    runner.registerInfo("___ spaceName #{spaceName}, habitable: #{habitable}")
    runner.registerInfo("    spaceType #{spaceType}")

    if habitable
      thermalZone = space.thermalZone.get
      thermalZoneName = thermalZone.name.get
      runner.registerInfo("    thermal zone #{thermalZoneName}")
      idealLoads = thermalZone.useIdealAirLoads
      runner.registerInfo("    cargas ideales: #{idealLoads}")
      if !idealLoads
        listaDeEquipos = thermalZone.zoneConditioningEquipmentListName
        if listaDeEquipos.empty?
          runner.registerInfo ("  habitable no acondicionado")
          horarioInfiltracion = horario_allways_on
        else
          runner.registerInfo ("  habitable acondicionado")
          horarios =  space.defaultScheduleSet.empty?  ?
                      space.spaceType.get.defaultScheduleSet.get :
                      space.defaultScheduleSet.get
          horarioInfiltracion = horarios.infiltrationSchedule.get
        end
      else
        runner.registerInfo ("  habitable acondicionado")
        horarios =  space.defaultScheduleSet.empty?  ?
                    space.spaceType.get.defaultScheduleSet.get :
                    space.defaultScheduleSet.get
        horarioInfiltracion = horarios.infiltrationSchedule.get
      end
    else
      runner.registerInfo ("  no habitable")
      horarios = space.defaultScheduleSet.get
      horarioInfiltracion = horarios.infiltrationSchedule.get
    end
    return horarioInfiltracion
end


#Se modelan las infiltraciones usando el método ELA y las permeabilidades
# y parámetros del documento de condic. técnicas
def cte_infiltracion(model, runner, user_arguments) #copiado del residencial

  # busca el horario para hacer allways_on
  horarios = model.getScheduleRulesets
  horario_allways_on = false
  horarios.each do | horario |
    if horario.name.get == 'CTER24B_HINF'
      horario_allways_on = horario
      break
    end
  end

  #hay que tomar el horario del espacio -> zona -> tipo de zona

  tipoEdificio = runner.getStringArgumentValue('tipoEdificio', user_arguments)
  claseVentana = runner.getStringArgumentValue('permeabilidadVentanas', user_arguments)
  coefStack = runner.getDoubleArgumentValue('coefStack', user_arguments)
  coefWind = runner.getDoubleArgumentValue('coefWind', user_arguments)

  runner.registerValue("CTE Tipo de Edificio (Nuevo/Existente)", tipoEdificio)
  runner.registerValue("CTE Clase de permeabilidad de Ventanas", claseVentana)

  spaces = model.getSpaces
  runner.registerValue("CTE Coeficientes de fugas de opacos a 4Pa", C_OP[tipoEdificio].round(4))
  runner.registerValue("CTE Coeficientes de fugas de puertas a 4Pa", C_PU.round(4))
  runner.registerValue("CTE Coeficientes de fugas de huecos a 4Pa", C_HU[claseVentana].round(4))

  runner.registerInfo("** Superficies para ELA **")
  # XXX: pensar como interactúa con los espacios distintos a los acondicionados
  spaces.each do |space|
    runner.registerInfo("* Espacio '#{ space.name }'")
    horarioInfiltracion = cte_horario_de_infiltracion(runner, space, horario_allways_on)
    areaOpacos = 0
    areaVentanas = 0
    areaPuertas = 0
    # TODO: filtrar superficies NoMass, que son superficies auxiliares
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == 'Outdoors' and surface.windExposure == 'WindExposed'
        surfArea = surface.netArea
        areaOpacos += surfArea
        runner.registerInfo("- '#{ surface.name }', #{ surface.surfaceType }, #{ surfArea.round(2) }")
        surface.subSurfaces.each do |subsur|
          subSurfArea = subsur.grossArea
          runner.registerInfo("- '#{subsur.name}', #{ subsur.subSurfaceType }, #{ subSurfArea.round(2) }")
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

    runner.registerInfo("-- Totales [m2]: opacos: #{ areaOpacos.round(2) }, huecos #{ areaVentanas.round(2) }, puertas #{ areaPuertas.round(2) }\n")

    c_ven = 0.0 # Superficie bocas admisión
    if claseVentana != 'Clase 1'
      c_ven = C_HU['Clase 1'] - C_HU[claseVentana]
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
    ela.setName('CTE_ELA_#{ space.name }')
  end

  return true # OS necesita saber que todo acaba bien
end
