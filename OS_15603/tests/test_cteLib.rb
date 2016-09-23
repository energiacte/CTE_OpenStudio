#! /usr/bin/ruby
# coding: utf-8
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative '../measure.rb'
require_relative "../resources/cte_lib.rb"

#require 'sqlite3'

# este test está pensado para que sea paralelo a test_pyOS
# osea que no tiene nada que ver con los objetos openstudio.. model, etc,
# unicamente con las lecturas SQL

class Cte_lib_Test < MiniTest::Unit::TestCase

    def setup
        #@cur = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"
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
      measure = OpenStudioResultsCopy.new

      # create an instance of a runner
      runner = OpenStudio::Ruleset::OSRunner.new

      # get arguments and test that they are what we are expecting
      arguments = measure.arguments()
      #assert_equal(22, arguments.size)

      # set up runner, this will happen automatically when measure is run in PAT
      runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath))
      runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(idfPath))
      runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath))

      # set argument values to good values and run the measure
      #argument_map = OpenStudio::Ruleset::OSArgumentMap.new

      # get arguments
      #arguments = measure.arguments(model)
      arguments = measure.arguments()
      argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
      
      translator = OpenStudio::OSVersion::VersionTranslator.new    
      model = translator.loadModel(modelPath)      
      model = model.get
      areaPuentesTermicos = {}
      
  coeficienteAcoplamiento = {}
    model.getSurfaces.each do |surface|
      if surface.name.get.include? "_pt"        
        tipoPT = surface.name.get.split('_pt')[1]
        unless coeficienteAcoplamiento.keys.include?(tipoPT)
          coeficienteAcoplamiento[tipoPT] = 0.0
        end
        construccion = surface.construction.get
        puts "Surface #{surface.name.get}"
        puts "construccion #{construccion.name.get.split('PSI')[1].to_f}"
        psi = surface.construction.get.name.get.split('PSI')[1].to_f
        puts "PSI: #{psi}"
        
        coeficienteAcoplamiento[tipoPT] += surface.grossArea.round(2)
      end
    end
      puts "___ fino filipino___"
      correr = false
      if correr
      measure.run(runner, argument_map)

      result = runner.result
      show_output(result)

      assert(result.value.valueName == "Success")
      assert(result.warnings.size == 0)
      #assert(result.info.size == 1)

      assert(File.exist?(reportPath))

      # model = runner.lastOpenStudioModel
      # if model.empty?
      #   runner.registerError("Cannot find last model.")
      #   return false
      # end
      # model = model.get
      # #puts model.getSpaces.size
      # sqlFile = model.setSqlFile(runner.lastEnergyPlusSqlFile.get)
      # sqlFile = model.sqlFile.get
      # puts sqlFile.is_initialized

      # assert(CTEgeo.zonasHabitables(sqlFile).count() == 1)
      # assert(CTEgeo.superficieHabitable == 49)
      # assert(CTEgeo.volumenHabitable == 49)
      # assert(CTEgeo.superficieHabitable == 49)
      # assert(CTEgeo.zonasNoHabitables(sqlFile).count() == 47)
      # assert(CTEgeo.superficieNoHabitable == 49)
      # assert(CTEgeo.volumenNoHabitable == 49)
      # assert(CTEgeo.envolventeSuperficiesExteriores.count() == 49)
      # assert(CTEgeo.envolventeSuperficiesInteriores.count() == 49)
      # assert(CTEgeo.envolventeAreaExterior == 49)
      # assert(CTEgeo.envolventeAreaInterior == 49)
      end
    end

    # def test_variables_disponibles
    #     stm = @cur.prepare CTE_lib.variablesdisponiblesquery
    #     rs = stm.execute
    #     assert_equal(rs.count,47)
    # end

    # def test_superficies
    #     stm = @cur.prepare CTEgeo::Query::ZONASHABITABLES_SUPERFICIES
    #     assert_equal(stm.execute.count, 8)
    # end

    # def test_superficiesexternas
    #     stm = @cur.prepare CTEgeo::Query::ENVOLVENTE_SUPERFICIES_EXTERIORES
    #     assert_equal(stm.execute.count, 5)
    # end

    # def test_superficiescontacto
    #     stm = @cur.prepare CTEgeo::Query::ENVOLVENTE_SUPERFICIES_INTERIORES
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_murosexteriores
    #     stm = @cur.prepare murosexterioresenvolventequery
    #     assert_equal(stm.execute.count, 3)
    # end

    # def test_cubiertasexteriores
    #     stm = @cur.prepare cubiertasexterioresenvolventequery
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_suelosterreno
    #     stm = @cur.prepare suelosterrenoenvolventequery
    #     assert_equal(stm.execute.count, 1)
    # end

    # def test_huecos
    #     stm = @cur.prepare huecosenvolventequery
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
    
    def test_consumo_electrico
      # create an instance of the measure
      puts
      puts 'test_consumo_electrico'
      puts 'create measure'
      measure = OpenStudioResultsCopy.new

      # create an instance of a runner
      puts 'create runner'
      runner = OpenStudio::Ruleset::OSRunner.new
      modelPath = "#{File.dirname(__FILE__)}/4_plurif_JUAN_TORNERO_corregido.osm"
      idfPath = "#{File.dirname(__FILE__)}/cubito+garaje_NH-out.idf"
      sqlPath = "#{File.dirname(__FILE__)}/cubito+garaje_NH.sql"
      sqlPath = "#{File.dirname(__FILE__)}/4_plurif_JUAN_TORNERO_corregido.sql"
      reportPath = "#{File.dirname(__FILE__)}/report.html"      
      
      runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath))
      #~ runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(idfPath))
      runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath))
      
      model = runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath))
      
      model = runner.lastOpenStudioModel
      if model.empty?
        runner.registerError("Cannot find last model.")
        return false
      end
      model = model.get
      #puts model.getSpaces.size
      sqlFile = model.setSqlFile(runner.lastEnergyPlusSqlFile.get)
      sqlFile = model.sqlFile.get
      
      model.getThermalZones.each do | thermalZone |
        puts thermalZone.name
        valueJ = sqlFile.execAndReturnFirstDouble(zonelightselectricenergymonthlyentry(thermalZone.name.to_s.upcase)).get
        value = OpenStudio.convert(valueJ, 'J', 'kWh').get
        puts "consumo electrico anual: #{value.round(1)} J"
      end
      
      valor = sqlFile.execAndReturnFirstDouble(zonelightselectricenergymonthlyentry('THERMAL ZONE 1'))
            
      puts valor
      
      #~ arguments = measure.arguments()
      #~ argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
      
      #~ measure.run(runner, argument_map)

      result = runner.result
      show_output(result)
    
    end
    
    def zonelightselectricenergymonthlyentry(thermalzonename)      
      return "
