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

  def _test_CTE_CambiaUs_no_cambia
    puts("\n____TEST::  CTE_CambiaUs_no_cambia")

    # create an instance of the measure
    measure = CTE_CambiaUs.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/residencial.osm")
    puts("cargando el modelo ", path)
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    puts("tomando los argumentos")
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["CTE_U_muros"] = 0
    args_hash["CTE_U_cubiertas"] = 0
    # args_hash["CTE_U_suelos"] = 0.92
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # Verifica que se modifica el modelo.
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
    puts("ejecutando la medida")
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
    assert_in_delta(u_inicial, u_final, 0.001)

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

  def test_CTE_CambiaUs_extenso
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
    u_cubiertas = 0.3
    u_suelos = 0.40
    u_terrenos = 1 / (1 / u_suelos - 0.5)

    args_hash = {}
    args_hash["CTE_U_muros"] = u_muros
    args_hash["CTE_U_cubiertas"] = u_cubiertas
    args_hash["CTE_U_suelos"] = u_suelos
    
    # using defaults values from measure.rb for other arguments

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
