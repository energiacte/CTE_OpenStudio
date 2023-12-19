require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class IdealLoadsOptions_Test < MiniTest::Unit::TestCase

  def workspace_out_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.idf"
  end

  def test_ach_limit_flow_rate
    test_name = "limit ACH flow rate"
    measure = IdealLoadsOptions.new
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test_NR01_con_volumen.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    runner.setLastOpenStudioModel(model)

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("Always On Discrete"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Always On Discrete"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule

    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Always On Discrete"))
    argument_map["cooling_availability_schedule"] = cooling_availability_schedule

    heating_limit_type = arguments[3].clone
    assert(heating_limit_type.setValue("LimitFlowACH"))
    argument_map["heating_limit_type"] = heating_limit_type

    cooling_limit_type = arguments[4].clone
    assert(cooling_limit_type.setValue("LimitFlowACH"))
    argument_map["cooling_limit_type"] = cooling_limit_type

    ach_limit_flow_rate = arguments[5].clone
    assert(ach_limit_flow_rate.setValue(4.0))
    argument_map["ach_limit_flow_rate"] = ach_limit_flow_rate

    dehumid_type = arguments[6].clone
    assert(dehumid_type.setValue("ConstantSensibleHeatRatio"))
    argument_map["dehumid_type"] = dehumid_type

    cooling_sensible_heat_ratio = arguments[7].clone
    assert(cooling_sensible_heat_ratio.setValue(0.7))
    argument_map["cooling_sensible_heat_ratio"] = cooling_sensible_heat_ratio

    humid_type = arguments[8].clone
    assert(humid_type.setValue("None"))
    argument_map["humid_type"] = humid_type

    oa_spec = arguments[9].clone
    assert(oa_spec.setValue("Use Individual Zone Design Outdoor Air"))
    argument_map["oa_spec"] = oa_spec

    dcv_type = arguments[10].clone
    assert(dcv_type.setValue("OccupancySchedule"))
    argument_map["dcv_type"] = dcv_type

    economizer_type = arguments[11].clone
    assert(economizer_type.setValue("NoEconomizer"))
    argument_map["economizer_type"] = economizer_type

    heat_recovery_type = arguments[12].clone
    assert(heat_recovery_type.setValue("Sensible"))
    argument_map["heat_recovery_type"] = heat_recovery_type

    sensible_effectiveness = arguments[13].clone
    assert(sensible_effectiveness.setValue(0.7))
    argument_map["sensible_effectiveness"] = sensible_effectiveness

    latent_effectiveness = arguments[14].clone
    assert(latent_effectiveness.setValue(0.65))
    argument_map["latent_effectiveness"] = latent_effectiveness

    add_meters = arguments[15].clone
    assert(add_meters.setValue(true))
    argument_map["add_meters"] = add_meters

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)

    # save the workspace for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = workspace_out_path(test_name)
    workspace.save(output_file_path,true)
  end

  def no_test_good_inputs
    #this measure tests a curve applied to all fans
    test_name = "test_good_inputs"

    # create an instance of the measure
    measure = IdealLoadsOptions.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test_NR01_con_volumen.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("Always On Discrete"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Always On Discrete"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule

    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Always On Discrete"))
    argument_map["cooling_availability_schedule"] = cooling_availability_schedule

    heating_limit_type = arguments[3].clone
    assert(heating_limit_type.setValue("NoLimit"))
    argument_map["heating_limit_type"] = heating_limit_type

    cooling_limit_type = arguments[4].clone
    assert(cooling_limit_type.setValue("NoLimit"))
    argument_map["cooling_limit_type"] = cooling_limit_type

    dehumid_type = arguments[5].clone
    assert(dehumid_type.setValue("ConstantSensibleHeatRatio"))
    argument_map["dehumid_type"] = dehumid_type

    cooling_sensible_heat_ratio = arguments[6].clone
    assert(cooling_sensible_heat_ratio.setValue(0.7))
    argument_map["cooling_sensible_heat_ratio"] = cooling_sensible_heat_ratio

    humid_type = arguments[7].clone
    assert(humid_type.setValue("None"))
    argument_map["humid_type"] = humid_type

    oa_spec = arguments[8].clone
    assert(oa_spec.setValue("Use Individual Zone Design Outdoor Air"))
    argument_map["oa_spec"] = oa_spec

    dcv_type = arguments[9].clone
    assert(dcv_type.setValue("OccupancySchedule"))
    argument_map["dcv_type"] = dcv_type

    economizer_type = arguments[10].clone
    assert(economizer_type.setValue("NoEconomizer"))
    argument_map["economizer_type"] = economizer_type

    heat_recovery_type = arguments[11].clone
    assert(heat_recovery_type.setValue("Sensible"))
    argument_map["heat_recovery_type"] = heat_recovery_type

    sensible_effectiveness = arguments[12].clone
    assert(sensible_effectiveness.setValue(0.7))
    argument_map["sensible_effectiveness"] = sensible_effectiveness

    latent_effectiveness = arguments[13].clone
    assert(latent_effectiveness.setValue(0.65))
    argument_map["latent_effectiveness"] = latent_effectiveness

    add_meters = arguments[14].clone
    assert(add_meters.setValue(true))
    argument_map["add_meters"] = add_meters

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)

    # save the workspace for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = workspace_out_path(test_name)
    workspace.save(output_file_path,true)
  end
end

# def test_calcula_volumen
# end
