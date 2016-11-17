# coding: utf-8
# Author(s): Daniel Jiménez González, Rafael Villar Burke
# email: danielj@ietcc.csic.es, pachi@ietcc.csic.es
#
# Measure based on previous measure in the BCL "Assign ConstructionSet to Building" by David Goldwasser
# Change constructionSet of Building and assign FrameAndDivider to windows that inherit from the defaultConstructionSet
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
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test.osm")
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
    args_hash["CTE_Construccion_defecto"] = "CTE_2013_E"
    args_hash["CTE_Carpinteria"] = "CTE_Ref_marco_E"
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
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 0)

    #save the model
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/out/test.osm")
    model.save(output_file_path, true)
  end

  def test_CTECambiaConstruccion_clear
    measure = CTE_CambiaConstruccion.new
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    construction_set = arguments[0].clone
    assert(construction_set.setValue("<clear field>"))
    argument_map["CTE_Construccion_defecto"] = construction_set

    carpinteria = arguments[1].clone
    assert(carpinteria.setValue("<clear field>"))
    argument_map["CTE_Carpinteria"] = carpinteria

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 0)
    assert(model.building.get.defaultConstructionSet.empty? == true)

    #save the model
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/out/test_clear.osm")
    model.save(output_file_path,true)
  end

end
