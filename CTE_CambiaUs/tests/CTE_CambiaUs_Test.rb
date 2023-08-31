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

  def test_CTE_CambiaUs_cambia_suelos_terreno
    puts("\n____TEST:: CTE_CambiaUs_cambia_suelos")

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

    # handle = OpenStudio.toUUID("cc187100-92a7-410b-bf38-3f6712910b74")
    # objeto = model.getModelObject(handle)
    # surface = objeto.get.to_Surface
    # surface = surface.get
    # construction = surface.construction.get
    # u_final = construction.thermalConductance().to_f
    # puts("U del muro final, #{u_final}")

    puts("__________ fin del test ________\n")
  end
end
