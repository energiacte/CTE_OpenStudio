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
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EJEMPLO.osm")
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
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/residencial.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["usoEdificio"] = "Residencial"
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
    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    result = runner.result

    show_output(result)

    assert(result.value.valueName == "Success")

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output_residencial.osm")
    model.save(output_file_path,true)

  end

end
