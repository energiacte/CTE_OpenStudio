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

require "openstudio"
require "openstudio/measure/ShowRunnerOutput"
require_relative "../measure"
require "minitest/autorun"
require "fileutils"
require "json"
require "pathname"

# tenemos que testear:
# que la medida se aplica pero no queremos cambiar la U
# cómo añade una capa aislante o cámara de aire si ya existe una
# cómo aborta si no hay capa aislante o cámara de aire
# cómo reacciona a que los elementos esté definidos en distintos niveles y de distintas maneras

# Carga modelo y obtén runner
def get_runner_model(file_path)
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  path = OpenStudio::Path.new(file_path)
  model = OpenStudio::OSVersion::VersionTranslator.new.loadModel(path)
  assert(!model.empty?)
  model = model.get

  [runner, model]
end

def get_surface(model, uuid)
  handle = OpenStudio.toUUID(uuid)
  objeto = model.getModelObject(handle).get

  if objeto.iddObject.name == "OS:Surface"
    elem = objeto.to_Surface.get
    construction = elem.construction.get
    u = construction.thermalConductance.to_f
  elsif objeto.iddObject.name == "OS:SubSurface"
    elem = objeto.to_SubSurface.get
    construction = elem.construction.get
    u = construction.uFactor.to_f
  else
    puts("Error, #{objeto.iddObject.name}, uuid:#{uuid}")
  end

  [elem, construction, u]
end

def get_solar_heat_gain_coefficient(model, uuid)
  handle = OpenStudio.toUUID(uuid)
  objeto = model.getModelObject(handle).get

  return false if objeto.iddObject.name != "OS:SubSurface"

  construction = objeto.to_SubSurface.get.construction.get.to_Construction.get
  construction.layers[0].to_SimpleGlazing.get.solarHeatGainCoefficient
end

def carga_elementos(model, elementos_para_test)
  elementos = {}
  elementos_para_test.each do |tipo, lista|
    lista.each do |uuid|
      _surface, _construction, u_inicial = get_surface(model, uuid)
      elementos[uuid] = {"tipo" => tipo, "u_inicial" => u_inicial}
    end
  end
  elementos
end

def find_windows(model)
  model.getSpaces.map {
    |s| s.surfaces.map {
      |ss| ss.subSurfaces.map{
        |w|
          if ["FixedWindow", "OperableWindow", "GlassDoor", "Door"].include?(w.subSurfaceType.to_s)
            w.handle
          else
            continue
          end
      }
    }
  }
end

