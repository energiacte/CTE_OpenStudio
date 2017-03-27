require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'
require 'set'
require 'pp'
require_relative "../resources/cte_lib"

class ConexionEPDB_Test < MiniTest::Unit::TestCase
  def setup
    @sqlPath = "#{ File.dirname(__FILE__) }/eplusout.sql"
    @modelPath = "#{ File.dirname(__FILE__) }/out.osm"
    assert(File.exist?(@modelPath))
    assert(File.exist?(@sqlPath))

    @sqlPathTerciario = "#{ File.dirname(__FILE__) }/eplusout_terciario.sql"
    @modelPathTerciario = "#{ File.dirname(__FILE__) }/out_terciario.osm"
    assert(File.exist?(@modelPathTerciario))
    assert(File.exist?(@sqlPathTerciario))
  end

  def _test_NR02_volumen
    puts "iniciando test NR02 volumen"
    sqlPath_NR02 = "#{ File.dirname(__FILE__) }/N_R02_plurif_entremedianeras_SFP+HS3_D3.sql"
    modelPath_NR02 = "#{ File.dirname(__FILE__) }/N_R02_plurif_entremedianeras_SFP+HS3_D3.osm"
    # create an instance of the measure
    measure = ConexionEPDB.new
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath_NR02))
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath_NR02))
    puts "corriendo la medida"
    measure.run(runner, argument_map)
    puts "media corrida"
    result = runner.result
    show_output(result)  
  end

  def test_NR02_volumen_sombras
    puts "iniciando test NR02 volumen_sombras"
    sqlPath_NR02 = "#{ File.dirname(__FILE__) }/N_R02_plurif_entremedianeras_sombrapatios_SFP+HS3_D3.sql"
    modelPath_NR02 = "#{ File.dirname(__FILE__) }/N_R02_plurif_entremedianeras_sombrapatios_SFP+HS3_D3.osm"
    # create an instance of the measure
    measure = ConexionEPDB.new
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath_NR02))
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath_NR02))
    puts "corriendo la medida"
    measure.run(runner, argument_map)
    puts "media corrida"
    result = runner.result
    show_output(result)  
  end



  def _test_residencial
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

  def _test_terciario
    # TODO: use model with non residential use
    # create an instance of the measure
    measure = ConexionEPDB.new
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(@sqlPathTerciario))
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(@modelPathTerciario))

    measure.run(runner, argument_map)
    result = runner.result
    show_output(result)
  end

end

