require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative '../measure'

class CTE_Workspace_Test < MiniTest::Test
  def test_Workspace_with_model
    # create an instance of the measure
    measure = CTE_Workspace.new

    puts('Iniciando test_Workspace con modelo')

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/RU04_P1.osm")
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    # create hash of argument values
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # TODO: esto es lo que no hacemos igual en un osw
    # TODO: pensar qué ocurre normalmente para ajustar el get_weather en la medida (y en CTE_Model)
    # Asignamos clima
    epw_path = "#{File.dirname(__FILE__)}/D3_peninsula.epw"
    runner.setLastEpwFilePath(OpenStudio::Path.new(epw_path))

    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)

    assert(result.value.valueName == 'Success')

    # save the workspace to output directory
    output_path = "#{File.dirname(__FILE__)}/output/RU04_P1_output.idf"
    workspace.save(OpenStudio::Path.new(output_path), true)
  end

  def test_Workspace
    # create an instance of the measure
    measure = CTE_Workspace.new

    puts('Iniciando test_Workspace')

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    idf_path = "#{File.dirname(__FILE__)}/cubitoygarajenhideal.idf"
    path = OpenStudio::Path.new(idf_path)

    workspace = OpenStudio::Workspace.load(path)
    if workspace.empty?
      runner.registerError("Cannot load #{path}")
      return false
    end
    workspace = workspace.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    # create hash of argument values

    args_hash = {}
    args_hash['recuperador'] = 'Sensible'
    # ~ args_hash["some_integer_we_need"] = 10
    # ~ args_hash["some_double_we_need"] = 10.0
    # ~ args_hash["a_bool_argument"] = true
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # assert_equal(1, arguments.size)
    # assert_equal("space_name", arguments[0].name)

    # # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(args_hash[arg.name])) if args_hash[arg.name]
      argument_map[arg.name] = temp_arg_var
    end

    # Asignamos clima
    epw_path = "#{File.dirname(__FILE__)}/D3_peninsula.epw"
    runner.setLastEpwFilePath(OpenStudio::Path.new(epw_path))

    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)

    assert(result.value.valueName == 'Success')

    # save the workspace to output directory
    output_path = "#{File.dirname(__FILE__)}/output/test_output.idf"
    workspace.save(OpenStudio::Path.new(output_path), true)
  end
end
