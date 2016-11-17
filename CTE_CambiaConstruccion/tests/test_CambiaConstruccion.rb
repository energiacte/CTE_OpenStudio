require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class CTECambiaConstruccion_Test < Test::Unit::TestCase

  def test_CTECambiaConstruccion_shadingControl
    measure = CTE_CambiaConstruccion.new
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/CTE_Blq_EM_limpio.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    
        # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_Construccion_defecto"] = "CTE_2013_zona Alfa"
    args_hash["CTE_Carpinteria"] = "CTE_Ref_marco_zona A"
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end
    
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    #~ assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    #save the model
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/out/test.osm")
    model.save(output_file_path,true)

  
  end

  #~ def test_CTECambiaConstruccion

    #~ # create an instance of the measure
    #~ measure = CTE_CambiaConstruccion.new

    #~ # create an instance of a runner
    #~ runner = OpenStudio::Ruleset::OSRunner.new

    #~ # load the test model
    #~ translator = OpenStudio::OSVersion::VersionTranslator.new
    #~ path = OpenStudio::Path.new(File.dirname(__FILE__) + "/LargeHotel.osm")
    #~ model = translator.loadModel(path)
    #~ assert((not model.empty?))
    #~ model = model.get

    #~ # get arguments and test that they are what we are expecting
    #~ arguments = measure.arguments(model)

    #~ # set argument values to good values and run the measure on model with spaces
    #~ argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    #~ construction_set = arguments[0].clone
    #~ assert(construction_set.setValue("189.1-2009 - CZ7-8 - LrgHotel"))
    #~ argument_map["construction_set"] = construction_set

    #~ measure.run(model, runner, argument_map)
    #~ result = runner.result
    #~ show_output(result)
    #~ assert(result.value.valueName == "Success")
    #~ #assert(result.warnings.size == 1)
    #~ #assert(result.info.size == 2)

    #~ #save the model
    #~ output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/out/test.osm")
    #~ model.save(output_file_path,true)

  #~ end

  #~ def test_CTECambiaConstruccion_clear

    #~ # create an instance of the measure
    #~ measure = CTE_CambiaConstruccion.new

    #~ # create an instance of a runner
    #~ runner = OpenStudio::Ruleset::OSRunner.new

    #~ # load the test model
    #~ translator = OpenStudio::OSVersion::VersionTranslator.new
    #~ path = OpenStudio::Path.new(File.dirname(__FILE__) + "/LargeHotel.osm")
    #~ model = translator.loadModel(path)
    #~ assert((not model.empty?))
    #~ model = model.get

    #~ # get arguments and test that they are what we are expecting
    #~ arguments = measure.arguments(model)

    #~ # set argument values to good values and run the measure on model with spaces
    #~ argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    #~ construction_set = arguments[0].clone
    #~ assert(construction_set.setValue("<clear field>"))
    #~ argument_map["construction_set"] = construction_set

    #~ measure.run(model, runner, argument_map)
    #~ result = runner.result
    #~ show_output(result)
    #~ assert(result.value.valueName == "Success")
    #~ #assert(result.warnings.size == 1)
    #~ #assert(result.info.size == 2)

    #~ #save the model
    #~ output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/out/test_clear.osm")
    #~ model.save(output_file_path,true)

  #~ end

end
