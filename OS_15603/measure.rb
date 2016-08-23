# coding: utf-8
require 'erb'
require 'json'
require 'pp'

require_relative "resources/os_lib_reporting_SI"
require_relative "resources/os_lib_schedules"
require_relative "resources/os_lib_helper_methods"
require_relative "resources/cte_lib"

# start the measure
class OpenStudioResultsCopy < OpenStudio::Ruleset::ReportingUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return "Informe 15603"
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

    #CTE_lib.mediciones()

    result = []

    # methods for sections in order that they will appear in report
    result << 'mediciones_de_superficies_segun_CTE'
    result << 'demandas_por_componentes'
    result << 'variables_de_inspeccion'
    #result << 'variables_cte'
    result << 'annual_overview_section'

    result << 'building_summary_section'
    # still need to extend building summary
    # still need to populate site performance

    result << 'monthly_overview_section'
    # result << 'utility_bills_rates_section'
    result << 'mediciones_envolvente'
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
    #-- result << 'air_loop_summary_section' # TODO: - stub only
    result << 'air_loops_detail_section'
    # later - on all loop detail sections get hard-sized value

    #-- result << 'plant_loop_summary_section' # TODO: - stub only
    result << 'plant_loops_detail_section'
    #-- result << 'outdoor_air_section'
    result << 'cte_outdoor_air_section'

    # result << 'cost_summary_section'
    # find out how to get lifecycle cost with utility escalation
    # consider second cost table listing all lifecycle cost objects in OSM (since can't see in GUI)

    result << 'source_energy_section'

    #-- result << 'co2_and_other_emissions_section'
    # TODO: - add emissions factors object to our template model

    #-- result << 'typical_load_profiles_section' # TODO: - stub only
    result << 'schedules_overview_section'
    # TODO: - clean up code to gather schedule profiles so I don't have to grab every 15 minutes

    # see the method below in os_lib_reporting.rb to see a simple example of code to make a section of tables
    #-- result << 'template_section'

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

  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    unless runner.validateUserArguments(arguments, user_arguments)
      return result
    end

    if runner.getBoolArgumentValue('hvac_load_profile', user_arguments)
      result << OpenStudio::IdfObject.load('Output:Variable,,Site Outdoor Air Drybulb Temperature,monthly;').get
    end

    if runner.getBoolArgumentValue('zone_condition_section', user_arguments)
      result << OpenStudio::IdfObject.load('Output:Variable,,Zone Air Temperature,hourly;').get
      result << OpenStudio::IdfObject.load('Output:Variable,,Zone Air Relative Humidity,hourly;').get
    end

    result
  end

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
      runner.registerInfo("* Llamando a método '#{method_name}'")
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
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = './report.html'
    File.open(html_out_path, 'w') do |file|
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
    runner.registerFinalCondition("Generado informe con #{sections_made} secciones en #{html_out_path}.")

    return true
  end # end the run method

end # end the measure

# this allows the measure to be use by the application
OpenStudioResultsCopy.new.registerWithApplication
