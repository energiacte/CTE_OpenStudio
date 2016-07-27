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


  def self.tabla_demanda_por_componentes(model, sqlFile, runner, periodo)
    runner.registerInfo("__ inicidada demanda por componentes__#{periodo}\n")

    superficiehabitable =  CTE_Query.superficieHabitable(sqlFile).round(2)
    temporada = {'invierno' => 'calefaccion', 'verano'   => 'refrigeracion' }[periodo]
    color = {'invierno' => '#EF1C21', 'verano'   => '#008FF0' }[periodo]

    data = []
    # paredes aire ext.
    airWallHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy', periodo, 'Wall', 0) / superficiehabitable
    data << [airWallHeat, temporada, 'Paredes Exteriores']
    # paredes terreno
    groundWallHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy', periodo, 'Wall', -1) / superficiehabitable
    data << [groundWallHeat, temporada, 'Paredes Terreno']
    # paredes interiores
    # XXX: no tenemos el balance de las particiones interiores entre zonas
    # cubiertas
    roofHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy', periodo, 'Roof', 0) / superficiehabitable
    data << [roofHeat, temporada, 'Cubiertas']
    # suelos aire ext
    airFloorHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy', periodo, 'Floor', 0) / superficiehabitable
    data << [airFloorHeat, temporada, 'Suelos Aire']
    # suelos terreno
    groundFloorHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy', periodo, 'Floor', -1) / superficiehabitable
    data << [groundFloorHeat, temporada, 'Suelos Terreno']
    # puentes termicos
    #valores_fila << 'sin calcular'
    # #solar y transmisión ventanas
    windowRadiation = _componentValueForPeriod(sqlFile, 'Surface Window Transmitted Solar Radiation Energy', periodo, 'Window', 0) / superficiehabitable
    data << [windowRadiation, temporada, 'Solar Ventanas']
    windowTransmissionGain = _componentValueForPeriod(sqlFile, 'Surface Window Heat Gain Energy', periodo, 'Window', 0) / superficiehabitable
    windowTransmissionLoss = _componentValueForPeriod(sqlFile, 'Surface Window Heat Loss Energy', periodo, 'Window', 0) / superficiehabitable
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
      '', 'Paredes Exteriores', 'Paredes Terreno',
      'Cubiertas', 'Suelos Aire', 'Suelos Terreno',
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

  def self._componentValueForPeriod(sqlFile, variableName, periodo, className, extBoundCond, unitsSource='J', unitsTarget='kWh')
    # XXX: Esto no funciona porque no se limitan las superficies a las que forman parte de la envolvente sino que son todas las
    # XXX: de las zonas habitables
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    superficieshabitables AS (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES })
SELECT
    SUM(VariableValue)
FROM
    superficieshabitables
    INNER JOIN ReportVariableDataDictionary
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time AS time USING (TimeIndex)
WHERE
    VariableName = '#{ variableName }'
    AND ReportingFrequency = 'Hourly'
    AND SurfaceName = KeyValue
    AND ClassName = '#{ className }'
    AND ExtBoundCond = #{ extBoundCond }
    AND Month IN #{ meses }
"
    return OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, unitsSource, unitsTarget).get
  end

  def self._zoneValueForPeriod(sqlFile, variableName, periodo, unitsSource='J', unitsTarget='kWh')
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    zonashabitables AS (#{ CTE_Query::ZONASHABITABLES }),
    demandatime AS (
        SELECT
           TimeIndex, Month, Day, Hour
        FROM
           ReportVariableDataDictionary
           INNER JOIN  ReportVariableData USING (ReportVariableDataDictionaryIndex)
           INNER JOIN Time USING (TimeIndex)
        WHERE
           VariableName = 'Zone Thermostat Cooling Setpoint Temperature'
           OR VariableName = 'Zone Thermostat Heating Setpoint Temperature'
           AND ReportingFrequency = 'Hourly'
           AND VariableValue < 95
           AND VariableValue > -45)
SELECT
    SUM(VariableValue)
FROM
    zonashabitables
    INNER JOIN ReportVariableDataDictionary
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN demandatime USING (TimeIndex)
WHERE
    VariableName = '#{ variableName }'
    AND ReportingFrequency = 'Hourly'
    AND KeyValue = ZoneName
    AND Month IN #{ meses }
"
    return OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, unitsSource, unitsTarget).get
  end

end
