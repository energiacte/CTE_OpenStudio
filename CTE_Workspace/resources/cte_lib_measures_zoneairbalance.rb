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

# === Introducción de objetos de balance de aire exterior ===
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
