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
    #~ @measure.sqlFile = sqlFile.get
    @sqlFile = sqlFile.get
    #~ puts 	@sqlFile.energyPlusSqliteFile() 
    #~ puts @sqlFile.methods()
    
    
    #~ puts @sqlFile.energyComsumptionByMonth('ELECTRICITY', 'HEATING', 'JANUARY')
  end
  
  
  # class level variable
  #~ @@co = OpenStudio::Runmanager::ConfigOptions.new(true)

  #~ def model_in_path
    #~ return "#{File.dirname(__FILE__)}/example_model.osm"
  #~ end
  
  #~ def epw_path
    #~ # make sure we have a weather data location
    #~ assert(!@@co.getDefaultEPWLocation.to_s.empty?)
    #~ epw = @@co.getDefaultEPWLocation / OpenStudio::Path.new("USA_CO_Golden-NREL.724666_TMY3.epw")
    #~ assert(File.exist?(epw.to_s))
    
    #~ return epw.to_s
  #~ end

  #~ def run_dir(test_name)
    #~ # always generate test output in specially named 'output' directory so result files are not made part of the measure    
    #~ return "#{File.dirname(__FILE__)}/output/#{test_name}"
  #~ end
  
  #~ def model_out_path(test_name)
    #~ return "#{run_dir(test_name)}/example_model.osm"
  #~ end
  
  #~ def sql_path(test_name)
    #~ return "#{run_dir(test_name)}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
  #~ end
  
  #~ def report_path(test_name)
    #~ return "#{run_dir(test_name)}/report.html"
  #~ end

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
  
  #~ def suma(lista)
    #~ result = 0
    #~ lista.each do | valor |
      #~ puts 'hola'
      #~ puts valor
      #~ puts 'caracola'
      #~ result += valor
    #~ end
    #~ return result
  #~ end
      
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
    @measure.exportComsumptionList(salida)     
  end 
  
  
  
  
  def zonashabitablesquery
    zonashabitablesquery =  "
SELECT
    ZoneIndex, ZoneName, Volume, FloorArea, ZoneListIndex, Name
FROM Zones
    LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex) 
    LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex) 
WHERE zl.Name != 'CTE_NOHABITA' AND zl.Name != 'CTE_N' AND zl.Name != 'CTE_NOHABITABLE' "
    zonashabitablesquery
  end
  
  def test_zonashabitables
    zonashabitablessearch = @sqlFile.execAndReturnVectorOfString("#{zonashabitablesquery}")
    assert(zonashabitablessearch.get.count == 21)
  end    
  
end


#de aquí para abajo no vale nada, lo dejo porque parece que pued ser interesante.

  # create test files if they do not exist when the test first runs 
  def setup_test(test_name, idf_output_requests)  
    
    @@co.findTools(false, true, false, true)
    
    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))
    
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end

    assert(File.exist?(model_in_path))
    
    if File.exist?(model_out_path(test_name))
      FileUtils.rm(model_out_path(test_name))
    end

    # convert output requests to OSM for testing, OS App and PAT will add these to the E+ Idf 
    workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel, "EnergyPlus".to_IddFileType)
    workspace.addObjects(idf_output_requests)
    rt = OpenStudio::EnergyPlus::ReverseTranslator.new
    request_model = rt.translateWorkspace(workspace)

    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_in_path)
    assert((not model.empty?))
    model = model.get
    model.addObjects(request_model.objects)
    model.save(model_out_path(test_name), true)

    if !File.exist?(sql_path(test_name))
      puts "Running EnergyPlus"

      wf = OpenStudio::Runmanager::Workflow.new("modeltoidf->energypluspreprocess->energyplus")
      wf.add(@@co.getTools())
      job = wf.create(OpenStudio::Path.new(run_dir(test_name)), OpenStudio::Path.new(model_out_path(test_name)), OpenStudio::Path.new(epw_path))

      rm = OpenStudio::Runmanager::RunManager.new
      rm.enqueue(job, true)
      rm.waitForFinished
    end
  end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = NewMeasure.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments()
    assert_equal(0, arguments.size)
  end

  def test_good_argument_values
  
    test_name = "test_good_argument_values"

    # create an instance of the measure
    measure = NewMeasure.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
    
    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)
    assert_equal(1, idf_output_requests.size)

    # mimic the process of running this measure in OS App or PAT
    setup_test(test_name, idf_output_requests)
    
    assert(File.exist?(model_out_path(test_name)))
    assert(File.exist?(sql_path(test_name)))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))
    
    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
      assert(result.warnings.size == 0)
    ensure
      Dir.chdir(start_dir)
    end
    
    # make sure the report file exists
    assert(File.exist?(report_path(test_name)))
  end
