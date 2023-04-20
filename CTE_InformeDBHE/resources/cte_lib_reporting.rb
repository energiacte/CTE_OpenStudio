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

# Plantilla de reportes basada en la distribuida con OpenStudio

require 'json'
require_relative "cte_query"

module CTELib_Reporting
  # setup - get model, sql, and setup web assets path
  def self.setup(runner)
    results = {}

    # get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # get the last idf
    # workspace = runner.lastEnergyPlusWorkspace
    # if workspace.empty?
    #   runner.registerError('Cannot find last idf file.')
    #   return false
    # end
    # workspace = workspace.get

    # get the last sql file
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    # populate hash to pass to measure
    results[:model] = model
    # results[:workspace] = workspace
    results[:sqlFile] = sqlFile
    results[:web_asset_path] = OpenStudio.getSharedResourcesPath / OpenStudio::Path.new('web_assets')

    return results
  end

  def self.ann_env_pd(sqlFile)
    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      env_type = sqlFile.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
          ann_env_pd = env_pd
        end
      end
    end

    return ann_env_pd
  end

  ### -----------------------------------------------------------------------------------
  ### Métodos propios -------------------------------------------------------------------
  ### -----------------------------------------------------------------------------------
  def self.translate(key)
    # Traducción de diversos elementos de la interfaz
    { 'Heating' => 'Calefacción',
      'Cooling' => 'Refrigeración',
      'Interior Lighting' => 'Iluminación interior',
      'Exterior Lighting' => 'Iluminación exterior',
      'Interior Equipment' => 'Equipos (interiores)',
      'Exterior Equipment' => 'Equipos (exteriores)',
      'Fans' => 'Ventiladores',
      'Pumps' => 'Bombas',
      'Heat Rejection' => 'Disipación de calor',
      'Humidification' => 'Humidificación',
      'Heat Recovery' => 'Recuperación de calor',
      'Water Systems' => 'Sistemas de agua',
      'Refrigeration' => 'Equipos frigoríficos',
      'Generators' => 'Equipos de generación',
      'Electricity' => 'Electricidad',
      'Natural Gas' => 'Gas Natural',
      'Additional Fuel' => 'Otro combustible',
      'District Cooling' => 'Demanda de refrigeración',
      'District Heating' => 'Demanda de calefacción',
      'Water' => 'Agua',
      'Photovoltaic' => 'Fotovoltaica',
      'Wind' => 'Eólica',
      'During Heating' => 'Con calefacción',
      'During Cooling' => 'Con refrigeración',
      'During Occupied Heating' => 'Con calefacción y ocupación',
      'During Occupied Cooling' => 'Con refrigeración y ocupación',
      'Gross Window-Wall Ratio' => 'Porcentaje bruto de huecos en fachada',
      'Weather File' => 'Archivo de clima',
      'Latitude' => 'Latitud',
      'Longitude' => 'Longitud',
      'Elevation' => 'Altitud',
      'Time Zone' => 'Zona horaria',
      'North Axis Angle' => 'Ángulo respecto al norte',
      'Area' => 'Área',
      'Conditioned (Y/N)' => 'Acondicionada (S/N)',
      'Part of Total Floor Area (Y/N)' => 'Parte del área total (S/N)',
      'Volume' => 'Volumen',
      'Multiplier' => 'Multiplicador',
      'Gross Wall Area' => 'Superficie bruta de muro',
      'Window Glass Area' => 'Superficie acristalada',
      'Lighting' => 'Iluminación',
      'People' => 'Ocupación',
      'Plug and Process' => 'Carga enchufada y de procesos',
      'Total Energy' => 'Energía total',
      'Energy Per Total Building Area' => 'Energía / sup. útil',
      'Energy Per Conditioned Building Area' => 'Energía / sup. acondicionada',
      'Total Site Energy' => 'Energía final total',
      'Net Site Energy' => 'Energía final neta',
      'Total Source Energy' => 'Energía primaria total',
      'Net Source Energy' => 'Energía primaria neta',
      'Total' => 'Total',
      'Conditioned Total' => 'Total Acondicionada',
      'Unconditioned Total' => 'Total No acondicionada',
      'Not Part of Total' => 'Fuera del total',
      'Heating/Cooling' => 'Calefacción/Refrigeración',
      'Calculated Design Load' => 'Carga térmica de diseño calculada',
      'User Design Load' => 'Carga de diseño de usuario',
      'Design Load With Sizing Factor' => 'Carga térmica para dimensionado',
      'Calculated Design Air Flow' => 'Flujo de aire de diseño',
      'User Design Air Flow' => 'Flujo de aire de usuario',
      'Design Air Flow  With Sizing Factor' => 'Flujo de aire de dimensionado',
      'Date/Time Of Peak' => 'Fecha/hora pico',
      'Outdoor Temperature at Peak Load' => 'Temperatura exterior con carga pico',
      'Outdoor Humidity Ratio at Peak Load' => 'Humedad exterior con carga pico'
    }.fetch(key) { |nokey| nokey }
  end

  ### -------------------------------------------------------------------------
  ### Secciones ---------------------------------------------------------------
  ### -------------------------------------------------------------------------

  # Datos_generales ======================================================

  def self.cte_datos_generales(model, sqlFile, runner, name_only = false)
    general_tables = []

    @general_data = {}
    @general_data[:title] = 'Datos generales'
    @general_data[:tables] = general_tables #esto no se lo que es

    if name_only == true
        return @general_data
    end

    general_tables << CTELib_Reporting.cte_weather_summary_table(model, sqlFile, runner)
    general_tables << CTELib_Reporting.cte_superficies_table(model, sqlFile, runner)
    general_tables << CTELib_Reporting.cte_setpoint_not_met_summary_table(model, sqlFile, runner)
    return @general_data
  end

  # Energía final por servicios ============================================

  def self.cte_energia_final_por_servicios(model, sqlFile, runner, name_only = false)
    general_tables = []

    @cte_end_use = {}
    @cte_end_use[:title] = 'Consumo de energía final'
    @cte_end_use[:tables] = general_tables #esto no se lo que es

    if name_only == true
        return @cte_end_use
    end

    general_tables << CTELib_Reporting.cte_end_use_energy_categories_table(model, sqlFile, runner)

    chart_tables = []
    chart_tables << CTELib_Reporting.output_data_end_use_table(model, sqlFile, runner)
    chart_tables << CTELib_Reporting.output_data_energy_use_table(model, sqlFile, runner)
    chart_tables << CTELib_Reporting.output_data_end_use_electricity_table(model, sqlFile, runner)
    chart_tables << CTELib_Reporting.output_data_end_use_gas_table(model, sqlFile, runner)
    chart_tables
      .select { |table| table[:data].map {|rowname, value| value.to_f.abs }.reduce(0, :+) > 0.01 }
      .each { |table| general_tables << table }

    return @cte_end_use
  end

  # Producción de energía =======================================================

  def self.cte_site_power_generation_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @site_power_generation_section = {}
    @site_power_generation_section[:title] = 'Producción de energía in situ'
    @site_power_generation_section[:tables] = general_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @site_power_generation_section
    end

    # add in general information from method
    site_power_generation_table = CTELib_Reporting.site_power_generation_table(model, sqlFile, runner)
    if site_power_generation_table
      general_tables << CTELib_Reporting.site_power_generation_table(model, sqlFile, runner)
    end

    return @site_power_generation_section
  end

  # Demanda por componentes =================================================

  def self.cte_demandas_por_componentes(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @demandas_por_componente = {}
    @demandas_por_componente[:title] = 'Demanda enegética'
    @demandas_por_componente[:tables] = general_tables

    if name_only == true
        return @demandas_por_componente
    end

    # add in general information from method
    general_tables << CTELib_Reporting.cte_energy_needs_table(model, sqlFile, runner, 'invierno')
    general_tables << CTELib_Reporting.cte_energy_needs_table(model, sqlFile, runner, 'verano')

    return @demandas_por_componente

  end

  # Mediciones envolvente =======================================================

  def self.cte_mediciones_envolvente(model, sqlfile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    #gather data for section
    @mediciones = {}
    @mediciones[:title] = "Mediciones de la envolvente"
    @mediciones[:tables] = general_tables

    if name_only == true
      return @mediciones
    end

    # add in general information from method
    general_tables << CTELib_Reporting.tabla_mediciones_envolvente(model, sqlfile, runner)
    general_tables << CTELib_Reporting.tabla_mediciones_puentes_termicos(model, runner)
    general_tables << CTELib_Reporting.cte_envelope_fenestration_table(model, sqlfile, runner)

    return @mediciones
  end

  # Tipos de espacios ==========================================================

  def self.cte_space_types_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @output_data_space_type_breakdown_section = {}
    @output_data_space_type_breakdown_section[:title] = 'Tipos de espacios'
    @output_data_space_type_breakdown_section[:tables] = general_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @output_data_space_type_breakdown_section
    end

    general_tables << CTELib_Reporting.space_type_breakdown_table(model, sqlFile, runner)
    CTELib_Reporting.space_type_detail_tables(model, sqlFile, runner).each { |table| general_tables << table }

    return @output_data_space_type_breakdown_section
  end

  # Zonas térmicas =============================================================

  def self.cte_zones_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @zone_summary_section = {}
    @zone_summary_section[:title] = 'Zonas térmicas'
    @zone_summary_section[:tables] = general_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @zone_summary_section
    end

    general_tables << CTELib_Reporting.cte_zone_summary_table(model, sqlFile, runner)
    general_tables << CTELib_Reporting.cte_zone_sizing_table(model, sqlFile, runner)

    return @zone_summary_section
  end


  # Intercambio de aire con el exterior ========================================

  def self.cte_outdoor_air_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @outdoor_air = {}
    @outdoor_air[:title] = 'Ventilación e infiltraciones'
    @outdoor_air[:tables] = general_tables

    if name_only == true
      return @outdoor_air
    end

    # add in general information from method
    general_tables << CTELib_Reporting.cte_outdoor_air_table(model, sqlFile, runner)

    return @outdoor_air
  end

  # Energía final y primaria ==================================================

  def self.cte_source_energy_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    source_energy_section_tables = []

    # gather data for section
    @source_energy_section = {}
    @source_energy_section[:title] = 'Energía primaria'
    @source_energy_section[:tables] = source_energy_section_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @source_energy_section
    end

    source_energy_section_tables << CTELib_Reporting.cte_source_energy_table(model, sqlFile, runner)
    source_energy_section_tables << CTELib_Reporting.cte_source_energy_factors_table(model, sqlFile, runner)

    return @source_energy_section
  end


  ### -------------------------------------------------------------------------
  ### Tablas  -----------------------------------------------------------------
  ### -------------------------------------------------------------------------

  # Tablas de datos generales =================================================

  # Tabla de resumen de clima =================================================

  def self.cte_weather_summary_table(model, sqlFile, runner)
    # data for query
    rows = ['Weather File', 'Latitude', 'Longitude', 'Elevation', 'Time Zone', 'North Axis Angle'] # el contenido son claves

    # create table
    table = {}
    table[:title] = 'Clima'
    table[:header] = rows.map { |row| self.translate(row) }
    table[:units] = []
    table[:data] = []

    # run query and populate table
    row_data = []
    rows.each do |row|
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='General' and RowName= '#{row}' and ColumnName= 'Value'"
      row_data << sqlFile.execAndReturnFirstString(query).get
    end
    table[:data] = [row_data]

    return table
  end

  # Tabla general de superficies y volumenes ==================================

  def self.cte_superficies_table(model, sqlFile, runner)
    # TODO: descomponer superficies externas de la envolvente por tipos (muros, cubiertas, huecos, lucernarios, etc)
    buildingName = model.getBuilding.name.get    
    # Zonas habitables
    zonasHabitables = CTE_Query.zonasHabitables(model)
    superficieHabitable = CTE_Query.superficieHabitable(model, sqlFile)
    volumenHabitable = CTE_Query.volumenHabitable(model, sqlFile)
    # Zonas no habitables
    zonasNoHabitables = CTE_Query.zonasNoHabitables(model)
    superficieNoHabitable = CTE_Query.superficieNoHabitable(model, sqlFile)
    volumenNoHabitable = CTE_Query.volumenNoHabitable(model, sqlFile)
    # Envolvente térmica
    superficiesExteriores = CTE_Query.envolventeSuperficiesExteriores(model, sqlFile)
    areaexterior = CTE_Query.envolventeAreaExterior(model, sqlFile)
    superficiesInteriores = CTE_Query.envolventeSuperficiesInteriores(model, sqlFile)
    areainterior = CTE_Query.envolventeAreaInterior(model, sqlFile)
    areatotal = areaexterior + areainterior
    compacidad = (volumenHabitable / areatotal)

    runner.registerInfo("* Iniciando mediciones (edificio #{ buildingName })")
    runner.registerValue("Zonas habitables", "#{ zonasHabitables }")
    runner.registerValue("Zonas habitables, número", zonasHabitables.count())
    runner.registerValue("Zonas habitables, superficie", '%.2f' % superficieHabitable, 'm^2')
    runner.registerValue("Zonas habitables, volumen", '%.2f' % volumenHabitable, 'm^3')
    runner.registerValue("Zonas no habitables", "#{ zonasNoHabitables }")
    runner.registerValue("Zonas no habitables, número", zonasNoHabitables.count())
    runner.registerValue("Zonas no habitables, superficie", '%.2f' % superficieNoHabitable, 'm^2')
    runner.registerValue("Zonas no habitables, volumen", '%.2f' % volumenNoHabitable, 'm^3')
    runner.registerValue('Envolvente Térmica, superficies exteriores', superficiesExteriores.count())
    runner.registerValue('Envolvente Térmica, superficies interiores', superficiesInteriores.count())
    runner.registerValue('Envolvente Térmica, área de superficies exteriores', '%.2f' % areaexterior, 'm^2')
    runner.registerValue('Envolvente Térmica, área de superficies interiores', '%.2f' % areainterior, 'm^2')
    runner.registerValue('Envolvente Térmica, área total', '%.2f' % areatotal, 'm^2')
    runner.registerValue('Compacidad', '%.2f' % compacidad)

    medicion_general = {}
    medicion_general[:title] = "Superficies y volúmenes (edificio #{ buildingName })"
    medicion_general[:header] = ['', '#', 'Superficie', 'Volumen']
    medicion_general[:units] = ['', '', 'm²', 'm³']
    medicion_general[:data] = []
    medicion_general[:data] << ['<b>Edificio</b>', '', '%.2f' % (superficieHabitable + superficieNoHabitable), '%.2f' % (volumenHabitable + volumenNoHabitable)]
    medicion_general[:data] << ["<u>Zonas habitables</u>", zonasHabitables.count(), '%.2f' % superficieHabitable, '%.2f' % volumenHabitable]
    medicion_general[:data] << ["<u>Zonas no habitables</u>", zonasNoHabitables.count(), '%.2f' % superficieNoHabitable, '%.2f' % volumenNoHabitable]
    medicion_general[:data] << ["<u>Envolvente térmica</u>", '', '%.2f' % areatotal, '']
    medicion_general[:data] << ['- Exterior', '', '%.2f' % areaexterior, '']
    medicion_general[:data] << ['- Interior', '', '%.2f' % areainterior, '']
    medicion_general[:data] << ['<b>Compacidad</b>', "<b>#{  '%.2f' % compacidad }</b>", '%.2f' % areatotal, '%.2f' % volumenHabitable]
    runner.registerInfo("* Finalizadas mediciones (edificio #{ buildingName })")

    return medicion_general
  end

  # Tabla de tiempo fuera de consigna ==============================================================

  def self.cte_setpoint_not_met_summary_table(model, sqlFile, runner)
    # unmet hours data output
    setpoint_not_met_summary = {}
    setpoint_not_met_summary[:title] = 'Cumplimiento de consignas'
    setpoint_not_met_summary[:header] = ['Tiempo fuera de consigna', 'Valor']
    setpoint_not_met_summary[:units] = ['', 'hr']
    setpoint_not_met_summary[:data] = []

    # create string for rows (transposing from what is in tabular data)
    setpoint_not_met_cat = []
    setpoint_not_met_cat << 'During Heating'
    setpoint_not_met_cat << 'During Cooling'
    setpoint_not_met_cat << 'During Occupied Heating'
    setpoint_not_met_cat << 'During Occupied Cooling'

    # loop through  messages
    setpoint_not_met_cat.each do |cat|
      # Retrieve end use percentages from  table
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='SystemSummary' and TableName = 'Time Setpoint Not Met' and RowName= 'Facility' and ColumnName='#{cat}';"
      setpoint_not_met_cat_value = sqlFile.execAndReturnFirstDouble(query)
      if setpoint_not_met_cat_value.empty?
        runner.registerError("Did not find value for #{cat}.")
        return false
      else
        # net site energy
        display = self.translate(cat)
        value = setpoint_not_met_cat_value.get
        setpoint_not_met_summary[:data] << [display, value]
        runner.registerValue("CTE horas fuera de consigna - #{display}", value, 'hr')

      end
    end # setpoint_not_met_cat.each do

    return setpoint_not_met_summary
  end

  # Tablas de consumo de energía final =======================================================

  # Tabla de energía final por categoría y servicio ==========================================

  def self.cte_end_use_energy_categories_table(model, sqlFile, runner)

    superficiehabitable = CTE_Query.superficieHabitable(model, sqlFile)

    # XXX: debería considerar de forma diferente la iluminación según se trate de edificios de uso residencial o terciario

    usosEPB = { 'Heating'=> 0,
                'Cooling'=> 0,
                'Water Systems'=> 0,
                'Fans'=> 0,
                'Pumps'=> 0 }

    usosNoEPB = { 'Interior Lighting'=> 0,
                  #'Exterior Lighting'=> 0,
                  'Interior Equipment'=> 0,
                  #'Exterior Equipment'=> 0,
                  #'Heat Rejection'=> 0,
                  #'Humidification'=> 0,
                  #'Heat Recovery'=> 0,
                  #'Refrigeration'=> 0,
                  #'Generators'=> 0
                }

    traduce = { 'Heating'=> 'Calefacción',
                'Cooling'=> 'Refrigeración',
                'Water Systems'=> 'ACS',
                'Interior Lighting'=> 'Iluminación',
                'Interior Equipment'=> 'Equipos',
                'Fans'=> 'Ventiladores',
                'Pumps'=> 'Bombas' }

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

    general_table = {}
    general_table[:title] = 'Energía final por categoría y servicio (Consumo Neto)'
    general_table[:header] =['Categoría / Servicio', 'Energía', 'Energía/Sup. Acond.']
    general_table[:units] = ['', 'kWh', 'kWh/m²']
    general_table[:data] = []
    general_table[:data] << ['<b>Servicios EPB + No EPB</b>', '<b>%.0f</b>' % (totalUsosEPB + totalUsosNoEPB),
      "<b>#{ '%.1f' % ((totalUsosEPB + totalUsosNoEPB) / superficiehabitable) }</b>"]
    general_table[:data] << ['<b>Servicios EPB</b>', '<b>%.0f</b>' % totalUsosEPB,
        "<b>#{ '%.1f' % (totalUsosEPB / superficiehabitable) }</b>"]
    usosEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", '%.0f' % valor, '%.1f' % (valor / superficiehabitable)]
    end

    general_table[:data] << ['<b>Servicios No EPB</b>', '<b>%.0f</b>' % totalUsosNoEPB,
        "<b>#{ '%.1f' % (totalUsosNoEPB/superficiehabitable) }</b>"]
    usosNoEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", '%.0f' % valor, '%.1f' % (valor / superficiehabitable)]
    end
    return general_table
  end

  #XXX: no se usa
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
        AND ColumnName IN  ('Electricity', 'Natural Gas',
                    'District Cooling', 'District Heating') "
      search = sqlFile.execAndReturnFirstDouble(query_all)
      result += search.get
    end

    return OpenStudio.convert(result, 'GJ', 'kWh').get
  end

  # Tabla y gráfica de uso de energía final por servicio ==================================================

  def self.output_data_end_use_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use = {}
    output_data_end_use[:title] = 'Consumo de energía final por servicio'
    output_data_end_use[:header] = ['Servicio', 'Consumo']
    output_data_end_use[:units] = ['', 'kWh']
    output_data_end_use[:data] = []
    output_data_end_use[:chart_type] = 'simple_pie'
    output_data_end_use[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    OpenStudio::EndUseCategoryType.getValues.each_with_index do |end_use, index|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription #aquí es un nombre de categoría:
        # Heating, Cooling, Interior Lighting, Exterior Lighting, Interior Equipment, Exterior Equipment,
        # Fans, Pumps, Heat Rejection, Humidification, Heat Recovery, Water Systems, Refrigeration, Generators

      query_elec = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Electricity'"
      query_gas = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Natural Gas'"
      # query_add = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Additional Fuel'"
      query_dc = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'District Cooling'"
      query_dh = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'District Heating'"
      results_elec = sqlFile.execAndReturnFirstDouble(query_elec).get
      results_gas = sqlFile.execAndReturnFirstDouble(query_gas).get
      # results_add = sqlFile.execAndReturnFirstDouble(query_add).get
      results_dc = sqlFile.execAndReturnFirstDouble(query_dc).get
      results_dh = sqlFile.execAndReturnFirstDouble(query_dh).get
      total_end_use = results_elec + results_gas + results_dc + results_dh
      value = OpenStudio.convert(total_end_use, 'GJ', 'kWh').get
      end_use_trans = self.translate(end_use)
      output_data_end_use[:data] << [end_use_trans, '%.0f' % value]
      runner.registerValue("CTE Uso energia final - #{end_use_trans}", value, 'kWh')
      if value > 0
        output_data_end_use[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[index])
      end
    end

    return output_data_end_use
  end

  # Tabla y gráfica de energía final por vector energético ======================================================

  def self.output_data_energy_use_table(model, sqlFile, runner)
    # energy use data output
    output_data_energy_use = {}
    output_data_energy_use[:title] = 'Consumo de energia final por vector energético'
    output_data_energy_use[:header] = ['Vector', 'Consumo']
    output_data_energy_use[:units] = ['', 'kWh']
    output_data_energy_use[:data] = []
    output_data_energy_use[:chart_type] = 'simple_pie'
    output_data_energy_use[:chart] = []

    # list of colors for fuel. Also used for cash flow chart
    color = []
    color << '#DDCC77' # Electricity
    color << '#999933' # Natural Gas
    color << '#AA4499' # Additional Fuel
    color << '#88CCEE' # District Cooling
    color << '#CC6677' # District Heating
    # color << "#332288" # Water (not used here but is in cash flow chart)
    # color << "#117733" # Capital and O&M (not used here but is in cash flow chart)

    # loop through fuels for consumption tables
    OpenStudio::EndUseFuelType.getValues.each_with_index do |fuel_type, index|
      # get fuel type and units
      fuel_type = OpenStudio::EndUseFuelType.new(fuel_type).valueDescription
      next if fuel_type == 'Water'
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= 'Total End Uses' and ColumnName= '#{fuel_type}'"
      results = sqlFile.execAndReturnFirstDouble(query)
      value = OpenStudio.convert(results.get, 'GJ', 'kWh').get
      fuel_type_trans = self.translate(fuel_type)
      output_data_energy_use[:data] << [fuel_type_trans, '%.0f' % value]
      runner.registerValue("CTE combustible - #{fuel_type_trans}", value, 'kWh')

      if value > 0
        output_data_energy_use[:chart] << JSON.generate(label: fuel_type, value: value, color: color[index])
      end
    end

    return output_data_energy_use
  end

  # Tabla y gráfica de uso de energía final de electricidad por servicios =====================================

  def self.output_data_end_use_electricity_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use_electricity = {}
    output_data_end_use_electricity[:title] = 'Consumo de energía final (electricidad) por servicios'
    output_data_end_use_electricity[:header] = ['Servicio', 'Consumo']
    output_data_end_use_electricity[:units] = ['', 'kWh']
    output_data_end_use_electricity[:data] = []
    output_data_end_use_electricity[:chart_type] = 'simple_pie'
    output_data_end_use_electricity[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    OpenStudio::EndUseCategoryType.getValues.each_with_index do |end_use, index|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Electricity'"
      results = sqlFile.execAndReturnFirstDouble(query)
      value = OpenStudio.convert(results.get, 'GJ', 'kWh').get
      end_use_trans = self.translate(end_use)
      output_data_end_use_electricity[:data] << [end_use_trans, '%.0f' % value]
      runner.registerValue("CTE energia final Electricidad - #{end_use_trans}", value, 'kWh')
      if value > 0
        output_data_end_use_electricity[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[index])
      end
    end

    return output_data_end_use_electricity
  end

  # Tabla y gráfica de uso de energía final gas natural por servicios ========================================
  def self.output_data_end_use_gas_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use_gas = {}
    output_data_end_use_gas[:title] = 'Consumo de energía final (gas natural) por servicios'
    output_data_end_use_gas[:header] = ['Servicio', 'Consumo']
    output_data_end_use_gas[:units] = ['', 'kWh']
    output_data_end_use_gas[:data] = []
    output_data_end_use_gas[:chart_type] = 'simple_pie'
    output_data_end_use_gas[:chart] = []
    output_data_end_use_gas[:chart_type] = 'simple_pie'
    output_data_end_use_gas[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    OpenStudio::EndUseCategoryType.getValues.each_with_index do |end_use, index|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Natural Gas'"
      results = sqlFile.execAndReturnFirstDouble(query)
      value = OpenStudio.convert(results.get, 'GJ', 'kWh').get
      end_use_trans = self.translate(end_use)
      output_data_end_use_gas[:data] << [end_use_trans, '%.0f' % value]
      runner.registerValue("CTE energia final Gas Natural - #{end_use_trans}", value, 'kWh')
      if value > 0
        output_data_end_use_gas[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[index])
      end
    end

    return output_data_end_use_gas
  end

  # Tabla de generación de energía in situ============================================

  def self.site_power_generation_table(model, sqlFile, runner)
    headers = ['', 'Rated Capacity', 'Annual Energy Generated']
    site_power_generation_table = {}
    site_power_generation_table[:title] = 'Generación de energía renovable'
    site_power_generation_table[:header] = ['', 'Capacidad nominal', 'Energía anual generada']
    site_power_generation_table[:source_units] = ['', 'kW', 'GJ']
    site_power_generation_table[:units] = ['', 'kW', 'kWh']
    site_power_generation_table[:data] = []

    rows = ['Photovoltaic', 'Wind']

    value_found = false
    rows.each do |row|
      row_data = [self.translate(row)]
      headers.each_with_index do |header, index|
        next if header == ''
        #XXX: Leedsummary?
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='LEEDsummary' and RowName= '#{row}' and ColumnName='#{header}';"
        data = sqlFile.execAndReturnFirstDouble(query).get
        data_ip = OpenStudio.convert(data, site_power_generation_table[:source_units][index], site_power_generation_table[:units][index]).get
        if data > 0 then value_found = true end

        row_data << '%.2f' % data_ip
      end
      site_power_generation_table[:data] << row_data
    end

    if value_found
      return site_power_generation_table
    else
      return false
    end
  end

  # Tablas de demanda energética =====================================================

  def self.cte_energy_needs_table(model, sqlFile, runner, periodo)
    superficiehabitable =  CTE_Query.superficieHabitable(model, sqlFile).round(2)
    temporada = {'invierno' => 'calefaccion', 'verano'   => 'refrigeracion' }[periodo]
    color = {'invierno' => '#EF1C21', 'verano'   => '#008FF0' }[periodo]
    data = []

    # paredes aire ext.
    airWallHeat =   _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                    periodo, 'Wall', "AND ExtBoundCond = 0 AND SurfaceName NOT LIKE '%_PT%'") / superficiehabitable
    data << [airWallHeat, temporada, 'Paredes Exteriores']

    # paredes terreno
    groundWallHeat = _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                    periodo, 'Wall', "AND ExtBoundCond = -1") / superficiehabitable
    data << [groundWallHeat, temporada, 'Paredes Terreno']

    # paredes interiores
    indoorWallHeat = _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                        periodo, 'Wall', "AND ExtBoundCond NOT IN (0, -1)") / superficiehabitable
    data << [indoorWallHeat, temporada, 'Paredes Interiores']

    # XXX: no tenemos el balance de las particiones interiores entre zonas
    # cubiertas
    roofHeat = _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                        periodo, 'Roof', "AND ExtBoundCond = 0") / superficiehabitable
    data << [roofHeat, temporada, 'Cubiertas']

    # suelos aire ext
    airFloorHeat = _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                          periodo, 'Floor', "AND ExtBoundCond = 0") / superficiehabitable
    data << [airFloorHeat, temporada, 'Suelos Aire']

    # suelos terreno
    groundFloorHeat = _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                              periodo, 'Floor', "AND ExtBoundCond = -1") / superficiehabitable
    data << [groundFloorHeat, temporada, 'Suelos Terreno']

    # puentes termicos
    thermalBridges = _componentValueForPeriod(model, sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                    periodo, 'Wall', "AND SurfaceName LIKE '%_PT%'") / superficiehabitable
    data << [thermalBridges, temporada, 'Puentes Termicos']

    # #solar y transmisión ventanas
    windowRadiation = _componentValueForPeriod(model, sqlFile, 'Surface Window Transmitted Solar Radiation Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    data << [windowRadiation, temporada, 'Solar Ventanas']
    windowTransmissionGain = _componentValueForPeriod(model, sqlFile, 'Surface Window Heat Gain Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    windowTransmissionLoss = _componentValueForPeriod(model, sqlFile, 'Surface Window Heat Loss Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    windowTransmission = windowTransmissionGain - windowTransmissionLoss - windowRadiation
    data << [windowTransmission, temporada, 'Transmision Ventanas']
    # fuentes internas
    internalHeating = _zoneValueForPeriod(model, sqlFile, "Zone Total Internal Total Heating Energy", periodo) / superficiehabitable
    data << [internalHeating, temporada, 'Fuentes Internas']
    # ventilacion + infiltraciones
    ventGain = _zoneValueForPeriod(model, sqlFile, "Zone Combined Outdoor Air Sensible Heat Gain Energy", periodo) / superficiehabitable
    ventLoss = _zoneValueForPeriod(model, sqlFile, "Zone Combined Outdoor Air Sensible Heat Loss Energy", periodo) / superficiehabitable
    airHeatBalance = ventGain - ventLoss
    data << [airHeatBalance, temporada, 'Ventilación + Infiltraciones']

    # total
    total = data.map{ | value, label, label_x | value }.reduce(:+)
    data << [total, temporada, 'Total']

    orden_eje_x = []
    medicion_general = {}
    medicion_general[:title] = "Demanda por componentes en #{periodo} [kWh/m²]"
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

  def self._componentValueForPeriod(model, sqlFile, variableName, periodo, className, extraCond, unitsSource='J', unitsTarget='kWh')
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    supHab AS (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES % CTE_Query.listaZonasHabitables(model)})
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

  def self._zoneValueForPeriod(model, sqlFile, variableName, periodo, unitsSource='J', unitsTarget='kWh')
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    zonashabitables AS (#{ CTE_Query::ZONASHABITABLES % CTE_Query.listaZonasHabitables(model) })
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

  # Mediciones de la envolvente =======================================================

  # Tabla de medición de opacos ===================================================================

  def self.tabla_mediciones_envolvente(model, sqlFile, runner)

    indicesquery = "SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES % CTE_Query.listaZonasHabitables(model) })
                    UNION
                    SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES % CTE_Query.listaZonasHabitablesYNoHabitables(model) })"
    indices  = sqlFile.execAndReturnVectorOfString(indicesquery).get

    data = []
    indices.each do | indiceconstruccion |
      query = "SELECT SUM(Area) FROM
                   (SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES % CTE_Query.listaZonasHabitables(model) })
                    UNION ALL
                    SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES % CTE_Query.listaZonasHabitablesYNoHabitables(model) }))
               WHERE ConstructionIndex == #{ indiceconstruccion }"
      area = sqlFile.execAndReturnFirstDouble(query).get
      nombre = sqlFile.execAndReturnFirstString("SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
      uvalue = sqlFile.execAndReturnFirstDouble("SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
      unless nombre.include?("_PSI")
        data << [nombre.force_encoding('UTF-8'), area, uvalue]
      end
    end

    contenedor_general = {}
    contenedor_general[:title] = "Medición de elementos de la envolvente térmica"
    contenedor_general[:header] = ['Construcción', 'Superficie', 'U']
    contenedor_general[:units] = ['', 'm²', 'W/m²K']
    contenedor_general[:data] = []
    data.each do | nombre, area, uvalue |
      contenedor_general[:data] << [nombre, '%.2f' % area, '%.3f' % uvalue]
    end

    return contenedor_general
  end

  # Tabla de medición de puentes térmicos ===================================================

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
    contenedor_general[:title] = "Medición de puentes térmicos"
    contenedor_general[:header] = ['Tipo', 'Coef. acoplamiento', 'Longitud', 'PSI']
    contenedor_general[:units] = ['', 'W/K', 'm', 'W/mK']
    contenedor_general[:data] = []
    coeficienteAcoplamiento.each do | key, value |
      psi = ttl_puenteTermico[key]
      contenedor_general[:data] << [key, '%.2f' % value,  '%.1f' % (value / psi),  '%.2f' % psi]
    end

    return contenedor_general
  end

  # Tabla de medición de huecos ==============================================================

  def self.cte_envelope_fenestration_table(model, sqlFile, runner)

    # Conditioned Window-Wall Ratio and Skylight-Roof Ratio
    fenestration_data = {}
    fenestration_data[:title] = 'Porcentaje de huecos'
    fenestration_data[:header] = %w(Descripción Total Norte Este Sur Oeste)
    fenestration_data[:units] = ['', '%', '%', '%', '%', '%']
    fenestration_data[:data] = []

    # create string for rows
    fenestrations = []
    fenestrations << 'Gross Window-Wall Ratio' # [%]

    # loop rows
    fenestrations.each do |fenestration|
      query0 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Window-Wall Ratio' and RowName='#{fenestration}' and ColumnName='Total'"
      query1 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Window-Wall Ratio' and RowName='#{fenestration}' and ColumnName='North (315 to 45 deg)'"
      query2 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Window-Wall Ratio' and RowName='#{fenestration}' and ColumnName='East (45 to 135 deg)'"
      query3 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Window-Wall Ratio' and RowName='#{fenestration}' and ColumnName='South (135 to 225 deg)'"
      query4 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Window-Wall Ratio' and RowName='#{fenestration}' and ColumnName='West (225 to 315 deg)'"
      query5 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Skylight-Roof Ratio'  and RowName='Skylight-Roof Ratio'"

      total = sqlFile.execAndReturnFirstDouble(query0)
      north = sqlFile.execAndReturnFirstDouble(query1)
      east = sqlFile.execAndReturnFirstDouble(query2)
      south = sqlFile.execAndReturnFirstDouble(query3)
      west = sqlFile.execAndReturnFirstDouble(query4)
      skylight = sqlFile.execAndReturnFirstDouble(query5)
      if total.empty? || north.empty? || east.empty? || south.empty? || west.empty?
        runner.registerError('No se han encontrado valores de porcentaje de huecos')
        return false
      else
        # add data
        display = self.translate(fenestration)
        fenestration_data[:data] << [display,  '%.1f' % total.get, '%.1f' % north.get, '%.1f' % east.get, '%.1f' % south.get, '%.1f' % west.get]
        runner.registerValue("CTE #{display}", total.get, '%')

        # skylight
        # skylight seems to provide back percentage vs. fraction. Changing to fraction to match vertical fenestration.
        fenestration_data[:data] << ['Porcentaje de huecos en cubierta', '%.1f' % skylight.get, '-', '-', '-', '-']
        runner.registerValue('CTE Porcentaje de huecos en cubierta', skylight.get, '%')
      end
    end

    return fenestration_data
  end

  # Tablas de tipos de espacios ====================================================

  # Tabla de reparto por tipos de espacios ==========================================

  def self.space_type_breakdown_table (model, sqlFile, runner)

    # Tabla y gráfica de reparto por tipos de espacios
    output_data_space_type_breakdown = {}
    output_data_space_type_breakdown[:title] = ''
    output_data_space_type_breakdown[:header] = ['Tipo de Espacio', 'Superficie útil']
    output_data_space_type_breakdown[:units] = ['', 'm^2']
    output_data_space_type_breakdown[:data] = []
    output_data_space_type_breakdown[:chart_type] = 'simple_pie'
    output_data_space_type_breakdown[:chart] = []

    space_types = model.getSpaceTypes

    space_types.sort.each do |spaceType|
      next if spaceType.floorArea == 0

      # get color
      color = spaceType.renderingColor
      if !color.empty?
        color = color.get
        red = color.renderingRedValue
        green = color.renderingGreenValue
        blue = color.renderingBlueValue
        color = "rgb(#{red},#{green},#{blue})"
      else
        # TODO: - this should set red green and blue as separate values
        color = 'rgb(20,20,20)' # maybe do random or let d3 pick color instead of this?
      end

      # data for space type breakdown
      display = spaceType.name.get
      floor_area_si = spaceType.floorArea
      value = floor_area_si
      value_neat = OpenStudio.toNeatString(value, 0, true)
      output_data_space_type_breakdown[:data] << [display, value_neat]
      runner.registerValue("CTE Tipo de espacio - #{display}", value, 'm^2')

      # data for graph
      output_data_space_type_breakdown[:chart] << JSON.generate(label: display, value: value, color: color)
    end

    spaces = model.getSpaces

    # count area of spaces that have no space type
    no_space_type_area_counter = 0

    spaces.each do |space|
      if space.spaceType.empty?
        no_space_type_area_counter += space.floorArea
      end
    end

    if no_space_type_area_counter > 0
      display = 'Sin tipo de espacio asignado'
      value = OpenStudio.convert(no_space_type_area_counter, 'm^2', units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      output_data_space_type_breakdown[:data] << [display, value_neat]
      runner.registerValue("CTE Tipo de espacio - #{display}", value, units)

      # data for graph
      color = 'rgb(20,20,20)' # maybe do random or let d3 pick color instead of this?
      output_data_space_type_breakdown[:chart] << JSON.generate(label: 'Sin tipo de espacio asignado',
                                                                value: OpenStudio.convert(no_space_type_area_counter, 'm^2', 'm^2'),
                                                                color: color)
    end
    return output_data_space_type_breakdown
  end

  # Tablas de detalles por tipos de espacios ===================================================

  # XXX: revisar cómo se usa
  def self.space_type_detail_tables (model, sqlFile, runner)
    output_data_space_type_detail_tables = []

    # loop through space types
    model.getSpaceTypes.sort.each do |spaceType|
      next if spaceType.floorArea == 0

      # get floor area
      floor_area_si = spaceType.floorArea

      # create variable for number of people
      num_people = nil

      # gather list of spaces and zones in space type
      zone_name_list = []
      space_name_list = []
      spaceType.spaces.each do |space|
        # grabspace and zone names
        space_name_list << space.name.to_s
        if space.thermalZone.is_initialized
          zone_name_list << space.thermalZone.get.name.to_s
        end
      end
      # TODO: Espacios por zonas
      # output_data_space_type_details[:data] << [space_name_list.uniq.join(","),space_name_list.uniq.size,"Spaces",""]
      # output_data_space_type_details[:data] << [zone_name_list.uniq.join(","),zone_name_list.uniq.size,"Thermal Zones",""]

      # space type details data output
      output_data_space_type_details = {}
      output_data_space_type_details[:title] = "#{spaceType.name}<br>(#{space_name_list.uniq.size} espacios y #{zone_name_list.uniq.size} zonas térmicas)"
      output_data_space_type_details[:header] = ['Definición', 'Valor', 'Unidad', 'Multiplicador']
      output_data_space_type_details[:units] = []  # won't use this for these tables since units change
      output_data_space_type_details[:data] = []

      # data for space type details
      instances = spaceType.internalMass
      instances.each do |instance|
        def_display = instance.definition.name
        if instance.surfaceArea.is_initialized && instance.surfaceArea.get > 0
          def_value = OpenStudio.convert(instance.surfaceArea.get, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'm^2'
        elsif instance.surfaceAreaPerFloorArea.is_initialized && instance.surfaceAreaPerFloorArea.get > 0
          def_value = instance.surfaceAreaPerFloorArea.get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'm^2/m^2 superficie útil'
        elsif instance.surfaceAreaPerPerson.is_initialized && instance.surfaceAreaPerPerson.get > 0
          def_value = OpenStudio.convert(instance.surfaceAreaPerPerson.get, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'm^2/persona'
        end
        count = instance.multiplier
        output_data_space_type_details[:data] << [def_display, def_value_neat, def_units, count]
      end

      instances = spaceType.people
      instances.each do |instance|
        def_display = instance.definition.name
        if instance.numberOfPeople.is_initialized && instance.numberOfPeople.get > 0
          def_value = instance.numberOfPeople.get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'personas'
        elsif instance.peoplePerFloorArea.is_initialized && instance.peoplePerFloorArea.get > 0
          def_value = instance.peoplePerFloorArea.get / OpenStudio.convert(1, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 4, true)
          def_units = 'personas/m^2'
        elsif instance.spaceFloorAreaPerPerson.is_initialized && instance.spaceFloorAreaPerPerson.get > 0
          def_value = OpenStudio.convert(instance.spaceFloorAreaPerPerson.get, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'm^2/persona'
        end
        count = instance.multiplier
        output_data_space_type_details[:data] << [def_display, def_value_neat, def_units, count]
      end

      instances = spaceType.electricEquipment
      instances.each do |instance|
        def_display = instance.definition.name
        if instance.designLevel.is_initialized && instance.designLevel.get > 0
          def_value = instance.designLevel.get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'W'
        elsif instance.powerPerFloorArea.is_initialized && instance.powerPerFloorArea.get > 0
          def_value = instance.powerPerFloorArea.get / OpenStudio.convert(1, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 4, true)
          def_units = 'W/m^2'
        elsif instance.powerPerPerson .is_initialized && instance.powerPerPerson .get > 0
          def_value = OpenStudio.convert(instance.powerPerPerson .get, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'W/persona'
        end
        count = instance.multiplier
        output_data_space_type_details[:data] << [def_display, def_value_neat, def_units, count]
      end

      instances = spaceType.gasEquipment
      instances.each do |instance|
        def_display = instance.definition.name
        if instance.designLevel.is_initialized && instance.designLevel.get > 0
          def_value = instance.designLevel.get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'W'
        elsif instance.powerPerFloorArea.is_initialized && instance.powerPerFloorArea.get > 0
          def_value = instance.powerPerFloorArea.get / OpenStudio.convert(1, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 4, true)
          def_units = 'W/m^2'
        elsif instance.powerPerPerson .is_initialized && instance.powerPerPerson .get > 0
          def_value = OpenStudio.convert(instance.powerPerPerson .get, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'W/persona'
        end
        count = instance.multiplier
        output_data_space_type_details[:data] << [def_display, def_value_neat, def_units, count]
      end

      instances = spaceType.lights
      instances.each do |instance|
        def_display = instance.definition.name
        if instance.lightingLevel.is_initialized && instance.lightingLevel.get > 0
          def_value = instance.lightingLevel.get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'W'
        elsif instance.powerPerFloorArea.is_initialized && instance.powerPerFloorArea.get > 0
          def_value = instance.powerPerFloorArea.get / OpenStudio.convert(1, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 4, true)
          def_units = 'W/m^2'
        elsif instance.powerPerPerson .is_initialized && instance.powerPerPerson .get > 0
          def_value = OpenStudio.convert(instance.powerPerPerson .get, 'm^2', 'm^2').get
          def_value_neat = OpenStudio.toNeatString(def_value, 0, true)
          def_units = 'W/persona'
        end
        count = instance.multiplier
        output_data_space_type_details[:data] << [def_display, def_value_neat, def_units, count]
      end

      instances = spaceType.spaceInfiltrationDesignFlowRates
      instances.each do |instance|
        instance_display = instance.name
        if instance.designFlowRate.is_initialized
          inst_value = OpenStudio.convert(instance.designFlowRate.get, 'm^3/s', 'm^3/s').get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'm^3/s'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
        if instance.flowperSpaceFloorArea.is_initialized
          inst_value = OpenStudio.convert(instance.flowperSpaceFloorArea.get, 'm/s', 'm/s').get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'm^3/s/m^2 superficie útil'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
        if instance.flowperExteriorSurfaceArea.is_initialized
          inst_value = OpenStudio.convert(instance.flowperExteriorSurfaceArea.get, 'm/s', 'm/s').get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'm^3/s/m^2 superficie exterior'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
        if instance.flowperExteriorWallArea.is_initialized # uses same input as exterior surface area but different calc method
          inst_value = OpenStudio.convert(instance.flowperExteriorWallArea.get, 'm/s', 'm/s').get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'm^3/s/m^2 superficie exterior'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
        if instance.airChangesperHour.is_initialized
          inst_value = instance.airChangesperHour.get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'ren/h'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
      end

      if spaceType.designSpecificationOutdoorAir.is_initialized
        instance = spaceType.designSpecificationOutdoorAir.get
        instance_display = instance.name
        if instance.to_DesignSpecificationOutdoorAir.is_initialized
          instance = instance.to_DesignSpecificationOutdoorAir.get
          outdoor_air_method = instance.outdoorAirMethod
          count = ''

          # calculate and report various methods
          if instance.outdoorAirFlowperPerson > 0
            inst_value = OpenStudio.convert(instance.outdoorAirFlowperPerson, 'm^3/s', 'm^3/s').get
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            inst_units = 'm^3/s/persona'
            output_data_space_type_details[:data] << ["#{instance_display} (método de aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end
          if instance.outdoorAirFlowperFloorArea > 0
            inst_value = OpenStudio.convert(instance.outdoorAirFlowperFloorArea, 'm/s', 'm/s').get
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            inst_units = 'm^3/s/m^2 superficie útil'
            output_data_space_type_details[:data] << ["#{instance_display} (método de aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end
          if instance.outdoorAirFlowRate > 0
            inst_value = OpenStudio.convert(instance.outdoorAirFlowRate, 'm^3/s', 'm^3/s').get
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            # inst_units = 'cfm'
            inst_units = 'm^3/s'
            output_data_space_type_details[:data] << ["#{instance_display} (método de aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end
          if instance.outdoorAirFlowAirChangesperHour > 0
            inst_value = instance.outdoorAirFlowAirChangesperHour
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            inst_units = 'ren/h'
            output_data_space_type_details[:data] << ["#{instance_display} (método de aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end

        end
      end

      # add table to array of tables
      output_data_space_type_detail_tables << output_data_space_type_details
    end

    return output_data_space_type_detail_tables
  end

  # Tablas de zonas térmicas ===================================================================================

  # Tabla de resumen de zonas ==================================================================================

  def self.cte_zone_summary_table(model, sqlFile, runner)
    # data for query
    columns = ['', 'Area', 'Conditioned (Y/N)', 'Part of Total Floor Area (Y/N)', 'Volume', 'Multiplier', 'Gross Wall Area', 'Window Glass Area', 'Lighting', 'People', 'Plug and Process']

    # populate dynamic rows
    rows_name_query = "SELECT DISTINCT  RowName FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Zone Summary'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end
    # rows = ['Total','Conditioned Total','Unconditioned Total','Not Part of Total']

    # create zone_summary_table
    zone_summary_table = {}
    zone_summary_table[:title] = 'Resumen de zonas'
    zone_summary_table[:header] = columns.map { |col| self.translate(col) }
    zone_summary_table[:units] = ['', 'm^2', '', '', 'm^3', '', 'm^2', 'm^2', 'W/m^2', 'm^2/person', 'W/m^2']
    zone_summary_table[:source_units] = ['', 'm^2', '', '', 'm^3', '', 'm^2', 'm^2', 'W/m^2', 'm^2/person', 'W/m^2'] # used for conversion
    zone_summary_table[:data] = []

    # run query and populate zone_summary_table
    rows.each do |row|
      row_data = [self.translate(row)]
      column_counter = -1
      columns.each do |header|
        column_counter += 1
        next if header == ''
        if header == 'Multiplier' then header = 'Multipliers' end # what we want to show is different than what is in E+ table
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='Zone Summary' and RowName= '#{row}' and ColumnName= '#{header}'"
        if not zone_summary_table[:source_units][column_counter] == ''
          results = sqlFile.execAndReturnFirstDouble(query).to_f
          row_data << results.round(2)
        else
          results = sqlFile.execAndReturnFirstString(query).get.sub('Yes', 'Sí')
          row_data << results
        end
      end

      zone_summary_table[:data] << row_data
    end

    return zone_summary_table
  end

  # Tabla de dimensionado de calefacción y refrigeración ==================================================================

  def self.cte_zone_sizing_table(model, sqlFile, runner)
    # data for query
    columns_query = ['', 'Heating/Cooling', 'Calculated Design Load', 'User Design Load', 'Calculated Design Air Flow', 'User Design Air Flow', 'Date/Time Of Peak', 'Outdoor Temperature at Peak Load', 'Outdoor Humidity Ratio at Peak Load']

    # XXX: no hay tabla 'Zone Cooling' en el ejemplo, sino 'Zone Sensible Cooling'
    # populate dynamic rows
    rows_name_query = "SELECT DISTINCT RowName FROM tabulardatawithstrings WHERE ReportName='HVACSizingSummary' and TableName='Zone Sensible Cooling'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end

    # create zone_dd_table
    zone_dd_table = {}
    zone_dd_table[:title] = 'Dimensionado de calefacción y refrigeración por zonas'
    zone_dd_table[:header] = columns_query.map { |col| self.translate(col) }
    zone_dd_table[:units] = ['', '', '', '', 'm^3/s', 'm^3/s', '', 'C', 'kgWater/kgDryAir']
    zone_dd_table[:source_units] = ['', '', '', '', 'm^3/s', 'm^3/s', '', 'C', 'kgWater/kgDryAir'] # used for conversion
    zone_dd_table[:data] = []
    # run query and populate zone_dd_table
    rows.each do |row|

      # XXX: no hay tabla 'Zone Cooling' en el ejemplo, sino 'Zone Sensible Cooling'
      # populate cooling row
      row_data = [row, 'Refrigeración']
      columns_query.each_with_index do |column, index|
        next if column == '' || column == 'Heating/Cooling'
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='HVACSizingSummary' and TableName='Zone Sensible Cooling' and RowName= '#{row}' and ColumnName= '#{column}'"
        if not zone_dd_table[:source_units][index] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_dd_table[:source_units][index], zone_dd_table[:units][index]).get
          row_data << '%.2f' % row_data_ip
        elsif column == 'Calculated Design Load' || column == 'User Design Load'
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, 'W', 'kW').get
          row_data << "#{ '%.2f' % row_data_ip } (kW)"
        else
          results = sqlFile.execAndReturnFirstString(query)
          row_data << results
        end
      end
      zone_dd_table[:data] << row_data

      # XXX: no hay tabla 'Zone Heating' en el ejemplo, sino 'Zone Sensible Heating'
      # populate heating row
      row_data = [row, 'Calefacción']
      columns_query.each_with_index do |column, index|
        next if column == '' || column == 'Heating/Cooling'
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='HVACSizingSummary' and TableName='Zone Sensible Heating' and RowName= '#{row}' and ColumnName= '#{column}'"
        if not zone_dd_table[:source_units][index] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_dd_table[:source_units][index], zone_dd_table[:units][index]).get
          row_data << '%.2f' % row_data_ip
        elsif column == 'Calculated Design Load' || column == 'User Design Load'
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, 'W', 'kW').get
          row_data << "#{ '%.2f' % row_data_ip } (kW)"
        else
          results = sqlFile.execAndReturnFirstString(query)
          row_data << results
        end
      end
      zone_dd_table[:data] << row_data
    end

    return zone_dd_table

  end

  # Tablas de ventilación e infiltraciones ==================================================

  # Tabla de aire exterior ==================================================================
  def self.cte_outdoor_air_table(model, sqlFile, runner)

    # XXX: Zone Combined Outdoor Air Changes per Hour is not includen in the OutdoorAirSummary,
    # it has to be read from general variable data in the SQL file.

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
        row_data << '%.2f' % row_data_ip

        # para la media de todo el edificio
        medias[header] += row_data_ip * zoneVolume
      end

      table[:data] << row_data
    end

    row_data = ['<b>Total edificio</b>']
    table[:header].each do |header|
      next if header == ''
      row_data << "<b>#{ '%.2f' % (medias[header] / totalVolume) }</b>"
    end
    table[:data] << row_data

    return table
  end

  # Tablas energía primaria =============================================================

  # Tabla de energía final y primaria ===========================================
  def self.cte_source_energy_table(model, sqlFile, runner)
    columns = ['', 'Total Energy', 'Energy Per Total Building Area', 'Energy Per Conditioned Building Area']
    rows = ['Total Site Energy', 'Net Site Energy', 'Total Source Energy', 'Net Source Energy']

    source_energy_table = {}
    source_energy_table[:title] = 'Energía final y primaria'
    source_energy_table[:header] = columns.map { |col| self.translate(col) }
    source_energy_table[:units] = ['', 'kWh', 'kWh/m^2', 'kWh/m^2']
    source_energy_table[:source_units] = ['', 'GJ', 'MJ/m^2', 'MJ/m^2'] # used for conversion, not needed for rendering.
    source_energy_table[:data] = []

    rows.each do |row|
      row_data = [self.translate(row)]
      columns.each_with_index do |col, index|
        next if col == ''
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='Site and Source Energy' and RowName= '#{row}' and ColumnName= '#{col}'"
        results = sqlFile.execAndReturnFirstDouble(query)
        row_data_ip = OpenStudio.convert(results.to_f, source_energy_table[:source_units][index], source_energy_table[:units][index]).get
        row_data << row_data_ip.round(1)
      end
      source_energy_table[:data] << row_data
    end
    return source_energy_table
  end

  # Tabla de factores de paso
  def self.cte_source_energy_factors_table(model, sqlFile, runner)
    source_energy_table = {}
    source_energy_table[:title] = 'Factores de paso de energía final a energía primaria'
    source_energy_table[:header] = ['', 'Factor de paso [kWh/kWh_f]']
    source_energy_table[:units] = []
    source_energy_table[:data] = []

    rows = ['Electricity', 'Natural Gas', 'District Cooling', 'District Heating']
    rows_es = {
      'Electricity' => 'Electricidad',
      'Natural Gas' => 'Gas Natural',
      'District Cooling' => 'Red de distrito (cal.)',
      'District Heating' => 'Red de distrito (ref.)'
    }

    rows.each do |row|
      row_data = [rows_es[row]]
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='Site to Source Energy Conversion Factors' and RowName= '#{row}' and ColumnName= 'Site=>Source Conversion Factor'"
      row_data << sqlFile.execAndReturnFirstDouble(query).to_f.round(3)
      source_energy_table[:data] << row_data
    end
    return source_energy_table
  end

end