class CTE_CambiaUs_Test < MiniTest::Test
  TEST_DIR = Pathname.new(__dir__)

  # Elementos de residencial.osm
  ELEMENTOS_RESIDENCIAL_OSM = {
    "muros_exteriores" => ["7aeba99e-3d64-4b69-a3b2-a7cf318f91f8", "1415c487-a7ec-493b-b6e2-40cb1770a6d7", "41d017a5-0490-4aa0-81bf-cd5b5e4a86c2", "b82786ae-b6c9-4cc1-ace2-e2c1771d17b2"],
    # "muros_terrenos" => [],
    # "muros_interiores" => [],
    "cubiertas_exteriores" => ["7e5b0180-4940-4f82-8d55-a82b356ed256", "4dba6073-0b46-4a4e-88f5-9cf67b1c0b1e", "1b4202a7-389e-413c-a734-3903f64499f0", "c4875e32-9291-48b3-bfe0-94bad05eb0d5"],
    "cubiertas_interiores" => ["bd6b3149-d34c-4ced-a718-7d9a506ca243", "d4a8d4b2-b59e-4e86-abe1-ba5a8fdc2431", "0355e260-8d73-4cd4-8b9c-f88882af2cad"],
    # "suelos_exteriores" => [],
    "suelos_interiores" => ["8c1e94b2-14cf-4a4c-9d46-907327050022", "50ded79a-3226-4fd9-98e9-e90968987d40", "57a5012c-8fa7-45a4-bd4e-05d1f80a1313"],
    "suelos_terrenos" => ["21f60244-fb64-4abe-abc3-464182337e27", "1d1a27e5-c230-435a-ac39-f4210b362a6d", "134cfe13-6464-4e3f-8235-bc25a284eceb"],
    "ventanas" => ["aedb937b-e035-4caf-8bd8-6d38aca58017", "bd75cc94-d2f4-4c61-89a0-ff79c0c406ba", "2f2adaad-60e6-4344-9d47-ee4787772d5c", "6852333b-05ee-4c91-a799-b7c1a0686274"],
    "puertas" => ["089b1b05-c16f-46c8-acf6-461e97125a7f"],
}.freeze

  # Elementos de modelo R_N01_unif_adosada.osm
  ELEMENTOS_R_N01_V23 = {
    "muros_exteriores" => ["94b8d093-436a-4d00-a34f-04c863de0d08", "5fdc6f02-ab04-43f7-abbb-6e2f5b585420", "be553ff8-1374-4869-8bcf-30ffb53290f9", "1f85cdc1-bf9a-4bd9-a5b9-b99ce38cfb2a"],
    # "puertas" => ["ce8352bc-f6a2-4fae-b36b-b57e2a1e235d", "1c40df56-8bb6-4450-bb4a-8e14fc6cf1c5"],
    "muros_terrenos" => ["25e1b51d-94eb-4f8f-813b-6a41d6e5c876"],
    "cubiertas_exteriores" => ["c0205929-9427-40b4-883e-34d52c6309cc", "9a0d5785-3883-499a-8c3f-c6a6a7c7ad12", "40464c22-46a4-4704-a5bc-db659410cd09"],
    "suelos_terrenos" => ["21f60244-fb64-4abe-abc3-464182337e27"],
    "suelos_exteriores" => ["31d16c6a-d398-49b1-bf40-b530d205037c", "f663dd7c-e24c-4fed-a937-61993c1095ba", "3ebf1a50-0485-485c-a1b2-bfa12c2026d7"],
    "ventanas" => ["9971a391-9f3d-4035-b8c5-b6d182b46e33", "adb347c4-df6e-45a6-96fd-d8ac1969e1d3", "208eb93c-b12d-4ff8-ba6e-cd92428cd463", "2a1c0c1e-2aa8-459e-b57b-a217407912ad"]
  }.freeze

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

  def test_cambia_g
    # create an instance of the measure
    measure = CTE_Model.new

    runner, model = get_runner_model(File.dirname(__FILE__) + "/test_N_R01_unif_adosada.osm")
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values. If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_g_gl"] = 0.65

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # ejecuta la medida que cambia los valores de g_vidrio
    measure.run(model, runner, argument_map)
    result = runner.result

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    # Asserts de condiciones
    assert_equal("Success", result.value.valueName)

    ELEMENTOS_R_N01_V23["ventanas"].each do |uuid|
      g_final = get_solar_heat_gain_coefficient(model, uuid)
      assert_in_delta(args_hash["CTE_g_gl"], g_final, 0.001, "uuid -> #{uuid}")
    end
  end

  def test_no_cambia_u
    # create an instance of the measure
    measure = CTE_Model.new

    runner, model = get_runner_model(File.dirname(__FILE__) + "/test_N_R01_unif_adosada.osm")
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0.0
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = "0"
    args_hash["CTE_U_huecos"] = 0

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    elementos = carga_elementos(model, ELEMENTOS_R_N01_V23)

    measure.run(model, runner, argument_map)
    result = runner.result

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    # Asserts de condiciones
    assert_equal("Success", result.value.valueName)

    elementos.each do |uuid, atributos|
      _surface, _construction, u_final = get_surface(model, uuid)
      assert_in_delta(atributos["u_inicial"], u_final, 0.001, "uuid -> #{uuid}")
    end
  end

  def test_cambia_u
    # create an instance of the measure
    measure = CTE_Model.new

    runner, model = get_runner_model(File.dirname(__FILE__) + "/test_N_R01_unif_adosada.osm")
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0.2
    args_hash["CTE_U_cubiertas"] = 0.3
    args_hash["CTE_U_suelos"] = 0.40
    args_hash["CTE_U_huecos"] = 0.62
    args_hash["CTE_g_gl"] = 0.65

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    elementos = carga_elementos(model, ELEMENTOS_R_N01_V23)

    measure.run(model, runner, argument_map)
    result = runner.result

    assert_equal("Success", result.value.valueName)

    transmitancias = {
      "muros_exteriores" => args_hash["CTE_U_muros"],
      "muros_terrenos" => 1 / (1 / args_hash["CTE_U_muros"] - 0.5),
      "cubiertas_exteriores" => args_hash["CTE_U_cubiertas"],
      "suelos_terrenos" => 1 / (1 / args_hash["CTE_U_suelos"] - 0.5),
      "suelos_exteriores" => args_hash["CTE_U_suelos"],
      "ventanas" => args_hash["CTE_U_huecos"]
    }

    elementos.each do |uuid, atributos|
      _surface, _construction, u_final = get_surface(model, uuid)
      assert_in_delta(u_final, transmitancias[atributos["tipo"]], 0.01, "uuid -> #{uuid}")
    end
  end
end
