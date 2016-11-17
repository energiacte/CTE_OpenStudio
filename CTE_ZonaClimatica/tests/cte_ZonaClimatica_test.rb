require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class CTE_ZonaClimatica_Test < MiniTest::Unit::TestCase
  def test_weather_file
    test_out_file = File.join(File.dirname(__FILE__), 'output', 'test_out.osm')
    FileUtils.rm_f test_out_file if File.exist? test_out_file

    #test_new_weather_file = 'another_weather_file.epw'
    test_new_weather_file = 'D3_peninsula.epw'

    # create an instance of the measure
    measure = CTE_ZonaClimatica.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = File.join(File.dirname(__FILE__), "test.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # convert this to measure attributes
    if model.weatherFile.empty?
      puts "No weather file in current model"
    else
      puts "Current weather file is #{ File.basename(model.weatherFile.get.path.get.to_s) }"# unless model.weatherFile.empty?
    end

    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)

    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1
    arg = arguments[count += 1].clone
    assert(arg.setValue("D3_peninsula"))
    argument_map["zona_climatica"] = arg

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0, "Warnings are greater than 0")
    #assert(result.info.size == 2)

    assert(model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).count == 2, "Expected 2 design day objects")

    puts "Final weather file is #{ File.basename(model.weatherFile.get.path.get.to_s) }" unless model.weatherFile.empty?
    puts "Final site data is #{ model.getSite }" if model.getSite
    puts "Final Water Mains Temp is #{ model.getSiteWaterMainsTemperature }" if model.getSiteWaterMainsTemperature
    model.save(test_out_file)

    assert(File.basename(model.weatherFile.get.path.get.to_s) == test_new_weather_file)
    if test_new_weather_file =~ /D3/
      assert(model.getSite.latitude == 40.68)
      assert(model.getSite.longitude == -4.13)
    end
  end

end
