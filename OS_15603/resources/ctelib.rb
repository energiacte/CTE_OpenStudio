# coding: utf-8

require "openstudio"
require_relative "cte_query"

module CTE_lib
  module Tables
    #======== Elementos generales  ============
    # variablesdisponiblesquery = "SELECT DISTINCT VariableName, ReportingFrequency FROM ReportVariableDataDictionary "

    #======== Tabla general de mediciones =====
    def self.CTE_tabla_general_de_mediciones(model, sqlFile, runner)
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

    def self.CTE_tabla_de_energias(model, sqlFile, runner)
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
      contenedor_general = {}
      contenedor_general[:title] = "Mediciones elementos de la envolvente"
      contenedor_general[:header] = ['Construcción', 'Superficie', 'U']
      contenedor_general[:units] = ['', 'm²', 'W/m²K']
      contenedor_general[:data] = []

      indicesquery = "SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
                    UNION
                    SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES })"
      indices  = sqlFile.execAndReturnVectorOfString(indicesquery).get

      indices.each do | indiceconstruccion |
        query = "SELECT SUM(Area) FROM
                   (SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
                    UNION ALL
                    SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES }))
               WHERE ConstructionIndex == #{ indiceconstruccion }"
        area = sqlFile.execAndReturnFirstDouble(query).get
        nombre = sqlFile.execAndReturnFirstString("SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
        uvalue = sqlFile.execAndReturnFirstDouble("SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
        contenedor_general[:data] << ["#{ nombre }".encode("UTF-8", invalid: :replace, undef: :replace), area.round(2), uvalue.round(3)]
      end

      return contenedor_general
    end





    def self.flowMurosExteriores(sqlFile)
      flowMurosExterioresQuery = "SELECT * FROM (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES }) AS surf
INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
INNER JOIN Time time USING (TimeIndex)
WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy'
AND surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0 "

      flowMurosExterioresInviernoQuery = "SELECT SUM(VariableValue) FROM (#{flowMurosExterioresQuery}) WHERE month IN (1,2,3,4,5,10,11,12)"
      flowMurosExterioresInviernoSearch = sqlFile.execAndReturnFirstDouble(flowMurosExterioresInviernoQuery)
      energianetaInvierno = OpenStudio.convert(flowMurosExterioresInviernoSearch.get, 'J', 'kWh').get

      flowMurosExterioresVeranoQuery = "SELECT SUM(variableValue) FROM (#{flowMurosExterioresQuery}) WHERE month IN (6,7,8,9)"
      flowMurosExterioresVeranoSearch = sqlFile.execAndReturnFirstDouble(flowMurosExterioresVeranoQuery)
      energianetaVerano = OpenStudio.convert(flowMurosExterioresVeranoSearch.get, 'J', 'kWh').get

      return [energianetaInvierno, energianetaVerano]
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

    def self.timeindexquery
      return "SELECT TimeIndex, Month, Day, Hour FROM ReportVariableDataDictionary
INNER JOIN  ReportVariableData USING (ReportVariableDataDictionaryIndex)
INNER JOIN Time USING (TimeIndex)
WHERE (VariableName = 'Zone Thermostat Cooling Setpoint Temperature' OR VariableName = 'Zone Thermostat Heating Setpoint Temperature')
AND ReportingFrequency == 'Hourly'
AND VariableValue < 95
AND VariableValue > -45 "
    end

    def self.valoresZonas(sqlFile, variable, runner)
      runner.registerInfo("\n.. variable: '#{variable}'\n")
      #, ZoneName, VariableName, month, VariableValue, variableUnits, reportingfrequency FROM
      respuesta = "SELECT SUM(VariableValue) FROM (#{ CTE_Query::ZONASHABITABLES })
    INNER JOIN ReportVariableDataDictionary rvdd
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN (#{timeindexquery}) USING (TimeIndex)
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
      # end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

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
      temporada = {'invierno' => {'ppal' => 'calefaccion',   'segun' => 'calef_par'},
                   'verano'   => {'ppal' => 'refrigeracion', 'segun' => 'refri_par'} }
      colores = {'invierno' => {'ppal' => '#EF1C21', 'segun' => '#F78D90'},
                 'verano'   => {'ppal' => '#008FF0','segun' => '#7FC7F7'} }

      registraValores = lambda do | data, label, tipo, signo |
        medicion_general[:chart] << JSON.generate(label:temporada[periodo][tipo],
                                                  label_x: label, value: signo * data[indice[periodo]]/superficiehabitable, color: colores[periodo][tipo])
        if tipo == 'ppal'
          valores_fila << (data[indice[periodo]]/superficiehabitable).round
          valores_data << data[indice[periodo]]/superficiehabitable
        end
        orden_eje_x << label
        runner.registerInfo("#{signo * data[indice[periodo]]/superficiehabitable}\n")
      end

      # paredes exteriores
      registraValores.call(flowMurosExteriores(sqlFile), 'Paredes Exteriores', 'ppal', 1)
      # cubiertas
      registraValores.call(flowCubiertas(sqlFile), 'Cubiertas', 'ppal', 1)
      # suelos terreno
      registraValores.call(flowSuelosTerreno(sqlFile), 'SuelosT', 'ppal', 1)
      # puentes termicos
      valores_fila << 'sin calcular'
      #solar y transmisión ventanas
      energiaVentanas = flowVentanas(sqlFile)
      runner.registerInfo("#{energiaVentanas}\n")
      # label = ['wHeGa', 'wHeLo', 'wSoVe', 'wTrVe']
      registraValores.call([energiaVentanas['TSi'], energiaVentanas['TSv']], 'Solar Ventanas', 'ppal', 1)

      transmisionVentanasInvierno = energiaVentanas['HGi'] - energiaVentanas['HLi'] -energiaVentanas['TSi']
      transmisionVentanaVerano = energiaVentanas['HGv'] - energiaVentanas['HLv'] -energiaVentanas['TSv']
      registraValores.call([transmisionVentanasInvierno, transmisionVentanaVerano], 'Transmision Ventanas', 'ppal', 1)

      # suelos terreno
      registraValores.call(valoresZonas(sqlFile, "Zone Total Internal Total Heating Energy", runner), 'Fuentes Internas', 'ppal', 1)

      # infiltracion
      heatGain = valoresZonas(sqlFile, "Zone Infiltration Total Heat Gain Energy", runner)
      heatLoss = valoresZonas(sqlFile, "Zone Infiltration Total Heat Loss Energy", runner)
      # registraValores.call(heatGain, 'InfGain', 'segun', 1)
      # registraValores.call(heatLoss, 'InfLoss', 'segun', -1)
      registraValores.call([heatGain[0] - heatLoss[0], heatGain[1] - heatLoss[1]], 'Infiltación', 'ppal', 1)

      # ventilacion
      ventGain = valoresZonas(sqlFile, "Zone Combined Outdoor Air Total Heat Gain Energy", runner)
      ventLoss = valoresZonas(sqlFile, "Zone Combined Outdoor Air Total Heat Loss Energy", runner)
      # registraValores.call(ventGain, 'VenGain', 'segun', 1)
      # registraValores.call(ventLoss, 'VenLoss', 'segun', -1)
      registraValores.call([ventGain[0]-ventLoss[0], ventGain[1]-ventLoss[1]], 'Ventilación', 'ppal', 1)

      #total
      total = 0
      valores_data.each do | valor |
        if valor.to_f == valor
          total += valor
        end
      end
      total = total*superficiehabitable

      registraValores.call([total, total], 'Total', 'ppal', 1)

      medicion_general[:data] << valores_fila
      return medicion_general

    end
  end
end
