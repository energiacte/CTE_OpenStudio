# Copyright (c) 2016-2023 Ministerio de Fomento
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
#
# Usa con ruby CTE_Model_Test.rb --verbose para salida adicional

require "openstudio"
require "openstudio/measure/ShowRunnerOutput"
require "minitest/autorun"
require_relative "../measure"
require "fileutils"
require "json"
require "pathname"

# https://s3.amazonaws.com/openstudio-sdk-documentation/cpp/OpenStudio-3.6.1-doc/measure/html/classopenstudio_1_1measure_1_1_o_s_argument.html
def get_attrb(result, nombre)
  result.attributes.find { |e| e.name == nombre }&.valueAsDouble
end

def get_attrb_str(result, nombre)
  result.attributes.find { |e| e.name == nombre }&.valueAsString
end

class CTE_Model_Test < MiniTest::Test
  TESTED_CLASS = CTE_Model

  TEST_DIR = Pathname.new(__dir__)

  # Patch to capture if --verbose was passed to minitest so we can call
  # show_output if so, and not do it otherwise
  @@verbose = false

  def self.run(reporter, options = {})
    @@verbose = options.fetch(:verbose, false)

    # Might as well shush some annoying logging message
    # logger = OpenStudio::Logger.instance.standardOutLogger
    # logger.setChannelRegex('.*(?<!OSRunner)(?<!WorkflowStepResult)$')
    # if logger.respond_to?(:useWorkflowGemFormatter)
    #   OpenStudio::Logger.instance.standardOutLogger.useWorkflowGemFormatter(true)
    # end
    super(reporter, options)
  end

  # def setup
  # end

  # def teardown
  # end
  def test_CTE_Model_Terciario
    # create an instance of the measure
    measure = CTE_Model.new

    puts("Iniciando el test CTE_Model_Terciario")

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/terciario.osm")
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_C_huecos_m3hm2"] = 50
    # args_hash["provincia"] = "Madrid"
    # args_hash["altitud"] = 650.0
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

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    # Asserts de condiciones
    assert_equal("Success", result.value.valueName)

    # attributes = JSON.parse(OpenStudio::to_json(result.attributes))
    # ela_total = attributes['attributes']['cte_ela_total_espacios']

    ela_total = get_attrb(result, "cte_ela_total_espacios")
    # https://s3.amazonaws.com/openstudio-sdk-documentation/cpp/OpenStudio-3.6.1-doc/measure/html/classopenstudio_1_1measure_1_1_o_s_argument.html
    # result.attributes.find {|e| e.name == 'cte_ela_total_espacios'}.valueAsDouble
    assert_in_delta(6248.9, ela_total, 1.0)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output_terciario.osm")
    model.save(output_file_path, true)
  end

  def test_CTE_Model_residencial
    # create an instance of the measure
    measure = CTE_Model.new
    puts("Iniciando el test CTE_Model_residencial")

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/residencial.osm")
    model = translator.loadModel(path).get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_Uso_edificio"] = "Residencial"
    args_hash["CTE_C_huecos_m3hm2"] = 50
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

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    assert(result.value.valueName == "Success")

    assert_equal("D3_peninsula", get_attrb_str(result, "cte_weather_file"))
    assert_in_delta(5624.88, get_attrb(result, "cte_ela_total_espacios"), 0.1)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output_residencial.osm")
    model.save(output_file_path, true)
  end
end
