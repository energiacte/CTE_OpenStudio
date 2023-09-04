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

require "openstudio"
require "openstudio/measure/ShowRunnerOutput"
require_relative "../measure.rb"
require "minitest/autorun"
require "fileutils"
require "json"

# tenemos que testear:
# que la medida se aplica pero no queremos cambiar la U
# cómo añade una capa aislante o cámara de aire si ya existe una
# cómo aborta si no hay capa aislante o cámara de aire
# cómo reacciona a que los elementos esté definidos en distintos niveles y de distintas maneras
#
class CTE_CambiaUs_Test < MiniTest::Test
  # def setup
  #   # puts('ejecutando el setup del test')
  #   # no comparte los objetos que se generen aquí con las demás funciones, solo permanecen los efectos de lo ejecutado.
  #   # puts('Fin de setup')
  # end

  def get_runner_model(file_path, measure)
    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + file_path)
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    return runner, model
  end

  def get_surface(model, uuid)
    handle = OpenStudio.toUUID(uuid)
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    u = construction.thermalConductance().to_f

    return surface, construction, u
  end

  def get_transmitance(model, uuid)
    surface, construction, u = get_surface(model, uuid)
    return u
  end

  def carga_elementos_residencial_osm()
    #residencial OSM
    muros_exteriores = ["7aeba99e-3d64-4b69-a3b2-a7cf318f91f8", "1415c487-a7ec-493b-b6e2-40cb1770a6d7", "41d017a5-0490-4aa0-81bf-cd5b5e4a86c2", "b82786ae-b6c9-4cc1-ace2-e2c1771d17b2"]
    muros_terrenos = []
    muros_interiores = []
    cubiertas_exteriores = ["7e5b0180-4940-4f82-8d55-a82b356ed256", "4dba6073-0b46-4a4e-88f5-9cf67b1c0b1e", "1b4202a7-389e-413c-a734-3903f64499f0", "c4875e32-9291-48b3-bfe0-94bad05eb0d5"]
    cubiertas_interiores = ["bd6b3149-d34c-4ced-a718-7d9a506ca243", "d4a8d4b2-b59e-4e86-abe1-ba5a8fdc2431", "0355e260-8d73-4cd4-8b9c-f88882af2cad"]
    suelos_exteriores = []
    suelos_interiores = ["8c1e94b2-14cf-4a4c-9d46-907327050022", "50ded79a-3226-4fd9-98e9-e90968987d40", "57a5012c-8fa7-45a4-bd4e-05d1f80a1313"]
    suelos_terrenos = ["ed02d7a6-7c4b-47a9-a072-0e7bf732a4d6", "1d1a27e5-c230-435a-ac39-f4210b362a6d", "134cfe13-6464-4e3f-8235-bc25a284eceb"]
    ventanas = ["aedb937b-e035-4caf-8bd8-6d38aca58017", "bd75cc94-d2f4-4c61-89a0-ff79c0c406ba", "2f2adaad-60e6-4344-9d47-ee4787772d5c", "6852333b-05ee-4c91-a799-b7c1a0686274"]
    puertas = ["089b1b05-c16f-46c8-acf6-461e97125a7f"]
    elementos = { "muros_exteriores" => muros_exteriores, "cubiertas_exteriores" => cubiertas_exteriores, "cubiertas_interiores" => cubiertas_interiores,
                  "suelos_interiores" => suelos_interiores, "suelos_terrenos" => suelos_terrenos, "ventanas" => ventanas, "puertas" => puertas }

    return elementos
  end

  def carga_elementos_R_N01_V23()
    muros_exteriores = ["94b8d093-436a-4d00-a34f-04c863de0d08", "5fdc6f02-ab04-43f7-abbb-6e2f5b585420", "be553ff8-1374-4869-8bcf-30ffb53290f9", "1f85cdc1-bf9a-4bd9-a5b9-b99ce38cfb2a"]
    muros_terrenos = ["25e1b51d-94eb-4f8f-813b-6a41d6e5c876"]
    cubiertas_exteriores = ["c0205929-9427-40b4-883e-34d52c6309cc", "9a0d5785-3883-499a-8c3f-c6a6a7c7ad12", "40464c22-46a4-4704-a5bc-db659410cd09"]
    suelos_terrenos = ["21f60244-fb64-4abe-abc3-464182337e27"]
    suelos_exteriores = ["31d16c6a-d398-49b1-bf40-b530d205037c", "f663dd7c-e24c-4fed-a937-61993c1095ba", "3ebf1a50-0485-485c-a1b2-bfa12c2026d7"]
    ventanas = ["9971a391-9f3d-4035-b8c5-b6d182b46e33", "adb347c4-df6e-45a6-96fd-d8ac1969e1d3", "208eb93c-b12d-4ff8-ba6e-cd92428cd463", "2a1c0c1e-2aa8-459e-b57b-a217407912ad"]
    puertas = ["ce8352bc-f6a2-4fae-b36b-b57e2a1e235d", "1c40df56-8bb6-4450-bb4a-8e14fc6cf1c5"]
    elementos = { "muros_exteriores" => muros_exteriores, "muros_terrenos" => muros_terrenos, "cubiertas_exteriores" => cubiertas_exteriores, 
      "suelos_terrenos" => suelos_terrenos, "suelos_exteriores" => suelos_exteriores, "ventanas" => ventanas, "puertas" => puertas }

  def carga_elementos(model, elementos_para_test)
    elementos = {}
    elementos_para_test.each do |tipo, lista|
      lista.each do |uuid|
        u_inicial = get_transmitance(model, uuid)
        elementos[uuid] = { "tipo" => tipo, "u_inicial" => u_inicial }
      end
    end
    return elementos
  end

  def test_CTE_CambiaUs_no_cambia
    puts("\n------------------------------------------")
    puts("____TEST::  CTE_CambiaUs_no_cambia______")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    runner, model = get_runner_model("/residencial.osm", measure)
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0
    args_hash["CTE_U_huecos"] = 0

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    elementos_para_test = carga_elementos_residencial_osm()
    elementos = carga_elementos(model, elementos_para_test)

    puts("  ejecutando la medida")
    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    elementos.each do |uuid, atributos|
      u_final = get_transmitance(model, uuid)
      atributos["u_final"] = u_final
    end

    elementos.each do |uuid, atr|
      assert_in_delta(atr["u_inicial"], atr["u_final"], 0.001)
    end

    puts("___________ fin del test ________\n")
  end

  def _test_CTE_CambiaUs_cambia_muro
    puts("\n_________TEST::  CTE_CambiaUs_cambia_muro______")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/residencial.osm")
    # puts("cargando el modelo ", path)
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    # puts("tomando los argumentos")
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0.42
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    handle = OpenStudio.toUUID("cc187100-92a7-410b-bf38-3f6712910b74")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    u_inicial = construction.thermalConductance().to_f
    puts("|||Valores iniciales")
    puts("|||cerramiento, #{surface.name}")
    puts("|||construccion, #{construction.name}")
    puts("|||U inicial del muro #{u_inicial}")

    muro = model.getModelObject(handle)
    # puts("ejecutando la medida")
    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    handle = OpenStudio.toUUID("cc187100-92a7-410b-bf38-3f6712910b74")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    u_final = construction.thermalConductance().to_f
    puts("U inicial y final #{u_inicial}, #{u_final}")
    puts("|||Valores finales")
    puts("|||cerramiento, #{surface.name}")
    puts("|||construccion, #{construction.name}")
    puts("|||U final del muro #{u_final}")
    assert_in_delta(args_hash["CTE_U_muros"], u_final, 0.001)

    puts("___________ fin del test ________\n")
  end

  def _test_CTE_CambiaUs_cambia_cubierta
    puts("\n____TEST:: CTE_CambiaUs_cambia_cubierta")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/residencial.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0.32
    args_hash["CTE_U_suelos"] = 0
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    handle = OpenStudio.toUUID("c4875e32-9291-48b3-bfe0-94bad05eb0d5")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    u_inicial = construction.thermalConductance().to_f
    puts("|||Valores iniciales")
    puts("|||cerramiento, #{surface.name}")
    puts("|||construccion, #{construction.name}")
    puts("|||U inicial de la cubierta #{u_inicial}")

    muro = model.getModelObject(handle)
    # puts("ejecutando la medida")
    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    handle = OpenStudio.toUUID("c4875e32-9291-48b3-bfe0-94bad05eb0d5")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    puts("La construcciones es #{construction.name.to_s}, con una transmitancia de #{construction.thermalConductance().to_f}")
    u_final = construction.thermalConductance().to_f
    puts("|||Valores finales")
    puts("|||cerramiento, #{surface.name}")
    puts("|||construccion, #{construction.name}")
    puts("|||U final de la cubierta #{u_final}")

    puts("U inicial y final #{u_inicial}, #{u_final}")
    assert_in_delta(args_hash["CTE_U_cubiertas"], u_final, 0.001)

    # handle = OpenStudio.toUUID("cc187100-92a7-410b-bf38-3f6712910b74")
    # objeto = model.getModelObject(handle)
    # surface = objeto.get.to_Surface
    # surface = surface.get
    # construction = surface.construction.get
    # u_final = construction.thermalConductance().to_f
    # puts("U del muro final, #{u_final}")

    puts("__________ fin del test ________\n")
  end

  def _test_CTE_CambiaUs_cambia_suelos_residencial
    puts("\n____TEST:: CTE_CambiaUs_cambia_suelos")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    runner, model = get_runner_model("/residencial.osm", measure)
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0
    args_hash["CTE_U_suelos"] = 0.37
    u_terreno = 1 / (1 / args_hash["CTE_U_suelos"] - 0.5)
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    handle = OpenStudio.toUUID("ed02d7a6-7c4b-47a9-a072-0e7bf732a4d6")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    u_inicial = construction.thermalConductance().to_f
    puts("|||Valores iniciales")
    puts("|||cerramiento, #{surface.name}")
    puts("|||construccion, #{construction.name}")
    puts("|||U inicial del suelo terreno #{u_inicial}")

    muro = model.getModelObject(handle)
    # puts("ejecutando la medida")
    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    handle = OpenStudio.toUUID("ed02d7a6-7c4b-47a9-a072-0e7bf732a4d6")
    objeto = model.getModelObject(handle)
    surface = objeto.get.to_Surface
    surface = surface.get
    construction = surface.construction.get
    puts("La construcciones es #{construction.name.to_s}, con una transmitancia de #{construction.thermalConductance().to_f}")
    u_final = construction.thermalConductance().to_f
    puts("|||Valores finales")
    puts("|||cerramiento, #{surface.name}")
    puts("|||construccion, #{construction.name}")
    puts("|||U final del suelo terreno #{u_final}")

    puts("U inicial y final #{u_inicial}, #{u_final}")
    # se le añade la capa de suelo args_hash["CTE_U_suelos"]
    assert_in_delta(u_terreno, u_final, 0.001)

    puts("__________ fin del test ________\n")
  end

  def _test_CTE_CambiaUs_cambia_suelos_N_R01_unif_adosadaV23
    puts("\n____TEST:: CTE_CambiaUs_cambia_suelos")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    runner, model = get_runner_model("/N_R01_unif_adosadaV23.osm", measure)
    # runner, model = get_runner_model("/residencial.osm", measure)
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
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    surface, construction, u = get_surface(model, "21f60244-fb64-4abe-abc3-464182337e27")
    u_inicial_terreno = u

    puts("" "
      |||Valores iniciales terreno
      |||cerramiento, #{surface.name}
      |||U inicial del suelo terreno #{u_inicial_terreno}
      " "")

    surface, construction, u = get_surface(model, "24252951-3545-42e5-a381-db75ffc3c395")
    u_inicial_exterior = u

    puts("" "
      |||Valores iniciales exterior
      |||cerramiento, #{surface.name}
      |||U inicial del suelo exterior #{u_inicial_exterior}
      " "")

    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    surface, construction, u = get_surface(model, "21f60244-fb64-4abe-abc3-464182337e27")
    u_final_terreno = u

    puts("" "
      |||Valores finales
      |||cerramiento, #{surface.name}
      |||U inicial del suelo terreno #{u_final_terreno}
      " "")

    surface, construction, u = get_surface(model, "24252951-3545-42e5-a381-db75ffc3c395")
    u_final_exterior = u

    puts("" "
      |||Valores finales exterior
      |||cerramiento, #{surface.name}
      |||U inicial del suelo exterior #{u_final_exterior}
      " "")

    puts("U inicial y final terreno #{u_inicial_terreno}, #{u_final_terreno}")
    puts("U inicial y final exterior #{u_inicial_exterior}, #{u_final_exterior}")
    # se le añade la capa de suelo args_hash["CTE_U_suelos"]
    assert_in_delta(u_terreno, u_final_terreno, 0.001)
    assert_in_delta(u_exterior, u_final_exterior, 0.001)

    puts("__________ fin del test ________\n")
  end

  def _test_CTE_CambiaUs_extenso
    puts("\n____TEST:: CTE_CambiaUs_cambia_suelos")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    runner, model = get_runner_model("/N_R01_unif_adosadaV23.osm", measure)
    # runner, model = get_runner_model("/residencial.osm", measure)
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

    args_hash = {}
    args_hash["CTE_U_muros"] = u_muros
    args_hash["CTE_U_cubiertas"] = u_cubiertas
    args_hash["CTE_U_suelos"] = u_suelos
    args_hash["CTE_U_huecos"] = u_huecos    

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    salida = measure.run(model, runner, argument_map)
    assert(salida, "algo falló")

    muros = ["94b8d093-436a-4d00-a34f-04c863de0d08", "5fdc6f02-ab04-43f7-abbb-6e2f5b585420", "be553ff8-1374-4869-8bcf-30ffb53290f9"]
    cubiertas = ["c0205929-9427-40b4-883e-34d52c6309cc", "9a0d5785-3883-499a-8c3f-c6a6a7c7ad12", "40464c22-46a4-4704-a5bc-db659410cd09"]
    terrenos = ["21f60244-fb64-4abe-abc3-464182337e27"]
    suelos = ["31d16c6a-d398-49b1-bf40-b530d205037c", "f663dd7c-e24c-4fed-a937-61993c1095ba", "3ebf1a50-0485-485c-a1b2-bfa12c2026d7"]

    ### TODO FALTARÍA EL WALL GROUND

    muros.each do |muro|
      assert_in_delta(u_muros, get_transmitance(model, muro))
    end

    cubiertas.each do |cubierta|
      assert_in_delta(u_cubiertas, get_transmitance(model, cubierta))
    end

    terrenos.each do |terreno|
      assert_in_delta(u_terrenos, get_transmitance(model, terreno))
    end

    suelos.each do |suelo|
      assert_in_delta(u_suelos, get_transmitance(model, suelo))
    end

    puts("__________ fin del test ________\n")
  end
end
