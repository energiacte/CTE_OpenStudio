# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'
require 'openstudio'

#start the measure
class ConexionEPDB < OpenStudio::Ruleset::ReportingUserScript

  TECNOLOGIAS = {
        gas_boiler: { descripcion: 'caldera de gas',
                      combustibles: [['GASNATURAL', 0.95]],
                      servicios: ['WATERSYSTEMS', 'HEATING']},
        hp_heat:    { descripcion: 'bomba de calor en calefaccion',
                      combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 2.0]], # COP_ma = COP -1 -> COP = 3.0
                      servicios: ['WATERSYSTEMS', 'HEATING']},
        hp_cool:    { descripcion: 'bomba de calor en refrigeracion',
                      combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 3.5]], # COP_ma = COP +1 -> COP = 2.5
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

    acs_tech = []
    acs_desc = []
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


  def procesedEPBFinalEnergyConsumptionByMonth(sqlFile, runner, servicios)
    if not _comprobacionDeConsistencia(sqlFile, runner) then return false end

    vectoresOrigen = {'WATERSYSTEMS' => 'DISTRICTHEATING', 'HEATING' => 'DISTRICTHEATING',
                      'COOLING' =>'DISTRICTCOOLING' }
    result = []
    servicios.each do | servicio, tecnologia |
      vectorOrigen = vectoresOrigen[servicio]
      vector = energyConsumptionByVectorAndUse(sqlFile, vectorOrigen , servicio)
      vector = vector.map{ |v| OpenStudio.convert(v, 'J', 'kWh').get }

      TECNOLOGIAS[tecnologia][:combustibles].each do | combustible, rendimiento |
        comentario   = "# #{servicio} #{tecnologia} #{vectorOrigen}-->#{combustible} #{rendimiento}"
        if vector.reduce(0, :+) != 0
          result << [combustible, 'CONSUMO', 'EPB'] + vector.map { |v| (v * rendimiento).round(2) } + [comentario]
        end
      end

    end
    return result
  end

  def exportComsumptionList(areaHabitable, listaConsumos)
    # TODO: añadir una cabecera con datos del edifico como la superficie acondicionada
    nombreFichero = 'consumoParaEPBDcalc.csv'

    outFile = File.open(nombreFichero, 'w')
    outFile.write("vector,tipo,src_dst\n")
    outFile.write("# Area_ref: #{ areaHabitable }\n")
    listaConsumos.each do | vectorConsumo |
      outFile.write(vectorConsumo[0..-2].join(',') + vectorConsumo[-1] + "\n")
    end
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


    waterSystemsTech = runner.getStringArgumentValue('WATERSYSTEMS', user_arguments)
    heatingTech = runner.getStringArgumentValue('HEATING', user_arguments)
    coolingTech = runner.getStringArgumentValue('COOLING', user_arguments)

    servicios = [['WATERSYSTEMS', waterSystemsTech.to_sym],
                 ['HEATING', heatingTech.to_sym],
                 ['COOLING', coolingTech.to_sym]]

    areaHabitable = sqlFile.execAndReturnFirstDouble(
    "SELECT
       SUM(FloorArea)
     FROM Zones
       LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
       LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
     WHERE zl.Name NOT LIKE 'CTE_N%' ").get

    consumosFinales = procesedEPBFinalEnergyConsumptionByMonth(sqlFile, runner, servicios)
    exportComsumptionList(areaHabitable, consumosFinales)

    return true

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
