# coding: utf-8
require "openstudio"
require_relative "cte_query"

module Variables_inspeccion

  def self.variables_inspeccionadas(model, sqlFile, runner)

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

end
