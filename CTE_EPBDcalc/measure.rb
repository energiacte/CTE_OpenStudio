# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'
#~ require 'openstudio'

#start the measure
class ConexionEPDB < OpenStudio::Ruleset::ReportingUserScript

  TECNOLOGIAS = {
        gas_boiler: {  descripcion: 'caldera de gas',
                        combustibles: [['GASNATURAL', 0.95]]},
        hp_heat:    {   descripcion: 'bomba de calor en calefaccion',
                        combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 2.0]]}, # COP_ma = COP -1 -> COP = 3.0
        hp_cool:    {   descripcion: 'bomba de calor en refrigeracion',
                        combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 3.5]]}, # COP_ma = COP +1 -> COP = 2.5
        }

    #TODO: hay que ver como se recoge en los consumos si tenemos WaterSystems
  SERVICIOS = { 'WATERSYSTEMS'    => ['DISTRICTHEATING', '# DH WS'],
                        'HEATING' => ['DISTRICTHEATING', '# DH HEAT'],
                        'COOLING' => ['DISTRICTCOOLING', '# DH COOL']}

  # human readable name
  def name
    return "Conexion con EPBDcalc"
  end

  # human readable description
  def description
    return "Prepara el resultado de la simulacion para la conexion con EPBDcalc"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Es necesasrio agrupar los consumos y producciones por usos y vectores energeticos"
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # this measure does not require any user arguments, return an empty list

    return args
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return result
    end

    request = OpenStudio::IdfObject.load("Output:Variable,,Site Outdoor Air Drybulb Temperature,Hourly;").get
    result << request

    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    # no funciona usar un self.sqlFile con las medidas de test
    #~ @sqlFile = runner.lastEnergyPlusSqlFile

    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)


    # put data into the local variable 'output', all local variables are available for erb to use when configuring the input html file

    output =  "Measure Name = " << name << "<br>"
    output << "Building Name = " << model.getBuilding.name.get << "<br>"                       # optional variable
    output << "Floor Area = " << model.getBuilding.floorArea.to_s << "<br>"                   # double variable
    output << "Floor to Floor Height = " << model.getBuilding.nominalFloortoFloorHeight.to_s << " (m)<br>" # double variable
    output << "Net Site Energy = " << sqlFile.netSiteEnergy.to_s << " (GJ)<br>" # double variable

    web_asset_path = OpenStudio.getSharedResourcesPath() / OpenStudio::Path.new("web_assets")

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.in"
    if File.exist?(html_in_path)
        html_in_path = html_in_path
    else
        html_in_path = "#{File.dirname(__FILE__)}/report.html.in"
    end
    html_in = ""
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      env_type = sqlFile.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new("WeatherRunPeriod")
          ann_env_pd = env_pd
          break
        end
      end
    end

    # only try to get the annual timeseries if an annual simulation was run
    if ann_env_pd

      # get desired variable
      key_value =  "Environment"
      time_step = "Hourly" # "Zone Timestep", "Hourly", "HVAC System Timestep"
      variable_name = "Site Outdoor Air Drybulb Temperature"
      output_timeseries = sqlFile.timeSeries(ann_env_pd, time_step, variable_name, key_value) # key value would go at the end if we used it.

      if output_timeseries.empty?
        runner.registerWarning("Timeseries not found.")
      else
        runner.registerInfo("Found timeseries.")
      end
    else
      runner.registerWarning("No annual environment period found.")
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = "./report.html"
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # close the sql file
    sqlFile.close()

    return true

  end


  def performancereportnames(sqlFile)
    reportname_query = "SELECT DISTINCT ReportName FROM TabularDataWithStrings
      WHERE ReportName LIKE 'Building Energy Performance - %'
      AND ReportName NOT LIKE '% Peak Demand'"
    performancereportnames = sqlFile.execAndReturnVectorOfString(reportname_query)
    return performancereportnames
  end

  def usedvectors(sqlFile)
    result = []
    performancereportnames(sqlFile).get.each do | report |
      result << report.split(' - ')[1]
    end
    return result
  end

  def energyConsumptionByVectorAndUse(sqlFile, vectorName, useName)
    # las unidades son Julios a tenor de la informacion del SQL:
    # SELECT distinct  reportname, units FROM TabularDataWithStrings
    # los reports son LIKE 'BUILDING ENERGY PERFORMANCE - %'
    result = [0.0]*12
    meses = (1..12).to_a
    meses.each do | mesNumber |
      endfueltype    = OpenStudio::EndUseFuelType.new(vectorName)
      endusecategory = OpenStudio::EndUseCategoryType.new(useName)
      monthofyear    = OpenStudio::MonthOfYear.new(mesNumber)
      valor = sqlFile.energyConsumptionByMonth(
                    endfueltype, endusecategory, monthofyear).to_f                    
      result[mesNumber-1] += valor
    end
    return result
  end

 
  def _comprobacionDeConsistencia(sqlFile, runner)
    ### búsqueda de errores, que es independiente de los servicios y vectores
    # si todo está simulado con DISTRICT

    tienenquesercero = [
        ['ELECTRICITY', 'WATERSYSTEMS'],
        ['ELECTRICITY', 'HEATING'],
        ['ELECTRICITY', 'COOLING'],
        ['DISTRICTCOOLING', 'WATERSYSTEMS'],
        ['DISTRICTCOOLING', 'HEATING'],
        ['DISTRICTHEATING', 'COOLING'],
        #~ ['DISTRICTHEATING', 'HEATING'], # linea de test que fuerza un error
        ]

    tienenquesercero.each do | fuel, enduse |
        consumomensual = energyConsumptionByVectorAndUse(sqlFile, fuel, enduse)
        if consumomensual.reduce(0, :+) != 0
          runner.registerError("ERROR: el consumo debería ser cero,
            combustible:#{fuel}, y uso: #{enduse}")
          return false
        end        
    end 
    return true      
  end


  def procesedEPBFinalEnergyConsumptionByMonth(sqlFile, runner)      
    if not _comprobacionDeConsistencia(sqlFile, runner) then return false end

    servicios = [['WATERSYSTEMS', :gas_boiler],
                 ['HEATING', :hp_heat],
                 ['COOLING', :hp_cool]]

    result = []
    servicios.each do | servicio, tecnologia |
      vectorOrigen = SERVICIOS[servicio][0]
      comentario   = SERVICIOS[servicio][1]
      vector = energyConsumptionByVectorAndUse(sqlFile, vectorOrigen , servicio)
      vector = vector.map{ |v| OpenStudio.convert(v, 'J', 'kWh').get }
      
      TECNOLOGIAS[tecnologia][:combustibles].each do | combustible, rendimiento |
        if vector.reduce(0, :+) != 0
          result << [combustible, 'CONSUMO', 'EPB'] + vector.map { |v| (v * rendimiento).round(2) } + [comentario]
        end        
      end

    end
    return result
  end
  
  def exportComsumptionList(listaConsumos)
    # TODO: añadir una cabecera con datos del edifico como la superficie acondicionada
    nombreFichero = 'consumoParaEPBDcalc.csv'
    File.open(nombreFichero, 'w') {|file| file.write("vector,tipo,src_dst\n")}    
    listaConsumos.each do | vectorConsumo |
      File.open(nombreFichero, 'a') {|file| file.write(vectorConsumo[0..-2].join(',') + vectorConsumo[-1])}
      File.open(nombreFichero, 'a') {|file| file.write("\n")}
    end
  end

end

# register the measure to be used by the application
ConexionEPDB.new.registerWithApplication

        #      W             refrigeracion  calefaccion
        #      |            ___  W              W     ____
        #  QF -+---> QC     |QF|-+---> QC   QF--+---> |QC|
        #                   ----                      ----
        # siempre Qc = Qf + W
        # calefaccion COP = Qc/W y Qf = medio ambiente, luego
        #     Qma = Qc - W = COP·W - W = W·(COP - 1)
        # refrigeracion COP = Qf/W y Qc = medio ambiente, luego
        #     Qma = Qf + W = COP·W + W = W·(COP + 1)
