#! /usr/bin/ruby
# coding: utf-8
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative '../measure.rb'
require_relative "../resources/ctelib.rb"

#require 'sqlite3'

# este test está pensado para que sea paralelo a test_pyOS
# osea que no tiene nada que ver con los objetos openstudio.. model, etc,
# unicamente con las lecturas SQL

class Cte_lib_Test < MiniTest::Unit::TestCase

    def setup
        #@cur = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"
    end

    def test_StandardReports
      modelPath = "cubito+garaje_NH.osm"
      idfPath = "cubito+garaje_NH-out.idf"
      sqlPath = "cubito+garaje_NH.sql"
      reportPath = "cubito+garaje_NH-report.html"

      assert(File.exist?(modelPath))
      model = OpenStudio::Path.new(modelPath)

      assert(File.exist?(idfPath))
      idfFile = OpenStudio::Path.new(idfPath)

      assert(File.exist?(sqlPath))
      sqlFile = OpenStudio::Path.new(sqlPath)

      # create an instance of the measure
      measure = OpenStudioResultsCopy.new

      # create an instance of a runner
      runner = OpenStudio::Ruleset::OSRunner.new

      # get arguments and test that they are what we are expecting
      arguments = measure.arguments()
      assert_equal(22, arguments.size)

      # set up runner, this will happen automatically when measure is run in PAT
      runner.setLastOpenStudioModelPath(model)
      runner.setLastEnergyPlusWorkspacePath(idfFile)
      runner.setLastEnergyPlusSqlFilePath(sqlFile)

      # set argument values to good values and run the measure
      #argument_map = OpenStudio::Ruleset::OSArgumentMap.new

      # get arguments
      #arguments = measure.arguments(model)
      arguments = measure.arguments()
      argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

      measure.run(runner, argument_map)

      result = runner.result
      show_output(result)

      assert(result.value.valueName == "Success")
      assert(result.warnings.size == 0)

      #assert(result.info.size == 1)

      assert(File.exist?(reportPath))

    end

    # def test_variables_disponibles
    #     stm = @cur.prepare CTE_lib.variablesdisponiblesquery
    #     rs = stm.execute
    #     assert_equal(rs.count,47)
    # end

    # def test_zonasHabitables
    #     stm = @cur.prepare CTE_lib.zonashabitablesquery
    #     rs = stm.execute
    #     assert_equal(rs.count,1)
    # end

    # def test_zonasNoHabitables
    #     stm = @cur.prepare CTE_lib.zonasnohabitablesquery
    #     assert_equal(stm.execute.count,1)
    # end

    # def test_superficies
    #     stm = @cur.prepare CTE_lib.superficiesquery
    #     assert_equal(stm.execute.count, 8)
    # end

    # def test_superficiescandidatas
    #     stm = @cur.prepare CTE_lib.superficiescandidatasquery
    #     assert_equal(stm.execute.count, 6)
    # end

    # def test_superficiesexternas
    #     stm = @cur.prepare CTE_lib.superficiesexternasquery
    #     assert_equal(stm.execute.count, 5)
    # end

    # def test_superficiesinternas
    #     stm = @cur.prepare CTE_lib.superficiesinternasquery
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_superficiescontacto
    #     stm = @cur.prepare CTE_lib.superficiescontactoquery
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_murosexterires
    #     stm = @cur.prepare CTE_lib.murosexterioresenvolventequery
    #     assert_equal(stm.execute.count, 3)
    # end

    # def test_cubiertasexteriores
    #     stm = @cur.prepare CTE_lib.cubiertassexterioresenvolventequery
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_suelosterreno
    #     stm = @cur.prepare CTE_lib.suelosterrenoenvolventequery
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_huecos
    #     stm = @cur.prepare CTE_lib.huecosenvolventequery
    #     rs =  stm.execute
    #     #~ puts rs.columns
    #     assert_equal(rs.count, 1)
    #     #~ puts '\n\rhola'
    #     #~ rs.each do |row|
    #         #~ puts row['SurfaceName']
    #         #~ puts row.join "\s"
    #     #~ end
    #     #~ puts '\n\rhola'
    # end

    #~ def test_CambioHorarioVeranoInvierno
        #~ stm = @cur.prepare CTE_lib.flowmurosexterioresquery
        #~ rs = stm.execute
    #~ end
end

# @cur = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"
# stm = @cur.prepare CTE_lib.huecosenvolventequery
# puts stm.execute.count

    #~ ### VARIABLES DISPONIBLES

    #~ ### ZONAS HABITABLES
    #~ def test_variablesDisponibles

        #~ #zonashabitablessearch = sqlFile.execAndReturnVectorOfString("#{zonashabitablesquery}")
        #~ # no podemos hacer test de esto porque tendríamos que cargar openstudio y, aún así,
        #~ # no sé como cargar un modelo concreto.

        #~ #numerodezonas = zonashabitablessearch.get.count()
        #~ #assert_equal(numerodezonas, 47)

        #~ db = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"

        #~ dburi = os.path.abspath(os.path.join(currpath, '../examples/cubito+garaje_eplusoutZAB.sql'))
        #~ assert len(pyos.variablesDisponibles(dburi)) == 47
