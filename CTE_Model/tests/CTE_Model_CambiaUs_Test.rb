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
#
class CTE_CambiaUs_Test < MiniTest::Test
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

  def carga_elementos_residencial_osm
    # residencial OSM
    muros_exteriores = ["7aeba99e-3d64-4b69-a3b2-a7cf318f91f8", "1415c487-a7ec-493b-b6e2-40cb1770a6d7", "41d017a5-0490-4aa0-81bf-cd5b5e4a86c2", "b82786ae-b6c9-4cc1-ace2-e2c1771d17b2"]
    # muros_terrenos = []
    # muros_interiores = []
    cubiertas_exteriores = ["7e5b0180-4940-4f82-8d55-a82b356ed256", "4dba6073-0b46-4a4e-88f5-9cf67b1c0b1e", "1b4202a7-389e-413c-a734-3903f64499f0", "c4875e32-9291-48b3-bfe0-94bad05eb0d5"]
    cubiertas_interiores = ["bd6b3149-d34c-4ced-a718-7d9a506ca243", "d4a8d4b2-b59e-4e86-abe1-ba5a8fdc2431", "0355e260-8d73-4cd4-8b9c-f88882af2cad"]
    # suelos_exteriores = []
    suelos_interiores = ["8c1e94b2-14cf-4a4c-9d46-907327050022", "50ded79a-3226-4fd9-98e9-e90968987d40", "57a5012c-8fa7-45a4-bd4e-05d1f80a1313"]
    suelos_terrenos = ["21f60244-fb64-4abe-abc3-464182337e27", "1d1a27e5-c230-435a-ac39-f4210b362a6d", "134cfe13-6464-4e3f-8235-bc25a284eceb"]
    ventanas = ["aedb937b-e035-4caf-8bd8-6d38aca58017", "bd75cc94-d2f4-4c61-89a0-ff79c0c406ba", "2f2adaad-60e6-4344-9d47-ee4787772d5c", "6852333b-05ee-4c91-a799-b7c1a0686274"]
    puertas = ["089b1b05-c16f-46c8-acf6-461e97125a7f"]
    {"muros_exteriores" => muros_exteriores, "cubiertas_exteriores" => cubiertas_exteriores, "cubiertas_interiores" => cubiertas_interiores,
     "suelos_interiores" => suelos_interiores, "suelos_terrenos" => suelos_terrenos, "ventanas" => ventanas, "puertas" => puertas}
  end

  def carga_elementos_R_N01_V23
    muros_exteriores = ["94b8d093-436a-4d00-a34f-04c863de0d08", "5fdc6f02-ab04-43f7-abbb-6e2f5b585420", "be553ff8-1374-4869-8bcf-30ffb53290f9", "1f85cdc1-bf9a-4bd9-a5b9-b99ce38cfb2a"]
    muros_terrenos = ["25e1b51d-94eb-4f8f-813b-6a41d6e5c876"]
    cubiertas_exteriores = ["c0205929-9427-40b4-883e-34d52c6309cc", "9a0d5785-3883-499a-8c3f-c6a6a7c7ad12", "40464c22-46a4-4704-a5bc-db659410cd09"]
    suelos_terrenos = ["21f60244-fb64-4abe-abc3-464182337e27"]
    suelos_exteriores = ["31d16c6a-d398-49b1-bf40-b530d205037c", "f663dd7c-e24c-4fed-a937-61993c1095ba", "3ebf1a50-0485-485c-a1b2-bfa12c2026d7"]
    ventanas = ["9971a391-9f3d-4035-b8c5-b6d182b46e33", "adb347c4-df6e-45a6-96fd-d8ac1969e1d3", "208eb93c-b12d-4ff8-ba6e-cd92428cd463", "2a1c0c1e-2aa8-459e-b57b-a217407912ad"]
    # puertas = ["ce8352bc-f6a2-4fae-b36b-b57e2a1e235d", "1c40df56-8bb6-4450-bb4a-8e14fc6cf1c5"]
    {"muros_exteriores" => muros_exteriores, "muros_terrenos" => muros_terrenos, "cubiertas_exteriores" => cubiertas_exteriores,
     "suelos_terrenos" => suelos_terrenos, "suelos_exteriores" => suelos_exteriores, "ventanas" => ventanas}
  end

  def get_runner_model(file_path, measure)
    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + file_path)
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    [runner, model]
  end

  def get_surface(model, uuid)
    handle = OpenStudio.toUUID(uuid)
    objeto = model.getModelObject(handle).get

    if objeto.iddObject.name == "OS:Surface"
      elem = objeto.to_Surface.get
    elsif objeto.iddObject.name == "OS:SubSurface"
      elem = objeto.to_SubSurface.get
    else
      puts("Error, #{objeto.iddObject.name}, uuid:#{uuid}")
    end

    construction = elem.construction.get

    u = if objeto.iddObject.name == "OS:Surface"
      construction.thermalConductance.to_f
    else
      construction.uFactor.to_f
    end

    [elem, construction, u]
  end

  def get_transmitance(model, uuid)
    _surface, _construction, u = get_surface(model, uuid)
    u
  end

  def get_solar_heat_gain_coefficient(model, uuid)
    handle = OpenStudio.toUUID(uuid)
    objeto = model.getModelObject(handle).get
    if objeto.iddObject.name == "OS:SubSurface"
      elem = objeto.to_SubSurface.get
    else
      return false
    end
    construction = elem.construction.get.to_Construction.get
    construction.layers[0].to_SimpleGlazing.get.solarHeatGainCoefficient
  end

  def carga_elementos(model, elementos_para_test)
    elementos = {}
    elementos_para_test.each do |tipo, lista|
      lista.each do |uuid|
        u_inicial = get_transmitance(model, uuid)
        elementos[uuid] = {"tipo" => tipo, "u_inicial" => u_inicial}
      end
    end
    elementos
  end

  def carga_elementos_ventanas(model, listas_ventanas)
    elementos = {}
    listas_ventanas.each do |uuid|
      g_inicial = get_solar_heat_gain_coefficient(model, uuid)
      elementos[uuid] = {"tipo" => "ventanas", "g_inicial" => g_inicial}
    end
    elementos
  end

  def test_CTE_Model_cambia_g_vidrios
    # create an instance of the measure
    measure = CTE_Model.new

    # runner, model = get_runner_model("/residencial.osm", measure)
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)
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

    # elementos_para_test = carga_elementos_residencial_osm
    elementos_para_test = carga_elementos_R_N01_V23
    # selecciona las ventanas
    ventanas_test = elementos_para_test["ventanas"]
    ventanas = carga_elementos_ventanas(model, ventanas_test)
    ventanas.each do |uuid, atributos|
      g_final = get_solar_heat_gain_coefficient(model, uuid)
      atributos["g_final"] = g_final
    end

    ventanas.each do |uuid, atr|
      assert_in_delta(args_hash["CTE_g_gl"], atr["g_final"], 0.001, "uuid -> #{uuid}")
    end
  end

  def test_CTE_CambiaUs_no_cambia
    # create an instance of the measure
    measure = CTE_Model.new

    # runner, model = get_runner_model("/residencial.osm", measure)
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)
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

    # elementos_para_test = carga_elementos_residencial_osm
    elementos_para_test = carga_elementos_R_N01_V23
    elementos = carga_elementos(model, elementos_para_test)

    measure.run(model, runner, argument_map)
    result = runner.result

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    # Asserts de condiciones
    assert_equal("Success", result.value.valueName)

    elementos.each do |uuid, atributos|
      u_final = get_transmitance(model, uuid)
      atributos["u_final"] = u_final
    end

    elementos.each do |uuid, atr|
      assert_in_delta(atr["u_inicial"], atr["u_final"], 0.001, "uuid -> #{uuid}")
    end
  end

  def test_CTE_Cambia_g_vidrios
    measure = CTE_Model.new

    # create an instance of a runner and load the test model
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
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

    uuid = "0b39cfba-de4f-4fe4-b0da-7ddd5c9d44f0"

    # u_inicial = get_transmitance(model, uuid)
    measure.run(model, runner, argument_map)

    assert_equal("Success", result.value.valueName)

    # u_final = get_transmitance(model, uuid)
    g_final = get_solar_heat_gain_coefficient(model, uuid)
    assert_in_delta(args_hash["CTE_g_gl"], g_final, 0.001, "uuid -> #{uuid}")
  end

  def test_CTE_CambiaUs_cambia_muro
    # create an instance of the measure
    measure = CTE_Model.new

    # create an instance of a runner and load the test model
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0.42
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0
    args_hash["CTE_g_gl"] = 0.65
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    uuid = "be553ff8-1374-4869-8bcf-30ffb53290f9"
    measure.run(model, runner, argument_map)

    assert_equal("Success", result.value.valueName)

    u_final = get_transmitance(model, uuid)

    assert_in_delta(args_hash["CTE_U_muros"], u_final, 0.001, "uuid -> #{uuid}")
  end

  def test_CTE_CambiaUs_cambia_cubierta
    measure = CTE_Model.new

    # create an instance of a runner
    # runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0.32
    args_hash["CTE_U_suelos"] = 0
    args_hash["CTE_g_gl"] = 0.65
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

    assert_equal("Success", result.value.valueName)

    handle = OpenStudio.toUUID("c0205929-9427-40b4-883e-34d52c6309cc")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get

    u_final = construction.thermalConductance.to_f
    assert_in_delta(args_hash["CTE_U_cubiertas"], u_final, 0.001, "uuid -> #{uuid}")
  end

  def test_CTE_CambiaUs_cambia_suelos_residencial
    # create an instance of the measure
    measure = CTE_Model.new

    # runner, model = get_runner_model("/residencial.osm", measure)
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0.37
    u_terreno = 1 / (1 / args_hash["CTE_U_suelos"] - 0.5)
    args_hash["CTE_g_gl"] = 0.65
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

    assert_equal("Success", result.value.valueName)

    uuid = "21f60244-fb64-4abe-abc3-464182337e27"
    handle = OpenStudio.toUUID(uuid)
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    u_final = construction.thermalConductance.to_f
    assert_in_delta(u_terreno, u_final, 0.001, "uuid -> #{uuid}")
  end

  def test_CTE_CambiaUs_cambia_suelos
    # create an instance of the measure
    measure = CTE_Model.new

    # runner, model = get_runner_model("/residencial.osm", measure)
    # runner, model = get_runner_model("/N_R01_unif_adosadaV23.osm", measure)
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0.37
    u_terreno = 1 / (1 / args_hash["CTE_U_suelos"] - 0.5)
    u_exterior = args_hash["CTE_U_suelos"]
    args_hash["CTE_g_gl"] = 0.65

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    measure.run(model, runner, argument_map)

    assert_equal("Success", result.value.valueName)

    _surface, _construction, u_final_terreno = get_surface(model, "21f60244-fb64-4abe-abc3-464182337e27")
    _surface, _construction, u_final_exterior = get_surface(model, "24252951-3545-42e5-a381-db75ffc3c395")

    assert_in_delta(u_terreno, u_final_terreno, 0.001)
    assert_in_delta(u_exterior, u_final_exterior, 0.001)
  end

  def _test_CTE_CambiaUs_cambia_huecos
    measure = CTE_Model.new

    # runner, model = get_runner_model("/N_R01_unif_adosadaV23.osm", measure)
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0
    args_hash["CTE_U_huecos"] = 0.68
    u_huecos = args_hash["CTE_U_huecos"]
    args_hash["CTE_g_gl"] = 0.65

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    measure.run(model, runner, argument_map)

    assert_equal("Success", result.value.valueName)

    uuid = "9971a391-9f3d-4035-b8c5-b6d182b46e33"
    _surface, _construction, u_final = get_surface(model, uuid)
    assert_in_delta(u_huecos, u_final, 0.001, "uuid -> #{uuid}")
  end

  def test_CTE_CambiaUs_extenso
    # create an instance of the measure
    measure = CTE_Model.new

    # runner, model = get_runner_model("/residencial.osm", measure)
    # runner, model = get_runner_model("/N_R01_unif_adosadaV23.osm", measure)
    runner, model = get_runner_model("/test_N_R01_unif_adosada.osm", measure)
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash

    u_muros = 0.2
    u_muros_terreno = 1 / (1 / u_muros - 0.5)
    u_cubiertas = 0.3
    u_suelos = 0.40
    u_suelos_terreno = 1 / (1 / u_suelos - 0.5)
    u_huecos = 0.62

    transmitancias = {"muros_exteriores" => u_muros, "muros_terrenos" => u_muros_terreno, "cubiertas_exteriores" => u_cubiertas,
                      "suelos_terrenos" => u_suelos_terreno, "suelos_exteriores" => u_suelos, "ventanas" => u_huecos}
    # puertas

    args_hash = {}
    args_hash["CTE_U_muros"] = u_muros
    args_hash["CTE_U_cubiertas"] = u_cubiertas
    args_hash["CTE_U_suelos"] = u_suelos
    args_hash["CTE_U_huecos"] = u_huecos
    args_hash["CTE_g_gl"] = 0.65

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    elementos_para_test = carga_elementos_R_N01_V23
    elementos = carga_elementos(model, elementos_para_test)

    measure.run(model, runner, argument_map)

    assert_equal("Success", result.value.valueName)

    elementos.each do |uuid, atributos|
      u_final = get_transmitance(model, uuid)
      atributos["u_final"] = u_final
    end

    elementos.each do |uuid, atrib|
      assert_in_delta(atrib["u_final"], transmitancias[atrib["tipo"]], 0.01, "uuid -> #{uuid}")
    end
  end
end
