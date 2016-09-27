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
