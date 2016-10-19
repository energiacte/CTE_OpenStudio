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
    workspace = runner.lastEnergyPlusWorkspace
    if workspace.empty?
      runner.registerError('Cannot find last idf file.')
      return false
    end
    workspace = workspace.get

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

  # cleanup - prep html and close sql
  def self.cleanup(html_in_path)
    # TODO: - would like to move code here, but couldn't get it working. May look at it again later on.

    return html_out_path
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
      'Refrigeration' => 'Refrigeradores',
      'Generators' => 'Generadores',
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
      'Energy Per Total Building Area' => 'Energía total por sup. útil',
      'Energy Per Conditioned Building Area' => 'Energía total por sup. acondicionada',
      'Total Site Energy' => 'Energía final total',
      'Net Site Energy' => 'Energía final neta',
      'Total Source Energy' => 'Energía primaria total',
      'Net Source Energy' => 'Energía primaria neta',
      'Total' => 'Total',
      'Conditioned Total' => 'Total Acondicionada',
      'Unconditioned Total' => 'Total No acondicionada',
      'Not Part of Total' => 'Fuera del total',
      'Heating/Cooling' => 'Calefacción/Refrigeración',
      'Calculated Design Load' => 'Carga térmica de diseño',
      'Design Load With Sizing Factor' => 'Carga térmica para dimensionado',
      'Calculated Design Air Flow' => 'Flujo de aire de diseño calculado',
      'Design Air Flow  With Sizing Factor' => 'Flujo de aire de dimensionado',
      'Date/Time Of Peak' => 'Fecha/hora pico',
      'Outdoor Temperature at Peak Load' => 'Temperatura exterior con carga pico',
      'Outdoor Humidity Ratio at Peak Load' => 'Humedad exterior con carga pico'
    }.fetch(key) { |nokey| nokey }
  end

  def self.cte_outdoor_air_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @aire_exterior = {}
    @aire_exterior[:title] = 'Aire exterior'
    @aire_exterior[:tables] = general_tables

    if name_only == true
      return @aire_exterior
    end

    # add in general information from method
    general_tables << CTELib_Reporting.tabla_de_aire_exterior(model, sqlFile, runner)


    return @aire_exterior
  end

  def self.cte_demandas_por_componentes(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @demandas_por_componente = {}
    @demandas_por_componente[:title] = "Demanda por componentes"
    @demandas_por_componente[:tables] = general_tables

    if name_only == true
        return @demandas_por_componente
    end

    # add in general information from method
    general_tables << CTELib_Reporting.tabla_demanda_por_componentes(model, sqlFile, runner, 'invierno')
    general_tables << CTELib_Reporting.tabla_demanda_por_componentes(model, sqlFile, runner, 'verano')

    return @demandas_por_componente

  end

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
    general_tables << self.cte_envelope_fenestration_table(model, sqlfile, runner)

    return @mediciones
  end

   # mediciones_segun_CTE section
  def self.cte_mediciones_de_superficies(model, sqlFile, runner, name_only = false)
    general_tables = []

    @mediciones_segun_CTE = {}
    @mediciones_segun_CTE[:title] = 'Superficies y compacidad'
    @mediciones_segun_CTE[:tables] = general_tables #esto no se lo que es

    if name_only == true
        return @mediciones_segun_CTE
    end

    general_tables << CTELib_Reporting.cte_mediciones_generales_table(model, sqlFile, runner)
    return @mediciones_segun_CTE
  end

  # Energía final por servicios
  def self.cte_energia_final_por_servicios(model, sqlFile, runner, name_only = false)
    general_tables = []

    @mediciones_segun_CTE = {}
    @mediciones_segun_CTE[:title] = 'Energía final por servicios'
    @mediciones_segun_CTE[:tables] = general_tables #esto no se lo que es

    if name_only == true
        return @mediciones_segun_CTE
    end

    general_tables << CTELib_Reporting.tabla_de_energias(model, sqlFile, runner)
    return @mediciones_segun_CTE
  end

  ### -----------------------------------------------------------------------------------
  ### Fin métodos propios ---------------------------------------------------------------
  ### -----------------------------------------------------------------------------------


  # building_summary section
  def self.building_summary_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @building_summary_section = {}
    @building_summary_section[:title] = 'Datos generales'
    @building_summary_section[:tables] = general_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @building_summary_section
    end

    # add in general information from method
    general_tables << CTELib_Reporting.general_building_information_table(model, sqlFile, runner)
    general_tables << CTELib_Reporting.weather_summary_table(model, sqlFile, runner)
    general_tables << CTELib_Reporting.setpoint_not_met_summary_table(model, sqlFile, runner)
    site_power_generation_table = CTELib_Reporting.site_power_generation_table(model, sqlFile, runner)
    if site_power_generation_table
      general_tables << CTELib_Reporting.site_power_generation_table(model, sqlFile, runner)
    end

    return @building_summary_section
  end

  # annual_overview section
  def self.annual_overview_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    annual_tables = []

    # gather data for section
    @annual_overview_section = {}
    @annual_overview_section[:title] = 'Uso anual de energía'
    @annual_overview_section[:tables] = annual_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @annual_overview_section
    end

    # add in annual overview from method
    annual_tables << CTELib_Reporting.output_data_end_use_table(model, sqlFile, runner)
    annual_tables << CTELib_Reporting.output_data_energy_use_table(model, sqlFile, runner)
    annual_tables << CTELib_Reporting.output_data_end_use_electricity_table(model, sqlFile, runner)
    annual_tables << CTELib_Reporting.output_data_end_use_gas_table(model, sqlFile, runner)

    return @annual_overview_section
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section

  def self.general_building_information_table(model, sqlFile, runner, name_only=false)
    # general building information type data output
    general_building_information = {}
    general_building_information[:title] = 'Edificio' # 'Building Summary' # name will be with section
    general_building_information[:header] = %w(Informacion Valor Unidades)
    general_building_information[:units] = [] # won't populate for this table since each row has different units
    general_building_information[:data] = []

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @general_building_information
    end

    # structure ID / building name
    value = model.getBuilding.name.to_s
    general_building_information[:data] << ['Nombre del edificio', value, 'building_name']
    runner.registerValue('CTE Nombre del edificio', value, 'building_name')

    # net site energy
    value = OpenStudio.convert(sqlFile.netSiteEnergy.get, 'GJ', 'kWh').get
    value_neat = OpenStudio.toNeatString(value, 0, true)
    general_building_information[:data] << ['Consumo neto de energía final', value_neat, 'kWh']
    runner.registerValue('CTE Consumo neto de energía final', value, 'kWh')

    # total building area
    query = 'SELECT Value FROM tabulardatawithstrings WHERE '
    query << "ReportName='AnnualBuildingUtilityPerformanceSummary' and " # Notice no space in SystemSummary
    query << "ReportForString='Entire Facility' and "
    query << "TableName='Building Area' and "
    query << "RowName='Total Building Area' and "
    query << "ColumnName='Area' and "
    query << "Units='m2';"
    query_results = sqlFile.execAndReturnFirstDouble(query)
    if query_results.empty?
      runner.registerError('Did not find value for total building area.')
      return false
    else
      value = query_results.get
      general_building_information[:data] << ['Superficie total del edificio', value.to_f.round(2), 'm^2']
      runner.registerValue('CTE Superficie total del edificio', value, 'm^2')
    end

    # EUI
    eui =  sqlFile.netSiteEnergy.get / query_results.get
    value = OpenStudio.convert(eui, 'GJ/m^2', 'kWh/m^2').get
    general_building_information[:data] << ['Intensidad energética (E.final)', value.to_f.round(2), 'kWh/m^2']
    runner.registerValue('CTE Intensidad energética (E.final)', value, 'kWh/m^2')

    return general_building_information
  end

  # create table of space type breakdown
  def self.space_type_breakdown_section(model, sqlFile, runner, name_only = false)
    # space type data output
    output_data_space_type_breakdown = {}
    output_data_space_type_breakdown[:title] = ''
    output_data_space_type_breakdown[:header] = ['Tipo de Espacio', 'Superficie útil']
    output_data_space_type_breakdown[:units] = ['', 'm^2']
    output_data_space_type_breakdown[:data] = []
    output_data_space_type_breakdown[:chart_type] = 'simple_pie'
    output_data_space_type_breakdown[:chart] = []

    # gather data for section
    @output_data_space_type_breakdown_section = {}
    @output_data_space_type_breakdown_section[:title] = 'Reparto por tipos de espacios'
    @output_data_space_type_breakdown_section[:tables] = [output_data_space_type_breakdown] # only one table for this section

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @output_data_space_type_breakdown_section
    end

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
      display = 'Sin tipo de espacio'
      value = OpenStudio.convert(no_space_type_area_counter, 'm^2', units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      output_data_space_type_breakdown[:data] << [display, value_neat]
      runner.registerValue("CTE Tipo de espacio - #{display}", value, units)

      # data for graph
      color = 'rgb(20,20,20)' # maybe do random or let d3 pick color instead of this?
      output_data_space_type_breakdown[:chart] << JSON.generate(label: 'Sin tipo de espacio asignado', value: OpenStudio.convert(no_space_type_area_counter, 'm^2', 'm^2'), color: color)
    end

    return @output_data_space_type_breakdown_section
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section
  def self.output_data_end_use_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use = {}
    output_data_end_use[:title] = 'Uso de energía final por servicio'
    output_data_end_use[:header] = ['Servicio', 'Consumo']
    target_units = 'kWh'
    output_data_end_use[:units] = ['', target_units]
    output_data_end_use[:data] = []
    output_data_end_use[:chart_type] = 'simple_pie'
    output_data_end_use[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    counter = 0
    OpenStudio::EndUseCategoryType.getValues.each do |end_use|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription #aquí es un nombre de categoría:
        # Heating, Cooling, Interior Lighting, Exterior Lighting, Interior Equipment, Exterior Equipment,
        # Fans, Pumps, Heat Rejection, Humidification, Heat Recovery, Water Systems, Refrigeration, Generators

      query_elec = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Electricity'"
      query_gas = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Natural Gas'"
      query_add = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Additional Fuel'"
      query_dc = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'District Cooling'"
      query_dh = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'District Heating'"
      results_elec = sqlFile.execAndReturnFirstDouble(query_elec).get
      results_gas = sqlFile.execAndReturnFirstDouble(query_gas).get
      results_add = sqlFile.execAndReturnFirstDouble(query_add).get
      results_dc = sqlFile.execAndReturnFirstDouble(query_dc).get
      results_dh = sqlFile.execAndReturnFirstDouble(query_dh).get
      total_end_use = results_elec + results_gas + results_add + results_dc + results_dh
      value = OpenStudio.convert(total_end_use, 'GJ', target_units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      end_use_trans = self.translate(end_use)
      output_data_end_use[:data] << [end_use_trans, value_neat]
      runner.registerValue("CTE Uso energia final - #{end_use_trans}", value, target_units)
      if value > 0
        output_data_end_use[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[counter])
      end

      counter += 1
    end

    return output_data_end_use
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section
  def self.output_data_end_use_electricity_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use_electricity = {}
    output_data_end_use_electricity[:title] = 'Uso de energía final - Electricidad'
    output_data_end_use_electricity[:header] = ['Servicio', 'Consumo']
    target_units = 'kWh'
    output_data_end_use_electricity[:units] = ['', target_units]
    output_data_end_use_electricity[:data] = []
    output_data_end_use_electricity[:chart_type] = 'simple_pie'
    output_data_end_use_electricity[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    counter = 0
    OpenStudio::EndUseCategoryType.getValues.each do |end_use|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Electricity'"
      results = sqlFile.execAndReturnFirstDouble(query)
      value = OpenStudio.convert(results.get, 'GJ', target_units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      end_use_trans = self.translate(end_use)
      output_data_end_use_electricity[:data] << [end_use_trans, value_neat]
      runner.registerValue("CTE energia final Electricidad - #{end_use_trans}", value, target_units)
      if value > 0
        output_data_end_use_electricity[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[counter])
      end

      counter += 1
    end

    return output_data_end_use_electricity
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section
  def self.output_data_end_use_gas_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use_gas = {}
    output_data_end_use_gas[:title] = 'Uso de energía final - Gas'
    output_data_end_use_gas[:header] = ['Servicio', 'Consumo']
    target_units = 'kWh'
    output_data_end_use_gas[:units] = ['', target_units]
    output_data_end_use_gas[:data] = []
    output_data_end_use_gas[:chart_type] = 'simple_pie'
    output_data_end_use_gas[:chart] = []
    output_data_end_use_gas[:chart_type] = 'simple_pie'
    output_data_end_use_gas[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    counter = 0
    OpenStudio::EndUseCategoryType.getValues.each do |end_use|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Natural Gas'"
      results = sqlFile.execAndReturnFirstDouble(query)
      value = OpenStudio.convert(results.get, 'GJ', target_units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      end_use_trans = self.translate(end_use)
      output_data_end_use_gas[:data] << [end_use_trans, value_neat]
      runner.registerValue("CTE energia final Gas Natural - #{end_use_trans}", value, target_units)
      if value > 0
        output_data_end_use_gas[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[counter])
      end

      counter += 1
    end

    return output_data_end_use_gas
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section
  def self.output_data_energy_use_table(model, sqlFile, runner)
    # energy use data output
    output_data_energy_use = {}
    output_data_energy_use[:title] = 'Energia Final por vector energético'
    output_data_energy_use[:header] = ['Combustible', 'Consumo']
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
    counter = 0
    OpenStudio::EndUseFuelType.getValues.each do |fuel_type|
      # get fuel type and units
      fuel_type = OpenStudio::EndUseFuelType.new(fuel_type).valueDescription
      next if fuel_type == 'Water'
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= 'Total End Uses' and ColumnName= '#{fuel_type}'"
      results = sqlFile.execAndReturnFirstDouble(query)
      target_units = 'kWh'
      value = OpenStudio.convert(results.get, 'GJ', target_units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      fuel_type_trans = self.translate(fuel_type)
      output_data_energy_use[:data] << [fuel_type_trans, value_neat]
      runner.registerValue("CTE combustible - #{fuel_type_trans}", value, target_units)

      if value > 0
        output_data_energy_use[:chart] << JSON.generate(label: fuel_type, value: value, color: color[counter])
      end

      counter += 1
    end

    return output_data_energy_use
  end

  # create table for advisory messages
  def self.setpoint_not_met_summary_table(model, sqlFile, runner)
    # unmet hours data output
    setpoint_not_met_summary = {}
    setpoint_not_met_summary[:title] = 'Horas fuera de consigna'
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
        value_neat = value
        setpoint_not_met_summary[:data] << [display, value_neat]
        runner.registerValue("CTE horas fuera de consigna - #{display}", value, 'hr')

      end
    end # setpoint_not_met_cat.each do

    return setpoint_not_met_summary
  end

  # summary of what to show for each type of air loop component
  def self.air_loop_component_summary_logic(component, model)
    if component.to_AirLoopHVACOutdoorAirSystem.is_initialized
      component = component.to_AirLoopHVACOutdoorAirSystem.get
      # get ControllerOutdoorAir
      controller_oa = component.getControllerOutdoorAir

      sizing_source_units = 'm^3/s'
      sizing_target_units = 'm^3/s'
      if controller_oa.maximumOutdoorAirFlowRate.is_initialized
        sizing_ip = OpenStudio.convert(controller_oa.maximumOutdoorAirFlowRate.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'm^3/s'
      value_target_units = 'm^3/s'
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        value_ip = OpenStudio.convert(controller_oa.minimumOutdoorAirFlowRate.get, value_source_units, value_target_units).get
        value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      else
        value_ip_neat = 'Autosized'
      end
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, 'Minimum Outdoor Air Flow Rate', value_ip_neat, value_target_units, '']

    elsif component.to_CoilCoolingDXSingleSpeed.is_initialized
      component = component.to_CoilCoolingDXSingleSpeed.get
      sizing_source_units = 'W'
      sizing_target_units = 'W'
      if component.ratedTotalCoolingCapacity.is_initialized
        sizing_ip = OpenStudio.convert(component.ratedTotalCoolingCapacity.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'COP'
      value_target_units = 'COP'
      value_ip = component.ratedCOP.get
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      description = 'Rated COP'
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, description, value_ip_neat, value_target_units, '']

    elsif component.to_CoilCoolingDXTwoSpeed.is_initialized
      component = component.to_CoilCoolingDXTwoSpeed.get

      # high speed
      sizing_source_units = 'W'
      sizing_target_units = 'W'
      if component.ratedHighSpeedTotalCoolingCapacity.is_initialized
        sizing_ip = OpenStudio.convert(component.ratedHighSpeedTotalCoolingCapacity.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'COP'
      value_target_units = 'COP'
      value_ip = component.ratedHighSpeedCOP.get
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      description = 'Rated COP'
      data_array = ["#{component.iddObject.name} - HighSpeed", sizing_ip_neat, sizing_target_units, description, value_ip_neat, value_target_units, '']

      # low speed
      sizing_source_units = 'W'
      sizing_target_units = 'W'
      if component.ratedLowSpeedTotalCoolingCapacity.is_initialized
        sizing_ip = OpenStudio.convert(component.ratedLowSpeedTotalCoolingCapacity.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'COP'
      value_target_units = 'COP'
      value_ip = component.ratedLowSpeedCOP.get
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      description = 'Rated COP'
      data_array = ["#{component.iddObject.name} (cont) - LowSpeed", sizing_ip_neat, sizing_target_units, description, value_ip_neat, value_target_units, '']

    elsif component.iddObject.name == 'OS:Coil:Cooling:Water'
      component = component.to_CoilCoolingWater.get
      sizing_source_units = 'm^3/s'
      sizing_target_units =  'm^3/s'
      if component.designWaterFlowRate.is_initialized
        sizing_ip = OpenStudio.convert(component.designWaterFlowRate.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value = component.plantLoop.get.name
      description = 'Plant Loop'
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, description, value, '', '']

    elsif component.to_CoilHeatingGas.is_initialized
      component = component.to_CoilHeatingGas.get
      sizing_source_units = 'W'
      sizing_target_units = 'W'
      if component.nominalCapacity.is_initialized
        sizing_ip = OpenStudio.convert(component.nominalCapacity.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = ''
      value_target_units = ''
      value_ip = component.gasBurnerEfficiency
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      description = 'Gas Burner Efficiency'
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, description, value_ip_neat, value_target_units, '']

    elsif component.to_CoilHeatingElectric.is_initialized
      component = component.to_CoilHeatingElectric.get
      sizing_source_units = 'W'
      sizing_target_units = 'W'
      if component.nominalCapacity.is_initialized
        sizing_ip = OpenStudio.convert(component.nominalCapacity.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = ''
      value_target_units = ''
      value_ip = component.efficiency
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      description = 'Efficiency'
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, description, value_ip_neat, value_target_units, '']

    elsif component.to_CoilHeatingDXSingleSpeed.is_initialized
      component = component.to_CoilHeatingDXSingleSpeed.get
      sizing_source_units = 'W'
      sizing_target_units = 'W'
      if component.ratedTotalHeatingCapacity.is_initialized
        sizing_ip = OpenStudio.convert(component.ratedTotalHeatingCapacity.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'COP'
      value_target_units = 'COP'
      value_ip = component.ratedCOP # is optional for CoilCoolingDXSingleSpeed but is just a double for CoilHeatingDXSingleSpeed
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      description = 'Rated COP'
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, description, value_ip_neat, value_target_units, '']

    elsif component.to_CoilHeatingWater.is_initialized
      component = component.to_CoilHeatingWater.get
      sizing_source_units = 'm^3/s'
      sizing_target_units = 'm^3/s'
      if component.maximumWaterFlowRate.is_initialized
        sizing_ip = OpenStudio.convert(component.maximumWaterFlowRate.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value = component.plantLoop.get.name
      description = 'Plant Loop'
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, description, value, '', '']

    elsif component.to_FanConstantVolume.is_initialized
      component = component.to_FanConstantVolume.get
      sizing_source_units = 'm^3/s'
      sizing_target_units = 'm^3/s'
      if component.maximumFlowRate.is_initialized
        sizing_ip = OpenStudio.convert(component.maximumFlowRate.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'Pa'
      value_target_units = 'Pa'
      value_ip = OpenStudio.convert(component.pressureRise, value_source_units, value_target_units).get
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, 'Pressure Rise', value_ip_neat, value_target_units, '']

    elsif component.to_FanVariableVolume.is_initialized
      component = component.to_FanVariableVolume.get
      sizing_source_units = 'm^3/s'
      sizing_target_units = 'm^3/s'
      if component.maximumFlowRate.is_initialized
        sizing_ip = OpenStudio.convert(component.maximumFlowRate.get, sizing_source_units, sizing_target_units).get
        sizing_ip_neat = OpenStudio.toNeatString(sizing_ip, 2, true)
      else
        sizing_ip_neat = 'Autosized'
      end
      value_source_units = 'Pa'
      value_target_units = 'Pa'
      value_ip = OpenStudio.convert(component.pressureRise, value_source_units, value_target_units).get
      value_ip_neat = OpenStudio.toNeatString(value_ip, 2, true)
      data_array = [component.iddObject.name, sizing_ip_neat, sizing_target_units, 'Pressure Rise', value_ip_neat, value_target_units, '']

    elsif component.iddObject.name == 'OS:SetpointManager:Scheduled'
      setpoint = component.to_SetpointManagerScheduled.get
      supply_air_temp_schedule = setpoint.schedule
      schedule_values = OsLib_Schedules.getMinMaxAnnualProfileValue(model, supply_air_temp_schedule)
      if schedule_values.nil?
        schedule_values_pretty = "can't inspect schedule"
        target_units = ''
      else
        if setpoint.controlVariable.to_s == 'Temperature'
          source_units = 'C'
          target_units = 'C'
          schedule_values_pretty = "#{OpenStudio.convert(schedule_values['min'], source_units, target_units).get.round(1)} to #{OpenStudio.convert(schedule_values['max'], source_units, target_units).get.round(1)}"
        else # TODO: - add support for other control variables
          schedule_values_pretty = "#{schedule_values['min']} to #{schedule_values['max']}"
          target_units = 'raw si values'
        end
      end
      data_array = [setpoint.iddObject.name, '', '', "Control Variable - #{setpoint.controlVariable}", schedule_values_pretty, target_units, '']

    elsif component.iddObject.name == 'OS:SetpointManager:SingleZone:Reheat'
      setpoint = component.to_SetpointManagerSingleZoneReheat.get
      control_zone = setpoint.controlZone
      if control_zone.is_initialized
        control_zone_name = control_zone.get.name
      else
        control_zone_name = ''
      end
      data_array = [component.iddObject.name, '', '', 'Control Zone', control_zone_name, '', '']

    else
      data_array = [component.iddObject.name, '', '', '', '', '', '']
    end

    # TODO: - add support for more types of objects

    # thermal zones and terminals are handled directly in the air loop helper
    # since they operate over a collection of objects vs. a single component

    return data_array
  end

  # create table for constructions
  def self.cte_envelope_fenestration_table(model, sqlFile, runner)

    # Conditioned Window-Wall Ratio and Skylight-Roof Ratio
    fenestration_data = {}
    fenestration_data[:title] = 'Porcentaje de huecos'
    fenestration_data[:header] = %w(Descripción Total Norte Este Sur Oeste)
    target_units = '%' # it is a bit odd, but eplusout.htm calls the tale ratio, but shows as percentage. I'll match that here for now.
    fenestration_data[:units] = ['', target_units, target_units, target_units, target_units, target_units]
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
        runner.registerError('Did not find value for Window or Skylight Ratio')
        return false
      else
        # add data
        display = self.translate(fenestration)
        fenestration_data[:data] << [display, total.get, north.get, east.get, south.get, west.get]
        runner.registerValue("CTE #{display}", total.get, target_units)

        # skylight
        # skylight seems to provide back percentage vs. fraction. Changing to fraction to match vertical fenestration.
        fenestration_data[:data] << ['Porcentaje de huecos en cubierta', skylight.get, '', '', '', '']
        runner.registerValue('CTE Porcentaje de huecos en cubierta', skylight.get, target_units)

      end
    end

    return fenestration_data
  end

  # create table of space type details
  def self.space_type_details_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    output_data_space_type_detail_tables = []

    # gather data for section
    @output_data_space_type_section = {}
    @output_data_space_type_section[:title] = 'Tipos de espacios - Resumen'
    @output_data_space_type_section[:tables] = output_data_space_type_detail_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @output_data_space_type_section
    end

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

    return @output_data_space_type_section
  end

  # create template section
  def self.weather_summary_table(model, sqlFile, runner)
    # data for query
    rows = ['Weather File', 'Latitude', 'Longitude', 'Elevation', 'Time Zone', 'North Axis Angle'] # el contenido son claves

    # create table
    table = {}
    table[:title] = 'Clima'
    table[:header] = ['', 'Valor']
    table[:units] = []
    table[:data] = []

    # run query and populate table
    rows.each do |row|
      row_data = [self.translate(row)]
      query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='InputVerificationandResultsSummary' and TableName='General' and RowName= '#{row}' and ColumnName= 'Value'"
      results = sqlFile.execAndReturnFirstString(query)
      row_data << results
      table[:data] << row_data
    end

    return table
  end

  # create template section
  def self.building_performance_table(model, sqlFile, runner)
    # create a second table
    building_performance_table = {}
    building_performance_table[:title] = 'Eficiencia energética'
    building_performance_table[:header] = %w(Descripción Valor)
    building_performance_table[:units] = []
    building_performance_table[:data] = []

    # add rows to table
    # building_performance_table[:data] << ["Vanilla",1.5]

    return building_performance_table
  end

  # create template section
  def self.site_power_generation_table(model, sqlFile, runner)
    # create a second table
    headers = ['', 'Rated Capacity', 'Annual Energy Generated']
    site_power_generation_table = {}
    site_power_generation_table[:title] = 'Generación de energía renovable'
    site_power_generation_table[:header] = ['', 'Capacidad nominal', 'Energía anual generada']
    site_power_generation_table[:source_units] = ['', 'kW', 'GJ']
    site_power_generation_table[:units] = ['', 'kW', 'kWh']
    site_power_generation_table[:data] = []

    # create string for LEED advisories
    rows = []
    rows << 'Photovoltaic'
    rows << 'Wind'

    # loop through advisory messages
    value_found = false
    rows.each do |row|
      row_data = [self.translate(row)]
      column_counter = -1
      headers.each do |header|
        column_counter += 1
        next if column_counter == 0
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='LEEDsummary' and RowName= '#{row}' and ColumnName='#{header}';"
        data = sqlFile.execAndReturnFirstDouble(query).get
        data_ip = OpenStudio.convert(data, site_power_generation_table[:source_units][column_counter], site_power_generation_table[:units][column_counter]).get
        if data > 0 then value_found = true end

        row_data << data_ip.round(2)
      end
      site_power_generation_table[:data] << row_data
    end

    if value_found
      return site_power_generation_table
    else
      return false
    end
  end

  def self.zone_summary_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    template_tables = []

    # gather data for section
    @zone_summary_section = {}
    @zone_summary_section[:title] = 'Resumen de zonas'
    @zone_summary_section[:tables] = template_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @zone_summary_section
    end

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
    source_units_area = 'm^2'
    target_units_area = 'm^2'
    source_units_area_per_person = 'm^2/person'
    target_units_area_per_person = 'm^2/person'
    source_units_volume = 'm^3'
    target_units_volume = 'm^3'
    source_units_pd = 'W/m^2'
    target_units_pd = 'W/m^2'
    zone_summary_table[:units] = ['', target_units_area, '', '', target_units_volume, '', target_units_area, target_units_area, target_units_pd, target_units_area_per_person, target_units_pd]
    zone_summary_table[:source_units] = ['', source_units_area, '', '', source_units_volume, '', source_units_area, source_units_area, source_units_pd, source_units_area_per_person, source_units_pd] # used for conversation, not needed for rendering.
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

    # add zone_summary_table to array of tables
    template_tables << zone_summary_table

    # data for query
    columns_query = ['', 'Heating/Cooling', 'Calculated Design Load', 'User Design Load', 'Calculated Design Air Flow', 'User Design Air Flow', 'Date/Time Of Peak', 'Outdoor Temperature at Peak Load', 'Outdoor Humidity Ratio at Peak Load']

    # populate dynamic rows
    rows_name_query = "SELECT DISTINCT  RowName FROM tabulardatawithstrings WHERE ReportName='HVACSizingSummary' and TableName='Zone Cooling'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end

    # create zone_dd_table
    zone_dd_table = {}
    zone_dd_table[:title] = 'Dimensionado de calefacción y refrigeración por zonas'
    zone_dd_table[:header] = columns_query.map { |col| self.translate(col) }
    zone_dd_table[:units] = ['', '', '', '', 'm^3/s', 'm^3/s', '', 'C', 'lbWater/lbAir']
    zone_dd_table[:source_units] = ['', '', '', '', 'm^3/s', 'm^3/s', '', 'C', 'lbWater/lbAir'] # used for conversion, not needed for rendering.
    zone_dd_table[:data] = []
    # run query and populate zone_dd_table
    rows.each do |row|
      # populate cooling row
      row_data = [row, 'Refrigeración']
      column_counter = -1
      columns_query.each do |header|
        column_counter += 1
        next if header == '' || header == 'Heating/Cooling'
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='HVACSizingSummary' and TableName='Zone Cooling' and RowName= '#{row}' and ColumnName= '#{header}'"
        if not zone_dd_table[:source_units][column_counter] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_dd_table[:source_units][column_counter], zone_dd_table[:units][column_counter]).get
          row_data << row_data_ip.round(2)
        elsif header == 'Calculated Design Load' || header == 'User Design Load'
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, 'W', 'kW').get
          row_data << "#{row_data_ip.round(2)} (kW)"
        else
          results = sqlFile.execAndReturnFirstString(query)
          row_data << results
        end
      end
      zone_dd_table[:data] << row_data

      # populate heating row
      row_data = [row, 'Calefacción']
      column_counter = -1
      columns_query.each do |header|
        column_counter += 1
        next if header == '' || header == 'Heating/Cooling'
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='HVACSizingSummary' and TableName='Zone Heating' and RowName= '#{row}' and ColumnName= '#{header}'"
        if not zone_dd_table[:source_units][column_counter] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_dd_table[:source_units][column_counter], zone_dd_table[:units][column_counter]).get
          row_data << row_data_ip.round(2)
        elsif header == 'Calculated Design Load' || header == 'User Design Load'
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, 'W', 'kW').get
          row_data << "#{row_data_ip.round(2)} (kW)"
        else
          results = sqlFile.execAndReturnFirstString(query)
          row_data << results
        end
      end
      zone_dd_table[:data] << row_data
    end

    # add zone_dd_table to array of tables
    template_tables << zone_dd_table

    return @zone_summary_section
  end


  # create source_energy_section
  def self.source_energy_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    source_energy_section_tables = []

    # gather data for section
    @source_energy_section = {}
    @source_energy_section[:title] = 'Energía final y primaria'
    @source_energy_section[:tables] = source_energy_section_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @source_energy_section
    end

    # ============== Energía final y primaria
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
      column_counter = -1
      columns.each do |col|
        column_counter += 1
        next if col == ''
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='Site and Source Energy' and RowName= '#{row}' and ColumnName= '#{col}'"
        results = sqlFile.execAndReturnFirstDouble(query)
        row_data_ip = OpenStudio.convert(results.to_f, source_energy_table[:source_units][column_counter], source_energy_table[:units][column_counter]).get
        row_data << row_data_ip.round(1)
      end
      source_energy_table[:data] << row_data
    end

    source_energy_section_tables << source_energy_table

    # ========== Factores de paso
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

    source_energy_section_tables << source_energy_table

    return @source_energy_section
  end

end


module CTELib_Reporting
  #======== Elementos generales  ============
  # variablesdisponiblesquery = "SELECT DISTINCT VariableName, ReportingFrequency FROM ReportVariableDataDictionary "

  #======== Tabla general de mediciones =====
  def self.cte_mediciones_generales_table(model, sqlFile, runner)
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
      general_table[:data] << [" - #{traduce[clave]}", valor.round(0), (valor/superficiehabitable).round(1)]
    end

    general_table[:data] << ['<b>Servicios No EPB</b>', totalUsosNoEPB.round(0),
        "<b>#{(totalUsosNoEPB/superficiehabitable).round(1)}</b>"]
    usosNoEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", valor.round(0), (valor/superficiehabitable).round(1)]
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
    contenedor_general[:title] = "Medición de elementos de la envolvente térmica"
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
    contenedor_general[:title] = "Medición de puentes térmicos"
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
        row_data << row_data_ip.round(2)

        # para la media de todo el edificio
        medias[header] += row_data_ip * zoneVolume
      end

      table[:data] << row_data
    end

    row_data = ['Total edificio']
    table[:header].each do |header|
      next if header == ''
      row_data << (medias[header] / totalVolume).round(2)
    end
    table[:data] << row_data

    return table
  end


  def self.tabla_demanda_por_componentes(model, sqlFile, runner, periodo)
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
