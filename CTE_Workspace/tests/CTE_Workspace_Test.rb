require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative '../measure'

class CTE_Workspace_Test < MiniTest::Test
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
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # assert_equal(1, arguments.size)
    # assert_equal("space_name", arguments[0].name)

    # # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(args_hash[arg.name])) if args_hash[arg.name]
      argument_map[arg.name] = temp_arg_var
    end

    model_path = "#{File.dirname(__FILE__)}/7_plurif_BLOQUE_4_ALTURAS.osm"
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_path))

    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)

    assert(result.value.valueName == 'Success')

    # save the workspace to output directory
    output_path = "#{File.dirname(__FILE__)}/output/test_output.idf"
    workspace.save(OpenStudio::Path.new(output_path), true)
  end
end
