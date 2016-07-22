# coding: utf-8
require "openstudio"
require_relative "cte_query"

module Variables_inspeccion

  def self.valoresZona(sqlFile, variable)
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

  def self.variables_inspeccionadas(model, sqlFile, runner)

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
      valores = valoresZona(sqlFile, variable)
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

    # orden_eje_x = %w(PEi PEv CUi CUv STi STv HGi HLi TSi TVi HGv HLv TSv TVv PTi PTv SVi SVv TVi TVv FIi FIv VIi VIv TOTi TOTv)
    # # end use colors by index
    # end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD',
    # '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

   # # hvac_load_prqofile_monthly_table[:chart_attributes] = { value_left: 'Cooling/Heating Load (kWh)',
   # # label_x: 'Month', value_right: 'Average Outdoor Air Dry Bulb (C)', sort_xaxis: month_order }
    # valoresPrueba = [-10.1, 0, -3.4, 0, -3.1, 0, -3.6, 0, 17.1, 0 , -9.6, 0, 22.8, 0, -21.2, 0, -11.1, 0]
    # valoresPrueba1 = [ -0, 2.9, 0, 2.0, 0, -1.4, 0, 1.2, 0 , 11.3, 0, 2.9, 0, 13.2, 0, -12.6, 0, 19.5]
    # medicion_general[:data] << ['invierno', -10.1, 0, -3.4, 0, -3.1, 0, -3.6, 0, 17.1, 0 , -9.6, 0, 22.8, 0, -21.2, 0, -11.1, 0]
    # medicion_general[:data] << ['verano', -0, 2.9, 0, 2.0, 0, -1.4, 0, 1.2, 0 , 11.3, 0, 2.9, 0, 13.2, 0, -12.6, 0, 19.5]
    # runner.registerInfo("__ cargando valores de muros exteriores__\n")
    # energiaMuros = flowMurosExteriores(sqlFile)
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'PEi', value: energiaMuros[0], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'PEv', value: energiaMuros[1], color:'#0071BD')
    # runner.registerInfo("#{energiaMuros}\n")
    # runner.registerInfo("__ cargando valores de cubiertas__\n")
    # energiaCubiertas = flowCubiertas(sqlFile)
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'CUi', value: energiaCubiertas[0], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'CUv', value: energiaCubiertas[1], color:'#0071BD')
    # runner.registerInfo("#{energiaCubiertas}\n")
    # runner.registerInfo("__ cargando valores de suelos terreno__\n")
    # energiaSuelosTerreno = flowSuelosTerreno(sqlFile)
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'STi', value: energiaSuelosTerreno[0], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'Sv', value: energiaSuelosTerreno[1], color:'#0071BD')
    # runner.registerInfo("#{energiaSuelosTerreno}\n")
    # runner.registerInfo("__ cargando valores de ventanas__\n")
    # energiaVentanas = flowVentanas(sqlFile)
    # runner.registerInfo("#{energiaVentanas}\n")
    # solarVentanasInvierno = energiaVentanas['TSi']
    # solarVentanasVerano = energiaVentanas['TSv']
    # transmisionVentanasInvierno = energiaVentanas['HGi'] - energiaVentanas['HLi'] -energiaVentanas['TSi']
    # transmisionVentanaVerano = energiaVentanas['HGv'] - energiaVentanas['HLv'] -energiaVentanas['TSv']
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'HGi', value: energiaVentanas['HGi'], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'HLi', value: energiaVentanas['HLi'], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'TSi', value: energiaVentanas['TSi'], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'TVi', value: transmisionVentanasInvierno, color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'HGv', value: energiaVentanas['HGv'], color:'#0071BD')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'HLv', value: energiaVentanas['HLv'], color:'#0071BD')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'TSv', value: energiaVentanas['TSv'], color:'#0071BD')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'TVv', value: transmisionVentanaVerano, color:'#0071BD')
    # (0..11).each do | orden |
        # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:orden_eje_x[orden], value: valoresPrueba[orden], color:'#EF1C21')
        # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:orden_eje_x[orden], value: valoresPrueba1[orden], color:'#0071BD')
    # end

    return medicion_general
  end

end
