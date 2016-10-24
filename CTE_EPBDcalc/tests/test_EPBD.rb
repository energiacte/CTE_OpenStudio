require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'
require 'set'
require 'pp'

class ConexionEPDB_Test < MiniTest::Unit::TestCase
  def setup
    @sqlPath = "#{ File.dirname(__FILE__) }/eplusout.sql"
    @modelPath = "#{ File.dirname(__FILE__) }/out.osm"
    assert(File.exist?(@modelPath))
    assert(File.exist?(@sqlPath))
  end


  def test_residencial
    # create an instance of the measure
    measure = ConexionEPDB.new
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(@sqlPath))
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(@modelPath))

    measure.run(runner, argument_map)
    result = runner.result
    show_output(result)
  end

  def test_terciario
    # TODO: use model with non residential use
    # create an instance of the measure
    measure = ConexionEPDB.new
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(@sqlPath))
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(@modelPath))

    measure.run(runner, argument_map)
    result = runner.result
    show_output(result)
  end

end

