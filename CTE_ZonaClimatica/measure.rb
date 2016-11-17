#see the URL below for information on how to write OpenStudio measures
# TODO: Remove this link and replace with the wiki
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

# Author: Nicholas Long
# Simple measure to load the EPW file and DDY file
#~ require_relative 'resources/stat_file'
require_relative 'resources/epw'

class CTE_ZonaClimatica < OpenStudio::Ruleset::ModelUserScript

  attr_reader :weather_directory

  def initialize
    super
    @weather_directory = File.expand_path(File.join(File.dirname(__FILE__), "./resources"))
  end

  def name
    return "CTE_ZonaClimatica"
  end

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    choices_zci = OpenStudio::StringVector.new
    choices_zci << "alpha"
    choices_zci << "A"
    choices_zci << "B"
    choices_zci << "C"
    choices_zci << "D"
    choices_zci << "E"
    zona_climatica_invierno =  OpenStudio::Ruleset::OSArgument.makeChoiceArgument('zona_climatica_invierno', choices_zci, true)
    zona_climatica_invierno.setDisplayName("Zona Climática de Invierno")
    args << zona_climatica_invierno

    choices_zcv = OpenStudio::StringVector.new
    choices_zcv << "1"
    choices_zcv << "2"
    choices_zcv << "3"
    choices_zcv << "4"
    zona_climatica_verano =  OpenStudio::Ruleset::OSArgument.makeChoiceArgument('zona_climatica_verano', choices_zcv, true)
    zona_climatica_verano.setDisplayName("Zona Climática de Verano")
    args << zona_climatica_verano

    peninsula = OpenStudio::Ruleset::OSArgument.makeBoolArgument('peninsular', true)
    peninsula.setDisplayName("¿Es peninsular?")
    peninsula.setDescription("Marque esta opción si la localidad de proyecto está en la península o Baleares")
    peninsula.setDefaultValue(true)
    args << peninsula

    args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    zci = runner.getStringArgumentValue("zona_climatica_invierno", user_arguments)
    zcv = runner.getStringArgumentValue("zona_climatica_verano", user_arguments)
    penin = runner.getStringArgumentValue("peninsular", user_arguments)

    weather_file_name = ''
    weather_file_name << zci + zcv + '_'
    peninsular = (penin == 'false') ? 'canarias' : 'peninsula'
    weather_file_name << peninsular

    runner.registerInfo("weather file = #{weather_file_name}")    
    
    unless (Pathname.new @weather_directory).absolute?
      @weather_directory = File.expand_path(File.join(File.dirname(__FILE__), @weather_directory))
    end

    weather_file = File.join(@weather_directory, weather_file_name + '.epw')
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
    site.setName(weather_file_name + '.epw')
    site.setLatitude(weather_lat)
    site.setLongitude(weather_lon)
    site.setTimeZone(weather_time)
    site.setElevation(weather_elev)

    ddy_file_name = weather_file_name + '.ddy'
    ddy_file = File.join(@weather_directory, ddy_file_name)
    ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file).get
    ddy_model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each do |d|
      # grab only the ones that matter
      ddy_list = /(Htg 99.6. Condns DB)|(Clg .4. Condns WB=>MDB)|(Clg .4% Condns DB=>MWB)/
      if d.name.get =~ ddy_list
        runner.registerInfo("Adding object #{d.name}")

        # add the object to the existing model
        model.addObject(d.clone)
      end
    end

    # todo - add final condition
    runner.registerFinalCondition("The final weather file is #{model.getWeatherFile.city} and the model has #{model.getDesignDays.size} design day objects")

    true
  end
end

CTE_ZonaClimatica.new.registerWithApplication
