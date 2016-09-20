# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# XXX: la medida asume que WATERSYSTEMS es equivalente a ACS, pero no es correcto porque
# XXX: un sistema real con distribución por agua (radiadores) podría estar incluído ahí.


require 'erb'
require 'openstudio'
require 'date'

#start the measure
class ConexionEPDB < OpenStudio::Ruleset::ReportingUserScript

 TECNOLOGIAS = {
        gas_boiler: { descripcion: 'caldera de gas',
                      combustibles: [['GASNATURAL', 0.95]],
                      servicios: ['WATERSYSTEMS', 'HEATING']},
        generic_acs:{descripcion: 'equipo genérico ACS',
                      combustibles: [['RED1', 1]],
                      servicios: ['WATERSYSTEMS']},
        hp_heat:    { descripcion: 'bomba de calor en calefaccion',
                      combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 2.0]], # COP_ma = COP -1 -> COP = 3.0
                      servicios: ['WATERSYSTEMS', 'HEATING']},
        generic_heat:{descripcion: 'equipo genérico en calefaccion',
                      combustibles: [['RED 1', 1]],
                      servicios: ['HEATING']},
        hp_cool:    { descripcion: 'bomba de calor en refrigeracion',
                      combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 3.5]], # COP_ma = COP +1 -> COP = 2.5
                      servicios: ['COOLING']},
        generic_cool:{descripcion: 'equipo genérico en refrigeración',
                      combustibles: [['RED 2', 1]],
                      servicios: ['COOLING']},        
        }

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
    provincias_display = OpenStudio::StringVector.new
    provincias_chs = OpenStudio::StringVector.new

    acs_tech = [] # teconología
    acs_desc = [] # descripción
    heat_tech = []
    heat_desc = []
    cool_tech = []
    cool_desc = []
    TECNOLOGIAS.each do | clave, valor |
      if valor[:servicios].include? 'WATERSYSTEMS'
        acs_tech << clave.to_s
        acs_desc << TECNOLOGIAS[clave][:descripcion]
      end
      if valor[:servicios].include? 'HEATING'
        heat_tech << clave.to_s
        heat_desc << TECNOLOGIAS[clave][:descripcion]
      end
      if valor[:servicios].include? 'COOLING'
        cool_tech << clave.to_s
        cool_desc << TECNOLOGIAS[clave][:descripcion]
      end
    end


    agua_caliente_sanitaria = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('WATERSYSTEMS', acs_tech,acs_desc, true)
    agua_caliente_sanitaria.setDisplayName("Agua Caliente Sanitaria")
    agua_caliente_sanitaria.setDefaultValue("gas_boiler")
    args << agua_caliente_sanitaria

    calefaccion = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('HEATING', heat_tech, heat_desc, true)
    calefaccion.setDisplayName("Calefacción")
    calefaccion.setDefaultValue("hp_heat")
    args << calefaccion

    refrigeracion = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('COOLING', cool_tech, cool_desc, true)
    refrigeracion.setDisplayName("Refrigeración")
    refrigeracion.setDefaultValue("hp_cool")
    args << refrigeracion


    # this measure does not require any user arguments, return an empty list

    return args
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

  def consumoDeIluminacion(runner, model, sqlFile)
    runner.registerInfo("Consumo de iluminacion")
    valores = []
    
    # usaría espacios, pero es que la variable del consumo para sistemas de iluminación 
    # está por zonas.
    # TODO: analizar el caso en que hay más de un equipo de iluminación por espacio.
  
    # Solamente usamos el primer espacio de la zona? suponemos que solo hay uno?
    
    model.getThermalZones.each do | thermalZone |
      valores << [0]*12
      # hay que saber si esta zona se suma o no
      # depende de los tipos de los espacios que la forman
      # los tipos de los espacios deben ser coheretes entre si
      # TODO: comprobar la coherencia y decidir si no lo son.      
      spaces = thermalZone.spaces()
      # vamos a tomar el tipo del primer espacio      
      spaceType = spaces[0].spaceType.get.name.get
      runner.registerInfo("#{thermalZone.name}")
      runner.registerInfo("#{spaces[0].name.get} tipo #{spaceType}")      
      next if (spaceType.start_with?('CTE_AR') or
         spaceType.start_with?('CTE_NOHABs') )
      
      valueJ = sqlFile.execAndReturnVectorOfDouble(
      zonelightselectricenergymonthlyentry(thermalZone.name.to_s.upcase)).get
      
      valueJ.each do | valor |
        value << OpenStudio.convert(valor, 'J', 'kWh').get.round(1)
      end
      valores << value
      runner.registerInfo("consumo electrico mensual: #{value} kWh")
    end
    totalzonas = valores.transpose.map {|x| x.reduce(:+)}
    totalzonas = totalzonas.map{ |x| x.round(0) }
    runner.registerInfo("consumo total zonas: #{totalzonas} kWh")
    return totalzonas
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


  def procesedEPBFinalEnergyConsumptionByMonth(model, sqlFile, runner, servicios)
  
    if not _comprobacionDeConsistencia(sqlFile, runner)      
      runner.registerInfo("Error de consistencia, hay consumo distinto de Distrito")      
    end
    
    salida = []
    salida << "vector,tipo,src_dst"
    
    vectoresOrigen = {'WATERSYSTEMS' => 'DISTRICTHEATING', 'HEATING' => 'DISTRICTHEATING',
                      'COOLING' =>'DISTRICTCOOLING' }
    result = []    
    
    servicios.each do | servicio, tecnologia |
      vectorOrigen = vectoresOrigen[servicio]
      vector = energyConsumptionByVectorAndUse(sqlFile, vectorOrigen , servicio)
      
      vector = vector.map{ |v| OpenStudio.convert(v, 'J', 'kWh').get }

      TECNOLOGIAS[tecnologia][:combustibles].each do | combustible, rendimiento |
        comentario   = "# #{servicio}, #{tecnologia}, #{vectorOrigen}-->#{combustible}, #{rendimiento}"
        if vector.reduce(0, :+) != 0
          result << [combustible, 'CONSUMO', 'EPB'] + vector.map { |v| (v * rendimiento).round(0) } + [comentario]
          salida << [combustible, 'CONSUMO', 'EPB'] + 
              vector.map { |v| (v * rendimiento).round(0) } + [comentario]
        end        
      end
    end
    
    consumoIluminacionPorMeses = consumoDeIluminacion(runner, model, sqlFile)
    if consumoIluminacionPorMeses.reduce(0, :+) != 0
      salida << ['ELECTRICIDAD', 'CONSUMO', 'EPB'] + 
        consumoIluminacionPorMeses +
            ['#LIGHTING']
    end
    runner.registerInfo("#{salida}")
    
    return salida
  end

  def exportStringRows(runner, string_rows)
    
    nombreFichero = 'consumoParaEPBDcalc.csv'

    outFile = File.open(nombreFichero, 'w')        
    runner.registerInfo("string_rows = #{string_rows}")
    
    string_rows.each do | string |
      runner.registerInfo("row: #{string}")      
      if string.is_a? String
        outFile.write(string + "\n")
      elsif string.is_a? Array
        outFile.write(string[0..-2].join(',') + string[-1] + "\n")
      end
    end
  end

  def get_servicios(runner, user_arguments)
    waterSystemsTech = runner.getStringArgumentValue('WATERSYSTEMS', user_arguments)
    heatingTech = runner.getStringArgumentValue('HEATING', user_arguments)
    coolingTech = runner.getStringArgumentValue('COOLING', user_arguments)

    servicios = [['WATERSYSTEMS', waterSystemsTech.to_sym],
                 ['HEATING', heatingTech.to_sym],
                 ['COOLING', coolingTech.to_sym]]
    return servicios
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get

    # get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    string_rows = []


    # BUG: Esta superficie incluye los espacios habitables no acondicionados que no deberían
    # BUG: formar parte del área de referencia.
    cte_areareferencia = sqlFile.execAndReturnFirstDouble("
    SELECT
      SUM(FloorArea)
    FROM Zones
      LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
      LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
    WHERE zl.Name NOT LIKE 'CTE_N%' ").get

    string_rows << "#CTE_Area_ref: #{cte_areareferencia.round(0)}"

    cte_name = model.building.get.name
    string_rows << "#CTE_Name: #{cte_name}"
    runner.registerInfo("CTE_Name: #{cte_name}")

    cte_datetime = DateTime.now.strftime "%d/%m/%Y %H:%M"
    string_rows << "#CTE_Datetime: #{cte_datetime}"
    runner.registerInfo("CTE_Datetime: #{cte_datetime}")

    cte_clima = model.weatherFile.get.path.get
    string_rows << "#CTE_Weather_file: #{cte_clima}"
    runner.registerInfo("CTE_Weather_file: #{cte_clima}")
    
    servicios = get_servicios(runner, user_arguments)
    result = procesedEPBFinalEnergyConsumptionByMonth(model, sqlFile, runner, servicios)
    if result != false
      string_rows = string_rows + result
    else
      return false
    end
            
    exportStringRows(runner, string_rows)
    return true

  end
  
  def zonelightselectricenergymonthlyentry(thermalzonename)      
    return "
SELECT 
    VariableValue
FROM 
    reportvariabledatadictionary as rvdd
    INNER JOIN ReportVariableData AS rvd 
    ON rvdd.ReportVariableDataDictionaryIndex == rvd.ReportVariableDataDictionaryIndex 
    WHERE rvdd.VariableName == 'Zone Lights Electric Energy' 
    AND rvdd.KeyValue == '#{thermalzonename}' 
    AND rvdd.ReportingFrequency == 'Monthly' "
    #~ ORDER BY rvd.TimeIndex ASC"
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
