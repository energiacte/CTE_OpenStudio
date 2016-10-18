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
require_relative "cte_lib"

module OsLib_Reporting
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
      'Natural Gas' => 'Gas Natural',
      'Additional Fuel' => 'Combustible adicional',
      'District Cooling' => 'Demanda de refrigeración',
      'District Heating' => 'Demanda de calefacción',
      'Water' => 'Agua',
      'Photovoltaic' => 'Fotovoltaica',
      'Wind' => 'Eólica'
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
    general_tables << CTE_tables.tabla_de_aire_exterior(model, sqlFile, runner)


    return @aire_exterior
  end

  def self.demandas_por_componentes(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @demandas_por_componente = {}
    @demandas_por_componente[:title] = "Demandas por componentes"
    @demandas_por_componente[:tables] = general_tables

    if name_only == true
        return @demandas_por_componente
    end

    # add in general information from method
    general_tables << CTE_tables.tabla_demanda_por_componentes(model, sqlFile, runner, 'invierno')
    general_tables << CTE_tables.tabla_demanda_por_componentes(model, sqlFile, runner, 'verano')

    return @demandas_por_componente

  end

  def self.mediciones_envolvente(model, sqlfile, runner, name_only = false)
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
    general_tables << CTE_tables.tabla_mediciones_envolvente(model, sqlfile, runner)
    general_tables << CTE_tables.tabla_mediciones_puentes_termicos(model, runner)

    return @mediciones
  end

   # mediciones_segun_CTE section
  def self.mediciones_de_superficies_segun_CTE(model, sqlFile, runner, name_only = false)
    # array to hold tables
    general_tables = []

    # gather data for section
    @mediciones_segun_CTE = {}
    @mediciones_segun_CTE[:title] = 'Mediciones de superficies segun CTE'
    @mediciones_segun_CTE[:tables] = general_tables #esto no se lo que es

    if name_only == true
        return @mediciones_segun_CTE
    end

    # add in general information from method
    general_tables << CTE_tables.tabla_mediciones_generales(model, sqlFile, runner)
    general_tables << CTE_tables.tabla_de_energias(model, sqlFile, runner)

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
    @building_summary_section[:title] = 'Resumen del Modelo (Building summary section)'
    @building_summary_section[:tables] = general_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @building_summary_section
    end

    # add in general information from method
    general_tables << OsLib_Reporting.general_building_information_table(model, sqlFile, runner)
    general_tables << OsLib_Reporting.weather_summary_table(model, sqlFile, runner)
    #~ general_tables << OsLib_Reporting.design_day_table(model, sqlFile, runner)
    general_tables << OsLib_Reporting.setpoint_not_met_summary_table(model, sqlFile, runner)
    # general_tables << OsLib_Reporting.site_performance_table(model,sqlFile,runner)
    site_power_generation_table = OsLib_Reporting.site_power_generation_table(model, sqlFile, runner)
    if site_power_generation_table
      general_tables << OsLib_Reporting.site_power_generation_table(model, sqlFile, runner)
    end

    return @building_summary_section
  end

  # annual_overview section
  def self.annual_overview_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    annual_tables = []

    # gather data for section
    @annual_overview_section = {}
    @annual_overview_section[:title] = 'Resumen anual' #'Annual Overview'
    @annual_overview_section[:tables] = annual_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @annual_overview_section
    end

    # add in annual overview from method
    annual_tables << OsLib_Reporting.output_data_end_use_table(model, sqlFile, runner)
    annual_tables << OsLib_Reporting.output_data_energy_use_table(model, sqlFile, runner)
    annual_tables << OsLib_Reporting.output_data_end_use_electricity_table(model, sqlFile, runner)
    annual_tables << OsLib_Reporting.output_data_end_use_gas_table(model, sqlFile, runner)

    return @annual_overview_section
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section

  def self.general_building_information_table(model, sqlFile, runner, name_only=false)
    # general building information type data output
    general_building_information = {}
    general_building_information[:title] = 'Resumen del Edificio' # 'Building Summary' # name will be with section
    general_building_information[:header] = %w(Informacion Valor Unidades)
    general_building_information[:units] = [] # won't populate for this table since each row has different units
    general_building_information[:data] = []

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @general_building_information
    end

    # structure ID / building name
    display = 'Nombre del edificio'
    target_units = 'building_name'
    value = model.getBuilding.name.to_s
    general_building_information[:data] << [display, value, target_units]
    runner.registerValue(display, value, target_units)

    # net site energy
    display = 'Consumo neto de energía final'
    source_units = 'GJ'
    target_units = 'kWh'
    value = OpenStudio.convert(sqlFile.netSiteEnergy.get, source_units, target_units).get
    value_neat = OpenStudio.toNeatString(value, 0, true)
    general_building_information[:data] << [display, value_neat, target_units]
    runner.registerValue(display, value, target_units)

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
      display = 'Superficie total del edificio'
      source_units = 'm^2'
      target_units = 'm^2'
      value = OpenStudio.convert(query_results.get, source_units, target_units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      general_building_information[:data] << [display, value_neat, target_units]
      runner.registerValue(display, value, target_units)
    end

    # EUI
    eui =  sqlFile.netSiteEnergy.get / query_results.get
    display = 'EUI'
    source_units = 'GJ/m^2'
    target_units = 'kWh/m^2'
    value = OpenStudio.convert(eui, source_units, target_units).get
    value_neat = OpenStudio.toNeatString(value, 2, true)
    general_building_information[:data] << [display, value_neat, target_units]
    runner.registerValue(display, value, target_units)

    return general_building_information
  end

  # create table of space type breakdown
  def self.space_type_breakdown_section(model, sqlFile, runner, name_only = false)
    # space type data output
    output_data_space_type_breakdown = {}
    output_data_space_type_breakdown[:title] = ''
    output_data_space_type_breakdown[:header] = ['Tipo de Espacio', 'Superficie útil']
    units = 'm^2'
    output_data_space_type_breakdown[:units] = ['', units]
    output_data_space_type_breakdown[:data] = []
    output_data_space_type_breakdown[:chart_type] = 'simple_pie'
    output_data_space_type_breakdown[:chart] = []

    # gather data for section
    @output_data_space_type_breakdown_section = {}
    @output_data_space_type_breakdown_section[:title] = 'Distribución por Tipos de Espacios'
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
      value = OpenStudio.convert(floor_area_si, 'm^2', units).get
      num_people = nil
      value_neat = OpenStudio.toNeatString(value, 0, true)
      output_data_space_type_breakdown[:data] << [display, value_neat]
      runner.registerValue("Tipo de espacio - #{display}", value, units)

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
      display = 'Sin Tipo de espacio'
      value = OpenStudio.convert(no_space_type_area_counter, 'm^2', units).get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      output_data_space_type_breakdown[:data] << [display, value_neat]
      runner.registerValue("Tipo de espacio - #{display}", value, units)

      # data for graph
      color = 'rgb(20,20,20)' # maybe do random or let d3 pick color instead of this?
      output_data_space_type_breakdown[:chart] << JSON.generate(label: 'Sin Tipo de Espacio asignado', value: OpenStudio.convert(no_space_type_area_counter, 'm^2', 'm^2'), color: color)
    end

    return @output_data_space_type_breakdown_section
  end

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section
  def self.output_data_end_use_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use = {}
    output_data_end_use[:title] = 'Uso de energía final'
    output_data_end_use[:header] = ['Uso', 'Consumo']
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
      runner.registerValue("CTE Uso energia final - #{end_use}", value, target_units)
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
    output_data_end_use_electricity[:header] = ['Uso', 'Consumo']
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
      runner.registerValue("CTE Energia final Electricidad - #{end_use_trans}", value, target_units)
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
    output_data_end_use_gas[:header] = ['Uso', 'Consumo']
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
      runner.registerValue("CTE Energia final Gas - #{end_use_trans}", value, target_units)
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
    output_data_energy_use[:title] = 'Energia Final (Energy Use)'
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
      runner.registerValue("Combustible - #{fuel_type_trans}", value, target_units)

      if value > 0
        output_data_energy_use[:chart] << JSON.generate(label: fuel_type_trans, value: value, color: color[counter])
      end

      counter += 1
    end

    return output_data_energy_use
  end

  # create table for advisory messages
  def self.setpoint_not_met_summary_table(model, sqlFile, runner)
    # unmet hours data output
    setpoint_not_met_summary = {}
    setpoint_not_met_summary[:title] = 'Resumen de Horas fuera de consigna'
    setpoint_not_met_summary[:header] = ['Tiempo fuera de consigna', 'Value']
    target_units = 'hr'
    setpoint_not_met_summary[:units] = ['', target_units]
    setpoint_not_met_summary[:data] = []

    # create string for rows (transposing from what is in tabular data)
    setpoint_not_met_cat = []
    setpoint_not_met_cat << 'Con calefacción'
    setpoint_not_met_cat << 'Con refrigeración'
    setpoint_not_met_cat << 'Con calefacción y ocupación'
    setpoint_not_met_cat << 'Con refrigeración y ocupación'

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
        display = cat
        source_units = 'hr'
        value = setpoint_not_met_cat_value.get
        value_neat = value # OpenStudio::toNeatString(value,0,true)
        setpoint_not_met_summary[:data] << [display, value_neat]
        runner.registerValue("Horas fuera de consigna - #{display}", value, target_units)

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
  def self.cte_envelope_section_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    envelope_tables = []

    # gather data for section
    @envelope_section = {}
    @envelope_section[:title] = 'Envelope'
    @envelope_section[:tables] = envelope_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @envelope_section
    end

    # Conditioned Window-Wall Ratio and Skylight-Roof Ratio
    fenestration_data = {}
    fenestration_data[:title] = 'Porcentaje de huecos'
    fenestration_data[:header] = %w(Descripción Total Norte Este Sur Oeste)
    target_units = '%' # it is a bit odd, but eplusout.htm calls the tale ratio, but shows as percentage. I'll match that here for now.
    fenestration_data[:units] = ['', target_units, target_units, target_units, target_units, target_units]
    fenestration_data[:data] = []

    # create string for rows
    fenestrations = []
    fenestrations << 'Porcentaje bruto de huecos (Hueco-muro)' # [%]

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
        display = fenestration
        fenestration_data[:data] << [display, total.get, north.get, east.get, south.get, west.get]
        runner.registerValue("#{display}", total.get, target_units)

        # skylight
        # skylight seems to provide back percentage vs. fraction. Changing to fraction to match vertical fenestration.
        fenestration_data[:data] << ['Porcentaje de lucernarios', skylight.get, '', '', '', '']
        runner.registerValue('CTE Porcentaje de lucernarios (lucernario-cubierta)', skylight.get, target_units)

      end
    end

    envelope_tables << fenestration_data

    return @envelope_section
  end

  # create table of space type details
  def self.space_type_details_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    output_data_space_type_detail_tables = []

    # gather data for section
    @output_data_space_type_section = {}
    @output_data_space_type_section[:title] = 'Resumen de tipos de espacios'
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
      output_data_space_type_details[:title] = "#{spaceType.name}<br>(#{space_name_list.uniq.size} spaces and #{zone_name_list.uniq.size} thermal zones)"
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
          def_units = 'm^2/superficie útil m^2'
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
          inst_units = 'm^3/s/superficie útil m^2'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
        if instance.flowperExteriorSurfaceArea.is_initialized
          inst_value = OpenStudio.convert(instance.flowperExteriorSurfaceArea.get, 'm/s', 'm/s').get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'm^3/s/superficie exterior m^2'
          count = ''
          output_data_space_type_details[:data] << [instance_display, inst_value_neat, inst_units, count]
        end
        if instance.flowperExteriorWallArea.is_initialized # uses same input as exterior surface area but different calc method
          inst_value = OpenStudio.convert(instance.flowperExteriorWallArea.get, 'm/s', 'm/s').get
          inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
          inst_units = 'm^3/s/superficie exterior m^2'
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
            output_data_space_type_details[:data] << ["#{instance_display} (método aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end
          if instance.outdoorAirFlowperFloorArea > 0
            inst_value = OpenStudio.convert(instance.outdoorAirFlowperFloorArea, 'm/s', 'm/s').get
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            inst_units = 'm^3/s/superficie útil m3/s/m2'
            output_data_space_type_details[:data] << ["#{instance_display} (método aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end
          if instance.outdoorAirFlowRate > 0
            inst_value = OpenStudio.convert(instance.outdoorAirFlowRate, 'm^3/s', 'm^3/s').get
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            inst_units = 'm^3/s'
            output_data_space_type_details[:data] << ["#{instance_display} (método aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
          end
          if instance.outdoorAirFlowAirChangesperHour > 0
            inst_value = instance.outdoorAirFlowAirChangesperHour
            inst_value_neat = OpenStudio.toNeatString(inst_value, 4, true)
            inst_units = 'ren/h'
            output_data_space_type_details[:data] << ["#{instance_display} (método aire exterior #{outdoor_air_method})", inst_value_neat, inst_units, count]
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
    report_name = 'InputVerificationandResultsSummary'
    table_name = 'Datos climáticos generales'
    columns = ['', 'Valor'] # el contenido son claves
    rows = ['Archivo de clima', 'Latitud', 'Longitud', 'Altitud', 'Zona Horaria', 'Ángulo con el norte'] # el contenido son claves

    # create table
    table = {}
    table[:title] = 'Resumen climático'
    table[:header] = ['', 'Valor']
    table[:units] = []
    table[:data] = []

    # run query and populate table
    rows.each do |row|
      row_data = [row]
      column_counter = -1
      columns.each do |header|
        column_counter += 1
        next if header == ''
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}' and RowName= '#{row}' and ColumnName= '#{header}'"
        results = sqlFile.execAndReturnFirstString(query) # this is first time I needed string vs. double for weather file
        # TODO: - would be nice to get units from first column
        row_data << results
      end

      table[:data] << row_data
    end

    return table
  end

  # create template section
  def self.building_performance_table(model, sqlFile, runner)
    # create a second table
    building_performance_table = {}
    building_performance_table[:title] = 'Eficiencia energética del edificio'
    building_performance_table[:header] = %w(Descripción Valor)
    building_performance_table[:units] = []
    building_performance_table[:data] = []

    # add rows to table
    # building_performance_table[:data] << ["Vanilla",1.5]

    return building_performance_table
  end

  # create template section
  def self.site_performance_table(model, sqlFile, runner)
    # create a second table
    site_performance_table = {}
    site_performance_table[:title] = 'Site Performance'
    site_performance_table[:header] = %w(Descripción Valor)
    site_performance_table[:units] = []
    site_performance_table[:data] = []

    # add rows to table
    # site_performance_table[:data] << ["Vanilla",1.5]

    return site_performance_table
  end

  # create template section
  def self.site_power_generation_table(model, sqlFile, runner)
    # create a second table
    site_power_generation_table = {}
    site_power_generation_table[:title] = 'Resumen de fuentes de energía renovable'
    site_power_generation_table[:header] = ['', 'Capacidad nominal', 'Generación anual de energía']
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
      row_data = [translate(row)]
      column_counter = -1
      site_power_generation_table[:header].each do |header|
        origheader = { 'Capacidad nominal'=>'Rated Capacity',
                       'Generación anual de energía'=>'Annual Energy Generated' }.fetch(header) { |nokey| nokey }
        column_counter += 1
        next if column_counter == 0
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='LEEDsummary' and RowName= '#{row}' and ColumnName='#{origheader}';"
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
    report_name = 'InputVerificationandResultsSummary'
    table_name = 'Resumen de zonas'
    columns = ['', 'Area', 'Acondicionada (Y/N)', 'Parte de la superficie útil (Y/N)', 'Volumen', 'Multiplicador', 'Superficie bruta de muro', 'Superficie acristalada', 'Iluminación', 'Ocupantes', 'Carga enchufada y de procesos']

    # test looking at getting entire table to get rows
    # query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}'"
    # results = sqlFile.execAndReturnVectorOfString(query).get

    # populate dynamic rows
    rows_name_query = "SELECT DISTINCT  RowName FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end

    # rows = ['Total','Conditioned Total','Unconditioned Total','Not Part of Total']

    # create zone_summary_table
    zone_summary_table = {}
    zone_summary_table[:title] = table_name
    zone_summary_table[:header] = columns
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
      row_data = [row]
      column_counter = -1
      zone_summary_table[:header].each do |header|
        column_counter += 1
        next if header == ''
        if header == 'Multiplier' then header = 'Multipliers' end # what we want to show is different than what is in E+ table
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}' and RowName= '#{row}' and ColumnName= '#{header}'"
        if not zone_summary_table[:source_units][column_counter] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_summary_table[:source_units][column_counter], zone_summary_table[:units][column_counter]).get
          row_data << row_data_ip.round(2)
        else
          results = sqlFile.execAndReturnFirstString(query)
          row_data << results
        end
      end

      zone_summary_table[:data] << row_data
    end

    # add zone_summary_table to array of tables
    template_tables << zone_summary_table

    # data for query
    report_name = 'HVACSizingSummary'
    table_01_name = 'Zone Cooling'
    table_02_name = 'Zone Heating'
    columns = ['', 'Heating/Cooling', 'Calculated Design Load', 'Design Load With Sizing Factor', 'Calculated Design Air Flow', 'Design Air Flow  With Sizing Factor', 'Date/Time Of Peak', 'Outdoor Temperature at Peak Load', 'Outdoor Humidity Ratio at Peak Load']
    columns_query = ['', 'Heating/Cooling', 'Calculated Design Load', 'User Design Load', 'Calculated Design Air Flow', 'User Design Air Flow', 'Date/Time Of Peak', 'Outdoor Temperature at Peak Load', 'Outdoor Humidity Ratio at Peak Load']

    # populate dynamic rows
    rows_name_query = "SELECT DISTINCT  RowName FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_01_name}'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end

    # create zone_dd_table
    zone_dd_table = {}
    zone_dd_table[:title] = 'Zone Cooling and Heating Sizing'
    zone_dd_table[:header] = columns
    source_units_power = 'W'
    target_units_power_clg = 'ton'
    target_units_power_htg = 'kW'
    source_units_air_flow = 'm^3/s'
    target_units_air_flow = 'm^3/s'
    source_units_temp = 'C'
    target_units_temp = 'C'
    zone_dd_table[:units] = ['', '', '', '', target_units_air_flow, target_units_air_flow, '', target_units_temp, 'lbWater/lbAir']
    zone_dd_table[:source_units] = ['', '', '', '', source_units_air_flow, source_units_air_flow, '', source_units_temp, 'lbWater/lbAir'] # used for conversation, not needed for rendering.
    zone_dd_table[:data] = []
    # run query and populate zone_dd_table
    rows.each do |row|
      # populate cooling row
      row_data = [row, 'Cooling']
      column_counter = -1
      columns_query.each do |header|
        column_counter += 1
        next if header == '' || header == 'Heating/Cooling'
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_01_name}' and RowName= '#{row}' and ColumnName= '#{header}'"
        if not zone_dd_table[:source_units][column_counter] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_dd_table[:source_units][column_counter], zone_dd_table[:units][column_counter]).get
          row_data << row_data_ip.round(2)
        elsif header == 'Calculated Design Load' || header == 'User Design Load'
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, source_units_power, target_units_power_clg).get
          row_data << "#{row_data_ip.round(2)} (#{target_units_power_clg})"
        else
          results = sqlFile.execAndReturnFirstString(query)
          row_data << results
        end
      end
      zone_dd_table[:data] << row_data

      # populate heating row
      row_data = [row, 'Heating']
      column_counter = -1
      columns_query.each do |header|
        column_counter += 1
        next if header == '' || header == 'Heating/Cooling'
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_02_name}' and RowName= '#{row}' and ColumnName= '#{header}'"
        if not zone_dd_table[:source_units][column_counter] == ''
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, zone_dd_table[:source_units][column_counter], zone_dd_table[:units][column_counter]).get
          row_data << row_data_ip.round(2)
        elsif header == 'Calculated Design Load' || header == 'User Design Load'
          results = sqlFile.execAndReturnFirstDouble(query)
          row_data_ip = OpenStudio.convert(results.to_f, source_units_power, target_units_power_htg).get
          row_data << "#{row_data_ip.round(2)} (#{target_units_power_htg})"
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
    @source_energy_section[:title] = 'Site and Source Summary'
    @source_energy_section[:tables] = source_energy_section_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @source_energy_section
    end

    # data for query
    report_name = 'AnnualBuildingUtilityPerformanceSummary'
    table_name = 'Site and Source Energy'
    columns = ['', 'Total Energy', 'Energy Per Total Building Area', 'Energy Per Conditioned Building Area']
    rows = ['Total Site Energy', 'Net Site Energy', 'Total Source Energy', 'Net Source Energy']

    # create table
    source_energy_table = {}
    source_energy_table[:title] = table_name
    source_energy_table[:header] = columns
    source_units_total = 'GJ'
    source_units_area = 'MJ/m^2'
    target_units_total = 'kWh'
    target_units_area = 'kWh/m^2'
    source_energy_table[:units] = ['', target_units_total, target_units_area, target_units_area]
    source_energy_table[:source_units] = ['', source_units_total, source_units_area, source_units_area] # used for conversation, not needed for rendering.
    source_energy_table[:data] = []

    # run query and populate table
    rows.each do |row|
      row_data = [row]
      column_counter = -1
      source_energy_table[:header].each do |header|
        column_counter += 1
        next if header == ''
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}' and RowName= '#{row}' and ColumnName= '#{header}'"
        results = sqlFile.execAndReturnFirstDouble(query)
        row_data_ip = OpenStudio.convert(results.to_f, source_energy_table[:source_units][column_counter], source_energy_table[:units][column_counter]).get
        row_data << row_data_ip.round(1)
      end
      source_energy_table[:data] << row_data
    end

    # add table to array of tables
    source_energy_section_tables << source_energy_table

    # data for query
    report_name = 'AnnualBuildingUtilityPerformanceSummary'
    table_name = 'Site to Source Energy Conversion Factors'
    columns = ['', 'Site=>Source Conversion Factor']
    rows = ['Electricity', 'Natural Gas', 'District Cooling', 'District Heating'] # TODO: - complete this and add logic to skip row if not used in model

    # create table
    source_energy_table = {}
    source_energy_table[:title] = table_name
    source_energy_table[:header] = columns
    source_energy_table[:units] = []
    source_energy_table[:data] = []

    # run query and populate table
    rows.each do |row|
      row_data = [row]
      column_counter = -1
      source_energy_table[:header].each do |header|
        column_counter += 1
        next if header == ''
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}' and RowName= '#{row}' and ColumnName= '#{header}'"
        results = sqlFile.execAndReturnFirstDouble(query).to_f
        row_data << results.round(3)
      end
      source_energy_table[:data] << row_data
    end

    # add table to array of tables
    source_energy_section_tables << source_energy_table

    return @source_energy_section
  end

end
