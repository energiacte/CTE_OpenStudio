# coding: utf-8
# Author(s): Daniel Jiménez González, Rafael Villar Burke
# email: pachi@ietcc.csic.es
#
# Measure based on previous measure by Nicholas Long
# Simple measure to load the EPW file and DDY file for a given CTE climate name
require_relative 'resources/epw'

class CTE_ZonaClimatica < OpenStudio::Ruleset::ModelUserScript

  attr_reader :weather_directory

  def initialize
    super
    @weather_directory = File.expand_path(File.join(File.dirname(__FILE__), "./resources"))
    @climatenames = ['A3_peninsula', 'A4_peninsula',
                     'B3_peninsula', 'B4_peninsula',
                     'C1_peninsula', 'C2_peninsula', 'C3_peninsula', 'C4_peninsula',
                     'D1_peninsula', 'D2_peninsula', 'D3_peninsula',
                     'E1_peninsula',
                     'alpha1_canarias', 'alpha2_canarias', 'alpha3_canarias', 'alpha4_canarias',
                     'A1_canarias', 'A2_canarias', 'A3_canarias', 'A4_canarias',
                     'B1_canarias', 'B2_canarias', 'B3_canarias', 'B4_canarias',
                     'C1_canarias', 'C2_canarias', 'C3_canarias', 'C4_canarias',
                     'D1_canarias', 'D2_canarias', 'D3_canarias',
                     'E1_canarias']
  end

  def name
    return "CTE_ZonaClimatica"
  end

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    choices_climas = OpenStudio::StringVector.new
    @climatenames.each { |climaname| choices_climas << climaname }
    clima =  OpenStudio::Ruleset::OSArgument.makeChoiceArgument('zona_climatica', choices_climas, true)
    clima.setDisplayName("Zona Climatica")
    clima.setDefaultValue("D3_peninsula")
    args << clima

    args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    clima_name = runner.getStringArgumentValue("zona_climatica", user_arguments)
    weather_file = File.join(@weather_directory, clima_name + '.epw')
    runner.registerInfo("weather file = #{ weather_file }")

    # Parse the EPW manually because OpenStudio can't handle multiyear weather files (or DATA PERIODS with YEARS)
    epw_file = OpenStudio::Weather::Epw.load(weather_file)

    weather_file = model.getWeatherFile
    weather_file.setCity(epw_file.city)
    weather_file.setStateProvinceRegion(epw_file.state)
    weather_file.setCountry(epw_file.country)
    weather_file.setDataSource(epw_file.data_type)
    weather_file.setWMONumber(epw_file.wmo.to_s)
    weather_file.setLatitude(epw_file.lat)
    weather_file.setLongitude(epw_file.lon)
    weather_file.setTimeZone(epw_file.gmt)
    #XXX: seleccionamos la altitud del archivo climático
    weather_file.setElevation(epw_file.elevation)
    weather_file.setString(10, "file:///#{epw_file.filename}")

    weather_lat = epw_file.lat
    weather_lon = epw_file.lon
    weather_time = epw_file.gmt
    weather_elev = epw_file.elevation

    # Add or update site data
    site = model.getSite
    site.setName(clima_name + '.epw')
    site.setLatitude(weather_lat)
    site.setLongitude(weather_lon)
    site.setTimeZone(weather_time)
    site.setElevation(weather_elev)

    # Remove existing design days
    # OpenStudio generates copies of our designdays using names:
    # - Sizing Period Design Day 1
    # - Sizing Period Design Day 2
    # and apparently it needs them
    # model.getDesignDays.each do |d|
    #     model.removeObject(d.handle)
    # end

    # Add new design days
    ddy_file = File.join(@weather_directory, clima_name + '.ddy')
    ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file).get
    ddy_model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each do |d|
      ddy_list = /(Winter 0.4% Dry Bulb Temperature)|(Summer 99.6% Dry Bulb Temperature)/
      if d.name.get =~ ddy_list
        runner.registerInfo("Adding object #{d.name}")
        model.addObject(d.clone)
      end
    end

    runner.registerFinalCondition("The final weather file is #{model.getWeatherFile.city} and the model has #{model.getDesignDays.size} design day objects")

    return true
  end
end

CTE_ZonaClimatica.new.registerWithApplication
