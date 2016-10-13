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

# 1 - Corrección de horarios de ventilación nocturna y caudal de diseño (HS3) para versiones anteriores a 1.12
# OpenStudio genera un objeto ZoneVentilation:DesignFlowRate con horario Always_On (en versiones anteriores a 1.12)
# cuando se introducen sistemas ideales. 
#Puesto que usamos objetos ZoneVentilation:DesignFlowRate para introducir el caudal
# de diseño de aire de renovación (HS3) y la ventilación noctura, debemos cambiar el horario Always_On
# por uno que cuando se use con fracción 1 nos de 4 ren/h en horario nocturno de verano y el caudal
# de diseño el resto del tiempo (CTER24B_HVEN).
# Corrección de horarios de ventilación en objetos ZoneVentilation:DesignFlowRate es CTER24B_HVEN

#~ CTE_SCHEDULE_NAME = "CTER24B_HVEN"

def cte_ventresidencial(workspace, runner, user_arguments)
  return true
end

    #~ runner.registerInitialCondition("CTE: Ventilacion en uso residencial")
    #~ runner.registerInfo(" Cambio de horarios en objetos ZoneVentilation_DesignFlowRate a #{ CTE_SCHEDULE_NAME }")
    #~ idfObjects = workspace.getObjectsByType("ZoneVentilation_DesignFlowRate".to_IddObjectType)
    #~ if idfObjects.empty?
      #~ runner.registerInfo("* No se han encontrado objetos ZoneVentilation_DesignFlowRate")
    #~ else
      #~ runner.registerInfo("* Encontrado(s) #{ idfObjects.size } objeto(s) ZoneVentilation_DesignFlowRate")
      #~ changeCounter = 0
      #~ idfObjects.each do | obj |
        #~ currentSchedule = obj.getString(2)
        #~ if currentSchedule == CTE_SCHEDULE_NAME then continue end
        #~ changeCounter += 1
        #~ runner.registerInfo("- Cambiando horario #{ currentSchedule } del objeto '#{ obj.getString(0) }'")
        #~ result = obj.setString(2, CTE_SCHEDULE_NAME) # Correccion de nombre de horario
        #~ if not result
          #~ runner.registerInfo("ERROR al modificar el nombre del horario")
        #~ end
      #~ end
      #~ runner.registerInfo("* Cambiado(s) #{ changeCounter } horario(s) de #{ idfObjects.size } objeto(s) ZoneVentilation_DesignFlowRate")
    #~ end
  #~ return true
#~ end
