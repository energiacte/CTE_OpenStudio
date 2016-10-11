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
  meters = model.getMeters
  output_variables = model.getOutputVariables
  runner.registerInfo("CTE_ADDVARS: The model started with #{meters.size} meter objects, and #{output_variables.size} output variables.")

  # Add CTE meters ==================================================

  new_meters = [
    ["DistrictHeating:Facility", "RunPeriod"],
    ["DistrictCooling:Facility", "RunPeriod"],
    #["Propane:Facility", "RunPeriod"] # this meter exists in the exampleModel
  ]

  existing_meters = Hash[meters.map{ |meter| [meter.name, meter] }.compact]

  new_meters.each do | new_meter |
    new_meter_name, new_reporting_frequency = new_meter
    if existing_meters.has_key?(new_meter_name)
      runner.registerInfo("Meter #{new_meter_name} already in meters")
      meter = existing_meters[new_meter_name]
      if not meter.reportingFrequency == new_reporting_frequency
        meter.setReportingFrequency(new_reporting_frequency)
        runner.registerInfo("Changing meter #{new_meter_name} reporting frequency to #{new_reporting_frequency}.")
      end
    else
      meter = OpenStudio::Model::Meter.new(model)
      meter.setName(new_meter_name)
      meter.setReportingFrequency(new_reporting_frequency)
      runner.registerInfo("Adding meter for #{new_meter_name} reporting #{ new_reporting_frequency }")
    end
  end

  # Add CTE output variables =========================================

  new_oputput_variables = [
    # Monthly variables
    ["Site Outdoor Air Drybulb Temperature", "monthly", "*"],
    ["Surface Inside Face Conduction Heat Transfer Energy", "monthly", "*"],
    ["Surface Window Heat Gain Energy", "monthly", "*"],
    ["Surface Window Heat Loss Energy", "monthly", "*"],
    ["Surface Window Transmitted Solar Radiation Energy", "monthly", "*"],
    ["Zone Total Internal Total Heating Energy", "monthly", "*"],
    #["Zone Total Internal Convective Heating Energy", "monthly", "*"], # parte convectiva de la carga total de la zona
    ["Zone Ideal Loads Zone Total Heating Energy", "monthly", "*"],
    ["Zone Ideal Loads Zone Total Cooling Energy", "monthly", "*"],
    #["Zone Ideal Loads Outdoor Air Standard Density Volume Flow Rate", "monthly", "*"],
    #["Zone Ideal Loads Supply Air Standard Density Volume Flow Rate", "monthly", "*"],
    ["Zone Combined Outdoor Air Sensible Heat Loss Energy", "monthly", "*"],
    ["Zone Combined Outdoor Air Sensible Heat Gain Energy", "monthly", "*"],
    ["Zone Combined Outdoor Air Changes per Hour", "monthly", "*"],
    ["Zone Combined Outdoor Air Fan Electric Energy", "monthly", "*"]
    
    # Hourly variables
    #~ ["Surface Inside Face Conduction Heat Transfer Energy", "hourly", "*"],
    #~ ["Surface Window Heat Gain Energy", "hourly", "*"],
    #~ ["Surface Window Heat Loss Energy", "hourly", "*"],
    #~ ["Surface Window Transmitted Solar Radiation Energy", "hourly", "*"],
    #~ ["Zone Thermostat Cooling Setpoint Temperature", "hourly", "*"],
    #~ ["Zone Thermostat Heating Setpoint Temperature", "hourly", "*"],
    #~ ["Zone Total Internal Total Heating Energy", "hourly", "*"],
    #["Zone Total Internal Convective Heating Energy", "hourly", "*"], # parte convectiva de la carga total de la zona
    #~ ["Zone Mechanical Ventilation Current Density Volume", "hourly", "*"],
    #~ ["Zone Combined Outdoor Air Sensible Heat Loss Energy", "hourly", "*"],
    #~ ["Zone Combined Outdoor Air Sensible Heat Gain Energy", "hourly", "*"],
    #~ ["Zone Combined Outdoor Air Changes per Hour", "hourly", "*"]
  ]

  new_oputput_variables.each do | variable_name, reporting_frequency, key |
    outputVariable = OpenStudio::Model::OutputVariable.new(variable_name, model)
    outputVariable.setReportingFrequency(reporting_frequency)
    outputVariable.setKeyValue(key)
    runner.registerInfo("Adding output variable #{variable_name} with reporting frequency #{reporting_frequency} for key #{key}.")
  end


  # Get final condition ================================================
  
  new_output_meteres = [  
  ["Cumulative,Fans:Electricity", "monthly", "*"], #Output:Meter:, %s , ,hourly; !- [J]  
  ]
  
  new_output_meteres.each do | meterName, reporting_frequency, key |
    outputMeter = OpenStudio::Model::Meter.new(model)
    outputMeter.setName(meterName)
    outputMeter.setReportingFrequency(reporting_frequency)
    runner.registerInfo("Adding output meter #{meterName} with reporting frequency #{reporting_frequency} for key #{key}.")
  end
  
  meters = model.getMeters
  output_variables = model.getOutputVariables
  runner.registerInfo("CTE_ADDVARS: The model finished with #{meters.size} meter objects and #{output_variables.size} output variables.")

  return true
end
