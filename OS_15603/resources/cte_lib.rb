# coding: utf-8

require "openstudio"
require_relative "cte_query"

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

  def self.tabla_de_energias(model, sqlFile, runner)
    # Basada en una tabla del report SI
    energianeta = OpenStudio.convert(sqlFile.netSiteEnergy.get, 'GJ', 'kWh').get
    superficiehabitable = CTE_Query.superficieHabitable(sqlFile)
    intensidadEnergetica = superficiehabitable != 0 ? (energianeta / superficiehabitable) : 0

    runner.registerValue('Energia Neta (Net Site Energy)', energianeta, 'kWh')
    runner.registerValue('Intensidad energética (EUI)', intensidadEnergetica, 'kWh/m^2')

    general_table = {}
    general_table[:title] = 'Energía según CTE'
    general_table[:header] =%w(informacion valor unidades)
    general_table[:units] = []
    general_table[:data] = []
    general_table[:data] << ['Energia Neta (Net Site Energy)', energianeta.round(2), 'kWh']
    general_table[:data] << ['Energía por superficie habitable', intensidadEnergetica.round(2), 'kWh/m^2']

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
      data << ["#{ nombre }".encode("UTF-8", invalid: :replace, undef: :replace), area, uvalue]
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




  def self.flowMurosExteriores(sqlFile, periodo)
    flowMurosExterioresQuery = "SELECT * FROM (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
INNER JOIN Time time USING (TimeIndex)
WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy'
AND surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0 "
    if periodo == 'invierno'
      query = "SELECT SUM(VariableValue) FROM (#{flowMurosExterioresQuery}) WHERE month IN (1,2,3,4,5,10,11,12)"
    else

      query = "SELECT SUM(variableValue) FROM (#{flowMurosExterioresQuery}) WHERE month IN (6,7,8,9)"
    end
    energianeta = OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, 'J', 'kWh').get
    return energianeta
  end

  def self.flowCubiertas(sqlFile)
    flowCubiertasQuery = "SELECT * FROM (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
INNER JOIN Time time USING (TimeIndex)
WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy'
AND surf.ClassName == 'Roof' AND surf.ExtBoundCond == 0 "

    flowCubiertasInviernoQuery = "SELECT SUM(VariableValue) FROM (#{flowCubiertasQuery}) WHERE month IN (1,2,3,4,5,10,11,12)"
    flowCubiertasInviernoSearch = sqlFile.execAndReturnFirstDouble(flowCubiertasInviernoQuery)
    energianetaInvierno = OpenStudio.convert(flowCubiertasInviernoSearch.get, 'J', 'kWh').get

    flowCubiertasVeranoQuery = "SELECT SUM(variableValue) FROM (#{flowCubiertasQuery}) WHERE month IN (6,7,8,9)"
    flowCubiertasVeranoSearch = sqlFile.execAndReturnFirstDouble(flowCubiertasVeranoQuery)
    energianetaVerano = OpenStudio.convert(flowCubiertasVeranoSearch.get, 'J', 'kWh').get

    return [energianetaInvierno, energianetaVerano]
  end

  def self.flowSuelosTerreno(sqlFile)
    flowSuelosTerrenoQuery = "SELECT * FROM (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
