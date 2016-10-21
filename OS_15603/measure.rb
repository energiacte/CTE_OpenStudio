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

require 'erb'
require 'json'
require 'pp'

require_relative "resources/os_lib_reporting_SI"
require_relative "resources/os_lib_schedules"
require_relative "resources/os_lib_helper_methods"

# Medida de OpenStudio para informes tipo CTE
# Esta medida se aplica en combinación con una medida de modelo y de workspace para CTE
class OpenStudioResultsSI < OpenStudio::Ruleset::ReportingUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return "OpenStudio Report SI units"
  end

  # human readable description
  def description
    return "OpenStudio Report in SI Units."
  end

  # human readable description of modeling approach
  def modeler_description
    return "OpenStudio Results Report."
  end

  def possible_sections

    result = []

    # methods for sections in order that they will appear in report
    result << 'annual_overview_section'

    result << 'building_summary_section'
    # still need to extend building summary
    # still need to populate site performance

    result << 'monthly_overview_section'
    result << 'utility_bills_rates_section'
    result << 'envelope_section_section'
    result << 'space_type_breakdown_section'
    result << 'space_type_details_section'

    result << 'interior_lighting_section'

    # consider binning to space types

    result << 'plug_loads_section'
    result << 'exterior_light_section'
    result << 'water_use_section'

    result << 'hvac_load_profile'
    # TODO: - turn on hvac_part_load_profile_table once I have data for it

    result << 'zone_condition_section'
    result << 'zone_summary_section'

    result << 'zone_equipment_detail_section' # TODO: - add in content from other measures
    result << 'air_loop_summary_section' # TODO: - stub only
    result << 'air_loops_detail_section'
    # later - on all loop detail sections get hard-sized value

    result << 'plant_loop_summary_section' # TODO: - stub only
    result << 'plant_loops_detail_section'
    result << 'outdoor_air_section'

    result << 'cost_summary_section'
    # find out how to get lifecycle cost with utility escalation
    # consider second cost table listing all lifecycle cost objects in OSM (since can't see in GUI)

    result << 'source_energy_section'

     result << 'co2_and_other_emissions_section'
    # TODO: - add emissions factors object to our template model

    result << 'typical_load_profiles_section' # TODO: - stub only
    result << 'schedules_overview_section'
    # TODO: - clean up code to gather schedule profiles so I don't have to grab every 15 minutes

    # see the method below in os_lib_reporting.rb to see a simple example of code to make a section of tables
    result << 'template_section'

    # TODO: - some tables are so long on real models you loose header. Should we have scrolling within a table?
    # TODO: - maybe sorting as well if it doesn't slow process down too much

    return result
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # populate arguments
    possible_sections.each do |method_name|
      # get display name
      arg = OpenStudio::Ruleset::OSArgument.makeBoolArgument(method_name, true)
      display_name = eval("OsLib_Reporting.#{method_name}(nil,nil,nil,true)[:title]")
      arg.setDisplayName(display_name)
      arg.setDefaultValue(true)
      args << arg
    end

    args
  end # end the arguments method

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # get sql, model, and web assets
    setup = OsLib_Reporting.setup(runner)
    unless setup
      return false
    end
    model = setup[:model]
    workspace = setup[:workspace]
    sql_file = setup[:sqlFile]
    web_asset_path = setup[:web_asset_path]

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments)
    unless args
      return false
    end

    # configure logging
    #logFile = OpenStudio::FileLogSink.new(OpenStudio::Path.new("./CTEReport.log"))
    #logFile.setLogLevel(OpenStudio::Debug)
    #logFile.setLogLevel(OpenStudio::Warn)
    #OpenStudio::Logger.instance.standardOutLogger.disable

    # reporting final condition
    runner.registerInitialCondition('Recopilando datos de archivo SQL de EnergyPlus y model OSM.')

    runner.registerInfo("Lista de secciones:")
    possible_sections.each_with_index { |method_name, index| runner.registerInfo("- #{ index }: #{method_name}")}

    # generate data for requested sections
    # create a array of sections to loop through in erb file
    @sections = []
    sections_made = 0
    possible_sections.each do |method_name|
      next unless args[method_name]
      method = OsLib_Reporting.method(method_name)
      @sections << method.call(model, sql_file, runner, false)
      sections_made += 1
    end

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
    if File.exist?(html_in_path)
      html_in_path = html_in_path
    else
      html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
    end
    html_in = ''
    File.open(html_in_path, 'r:UTF-8') do |file|
      html_in = file.read
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = './report.html'
    File.open(html_out_path, 'w:UTF-8') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # closing the sql file
    sql_file.close

    # reporting final condition
    runner.registerFinalCondition("Report generatede with sections #{sections_made} in #{html_out_path}.")

    return true
  end # end the run method

end # end the measure

# this allows the measure to be use by the application
OpenStudioResultsSI.new.registerWithApplication
