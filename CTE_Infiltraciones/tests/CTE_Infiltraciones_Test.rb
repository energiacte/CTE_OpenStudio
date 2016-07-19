require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CTE_InfiltracionesTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_good_argument_values
    measure = CTE_Infiltraciones.new
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/ejemploCTE.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and load non default values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    args_hash = {}
    args_hash["tipoEdificio"] = "Nuevo"
    args_hash["permeabilidadVentanas"] = "Clase 2"
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.osm")
    model.save(output_file_path, true)
  end

  def test_bad_model
    measure = CTE_Infiltraciones.new
    runner = OpenStudio::Ruleset::OSRunner.new
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/example_model.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    assert_equal("Fail", result.value.valueName)
  end

end
