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
require_relative "resources/cte_lib"

# Medida de OpenStudio para informes tipo CTE
# Esta medida se aplica en combinaci??n con una medida de modelo y de workspace para CTE
class CTE_InformeDBHE < OpenStudio::Ruleset::ReportingUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return " Informe DBHE"
  end
  # human readable description
  def description
    return "Informe de resultados con informacion relativa al CTE DB-HE."
  end
  # human readable description of modeling approach
  def modeler_description
    return "Datos obtenidos de los resultados de EnergyPlus y del modelo de OpenStudio.
 La estructura del informe usa Bootstrap, y dimple js para las graficas."
  end
  def possible_sections
    result = []
    # methods for sections in order that they will appear in report
    result << 'mediciones_de_superficies_segun_CTE'
    result << 'demandas_por_componentes'
    result << 'annual_overview_section'
    result << 'building_summary_section'
    result << 'mediciones_envolvente'
    result << 'cte_envelope_section_section'
    result << 'space_type_breakdown_section'
    result << 'space_type_details_section'
    result << 'zone_summary_section'
    result << 'cte_outdoor_air_section' #Aire exterior
    result << 'source_energy_section'
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
    # workspace = setup[:workspace]
    sql_file = setup[:sqlFile]

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments)
    unless args
      return false
    end

    # reporting final condition
    runner.registerInitialCondition('Recopilando datos de archivo SQL de EnergyPlus y model OSM.')

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
    runner.registerFinalCondition("Generado informe en #{ html_out_path } con secciones: #{ sections_made }")

    return true
  end # end the run method

end # end the measure

# this allows the measure to be use by the application
CTE_InformeDBHE.new.registerWithApplication
