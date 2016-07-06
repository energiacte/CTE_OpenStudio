
general_tables << OsLib_Reporting.general_building_information_table(model, sqlFile, runner)

  # create table with general building information
  # this just makes a table, and not a full section. It feeds into another method that makes a full section
  def self.general_building_information_table(model, sqlFile, runner)
    # general building information type data output
    general_building_information = {}
    general_building_information[:title] = 'Resumen del Edificio, Building Summary' # name will be with section
    general_building_information[:header] = %w(Informacion Valor Unidades)
    general_building_information[:units] = [] # won't populate for this table since each row has different units
    general_building_information[:data] = []

    # structure ID / building name
    display = 'Nombre del edificio Building Name'
    target_units = 'Nombre, building_name'
    value = model.getBuilding.name.to_s
    general_building_information[:data] << [display, value, target_units]
    runner.registerValue(display, value, target_units)

    # net site energy
    display = 'Energia Neta (Net Site Energy)'
    source_units = 'GJ'
    target_units = 'kWh'
    value = OpenStudio.convert(sqlFile.netSiteEnergy.get, source_units, target_units).get
    value_neat = OpenStudio.toNeatString(value, 0, true)
    general_building_information[:data] << [display, value_neat, source_units]
    runner.registerValue(display, value, source_units)

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
      display = 'Area total del edificio (Total Building Area)'
      source_units = 'm^2'
      target_units = 'ft^2'
      # value = OpenStudio.convert(query_results.get, source_units, target_units).get
      value = query_results.get
      value_neat = OpenStudio.toNeatString(value, 0, true)
      general_building_information[:data] << [display, value_neat, source_units]
      runner.registerValue(display, value, source_units)
    end

    # EUI
    eui =  sqlFile.netSiteEnergy.get / query_results.get
    display = 'EUI'
    source_units = 'GJ/m^2'
    target_units = 'kWh/m^2'
    value = OpenStudio.convert(eui, source_units, target_units).get
    value_neat = OpenStudio.toNeatString(value, 2, true)
    general_building_information[:data] << [display, value_neat, source_units]
    runner.registerValue(display, value, source_units)

    return general_building_information
  end