#! /usr/bin/ruby
# coding: utf-8
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative '../measure.rb'

#require 'sqlite3'

# este test está pensado para que sea paralelo a test_pyOS
# osea que no tiene nada que ver con los objetos openstudio.. model, etc,
# unicamente con las lecturas SQL

class Cte_lib_Test < MiniTest::Unit::TestCase

    def setup
        #@cur = SQLite3::Database.open "eplusout.sql"
    end

    def test_StandardReports
      modelPath = "#{File.dirname(__FILE__)}/out.osm"
      idfPath = "#{File.dirname(__FILE__)}/out.idf"
      sqlPath = "#{File.dirname(__FILE__)}/eplusout.sql"
      reportPath = "#{File.dirname(__FILE__)}/report.html"

      assert(File.exist?(modelPath))
      assert(File.exist?(idfPath))
      assert(File.exist?(sqlPath))

      # create an instance of the measure
      measure = CTE_InformeDBHE.new

      # create an instance of a runner
      runner = OpenStudio::Ruleset::OSRunner.new

      # set up runner, this will happen automatically when measure is run in PAT
      runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath))
      runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(idfPath))
      runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath))

      #~ # get the last model
      #~ model = runner.lastOpenStudioModel
      #~ if model.empty?
      #~ runner.registerError('Cannot find last model.')
      #~ return false
      #~ end
      #~ model = model.get

      # set argument values to good values and run the measure
      #argument_map = OpenStudio::Ruleset::OSArgumentMap.new

      translator = OpenStudio::OSVersion::VersionTranslator.new
      model = translator.loadModel(modelPath)
      model = model.get
      sqlFile = model.setSqlFile(runner.lastEnergyPlusSqlFile.get)
      sqlFile = model.sqlFile.get

      # get arguments
      #arguments = measure.arguments(model)
      arguments = measure.arguments()
      argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)

      assert(result.value.valueName == "Success")
      assert(result.warnings.size == 0)
      assert(File.exist?(reportPath))
    end
end

