require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require_relative "../measure.rb"
require 'minitest/autorun'
require 'fileutils'

class CTE_Model_Test < MiniTest::Unit::TestCase

  def test_CTE_Model_Terciario
    # create an instance of the measure
    measure = CTE_Model.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new    
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/01_oficinas_B+2.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    #args_hash["provincia"] = "Madrid"
    #args_hash["altitud"] = 650.0
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # set argument values to good values and run the measure on model with spaces
    measure.run(model, runner, argument_map)
    result = runner.result

    show_output(result)

    assert(result.value.valueName == "Success")

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output_terciario.osm")
    model.save(output_file_path,true)
  end
  
  def test_CTE_Model_residencial
    # create an instance of the measure
    measure = CTE_Model.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new    
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/plurif_bloque4alturas_Virginia.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    #args_hash["provincia"] = "Madrid"
    #args_hash["altitud"] = 650.0
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # set argument values to good values and run the measure on model with spaces
    measure.run(model, runner, argument_map)
    result = runner.result

    show_output(result)

    assert(result.value.valueName == "Success")

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output_residencial.osm")
    model.save(output_file_path,true)
  end

end
