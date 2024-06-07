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

def get_surface_u(model, uuid)
  handle = OpenStudio.toUUID(uuid)
  objeto = model.getModelObject(handle).get
  if objeto.iddObject.name == "OS:Surface"
    objeto.to_Surface.get.construction.get.thermalConductance.to_f
  else # objeto.iddObject.name == "OS:SubSurface"
    objeto.to_SubSurface.get.construction.get.uFactor.to_f
  end
end

def get_solar_heat_gain_coefficient(model, uuid)
  handle = OpenStudio.toUUID(uuid)
  objeto = model.getModelObject(handle).get

  return false if objeto.iddObject.name != "OS:SubSurface"

  construction = objeto.to_SubSurface.get.construction.get.to_Construction.get
  construction.layers[0].to_SimpleGlazing.get.solarHeatGainCoefficient
end

# Localiza huecos exteriores soportados por la medida
def find_windows(model)
  model.getSpaces.flat_map do |space|
    space.surfaces.flat_map do |surface|
      next unless surface.outsideBoundaryCondition == "Outdoors" && surface.windExposure == "WindExposed"
      surface.subSurfaces.map { |window| window.handle.to_s if ["FixedWindow", "OperableWindow", "GlassDoor", "Door", "OverheadDoor", "Skylight"].include?(window.subSurfaceType.to_s) }
    end
  end.compact
end

# Lista de opacos al aire o terreno que no son PT_ o _PT
# outsideBoundaryCondition: "Outdoors", "Ground"
# surfaceType: Wall, RoofCeiling, Floor
def find_opaques(model)
  model.getSpaces.flat_map do |space|
    space.surfaces.map do |surface|
      [surface.handle.to_s, surface.surfaceType.to_s, surface.outsideBoundaryCondition.to_s] if ["Outdoors", "Ground"].include?(surface.outsideBoundaryCondition) && !surface.name.to_s.upcase.include?("PT_") && !surface.name.to_s.upcase.include?("_PT")
    end
  end.compact
end

class CTE_CambiaUs_Test < MiniTest::Test
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

  def test_cambia_huecos
    # create an instance of the measure
    measure = CTE_Model.new

    runner, model = get_runner_model(File.dirname(__FILE__) + "/test_N_R01_unif_adosada.osm")
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values. If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
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

    # ejecuta la medida que cambia los valores de g_vidrio
    measure.run(model, runner, argument_map)
    result = runner.result

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    # Asserts de condiciones
    assert_equal("Success", result.value.valueName)

    find_windows(model).each do |uuid|
      g_final = get_solar_heat_gain_coefficient(model, uuid)
      assert_in_delta(args_hash["CTE_g_gl"], g_final, 0.001, "uuid -> #{uuid}")
      u_final = get_surface_u(model, uuid)
      assert_in_delta(args_hash["CTE_U_huecos"], u_final, 0.001, "uuid -> #{uuid}")
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

    initial_values = {}
    find_opaques(model).each do |uuid, _type, _boundary|
      u = get_surface_u(model, uuid)
      initial_values[uuid] = u
    end

    measure.run(model, runner, argument_map)
    result = runner.result

    # Muestra resultados extra si se pasa --verbose
    show_output(result) if @@verbose

    # Asserts de condiciones
    assert_equal("Success", result.value.valueName)

    initial_values.each do |uuid, u_inicial|
      u_final = get_surface_u(model, uuid)
      assert_in_delta(u_inicial, u_final, 0.001, "uuid -> #{uuid}")
    end
  end

  def test_cambia_u_opacos
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

    measure.run(model, runner, argument_map)
    result = runner.result

    assert_equal("Success", result.value.valueName)

    # puts(find_opaques(model))

    transmitancias = {
      ["Wall", "Outdoors"] => args_hash["CTE_U_muros"],
      ["Wall", "Ground"] => 1 / (1 / args_hash["CTE_U_muros"] - 0.5),
      ["RoofCeiling", "Outdoors"] => args_hash["CTE_U_cubiertas"],
      ["Floor", "Ground"] => 1 / (1 / args_hash["CTE_U_suelos"] - 0.5),
      ["Floor", "Outdoors"] => args_hash["CTE_U_suelos"],
    }

    find_opaques(model).each do |uuid, type, boundary|
      u_final = get_surface_u(model, uuid)
      assert_in_delta(u_final, transmitancias[[type, boundary]], 0.01, "uuid -> #{uuid}")
    end
  end
end
