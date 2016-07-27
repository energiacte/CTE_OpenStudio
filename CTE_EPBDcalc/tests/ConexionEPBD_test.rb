require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'
require 'set'
require 'pp'

SQLPATH = "#{File.dirname(__FILE__)}/eplusout.sql"

class ConexionEPDB_Test < MiniTest::Unit::TestCase

  def setup
    @measure = ConexionEPDB.new    

    # create an instance of a runner
    @runner = OpenStudio::Ruleset::OSRunner.new
    
    # get arguments
    arguments = @measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
    @runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(SQLPATH))
        
    sqlFile = @runner.lastEnergyPlusSqlFile
    @sqlFile = sqlFile.get

  end

  def modeledEPBFinalEnergyConsumptionByMonth(sqlFile)
    meses = (1..12).to_a
    valoresvectores = {}
    # TODO: terciario
    enduses = ['Heating', 'Cooling', 'WaterSystems']

    @measure.usedvectors(sqlFile).each do | vectorName |
      vector = OpenStudio::EndUseFuelType.new(vectorName)
      valoresvectores[vectorName] = [0.0] *12
      enduses.each do | useName |
        meses.each do | mesNumber |
            endfueltype    = OpenStudio::EndUseFuelType.new(vectorName)
            endusecategory = OpenStudio::EndUseCategoryType.new(useName)
            monthofyear    = OpenStudio::MonthOfYear.new(mesNumber)
            valor = sqlFile.energyConsumptionByMonth(
                    endfueltype, endusecategory, monthofyear).to_f
            valoresvectores[vectorName][mesNumber-1] += valor
        end
      end
    end
    return valoresvectores
  end
  
  def performancereportnames(sqlFile)
    reportname_query = "SELECT DISTINCT ReportName FROM TabularDataWithStrings
      WHERE ReportName LIKE 'Building Energy Performance - %'
      AND ReportName NOT LIKE '% Peak Demand'"
    performancereportnames = sqlFile.execAndReturnVectorOfString(reportname_query)
    return performancereportnames
  end
  
  
  
  def test_performanceReportNames
    #~ if  !@measure.performancereportnames(@sqlFile).empty?
      #~ puts reports.get
    #~ end
    assert(performancereportnames(@sqlFile).get.count ==3)
  end
  
  def test_uses
    performancereportnames(@sqlFile).get.each do | report |
      
      columnnames_query = "SELECT DISTINCT ColumnName FROM  TabularDataWithStrings
      WHERE ReportName = '#{report}'"
      columnsnamessearch = @sqlFile.execAndReturnVectorOfString(columnnames_query)      
      if report.end_with?("ELECTRICITY")
        assert(columnsnamessearch.get.count == 14)
      elsif report.end_with?("HEATING")
        assert(columnsnamessearch.get.count == 13)
      elsif report.end_with?("COOLING")
        assert(columnsnamessearch.get.count == 13)
      end      
      
    end
  end
  
  def test_usedvectors
    assert(@measure.usedvectors(@sqlFile) == 
        ['ELECTRICITY', 'DISTRICT HEATING', 'DISTRICT COOLING'])
  end
  
  def enduses(sqlFile)
    # TODO: terciario
    result = {}
    @measure.performancereportnames(sqlFile).get.each do | reportName |
      vector = reportName.split(' - ')[1]
      enduses_query = "
      SELECT DISTINCT columnName FROM TabularDataWithStrings
      WHERE reportName == '#{reportName}' "
      enduses_search = sqlFile.execAndReturnVectorOfString(enduses_query)
      result[vector] = []
      enduses_search.get.each do | endUse |
        result[vector] << endUse.split(':')[0]
      end
    end
    return result
  end
  
  def test_enduses  
    enduses = enduses(@sqlFile)    
    
    assert(enduses.keys == ['ELECTRICITY', 'DISTRICT HEATING', 'DISTRICT COOLING'])
    uses = ['INTERIORLIGHTS', 'EXTERIORLIGHTS',
    'INTERIOREQUIPMENT', 'EXTERIOREQUIPMENT', 'FANS', 'PUMPS',
    'HEATING', 'COOLING', 'HEATREJECTION', 'HUMIDIFIER', 'HEATRECOVERY',
    'WATERSYSTEMS', 'COGENERATION'].to_set    
    
    assert_equal(enduses['DISTRICT HEATING'].to_set, uses,
        "Error en el test: los usos finales para vector district heating no coinciden")
    assert_equal(enduses['DISTRICT COOLING'].to_set, uses, 
        "Error en el test: los usos finales para vector district cooling no coinciden")    
    assert_equal(enduses['ELECTRICITY'].to_set, uses.add('REFRIGERATION'),
        "Error en el test: los usos finales para vector ELECTRICITY no coinciden")
    
  end
  
      
  def test_valoresmensualesEPBmodelada
    # TODO: terciario    
    valoresmensuales = modeledEPBFinalEnergyConsumptionByMonth(@sqlFile)    
    assert_equal(valoresmensuales['ELECTRICITY'].reduce(0, :+), 0)
    assert_equal(valoresmensuales['DISTRICT HEATING'].reduce(0, :+),241976789760.0)
    assert_equal(valoresmensuales['DISTRICT COOLING'].reduce(0, :+), 69564910592.0)
    #~ assert_in_epsilon(a, b, epsilon = 0.001, msg = 'nones')   
  end
  
  def test_valoresmensualesEPBprocesada
    #TODO: terciario
    salida = @measure.procesedEPBFinalEnergyConsumptionByMonth(@sqlFile, @runner)
    if !salida
      show_output(@runner.result)
    end    
    salida.each do | linea |
      vectorfinal = linea[0]       
      if linea[-1].start_with?('# DH WS') && vectorfinal == 'GASNATURAL'
        assert_equal(linea[3..14].reduce(0, :+),0.0)
      end
      if linea[-1].start_with?('# DH HEAT') && vectorfinal == 'ELECTRICIDAD'
        assert_equal(linea[3..14].reduce(0, :+),67215.77)
      end
      if linea[-1].start_with?('# DH HEAT') && vectorfinal == 'MEDIOAMBIENTE'
        assert_equal(linea[3..14].reduce(0, :+),134431.54)
      end
      if linea[-1].start_with?('# DH COOL') && vectorfinal == 'ELECTRICIDAD'
        assert_equal(linea[3..14].reduce(0, :+).round(2),19323.60)
      end
      if linea[-1].start_with?('# DH COOL') && vectorfinal == 'MEDIOAMBIENTE'
        assert_equal(linea[3..14].reduce(0, :+),67632.55)
      end
      assert_equal(linea.count, 16)
    end    
    @measure.exportComsumptionList(10, salida)     
  end   
  
end

