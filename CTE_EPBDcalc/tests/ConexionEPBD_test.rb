require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'
require 'set'
require 'pp'

class ConexionEPDB_Test < MiniTest::Unit::TestCase
  
  def test_unico
    # create an instance of the measure
    measure = ConexionEPDB.new
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new    
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
    
    sqlPath = "#{File.dirname(__FILE__)}/cubito+garaje_NH_ideal.sql"
    modelPath = "#{File.dirname(__FILE__)}/cubito+garaje_NH_ideal.osm"
    assert(File.exist?(modelPath))
    assert(File.exist?(sqlPath))
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath))
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath))    
    
    #~ sqlFile = runner.lastEnergyPlusSqlFile      
    #~ sqlFile = sqlFile.get
    
    #~ # get the last model
    #~ model = runner.lastOpenStudioModel
    #~ if model.empty?
      #~ runner.registerError('Cannot find last model.')
      #~ return false
    #~ end
    #~ model = model.get
    
    measure.run(runner, argument_map)
    result = runner.result
    show_output(result)

  #~ LastOpenStudioModelPath
    
    
    
    
  end
  
  #~ def test_performanceReportNames
    #~ # create an instance of the measure
    #~ measure = ConexionEPDB.new
    #~ # create an instance of a runner
    #~ runner = OpenStudio::Ruleset::OSRunner.new
    #~ # get arguments
    #~ arguments = measure.arguments()
    #~ argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
    #~ runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(SQLPATH))
    #~ sqlFile = runner.lastEnergyPlusSqlFile
    #~ sqlFile = sqlFile.get
        
    #~ if  !measure.performancereportnames(sqlFile).empty?
        #~ runner.registerError("performancereportnames(sqlFile) vacío")
    #~ end
    #~ assert(measure.performancereportnames(sqlFile).get.count ==3)    
  #~ end
  
  #~ def test_uses
    
    
    #~ measure.performancereportnames(sqlFile).get.each do | report |      
      #~ columnnames_query = "SELECT DISTINCT ColumnName FROM  TabularDataWithStrings
      #~ WHERE ReportName = '#{report}'"
      #~ columnsnamessearch = sqlFile.execAndReturnVectorOfString(columnnames_query)      
      #~ if report.end_with?("ELECTRICITY")
        #~ assert(columnsnamessearch.get.count == 14)
      #~ elsif report.end_with?("HEATING")
        #~ assert(columnsnamessearch.get.count == 13)
      #~ elsif report.end_with?("COOLING")
        #~ assert(columnsnamessearch.get.count == 13)
      #~ end            
    #~ end
  #~ end
  
  #~ def test_usedvectors
    #~ measure = ConexionEPDB.new
    #~ runner = OpenStudio::Ruleset::OSRunner.new
    #~ runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(SQLPATH))
    #~ sqlFile = runner.lastEnergyPlusSqlFile
    #~ sqlFile = sqlFile.get
    
    #~ assert(measure.usedvectors(sqlFile) == 
        #~ ['ELECTRICITY', 'DISTRICT HEATING', 'DISTRICT COOLING'])
  #~ end
  
  #~ def enduses(measure, sqlFile)
    #~ # TODO: terciario
    #~ result = {}
    #~ measure.performancereportnames(sqlFile).get.each do | reportName |
      #~ vector = reportName.split(' - ')[1]
      #~ enduses_query = "
      #~ SELECT DISTINCT columnName FROM TabularDataWithStrings
      #~ WHERE reportName == '#{reportName}' "
      #~ enduses_search = sqlFile.execAndReturnVectorOfString(enduses_query)
      #~ result[vector] = []
      #~ enduses_search.get.each do | endUse |
        #~ result[vector] << endUse.split(':')[0]
      #~ end
    #~ end
    #~ return result
  #~ end
  
  #~ def test_enduses    
    #~ measure = ConexionEPDB.new
    #~ runner = OpenStudio::Ruleset::OSRunner.new
    #~ runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(SQLPATH))
    #~ sqlFile = runner.lastEnergyPlusSqlFile
    #~ sqlFile = sqlFile.get
    
    #~ enduses = enduses(measure, sqlFile)    
    
    #~ assert(enduses.keys == ['ELECTRICITY', 'DISTRICT HEATING', 'DISTRICT COOLING'])
    #~ uses = ['INTERIORLIGHTS', 'EXTERIORLIGHTS',
    #~ 'INTERIOREQUIPMENT', 'EXTERIOREQUIPMENT', 'FANS', 'PUMPS',
    #~ 'HEATING', 'COOLING', 'HEATREJECTION', 'HUMIDIFIER', 'HEATRECOVERY',
    #~ 'WATERSYSTEMS', 'COGENERATION'].to_set    
    
    #~ assert_equal(enduses['DISTRICT HEATING'].to_set, uses,
        #~ "Error en el test: los usos finales para vector district heating no coinciden")
    #~ assert_equal(enduses['DISTRICT COOLING'].to_set, uses, 
        #~ "Error en el test: los usos finales para vector district cooling no coinciden")    
    #~ assert_equal(enduses['ELECTRICITY'].to_set, uses.add('REFRIGERATION'),
        #~ "Error en el test: los usos finales para vector ELECTRICITY no coinciden")
    
  #~ end

  #~ def modeledEPBFinalEnergyConsumptionByMonth(measure, sqlFile)
    #~ meses = (1..12).to_a
    #~ valoresvectores = {}
    #~ # TODO: terciario
    #~ enduses = ['Heating', 'Cooling', 'WaterSystems']

    #~ measure.usedvectors(sqlFile).each do | vectorName |
      #~ vector = OpenStudio::EndUseFuelType.new(vectorName)
      #~ valoresvectores[vectorName] = [0.0] *12
      #~ enduses.each do | useName |
        #~ meses.each do | mesNumber |
            #~ endfueltype    = OpenStudio::EndUseFuelType.new(vectorName)
            #~ endusecategory = OpenStudio::EndUseCategoryType.new(useName)
            #~ monthofyear    = OpenStudio::MonthOfYear.new(mesNumber)
            #~ valor = sqlFile.energyConsumptionByMonth(
                    #~ endfueltype, endusecategory, monthofyear).to_f
            #~ valoresvectores[vectorName][mesNumber-1] += valor
        #~ end
      #~ end
    #~ end
    #~ return valoresvectores
  #~ end  
      
  #~ def test_valoresmensualesEPBmodelada
    #~ measure = ConexionEPDB.new
    #~ runner = OpenStudio::Ruleset::OSRunner.new
    #~ runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(SQLPATH))
    #~ sqlFile = runner.lastEnergyPlusSqlFile
    #~ sqlFile = sqlFile.get
    
    #~ # TODO: terciario    
    #~ valoresmensuales = modeledEPBFinalEnergyConsumptionByMonth(measure, sqlFile)    
    #~ assert_equal(valoresmensuales['ELECTRICITY'].reduce(0, :+), 0)
    #~ assert_equal(valoresmensuales['DISTRICT HEATING'].reduce(0, :+),241976789760.0)
    #~ assert_equal(valoresmensuales['DISTRICT COOLING'].reduce(0, :+), 69564910592.0)
    # assert_in_epsilon(a, b, epsilon = 0.001, msg = 'nones')   
  #~ end
  
  #~ def test_valoresmensualesEPBprocesada
    #~ measure = ConexionEPDB.new
    #~ runner = OpenStudio::Ruleset::OSRunner.new
    #~ runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(SQLPATH))
    #~ runner.setLastOpenStudioModelPath(OpenStudio::Path.new(SQLPATH))
    #~ model = runner.lastOpenStudioModel
    
    #~ arguments = measure.arguments()
    #~ argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
    #~ sqlFile = runner.lastEnergyPlusSqlFile
    #~ sqlFile = sqlFile.get
    
    
    #~ #TODO: terciario    
    #~ servicios = measure.get_servicios(runner, argument_map )
    #~ salida = measure.procesedEPBFinalEnergyConsumptionByMonth(sqlFile, runner, servicios)
    #~ if !salida
      #~ show_output(@runner.result)
    #~ end    
    #~ salida.each do | linea |
      #~ vectorfinal = linea[0]       
      #~ if linea[-1].start_with?('# DH WS') && vectorfinal == 'GASNATURAL'
        #~ assert_equal(linea[3..14].reduce(0, :+),0.0)
      #~ end
      #~ if linea[-1].start_with?('# DH HEAT') && vectorfinal == 'ELECTRICIDAD'
        #~ assert_equal(linea[3..14].reduce(0, :+),67215.77)
      #~ end
      #~ if linea[-1].start_with?('# DH HEAT') && vectorfinal == 'MEDIOAMBIENTE'
        #~ assert_equal(linea[3..14].reduce(0, :+),134431.54)
      #~ end
      #~ if linea[-1].start_with?('# DH COOL') && vectorfinal == 'ELECTRICIDAD'
        #~ assert_equal(linea[3..14].reduce(0, :+).round(2),19323.60)
      #~ end
      #~ if linea[-1].start_with?('# DH COOL') && vectorfinal == 'MEDIOAMBIENTE'
        #~ assert_equal(linea[3..14].reduce(0, :+),67632.55)
      #~ end
      #~ assert_equal(linea.count, 16)
    #~ end    
    #~ measure.exportComsumptionList(10, salida)     
  #~ end   
  
end

