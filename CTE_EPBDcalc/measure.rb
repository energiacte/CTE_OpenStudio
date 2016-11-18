# -*- coding: utf-8 -*-
#
# Copyright (c) 2016 Ministerio de Fomento
#                    Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author(s): Rafael Villar Burke <pachi@ietcc.csic.es>,
#            Daniel Jiménez González <dani@ietcc.csic.es>
#            Marta Sorribes Gil <msorribes@ietcc.csic.es>

require 'erb'
require 'openstudio'
require 'date'
require 'json'
require 'fileutils'

require_relative "resources/cte_query"
require_relative "resources/cte_lib"

# Medida de OpenStudio (ReportingUserScript) para usar en condiciones CTE
# La medida permite obtener salidas válidas para su uso con el software
# de evaluación de indicadores según la ISO 52000-1 (EN 15603)
class ConexionEPDB < OpenStudio::Ruleset::ReportingUserScript
  # XXX: la medida asume que WATERSYSTEMS es equivalente a ACS, pero no es correcto porque
  # XXX: un sistema real con distribución por agua (radiadores) podría estar incluído ahí.

  TECNOLOGIAS = {
    'gas_boiler' => { descripcion: 'caldera de gas',
                      combustibles: [['GASNATURAL', 0.95]],
                      servicios: ['WATERSYSTEMS', 'HEATING'] },
    'generic_acs' => { descripcion: 'equipo genérico ACS',
                       combustibles: [['RED1', 1]],
                       servicios: ['WATERSYSTEMS'] },
    'hp_heat' => { descripcion: 'bomba de calor en calefaccion',
                   combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 2.0]], # COP_ma = COP -1 -> COP = 3.0
                   servicios: ['WATERSYSTEMS', 'HEATING'] },
    'generic_heat' => { descripcion: 'equipo genérico en calefaccion',
                        combustibles: [['RED1', 1]],
                        servicios: ['HEATING'] },
    'hp_cool' => { descripcion: 'bomba de calor en refrigeracion',
                   combustibles: [['ELECTRICIDAD', 1], ['MEDIOAMBIENTE', 1.5]], # COP_ma = COP - 1 -> COP = 1.5
                   servicios: ['COOLING'] },
    'generic_cool' => { descripcion: 'equipo genérico en refrigeración',
                        combustibles: [['RED2', 1]],
                        servicios: ['COOLING'] }
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

    acs_tech = [] # tecnología
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


    agua_caliente_sanitaria = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('CTE_Watersystems', acs_tech,acs_desc, true)
    agua_caliente_sanitaria.setDisplayName("Agua Caliente Sanitaria")
    agua_caliente_sanitaria.setDefaultValue("generic_acs")
    args << agua_caliente_sanitaria

    calefaccion = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('CTE_Heating', heat_tech, heat_desc, true)
    calefaccion.setDisplayName("Calefacción")
    calefaccion.setDefaultValue("generic_heat")
    args << calefaccion

    refrigeracion = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('CTE_Cooling', cool_tech, cool_desc, true)
    refrigeracion.setDisplayName("Refrigeración")
    refrigeracion.setDefaultValue("generic_cool")
    args << refrigeracion


    # this measure does not require any user arguments, return an empty list

    return args
  end

  def checkFuelsAndUses(sqlFile, runner)
    # Comprobamos que no hay consumos que no sean district para aplicar esta medida
    mustBeZero = [
        ['ELECTRICITY', 'WATERSYSTEMS'],
        ['ELECTRICITY', 'HEATING'],
        ['ELECTRICITY', 'COOLING'],
        ['DISTRICTCOOLING', 'WATERSYSTEMS'],
        ['DISTRICTCOOLING', 'HEATING'],
        ['DISTRICTHEATING', 'COOLING']]
    mustBeZero.each do |fuel, enduse|
        if consumoMensualVectorPorUso(sqlFile, fuel, enduse).reduce(0, :+) != 0
          runner.registerError("CTE ERROR: consumo inesperado de combustible '#{ fuel }' para el uso '#{ enduse }'")
          return false
        end
    end
    return true
  end

  def usedvectors(sqlFile)
    reportname_query = "SELECT DISTINCT ReportName FROM TabularDataWithStrings
      WHERE ReportName LIKE 'Building Energy Performance - %'
      AND ReportName NOT LIKE '% Peak Demand'"
    performancereportnames = sqlFile.execAndReturnVectorOfString(reportname_query).get

    result = []
    performancereportnames.each do | report |
      result << report.split(' - ')[1]
    end
    return result
  end

  def consumoMensualIluminacion(runner, model, sqlFile)
    valores = [[0] * 12]
    model.getThermalZones.each do | thermalZone |
      spaceTypeNames = thermalZone.spaces().map { |space| space.spaceType.get.name.get }
      validSpaceTypeNames = spaceTypeNames.select { |name| not (name.start_with?('CTE_AR') or name.start_with?('CTE_NOHAB')) }
      next if validSpaceTypeNames.length == 0
      valueJ = sqlFile.execAndReturnVectorOfDouble(zonelightselectricenergymonthlyentry(thermalZone.name.to_s.upcase)).get
      valores << valueJ.map { |valor| OpenStudio.convert(valor, 'J', 'kWh').get.round(2) }
    end
    # Consumo total de iluminación para todas las zonas [kWh]
    totalzonas = valores.transpose.map {|x| x.reduce(:+)}
    totalzonas = totalzonas.map{ |x| x.round(1) }
    return totalzonas
  end

  def consumoMensualVentiladores(runner, model, sqlFile)
    fanquery = "SELECT VariableValue
    FROM ReportMeterDataDictionary rmdd
    INNER JOIN ReportMeterData rmd
    ON rmdd.ReportMeterDataDictionaryIndex = rmd.ReportMeterDataDictionaryIndex
    WHERE VariableName = 'Fans:Electricity'
    AND ReportingFrequency = 'Monthly' "
    fansearch = sqlFile.execAndReturnVectorOfDouble(fanquery)
    fanValues = fansearch.get
    fanValuesKWh = fanValues.map{ |valorJ| OpenStudio.convert(valorJ, 'J', 'kWh').get.round(2) }
    return fanValuesKWh
  end

  def consumoMensualVectorPorUso(sqlFile, vectorName, useName)
    result = [0.0] * 12
    meses = (1..12).to_a
    meses.each do | mesNumber |
      endfueltype    = OpenStudio::EndUseFuelType.new(vectorName)
      endusecategory = OpenStudio::EndUseCategoryType.new(useName)
      monthofyear    = OpenStudio::MonthOfYear.new(mesNumber)
      valor = sqlFile.energyConsumptionByMonth(endfueltype, endusecategory, monthofyear).to_f
      result[mesNumber - 1] += valor
    end
    return result.map{ |v| OpenStudio.convert(v, 'J', 'kWh').get.round(2) }
  end

  def consumoMensual(model, sqlFile, runner, servicios)
    # Montly energy use for EPB services
    salida = []
    salida << "vector,tipo,src_dst"

    servicios.each do | servicio, tecnologia |
      vectorOrigen = { 'WATERSYSTEMS' => 'DISTRICTHEATING',
                       'HEATING' => 'DISTRICTHEATING',
                       'COOLING' =>'DISTRICTCOOLING' }[servicio]
      vector = consumoMensualVectorPorUso(sqlFile, vectorOrigen, servicio)

      TECNOLOGIAS[tecnologia][:combustibles].each do | combustible, rendimiento |
        if vector.reduce(0, :+) != 0
          comentario   = "# #{ servicio }, #{ tecnologia }, #{ vectorOrigen }-->#{ combustible }, #{ rendimiento }"
          salida << [combustible, 'CONSUMO', 'EPB'] + vector.map { |v| (v * rendimiento).round(2) } + [comentario]
        end
      end
    end

    consumoIluminacionPorMeses = consumoMensualIluminacion(runner, model, sqlFile)
    if consumoIluminacionPorMeses.reduce(0, :+) != 0
      salida << ['ELECTRICIDAD', 'CONSUMO', 'EPB'] + consumoIluminacionPorMeses + ['#LIGHTING']
    end

    consumoVentiladoresPorMeses = consumoMensualVentiladores(runner, model, sqlFile)
    if consumoVentiladoresPorMeses.reduce(0, :+) != 0
      salida << ['ELECTRICIDAD', 'CONSUMO', 'EPB'] + consumoVentiladoresPorMeses + ['#FANS']
    end

    return salida
  end


  def get_string_rows(model, sqlFile, runner, user_arguments)
    string_rows = []
    string_rows << "# Datos de entrada"

    # General metadata and attributes stored in the model
    string_rows << "#CTE_Name: #{ model.building.get.name }"
    string_rows << "#CTE_Datetime: #{ DateTime.now.strftime '%d/%m/%Y %H:%M' }"
    string_rows << "#CTE_Weather_file: #{ model.weatherFile.get.path.get.to_s.split(File::SEPARATOR)[-1].strip.chomp('.epw') }"
    unless model.building.get.comment.empty?
      json = JSON.parse(model.building.get.comment[2..-1])
      unless json.key?("CTE_ConstructionSet")
        unless model.building.get.defaultConstructionSet.empty?
          mycset = model.building.get.defaultConstructionSet.get.name.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
        else
          mycset = 'Base'
        end
        json["CTE_ConstructionSet"] = mycset
        model.building.get.setComment(json.to_json)
      end
      json.each do | clave, valor |
        string_rows << "##{ clave }: #{ valor }"
      end
    end

    # Building quantities

    # XXX: Esta superficie incluye los espacios habitables no acondicionados
    # XXX: ¿Deberían excluirse del área de referencia también estos o solo los no habitables?
    cte_areareferencia = sqlFile.execAndReturnFirstDouble("
    SELECT
      SUM(FloorArea)
    FROM Zones
      LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
      LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
    WHERE zl.Name NOT LIKE 'CTE_N%' ").get

    string_rows << "# Datos medidos"
    string_rows << "#CTE_Area_ref: #{ cte_areareferencia.round(2) }"
    string_rows << "#CTE_Vol_ref: #{ CTE_Query.volumenHabitable(sqlFile).round(2) }"

    string_rows << "# Medicion construcciones: [Area [m2], Transmitancia U [W/m2K]]"
    mediciones = CTE_tables.tabla_mediciones_envolvente(model, sqlFile, runner)[:data]
    mediciones.each do | nombre, area, transmitancia |
      string_rows << "#CTE_medicion_#{ nombre }: [#{ area }, #{ transmitancia }]"
    end

    string_rows << "# Medicion puentes termicos: ['Coef. acoplamiento [W/K]', 'Longitud [m]', 'PSI [W/mK]']"
    mediciones = CTE_tables.tabla_mediciones_puentes_termicos(model, runner)[:data]
    mediciones.each do | nombre, coefAcop, long, psi|
      string_rows << "#CTE_medicion_PT_#{ nombre }: [#{ coefAcop }, #{ long }, #{ psi }]"
    end

    # Building services
    servicios = [['WATERSYSTEMS', runner.getStringArgumentValue('CTE_Watersystems', user_arguments)],
                 ['HEATING', runner.getStringArgumentValue('CTE_Heating', user_arguments)],
                 ['COOLING', runner.getStringArgumentValue('CTE_Cooling', user_arguments)]]

    # Final energy by month
    result = consumoMensual(model, sqlFile, runner, servicios)
    if result != false
      string_rows = string_rows + result
    end

    return string_rows
  end

  def get_filename(model)
    buildingName = model.building.get.name.to_s.strip
    climatePath = model.weatherFile.get.path.get.to_s
    climateFilename = climatePath.split(File::SEPARATOR)[-1].strip.chomp('.epw')
    unless model.building.get.comment.empty?
      json = JSON.parse(model.building.get.comment[2..-1])
      constructionSet = json["CTE_ConstructionSet"] || 'Base'
      recuperador = json["CTE_Heat_recovery"].to_f * 100
      ventilacionDiseno = json["CTE_Design_flow_rate"].to_f
    end
    nnRec =   ('%2s' % recuperador).gsub(' ','0').gsub('.','')
    nnnVent = ('%3s' % ventilacionDiseno).gsub(' ','0').gsub('.','')
    return "cteEPBD-#{ buildingName }-#{ constructionSet }-V#{ nnnVent }R#{ nnRec }-#{ climateFilename }.csv"
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

    # Basic consistency check - no fuel types other than disctrict for WATERSYSTEMS, HEATING and COOLING
    checkFuelsAndUses(sqlFile, runner)

    string_rows = get_string_rows(model, sqlFile, runner, user_arguments)

    outFile = File.open(get_filename(model), 'w')

    string_rows.each do | string |
      if string.is_a? String
        outFile.write(string + "\n")
      elsif string.is_a? Array
        outFile.write(string[0..-2].join(',') + string[-1] + "\n")
      end
    end

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
