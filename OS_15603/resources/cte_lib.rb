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

require "openstudio"
require_relative "cte_query"

# TODO: acabar la tabla de remplazo
REPLACEMENTS = {
  'Ñ' => 'N',
  'ñ' => 'N',
  'Á' => 'A'}
ENCODING_OPTIONS = {
  :invalid           => :replace,  # Replace invalid byte sequences
  :replace           => "",        # Use a blank for those replacements
  :universal_newline => true,       # Always break lines with \n
  :fallback => lambda { |char|
  	REPLACEMENTS.fetch(char, "")}}

# TODO: aplicar sanitize a todos los name.get que se vayan (sólo) a representar
module Utils
  def self.sanitizestring(runner, inputstring)
    runner.registerInfo(" para sanitize, recibido |#{inputstring}|")
    return inputstring.encode(Encoding.find('ASCII'), ENCODING_OPTIONS)
  end

  def self.sanitize(runner, input)
  	if input.class == Array
  		salida = []
  		input.each do | elemento |
  			salida << sanitizestring(runner, elemento)
  		end
  	else
  		salida = sanitizestring(runner, input)
  	end
  	return salida
  end
end


module CTE_tables
  #======== Elementos generales  ============
  # variablesdisponiblesquery = "SELECT DISTINCT VariableName, ReportingFrequency FROM ReportVariableDataDictionary "

  #======== Tabla general de mediciones =====
  def self.tabla_mediciones_generales(model, sqlFile, runner)
    # TODO: descomponer superficies externas de la envolvente por tipos (muros, cubiertas, huecos, lucernarios, etc)
    buildingName = model.getBuilding.name.get
    # Zonas habitables
    zonasHabitables = CTE_Query.zonasHabitables(sqlFile)
    superficieHabitable = CTE_Query.superficieHabitable(sqlFile).round(2)
    volumenHabitable = CTE_Query.volumenHabitable(sqlFile).round(2)
    # Zonas no habitables
    zonasNoHabitables = CTE_Query.zonasNoHabitables(sqlFile)
    superficieNoHabitable = CTE_Query.superficieNoHabitable(sqlFile).round(2)
    volumenNoHabitable = CTE_Query.volumenNoHabitable(sqlFile).round(2)
    # Envolvente térmica
    superficiesExteriores = CTE_Query.envolventeSuperficiesExteriores(sqlFile)
    areaexterior = CTE_Query.envolventeAreaExterior(sqlFile).round(2)
    superficiesInteriores = CTE_Query.envolventeSuperficiesInteriores(sqlFile)
    areainterior = CTE_Query.envolventeAreaInterior(sqlFile).round(2)
    areatotal = areaexterior + areainterior
    compacidad = (volumenHabitable / areatotal).round(2)

    runner.registerInfo("* Iniciando mediciones (edificio #{ buildingName })")
    runner.registerValue("Zonas habitables", "#{ zonasHabitables }")
    runner.registerValue("Zonas habitables, número", zonasHabitables.count())
    runner.registerValue("Zonas habitables, superficie", superficieHabitable, 'm^2')
    runner.registerValue("Zonas habitables, volumen", volumenHabitable, 'm^3')
    runner.registerValue("Zonas no habitables", "#{ zonasNoHabitables }")
    runner.registerValue("Zonas no habitables, número", zonasNoHabitables.count())
    runner.registerValue("Zonas no habitables, superficie", superficieNoHabitable, 'm^2')
    runner.registerValue("Zonas no habitables, volumen", volumenNoHabitable, 'm^3')
    runner.registerValue('Envolvente Térmica, superficies exteriores', superficiesExteriores.count())
    runner.registerValue('Envolvente Térmica, superficies interiores', superficiesInteriores.count())
    runner.registerValue('Envolvente Térmica, área de superficies exteriores', areaexterior, 'm^2')
    runner.registerValue('Envolvente Térmica, área de superficies interiores', areainterior, 'm^2')
    runner.registerValue('Envolvente Térmica, área total', areatotal, 'm^2')
    runner.registerValue('Compacidad', compacidad)

    medicion_general = {}
    medicion_general[:title] = "Mediciones (edificio #{ buildingName })"
    medicion_general[:header] = ['', '#', 'Superficie', 'Volumen']
    medicion_general[:units] = ['', '', 'm²', 'm³']
    medicion_general[:data] = []
    medicion_general[:data] << ['<b>Edificio</b>', '', superficieHabitable + superficieNoHabitable, volumenHabitable + volumenNoHabitable]
    medicion_general[:data] << ["<u>Zonas habitables</u>", zonasHabitables.count(), superficieHabitable, volumenHabitable]
    medicion_general[:data] << ["<u>Zonas no habitables</u>", zonasNoHabitables.count(), superficieNoHabitable, volumenNoHabitable]
    medicion_general[:data] << ["<u>Envolvente térmica</u>", '', areatotal, '']
    medicion_general[:data] << ['- Exterior', '', areaexterior, '']
    medicion_general[:data] << ['- Interior', '', areainterior, '']
    medicion_general[:data] << ['<b>Compacidad</b>', "<b>#{ compacidad }</b>", areatotal, volumenHabitable]
    runner.registerInfo("* Finalizadas mediciones (edificio #{ buildingName })")

    return medicion_general
  end


 def self.energyConsumptionByVectorAndUse(sqlFile, vectorName, useName)
    # las unidades son Julios a tenor de la informacion del SQL:
    # SELECT distinct  reportname, units FROM TabularDataWithStrings
    # los reports son LIKE 'BUILDING ENERGY PERFORMANCE - %'
    result = [0.0] * 12
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

  def self.energyConsumptionByUses(sqlFile, useNames)
    useNames = [useNames] unless useNames.class == Array

    result = 0
    useNames.each do | end_use |
      query_all = "
      SELECT
        SUM(Value)
      FROM
        tabulardatawithstrings
      WHERE
        ReportName='AnnualBuildingUtilityPerformanceSummary'
        AND TableName='End Uses'
        AND RowName= '#{end_use}'
        AND ColumnName IN  ('Electricity', 'Natural Gas', 'Additional Fuel',
                    'District Cooling', 'District Heating') "
      search = sqlFile.execAndReturnFirstDouble(query_all)
      result += search.get
    end

    return OpenStudio.convert(result, 'GJ', 'kWh').get
  end



  def self.tabla_de_energias(model, sqlFile, runner)

    superficiehabitable = CTE_Query.superficieHabitable(sqlFile)

    usosEPB = {'Heating'=> 0, 'Cooling'=> 0, 'Water Systems'=> 0}
    #~ usosNoEPB = {'Interior Lighting'=> 0, 'Exterior Lighting'=> 0, 'Interior Equipment'=> 0,
            #~ 'Exterior Equipment'=> 0, 'Fans'=> 0, 'Pumps'=> 0, 'Heat Rejection'=> 0,
            #~ 'Humidification'=> 0, 'Heat Recovery'=> 0, 'Refrigeration'=> 0, 'Generators'=> 0}

    usosNoEPB = {'Interior Lighting'=> 0, 'Interior Equipment'=> 0,
            'Fans'=> 0, 'Pumps'=> 0, }
    
    traduce = {'Heating'=> 'Calefacción', 'Cooling'=> 'Refrigeración', 
      'Water Systems'=> 'ACS', 'Interior Lighting'=> 'Iluminación', 
      'Interior Equipment'=> 'Equipos','Fans'=> 'Ventiladores', 
      'Pumps'=> 'Bombas'}
    
    totalUsosEPB = 0
    usosEPB.each do | clave, dummy |
      valor = energyConsumptionByUses(sqlFile, clave)
      usosEPB[clave] = valor
      totalUsosEPB += valor
    end

    totalUsosNoEPB = 0
    usosNoEPB.each do | clave, dummy |
      valor = energyConsumptionByUses(sqlFile, clave)
      usosNoEPB[clave] = valor
      totalUsosNoEPB += valor
    end

    #~ runner.registerValue('Energia Neta (Net Site Energy)', energianeta, 'kWh')
    #~ runner.registerValue('Intensidad energética (EUI)', intensidadEnergetica, 'kWh/m^2')

    general_table = {}
    general_table[:title] = 'Consumo Neto (Energía Final)'
    general_table[:header] =['', 'Energía', 'Energía/Sup. Acond.']
    general_table[:units] = ['', 'kWh', 'kWh/m²']
    general_table[:data] = []
    general_table[:data] << ['<b>Servicios EPB + No EPB</b>',
      (totalUsosEPB+totalUsosNoEPB).round(0),
      "<b>#{((totalUsosEPB+totalUsosNoEPB)/superficiehabitable).round(1)}</b>"]      
    general_table[:data] << ['<b>Servicios EPB</b>', totalUsosEPB.round(0),
        "<b>#{(totalUsosEPB/superficiehabitable).round(1)}</b>"]
    usosEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", valor.round(0), (valor/superficiehabitable).round(0)]
    end

    general_table[:data] << ['<b>Servicios No EPB</b>', totalUsosNoEPB.round(0),
        "<b>#{(totalUsosNoEPB/superficiehabitable).round(1)}</b>"]
    usosNoEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", valor.round(0), (valor/superficiehabitable).round(0)]
    end
    return general_table
  end




  def self.tabla_mediciones_envolvente(model, sqlFile, runner)

    indicesquery = "SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
                    UNION
                    SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES })"
    indices  = sqlFile.execAndReturnVectorOfString(indicesquery).get

    data = []
    indices.each do | indiceconstruccion |
      query = "SELECT SUM(Area) FROM
                   (SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
                    UNION ALL
                    SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES }))
               WHERE ConstructionIndex == #{ indiceconstruccion }"
      area = sqlFile.execAndReturnFirstDouble(query).get
      nombre = sqlFile.execAndReturnFirstString("SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
      uvalue = sqlFile.execAndReturnFirstDouble("SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
      unless nombre.include?("_PSI")
        data << ["#{ nombre }".encode("UTF-8", invalid: :replace, undef: :replace), area, uvalue]
      end
    end

    contenedor_general = {}
    contenedor_general[:title] = "Mediciones elementos de la envolvente"
    contenedor_general[:header] = ['Construcción', 'Superficie', 'U']
    contenedor_general[:units] = ['', 'm²', 'W/m²K']
    contenedor_general[:data] = []
    data.each do | nombre, area, uvalue |
      contenedor_general[:data] << [nombre, area.round(2), uvalue.round(3)]
    end

    return contenedor_general
  end

  def self.tabla_mediciones_puentes_termicos(model, runner)

    coeficienteAcoplamiento = {}
    ttl_puenteTermico = {}
    model.getSurfaces.each do |surface|
      if surface.name.get.include? "_pt"
        tipoPT = surface.name.get.split('_pt')[1]
        unless coeficienteAcoplamiento.keys.include?(tipoPT)
          coeficienteAcoplamiento[tipoPT] = 0.0
          ttl_puenteTermico[tipoPT] = 0.0
        end
        coeficienteAcoplamiento[tipoPT] += surface.grossArea.round(2)
        ttl_puenteTermico[tipoPT] = surface.construction.get.name.get.split('PSI')[1].to_f
      end
    end

    contenedor_general = {}
    contenedor_general[:title] = "Mediciones de puentes térmicos"
    contenedor_general[:header] = ['Tipo', 'Coef. acoplamiento', 'Longitud', 'PSI']
    contenedor_general[:units] = ['', 'W/K', 'm', 'W/mK']
    contenedor_general[:data] = []
    coeficienteAcoplamiento.each do | key, value |
      psi = ttl_puenteTermico[key]
      contenedor_general[:data] << [key, value.round(0), (value/psi).round(0), psi.round(2)]
    end

    return contenedor_general


  end

  # Tabla de aire exterior
  def self.tabla_de_aire_exterior(model, sqlFile, runner)

    # Zone Combined Outdoor Air Changes per Hour is not includen in the OutdoorAirSummary,
    # it has to be read from general variable data in the SQL file.
    variableName = 'Zone Combined Outdoor Air Changes per Hour'


    # data for query
    report_name = 'OutdoorAirSummary'
    table_name = 'Average Outdoor Air During Occupied Hours'
    columns = ['', 'Ventilación mecánica media',
          'Infiltración media', 'Ventilación simple media', 'Ventilación combinada media']

    variableNamesForColumns = {
      'Ventilación mecánica media' => 'Avg. Mechanical Ventilation',
      'Infiltración media' => 'Avg. Infiltration',
      'Ventilación simple media' => 'Avg. Simple Ventilation',
      'Ventilación combinada media' => 'Zone Combined Outdoor Air Changes per Hour'}

    # populate dynamic rows
    # los rows son las filas, es decir las zonas térmicas
    rows_name_query = "SELECT DISTINCT  RowName FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end

    # create table
    table = {}
    table[:title] = 'Renovación del aire exterior (medias)'
    table[:header] = columns
    table[:units] = ['', 'ach', 'ach', 'ach', 'ach']
    table[:source_units] = [ '', 'ach', 'ach', 'ach', 'ach']
    table[:data] = []

    medias = {}
    table[:header].each do | columna|
      medias[columna] = 0
    end
    totalVolume = 0

    # run query and populate table
    rows.each do |row| # va zona a zona
      query = "SELECT Volume FROM Zones WHERE ZoneName='#{row}' "
      zoneVolume = sqlFile.execAndReturnFirstDouble(query).to_f
      totalVolume += zoneVolume
      row_data = [row]
      column_counter = -1
      table[:header].each do |header| #va columna a columna
        column_counter += 1
        next if header == ''

        if header.include? 'combinada'
          query = "SELECT
              AVG(VariableValue)
            FROM
              ReportVariableData AS rvd
              INNER JOIN ReportVariableDataDictionary AS rvdd ON rvdd.ReportVariableDataDictionaryIndex = rvd.ReportVariableDataDictionaryIndex
            WHERE
              rvdd.VariableName = 'Zone Combined Outdoor Air Changes per Hour'
              AND ReportingFrequency ='Monthly'
              AND KeyValue = '#{row}'"
        else  header.include? 'media'
          query = "SELECT
              Value
            FROM
              tabulardatawithstrings
            WHERE
              ReportName='#{report_name}' and TableName='#{table_name}'
              and RowName= '#{row}' and ColumnName= '#{variableNamesForColumns[header].gsub('Avg. ', '')}'"
        end

        results = sqlFile.execAndReturnFirstDouble(query)
        row_data_ip = OpenStudio.convert(results.to_f,
                      table[:source_units][column_counter],
                      table[:units][column_counter]).get
        row_data << row_data_ip.round(2)

        # para la media de todo el edificio
        medias[header] += row_data_ip*zoneVolume
      end

      table[:data] << row_data
    end

    row_data = ['Total edificio']
    table[:header].each do |header|
      next if header == ''
      row_data << (medias[header]/totalVolume).round(2)
    end
    table[:data] << row_data

    return table
  end

  # Tabla y gráfica con variables seleccionadas
  def self.tabla_variables_inspeccionadas(model, sqlFile, runner)

    # Valores de invierno y verano para una variable
    valoresZona = lambda do |sqlFile, variable|
      #, ZoneName, VariableName, month, variablevalue, variableUnits, reportingfrequency FROM
      respuesta = "SELECT SUM(VariableValue) FROM (#{ CTE_Query::ZONASHABITABLES })
    INNER JOIN ReportVariableDataDictionary rvdd
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time time USING (TimeIndex)
    WHERE rvdd.VariableName == '#{variable}'
    AND ReportingFrequency == 'Monthly' "

      queryInvierno = respuesta + "AND month IN (1,2,3,4,5,10,11,12)"
      queryVerano = respuesta + "AND month IN (6,7,8,9)"

      searchInvierno = sqlFile.execAndReturnFirstDouble(queryInvierno).get
      searchVerano = sqlFile.execAndReturnFirstDouble(queryVerano).get

      salida = { 'valInv' => OpenStudio.convert(searchInvierno, 'J', 'kWh').get.round(2),
                 'valVer' => OpenStudio.convert(searchVerano,   'J', 'kWh').get.round(2) }
      return salida
    end

    variables_inspeccionadas = [
      ['IntHeat', "Zone Total Internal Total Heating Energy"],
      ['IdealHeat', "Zone Ideal Loads Zone Total Heating Energy"],
      ['IdealCool', "Zone Ideal Loads Zone Total Cooling Energy"],
      #['InfGain', "Zone Infiltration Total Heat Gain Energy"], # ya no sale al combinar
      #['InfLoss', "Zone Infiltration Total Heat Loss Energy"], # ya no la tenemos al combinar
      ['VenCombGain', "Zone Combined Outdoor Air Total Heat Gain Energy"], # es horaria
      ['VenCombLoss', "Zone Combined Outdoor Air Total Heat Loss Energy"], # es horaria
      #['MecAdd', "Zone Mechanical Ventilation No Load Heat Addition Energy"],
      #['MecRem', "Zone Mechanical Ventilation No Load Heat Removal Energy"]
    ]

    data = variables_inspeccionadas.map do | labelx, variable |
      valores = valoresZona.call(sqlFile, variable)
      valorInvierno = valores['valInv']
      valorVerano = valores['valVer']
      [labelx, variable, valorInvierno, valorVerano]
    end

    labels = data.map{ |label, var, vi, vv| label }
    valoresi = data.map{ |label, var, valori, valorv| valori }
    valoresv = data.map{ |label, var, valori, valorv| valorv }
    ordenx = labels.map{ |l| [l+'i', l+'v'] }.flatten

    data.each{ | label, var, vi, vv | runner.registerInfo("- '#{ var }' (etiqueta '#{ label }'): Valores:: invierno #{ vi }, verano: #{ vv }")}
    runner.registerInfo("* Variables inspeccionadas")
    runner.registerInfo("+ Encabezado tabla: #{ labels }")

    # # hvac_load_prqofile_monthly_table[:chart_attributes] = { value_left: 'Cooling/Heating Load (kWh)',
    # # label_x: 'Month', value_right: 'Average Outdoor Air Dry Bulb (C)', sort_xaxis: month_order }
    medicion_general = {}
    medicion_general[:title] = 'Variables Inspeccionadas'
    medicion_general[:header] = [''] + labels
    medicion_general[:units] = [''] + ['kWh'] * data.size
    medicion_general[:data] = []
    medicion_general[:data] << ['invierno'] + valoresi
    medicion_general[:data] << ['verano'] + valoresv
    medicion_general[:chart_type] = 'vertical_stacked_bar'
    medicion_general[:chart_attributes] = { value: medicion_general[:title], label_x: 'Variable', sort_yaxis: [], sort_xaxis: ordenx }
    medicion_general[:chart] = []
    data.each do |label, variable, valori, valorv|
      medicion_general[:chart] << JSON.generate(label: 'calefaccion', label_x: label + 'i', value: valori, color: '#EF1C21')
      medicion_general[:chart] << JSON.generate(label: 'refrigeracion', label_x: label + 'v', value: valorv, color: '#0071BD')
    end

    return medicion_general
  end


  def self.tabla_demanda_por_componentes(model, sqlFile, runner, periodo)
    runner.registerInfo("__ inicidada demanda por componentes__#{periodo}\n")

    superficiehabitable =  CTE_Query.superficieHabitable(sqlFile).round(2)
    temporada = {'invierno' => 'calefaccion', 'verano'   => 'refrigeracion' }[periodo]
    color = {'invierno' => '#EF1C21', 'verano'   => '#008FF0' }[periodo]
    data = []

    # paredes aire ext.
    airWallHeat =   _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                    periodo, 'Wall', "AND ExtBoundCond = 0 AND SurfaceName NOT LIKE '%_PT%'") / superficiehabitable
    data << [airWallHeat, temporada, 'Paredes Exteriores']

    # paredes terreno
    groundWallHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                    periodo, 'Wall', "AND ExtBoundCond = -1") / superficiehabitable
    data << [groundWallHeat, temporada, 'Paredes Terreno']

    # paredes interiores
    indoorWallHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                        periodo, 'Wall', "AND ExtBoundCond NOT IN (0, -1)") / superficiehabitable
    data << [indoorWallHeat, temporada, 'Paredes Interiores']

    # XXX: no tenemos el balance de las particiones interiores entre zonas
    # cubiertas
    roofHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                        periodo, 'Roof', "AND ExtBoundCond = 0") / superficiehabitable
    data << [roofHeat, temporada, 'Cubiertas']

    # suelos aire ext
    airFloorHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                          periodo, 'Floor', "AND ExtBoundCond = 0") / superficiehabitable
    data << [airFloorHeat, temporada, 'Suelos Aire']

    # suelos terreno
    groundFloorHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                              periodo, 'Floor', "AND ExtBoundCond = -1") / superficiehabitable
    data << [groundFloorHeat, temporada, 'Suelos Terreno']

    # puentes termicos
    thermalBridges = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                    periodo, 'Wall', "AND SurfaceName LIKE '%_PT%'") / superficiehabitable
    data << [thermalBridges, temporada, 'Puentes Termicos']

    # #solar y transmisión ventanas
    windowRadiation = _componentValueForPeriod(sqlFile, 'Surface Window Transmitted Solar Radiation Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    data << [windowRadiation, temporada, 'Solar Ventanas']
    windowTransmissionGain = _componentValueForPeriod(sqlFile, 'Surface Window Heat Gain Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    windowTransmissionLoss = _componentValueForPeriod(sqlFile, 'Surface Window Heat Loss Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    windowTransmission = windowTransmissionGain - windowTransmissionLoss - windowRadiation
    data << [windowTransmission, temporada, 'Transmision Ventanas']
    # fuentes internas
    internalHeating = _zoneValueForPeriod(sqlFile, "Zone Total Internal Total Heating Energy", periodo) / superficiehabitable
    data << [internalHeating, temporada, 'Fuentes Internas']
    # ventilacion + infiltraciones
    ventGain = _zoneValueForPeriod(sqlFile, "Zone Combined Outdoor Air Sensible Heat Gain Energy", periodo) / superficiehabitable
    ventLoss = _zoneValueForPeriod(sqlFile, "Zone Combined Outdoor Air Sensible Heat Loss Energy", periodo) / superficiehabitable
    airHeatBalance = ventGain - ventLoss
    data << [airHeatBalance, temporada, 'Ventilación + Infiltraciones']

    # total
    total = data.map{ | value, label, label_x | value }.reduce(:+)
    data << [total, temporada, 'Total']

    orden_eje_x = []
    medicion_general = {}
    medicion_general[:title] = "Demandas por componentes en #{periodo} [kWh/m²]"
    medicion_general[:header] = [
      '', 'Paredes Exteriores', 'Paredes Terreno', 'Paredes Interiores',
      'Cubiertas', 'Suelos Aire', 'Suelos Terreno', 'Puentes Termicos',
      'Solar Ventanas', 'Transmisión Ventanas',
      'Fuentes Internas',
      'Ventilación + Infiltraciones', 'Total'
    ]
    medicion_general[:units] = [''] + ['kWh/m²'] * (medicion_general[:header].size - 1)
    medicion_general[:chart_type] = 'vertical_stacked_bar'
    medicion_general[:chart_attributes] = {
      value: medicion_general[:title],
      label_x: 'Componente',
      sort_yaxis: [],
      sort_xaxis: orden_eje_x
    }
    medicion_general[:chart] = []

    valores_fila = [periodo] #la fila de la tabla en cuestión
    data.each do | value, label, label_x |
      medicion_general[:chart] << JSON.generate(
        label: label,
        label_x: label_x,
        value: value,
        color: color
      )
      valores_fila << value.round(2)
      orden_eje_x << label_x
    end
    medicion_general[:data] = [] << valores_fila

    return medicion_general
  end

  def self._componentValueForPeriod(sqlFile, variableName, periodo, className, extraCond, unitsSource='J', unitsTarget='kWh')
    # XXX: Esto no funciona porque no se limitan las superficies a las que forman parte de la envolvente sino que son todas las
    # XXX: de las zonas habitables
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    supHab AS (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES })
SELECT
    SUM(VariableValue)
FROM
    supHab
    INNER JOIN ReportVariableDataDictionary AS rvdd ON supHab.SurfaceName = rvdd.KeyValue
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time AS time USING (TimeIndex)
WHERE
    VariableName = '#{ variableName }'
    AND ReportingFrequency = 'Monthly'
    AND ClassName = '#{ className }'
    AND Month IN #{ meses }
    #{ extraCond }
"

    return OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, unitsSource, unitsTarget).get
  end

  def self._zoneValueForPeriod(sqlFile, variableName, periodo, unitsSource='J', unitsTarget='kWh')
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    zonashabitables AS (#{ CTE_Query::ZONASHABITABLES })
SELECT
    SUM(VariableValue)
FROM
    zonashabitables
    INNER JOIN ReportVariableDataDictionary
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time USING (TimeIndex)
WHERE
    VariableName = '#{ variableName }'
    AND ReportingFrequency = 'Monthly'
    AND KeyValue = ZoneName
    AND Month IN #{ meses }
"
    return OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, unitsSource, unitsTarget).get
  end

end
