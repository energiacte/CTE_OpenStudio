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

def cte_horarioestacional(runner, workspace)
  dayligthSavings = workspace.getObjectsByType("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
  if not dayligthSavings.empty?
    dayligthSavings.each do | dayligthSaving |
      runner.registerInfo("  Se ha localizado y modificado una definición de horario de verano")
      dayligthSaving.setString(0, "Last Sunday in March")
      dayligthSaving.setString(1, "Last Sunday in October")
    end
  else
    dayligthSaving = OpenStudio::IdfObject.new("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
    runner.registerInfo("Se ha añadido una definición de horario de verano")
    dayligthSaving.setString(0, "Last Sunday in March")
    dayligthSaving.setString(1, "Last Sunday in October")
    workspace.addObject(dayligthSaving)
  end
  return true
end