SELECT 
    SUM(VariableValue) 
FROM 
    reportvariabledatadictionary as rvdd
    INNER JOIN ReportVariableData AS rvd 
    ON rvdd.ReportVariableDataDictionaryIndex == rvd.ReportVariableDataDictionaryIndex 
    WHERE VariableName == 'Zone Lights Electric Energy' 
    AND KeyValue == '#{thermalzonename}' "
    end
    
    def murosexterioresenvolventequery
      return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{ CTEgeo::Query::ENVOLVENTE_SUPERFICIES_EXTERIORES }) AS surf
    WHERE (surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0) "
    end

    def cubiertasexterioresenvolventequery
      return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{ CTEgeo::Query::ENVOLVENTE_SUPERFICIES_EXTERIORES }) AS surf
    WHERE (surf.ClassName == 'Roof' AND surf.ExtBoundCond == 0) "
    end

    def suelosterrenoenvolventequery
      return "
SELECT
    SurfaceIndex, SurfaceName, ConstructionIndex, ClassName, Area,
    GrossArea, ExtBoundCond, ZoneIndex
FROM
    (#{ CTEgeo::Query::ENVOLVENTE_SUPERFICIES_EXTERIORES }) AS surf
    WHERE (surf.ClassName == 'Floor' AND surf.ExtBoundCond == -1) "
    end

    def huecosenvolventequery
      # XXX: No incluye lucernarios!
      return "
SELECT
    *
FROM Surfaces surf
    INNER JOIN  ( #{ CTEgeo::Query::ZONASHABITABLES } ) AS zones
    ON surf.ZoneIndex = zones.ZoneIndex
    WHERE (surf.ClassName == 'Window' AND surf.ExtBoundCond == 0) "
    end

end




# @cur = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"
# stm = @cur.prepare CTE_lib.huecosenvolventequery
# puts stm.execute.count

    #~ ### VARIABLES DISPONIBLES

    #~ ### ZONAS HABITABLES
    #~ def test_variablesDisponibles

        #~ #zonashabitables = CTEgeo.zonasHabitables(sqlFile)
        #~ # no podemos hacer test de esto porque tendríamos que cargar openstudio y, aún así,
        #~ # no sé como cargar un modelo concreto.

        #~ #numerodezonas = zonashabitables.count()
        #~ #assert_equal(numerodezonas, 47)

        #~ db = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"

        #~ dburi = os.path.abspath(os.path.join(currpath, '../examples/cubito+garaje_eplusoutZAB.sql'))
        #~ assert len(pyos.variablesDisponibles(dburi)) == 47
