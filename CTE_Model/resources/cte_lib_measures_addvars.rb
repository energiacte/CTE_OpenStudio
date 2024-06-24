# Copyright (c) 2016-2023 Ministerio de Fomento
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

# Inyecta variables y meters para uso con el CTE
def cte_addvars(model, runner, _user_arguments)
  # Get initial conditions ==========================================
  meters = model.getOutputMeters
  output_variables = model.getOutputVariables
  runner.registerInfo("CTE_ADDVARS: The model started with #{meters.size} meter objects, and #{output_variables.size} output variables.")

  # Add CTE meters ==================================================
  # Consultar en archivo **eplusout.mdd** los report meters disponibles

  new_meters = [
    # ["Propane:Facility", "RunPeriod"], # this meter exists in the exampleModel
    ['DistrictHeating:Facility', 'RunPeriod'],
    ['DistrictCooling:Facility', 'RunPeriod'],
    ['Fans:Electricity', 'Monthly', '*'],
    ['InteriorLights:Electricity', 'Monthly', '*'],
    ['Heating:DistrictHeating', 'Hourly', '*'],
    ['Cooling:DistrictCooling', 'Hourly', '*']
  ]

  existing_meters = Hash[meters.map { |meter| [meter.name, meter] }.compact]

  new_meters.each do |meterName, reporting_frequency, key|
    if existing_meters.has_key?(meterName)
      runner.registerInfo("Meter #{meterName} already in meters")
      meter = existing_meters[meterName]
      if meter.reportingFrequency != reporting_frequency
        meter.setReportingFrequency(reporting_frequency)
        runner.registerInfo("Changing meter #{meterName} reporting frequency to #{reporting_frequency}.")
      end
    else
      meter = OpenStudio::Model::OutputMeter.new(model)
      meter.setName(meterName)
      meter.setReportingFrequency(reporting_frequency)
      runner.registerInfo("Adding output meter #{meterName} with reporting frequency #{reporting_frequency} for key #{key}.")
    end
  end

  # Add CTE output variables =========================================
  # Consultar en archivo **eplusout.rdd** variables disponibles

  new_oputput_variables = [
    # Datos generales
    ['Site Outdoor Air Drybulb Temperature', 'Monthly', '*'],

    # Para demandas en reporting
    ['Surface Inside Face Conduction Heat Transfer Energy', 'Monthly', '*'],
    ['Surface Window Heat Gain Energy', 'Monthly', '*'],
    ['Surface Window Heat Loss Energy', 'Monthly', '*'],
    ['Surface Window Transmitted Solar Radiation Energy', 'Monthly', '*'],
    ['Zone Lights Electricity Energy', 'Monthly', '*'],
    ['Zone Total Internal Total Heating Energy', 'Monthly', '*'],
    ['Zone Ideal Loads Zone Total Heating Energy', 'Monthly', '*'],
    ['Zone Ideal Loads Zone Total Cooling Energy', 'Monthly', '*'],

    # Datos de intercambio de aire
    ['Zone Ideal Loads Heat Recovery Active Time', 'Hourly', '*'],
    ['Zone Ideal Loads Heat Recovery Active Time', 'Daily', '*'],
    ['Zone Ideal Loads Heat Recovery Active Time', 'Monthly', '*'],
    ['Zone Ideal Loads Economizer Active Time', 'Hourly', '*'],
    ['Zone Ideal Loads Economizer Active Time', 'Daily', '*'],
    ['Zone Ideal Loads Economizer Active Time', 'Monthly', '*'],
    ['Zone Ideal Loads Supply Air Standard Density Volume Flow Rate', 'Hourly', '*'],
    ['Zone Ideal Loads Supply Air Standard Density Volume Flow Rate', 'Monthly', '*'],
    ['Zone Ideal Loads Outdoor Air Standard Density Volume Flow Rate', 'Hourly', '*'],
    ['Zone Ideal Loads Outdoor Air Standard Density Volume Flow Rate', 'Monthly', '*'],

    ['Zone Mechanical Ventilation Current Density Volume', 'Hourly', '*'], # no localizada
    ['Zone Mechanical Ventilation Air Changes per Hour', 'Hourly', '*'], # no localizada

    # Infiltraciones (no localizadas)
    ['Zone Infiltration Current Density Volume Flow Rate', 'Monthly', '*'], # no localizado
    ['Zone Infiltration Total Heat Loss Energy', 'Monthly', '*'], # no localizado
    ['Zone Infiltration Total Heat Gain Energy', 'Monthly', '*'], # no localizado
    ['Zone Infiltration Air Change Rate', 'Monthly', '*'], # no localizado

    # Reporting
    ['Zone Combined Outdoor Air Sensible Heat Loss Energy', 'Daily', '*'], # no localizada
    ['Zone Combined Outdoor Air Sensible Heat Loss Energy', 'Monthly', '*'],
    ['Zone Combined Outdoor Air Sensible Heat Gain Energy', 'Monthly', '*'],
    ['Zone Combined Outdoor Air Total Heat Loss Energy', 'Hourly', '*'], # no localizada
    ['Zone Combined Outdoor Air Total Heat Loss Energy', 'Monthly', '*'], # no localizada
    ['Zone Combined Outdoor Air Total Heat Gain Energy', 'Hourly', '*'], # no localizada
    ['Zone Combined Outdoor Air Total Heat Gain Energy', 'Monthly', '*'], # no localizada
    ['Zone Combined Outdoor Air Changes per Hour', 'Hourly', '*'],
    ['Zone Combined Outdoor Air Changes per Hour', 'Daily', '*'],
    ['Zone Combined Outdoor Air Changes per Hour', 'Monthly', '*'],
    ['Zone Combined Outdoor Air Fan Electric Energy', 'Monthly', '*'],
    # Esta variable no aparece en el rdd ya que se desactiva
    # al introducir el objeto ZoneAirBalance:OutdoorAir en CTE_Workspace
    # Ver https://bigladdersoftware.com/epx/docs/8-7/input-output-reference/group-airflow.html#outputs-1-002
    ['Zone Ventilation Air Change Rate', 'Monthly', '*'] # no localizada
  ]

  new_oputput_variables.each do |variable_name, reporting_frequency, key|
    outputVariable = OpenStudio::Model::OutputVariable.new(variable_name, model)
    outputVariable.setReportingFrequency(reporting_frequency)
    outputVariable.setKeyValue(key)
    runner.registerInfo("Adding output variable #{variable_name} with reporting frequency #{reporting_frequency} for key #{key}.")
  end

  # Get final condition ================================================

  meters = model.getOutputMeters
  output_variables = model.getOutputVariables
  runner.registerInfo("CTE_ADDVARS: The model finished with #{meters.size} meter objects and #{output_variables.size} output variables.")

  true
end