INNER JOIN Time time USING (TimeIndex)
WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy'
AND surf.ClassName == 'Floor' AND surf.ExtBoundCond == -1 "

    flowSuelosTerrenoInviernoQuery = "SELECT SUM(VariableValue) FROM (#{flowSuelosTerrenoQuery}) WHERE month IN (1,2,3,4,5,10,11,12)"
    flowSuelosTerrenoInviernoSearch = sqlFile.execAndReturnFirstDouble(flowSuelosTerrenoInviernoQuery)
    energianetaInvierno = OpenStudio.convert(flowSuelosTerrenoInviernoSearch.get, 'J', 'kWh').get

    flowSuelosTerrenoVeranoQuery = "SELECT SUM(variableValue) FROM (#{flowSuelosTerrenoQuery}) WHERE month IN (6,7,8,9)"
    flowSuelosTerrenoVeranoSearch = sqlFile.execAndReturnFirstDouble(flowSuelosTerrenoVeranoQuery)
    energianetaVerano = OpenStudio.convert(flowSuelosTerrenoVeranoSearch.get, 'J', 'kWh').get

    return [energianetaInvierno, energianetaVerano]
  end

  def self.flowVentanas(sqlFile)
    variable =   {  'heat gain' => 'Surface Window Heat Gain Energy',
                    'heat loss' => 'Surface Window Heat Loss Energy',
                    'transmitted solar' => 'Surface Window Transmitted Solar Radiation Energy'}

    flowVentanasInvierno = lambda do | var | "SELECT SUM(variableValue) FROM
    (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
    INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time time USING (TimeIndex)
    WHERE surf.VariableName == '#{variable[var]}'
    AND surf.ClassName == 'Window'
    AND month IN (1,2,3,4,5,10,11,12)"
    end

    flowVentanasVerano = lambda do | var | "SELECT SUM(variableValue) FROM
    (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
    INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time time USING (TimeIndex)
    WHERE surf.VariableName == '#{variable[var]}'
    AND surf.ClassName == 'Window'
    AND month IN (6,7,8,9)"
    end

    heatGainInviernoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasInvierno.call('heat gain'))
    heatGainInvierno = OpenStudio.convert(heatGainInviernoSearch.get, 'J', 'kWh').get

    heatGainVeranoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasVerano.call('heat gain'))
    heatGainVerano = OpenStudio.convert(heatGainVeranoSearch.get, 'J', 'kWh').get

    heatLossInviernoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasInvierno.call('heat loss'))
    heatLossInvierno = OpenStudio.convert(heatLossInviernoSearch.get, 'J', 'kWh').get

    heatLossVeranoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasVerano.call('heat loss'))
    heatLossVerano = OpenStudio.convert(heatLossVeranoSearch.get, 'J', 'kWh').get

    transmittedInviernoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasInvierno.call('transmitted solar'))
    transmittedInvierno = OpenStudio.convert(transmittedInviernoSearch.get, 'J', 'kWh').get

    transmittedVeranoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasVerano.call('transmitted solar'))
    transmittedVerano = OpenStudio.convert(transmittedVeranoSearch.get, 'J', 'kWh').get

    return {'HGi' => heatGainInvierno, 'HGv' => heatGainVerano,
            'HLi' => heatLossInvierno, 'HLv' => heatLossVerano,
            'TSi' => transmittedInvierno, 'TSv' => transmittedVerano,}
  end

  def self.valoresZonas(sqlFile, variable, runner)
    runner.registerInfo("\n.. variable: '#{variable}'\n")
    #, ZoneName, VariableName, month, VariableValue, variableUnits, reportingfrequency FROM
    respuesta = "SELECT SUM(VariableValue) FROM (#{ CTE_Query::ZONASHABITABLES })
    INNER JOIN ReportVariableDataDictionary rvdd
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN (SELECT TimeIndex, Month, Day, Hour FROM ReportVariableDataDictionary
                INNER JOIN  ReportVariableData USING (ReportVariableDataDictionaryIndex)
                INNER JOIN Time USING (TimeIndex)
                WHERE (VariableName = 'Zone Thermostat Cooling Setpoint Temperature' OR VariableName = 'Zone Thermostat Heating Setpoint Temperature')
                AND ReportingFrequency == 'Hourly'
                AND VariableValue < 95
                AND VariableValue > -45) USING (TimeIndex)
    WHERE rvdd.variableName == '#{variable}' "

    queryInvierno = respuesta + "AND month IN (1,2,3,4,5,10,11,12)"
    queryVerano = respuesta + "AND month IN (6,7,8,9)"

    searchInvierno = sqlFile.execAndReturnFirstDouble(queryInvierno)
    searchVerano = sqlFile.execAndReturnFirstDouble(queryVerano)

    salida = {'valInv' => OpenStudio.convert(searchInvierno.get, 'J', 'kWh').get,
              'valVer' => OpenStudio.convert(searchVerano.get,   'J', 'kWh').get   }
    runner.registerInfo("     salida #{salida}\n")
    return [salida['valInv'], salida['valVer']]
  end

  def self.tabla_demanda_por_componentes_invierno(model, sqlFile, runner)
    return demanda_por_componentes(model, sqlFile, runner, 'invierno')
  end

  def self.tabla_demanda_por_componentes_verano(model, sqlFile, runner)
    return demanda_por_componentes(model, sqlFile, runner, 'verano')
  end

  def self.demanda_por_componentes(model, sqlFile, runner, periodo)
    runner.registerInfo("__ inicidada demanda por componentes__#{periodo}\n")

    superficiehabitable =  CTE_Query.superficieHabitable(sqlFile).round(2)

    orden_eje_x = []
    medicion_general = {}
    medicion_general[:title] = "Demandas por componentes en #{periodo}"
    medicion_general[:header] = ['', 'Paredes E', 'Cubiertas', 'SuelosT', 'PuentesT','SolarVen', 'TransVen', 'FuentesI', 'Infiltr', 'Ventil', 'Total']

    medicion_general[:units] = [] #vacio porque son distintas
    medicion_general[:data] = []
    medicion_general[:chart_type] = 'vertical_stacked_bar'
    medicion_general[:chart_attributes] = { value: medicion_general[:title], label_x: 'Componente', sort_yaxis: [], sort_xaxis: orden_eje_x }
    medicion_general[:chart] = []

    valores_fila = [periodo] #la fila de la tabla en cuestión
    valores_data = []
    indice = {'invierno' => 0, 'verano' => 1}
    temporada = {'invierno' => 'calefaccion',
                 'verano'   => 'refrigeracion' }
    colores = {'invierno' => '#EF1C21',
               'verano'   => '#008FF0' }

    registraValores = lambda do | value, label, label_x |
      medicion_general[:chart] << JSON.generate(label: label, label_x: label_x, value: value, color: colores[periodo])
      valores_fila << value.round
      valores_data << value
      orden_eje_x << label_x
    end

    # paredes exteriores
    value = flowMurosExteriores(sqlFile, periodo) / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Paredes Exteriores')
    # cubiertas
    values = flowCubiertas(sqlFile)
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Cubiertas')
    # suelos terreno
    values = flowSuelosTerreno(sqlFile)
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'SuelosT')
    # puentes termicos
    valores_fila << 'sin calcular'
    #solar y transmisión ventanas
    energiaVentanas = flowVentanas(sqlFile)
    values = [energiaVentanas['TSi'], energiaVentanas['TSv']]
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Solar Ventanas')

    transmisionVentanasInvierno = energiaVentanas['HGi'] - energiaVentanas['HLi'] - energiaVentanas['TSi']
    transmisionVentanaVerano = energiaVentanas['HGv'] - energiaVentanas['HLv'] - energiaVentanas['TSv']
    values = [transmisionVentanasInvierno, transmisionVentanaVerano]
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Transmision Ventanas')

    # suelos terreno
    values = valoresZonas(sqlFile, "Zone Total Internal Total Heating Energy", runner)
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Fuentes Internas')

    # infiltracion
    heatGain = valoresZonas(sqlFile, "Zone Infiltration Total Heat Gain Energy", runner)
    heatLoss = valoresZonas(sqlFile, "Zone Infiltration Total Heat Loss Energy", runner)
    values = [heatGain[0] - heatLoss[0], heatGain[1] - heatLoss[1]]
    registraValores.call(values[indice[periodo]] / superficiehabitable, temporada[periodo], 'Infiltación')

    # ventilacion + infiltraciones
    ventGain = valoresZonas(sqlFile, "Zone Combined Outdoor Air Total Heat Gain Energy", runner)
    ventLoss = valoresZonas(sqlFile, "Zone Combined Outdoor Air Total Heat Loss Energy", runner)
    values = [ventGain[0] - ventLoss[0], ventGain[1] - ventLoss[1]]
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Ventilación')

    #total
    total = superficieHabitable * valores_data.reduce(:+)
    values = [total, total]
    value = values[indice[periodo]] / superficiehabitable
    registraValores.call(value, temporada[periodo], 'Total')

    medicion_general[:data] << valores_fila
    return medicion_general

  end
end
