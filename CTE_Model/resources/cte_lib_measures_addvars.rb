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

# Inyecta variables y meters para uso con el CTE
def cte_addvars(model, runner, user_arguments)

  # Get initial conditions ==========================================
  meters = model.getOutputMeters
  output_variables = model.getOutputVariables
  runner.registerInfo("CTE_ADDVARS: The model started with #{meters.size} meter objects, and #{output_variables.size} output variables.")

  # Add CTE meters ==================================================

  new_meters = [
    #["Propane:Facility", "RunPeriod"], # this meter exists in the exampleModel
    ["DistrictHeating:Facility", "RunPeriod"],
    ["DistrictCooling:Facility", "RunPeriod"],
    ["Fans:Electricity", "Monthly", "*"],
    ["InteriorLights:Electricity", "Monthly", "*"],
    ["Heating:DistrictHeating", "Hourly", "*"],
    ["Cooling:DistrictCooling", "Hourly", "*"],
  ]

  existing_meters = Hash[meters.map{ |meter| [meter.name, meter] }.compact]

  new_meters.each do | meterName, reporting_frequency, key |
    if existing_meters.has_key?(meterName)
      runner.registerInfo("Meter #{meterName} already in meters")
      meter = existing_meters[meterName]
      if not meter.reportingFrequency == reporting_frequency
        meter.setReportingFrequency(reporting_frequency)
        runner.registerInfo("Changing meter #{meterName} reporting frequency to #{reporting_frequency}.")
      end
    else
      meter = OpenStudio::Model::OutputMeter.new(model)
      meter.setName(meterName)
      meter.setReportingFrequency(reporting_frequency)
      runner.registerInfo("Adding output meter #{meterName} with reporting frequency #{ reporting_frequency } for key #{key}.")
    end
  end

  # Add CTE output variables =========================================

  new_oputput_variables = [
    # Monthly variables
    ["Site Outdoor Air Drybulb Temperature", "Monthly", "*"],
    ["Surface Inside Face Conduction Heat Transfer Energy", "Monthly", "*"],
    ["Surface Window Heat Gain Energy", "Monthly", "*"],
    ["Surface Window Heat Loss Energy", "Monthly", "*"],
    ["Surface Window Transmitted Solar Radiation Energy", "Monthly", "*"],
    ["Zone Lights Electricity Energy", "Monthly", "*"],
    ["Zone Total Internal Total Heating Energy", "Monthly", "*"],
    ["Zone Ideal Loads Zone Total Heating Energy", "Monthly", "*"],
    ["Zone Ideal Loads Zone Total Cooling Energy", "Monthly", "*"],
    ["Zone Combined Outdoor Air Sensible Heat Loss Energy", "Monthly", "*"],
    ["Zone Combined Outdoor Air Sensible Heat Loss Energy", "Daily", "*"],
    ["Zone Combined Outdoor Air Sensible Heat Gain Energy", "Monthly", "*"],
    ["Zone Combined Outdoor Air Changes per Hour", "Monthly", "*"],
    ["Zone Combined Outdoor Air Fan Electric Energy", "Monthly", "*"],
    ["Zone Ideal Loads Economizer Active Time", "Monthly", "*"],
    ["Zone Ideal Loads Heat Recovery Active Time", "Monthly", "*"],
    ["Zone Ideal Loads Economizer Active Time", "Daily", "*"],
    ["Zone Ideal Loads Heat Recovery Active Time", "Daily", "*"],
    ["Zone Ideal Loads Economizer Active Time", "Hourly", "*"],
    ["Zone Ideal Loads Heat Recovery Active Time", "Hourly", "*"],    
    ["Zone Combined Outdoor Air Changes per Hour", "Hourly", "*"],
    ["Zone Combined Outdoor Air Changes per Hour", "Daily", "*"],
    ["Zone Ventilation Air Change Rate", "monthly", "*"],
    ["Zone Mechanical Ventilation Air Changes per Hour", "hourly", "*"]    
  ]

  new_oputput_variables.each do | variable_name, reporting_frequency, key |
    outputVariable = OpenStudio::Model::OutputVariable.new(variable_name, model)
    outputVariable.setReportingFrequency(reporting_frequency)
    outputVariable.setKeyValue(key)
    runner.registerInfo("Adding output variable #{variable_name} with reporting frequency #{reporting_frequency} for key #{key}.")
  end


  # Get final condition ================================================

  meters = model.getOutputMeters
  output_variables = model.getOutputVariables
  runner.registerInfo("CTE_ADDVARS: The model finished with #{meters.size} meter objects and #{output_variables.size} output variables.")

  return true
end
