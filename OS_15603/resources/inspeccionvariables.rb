# coding: utf-8
require_relative "os_lib_reporting_SI"

module Variables_inspeccion

  def self.valoresZona(sqlFile, variable)
    # esto parece una query que hay en ctegeometria
    respuesta = "SELECT SUM(VariableValue) FROM "#, ZoneName, VariableName, month, variablevalue, variableUnits, reportingfrequency FROM
    respuesta << "(#{zonashabitablesquery})
    INNER JOIN ReportVariableDataDictionary rvdd
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time time USING (TimeIndex)
    WHERE rvdd.VariableName == '#{variable}'
    AND ReportingFrequency == 'Monthly' "

    queryInvierno = respuesta + "AND month IN (1,2,3,4,5,10,11,12)"
    queryVerano = respuesta + "AND month IN (6,7,8,9)"

    searchInvierno = sqlFile.execAndReturnFirstDouble(queryInvierno)
    searchVerano = sqlFile.execAndReturnFirstDouble(queryVerano)

    salida = {'valInv' => OpenStudio.convert(searchInvierno.get, 'J', 'kWh').get,
              'valVer' => OpenStudio.convert(searchVerano.get,   'J', 'kWh').get   }
    return salida
  end

  def self.variables_inspeccionadas(model, sqlFile, runner)
    log = 'log_variablesInspeccionadas'
    msg(log, "__ inicidada otras variables inspeccionadas__\n")

    variables_inspeccionadas = [
        ["Zone Total Internal Total Heating Energy", 'IntHeat'],
        ["Zone Ideal Loads Zone Total Heating Energy", 'IdealHeat'],
        ["Zone Ideal Loads Zone Total Cooling Energy", 'IdealCool'],
        ["Zone Infiltration Total Heat Gain Energy", 'InfGain'],
        ["Zone Infiltration Total Heat Loss Energy", 'InfLoss'],
        ["Zone Mechanical Ventilation No Load Heat Addition Energy", 'MecAdd'],
        ["Zone Mechanical Ventilation No Load Heat Removal Energy", 'MecRem']
    ]

    medicion_general = {}
    medicion_general[:title] = 'Variables Inspeccionadas'
    #medicion_general[:header] = ['', 'PEi', 'PEv', 'CUi', 'CUv', 'SUi', 'SUv', 'PTi', 'PTv', 'SVi',
    #            'SVv', 'TVi', 'TVv', 'FIi', 'FIv', 'VIi', 'VIv', 'TOTi', 'TOTv']
    medicion_general[:units] = [] #vacio porque son distintas
    medicion_general[:data] = []
    medicion_general[:chart_type] = 'vertical_stacked_bar'
    #medicion_general[:chart_attributes] = { value: medicion_general[:title], label_x: 'Componente', sort_yaxis: [], sort_xaxis: orden_eje_x }
    medicion_general[:chart] = []

    header = []
    ordenX = []
    invierno = []
    verano = []
    msg(log, "_ se recorren las variables\n")
    variables_inspeccionadas.each do | variable |
      msg(log, ".. variable: #{variable[0]}\n")
      valores = valoresZona(sqlFile, variable[0])
      msg(log, "     valores #{valores}\n")
      valorInvierno = valores['valInv']
      valorVerano = valores['valVer']
      label = variable[1]
      msg(log, " #{label}: inv #{valorInvierno}, ver: #{valorVerano}\n")
      medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:label+'i', value: valorInvierno.to_f, color:'#EF1C21')
      medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:label+'v', value: valorVerano.to_f, color:'#0071BD')
      header << label + '[kWh]'
      # header << label + '_v'
      ordenX << label + 'i'
      ordenX << label + 'v'
      invierno << valorInvierno.round
      verano << valorVerano.round
      msg(log, "\n     header #{header}\n")

    end

    msg(log, "Header: #{header}\n")
    medicion_general[:header] = [''] + header
    medicion_general[:chart_attributes] = {value: medicion_general[:title], label_x: 'Variable', sort_yaxis: [], sort_xaxis: ordenX}
    medicion_general[:data] << ['invierno'] + invierno
    medicion_general[:data] << ['verano'] + verano

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
    # msg(log, "__ cargando valores de muros exteriores__\n")
    # energiaMuros = flowMurosExteriores(sqlFile)
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'PEi', value: energiaMuros[0], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'PEv', value: energiaMuros[1], color:'#0071BD')
    # msg(log, "#{energiaMuros}\n")
    # msg(log, "__ cargando valores de cubiertas__\n")
    # energiaCubiertas = flowCubiertas(sqlFile)
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'CUi', value: energiaCubiertas[0], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'CUv', value: energiaCubiertas[1], color:'#0071BD')
    # msg(log, "#{energiaCubiertas}\n")
    # msg(log, "__ cargando valores de suelos terreno__\n")
    # energiaSuelosTerreno = flowSuelosTerreno(sqlFile)
    # medicion_general[:chart] << JSON.generate(label:'calefaccion', label_x:'STi', value: energiaSuelosTerreno[0], color:'#EF1C21')
    # medicion_general[:chart] << JSON.generate(label:'refrigeracion', label_x:'Sv', value: energiaSuelosTerreno[1], color:'#0071BD')
    # msg(log, "#{energiaSuelosTerreno}\n")
    # msg(log, "__ cargando valores de ventanas__\n")
    # energiaVentanas = flowVentanas(sqlFile)
    # msg(log, "#{energiaVentanas}\n")
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

  def self.zonashabitablesquery
    zonashabitablesquery =  "SELECT zones.ZoneIndex, zones.ZoneName  FROM Zones zones "
    zonashabitablesquery << "LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex) "
    zonashabitablesquery << "LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex) "
    zonashabitablesquery << "WHERE zl.Name != 'CTE_NOHABITA' AND zl.Name != 'CTE_N' "
    zonashabitablesquery
  end


  def self.msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end
end
