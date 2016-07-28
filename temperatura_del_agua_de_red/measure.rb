# coding: utf-8
# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require 'csv'
require 'fileutils'

class TemperaturaDelAguaDeRed < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Temperatura del agua de red"
  end

  # human readable description
  def description
    return "Introduce perfiles mensuales de la temperatura de agua de red en funcion de la provincia y
    corregida con la altitud"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Hay que leer un csv y generar los perfiles de agua de red."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    provincias_chs = OpenStudio::StringVector.new

    ['A_Coruna', 'Albacete', 'Alicante_Alacant', 'Almeria', 'Avila', 'Badajoz', 'Barcelona', 'Bilbao_Bilbo',
     'Burgos', 'Caceres', 'Cadiz', 'Castellon_Castello', 'Ceuta', 'Ciudad_Real', 'Cordoba', 'Cuenca',
     'Girona', 'Granada', 'Guadalajara', 'Huelva', 'Huesca', 'Jaen', 'Las_Palmas_de_Gran_Canaria', 'Leon',
     'Lleida', 'Logrono', 'Lugo', 'Madrid', 'Malaga', 'Melilla', 'Murcia', 'Ourense', 'Oviedo', 'Palencia',
     'Palma_de_Mallorca', 'Pamplona_Iruna', 'Pontevedra', 'Salamanca', 'San_Sebastian', 'Santa_Cruz_de_Tenerife',
     'Santander', 'Segovia', 'Sevilla', 'Soria', 'Tarragona', 'Teruel', 'Toledo', 'Valencia', 'Valladolid',
     'Vitoria_Gasteiz', 'Zamora', 'Zaragoza'].each{ |prov|  provincias_chs << prov }

    provincia = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('provincia', provincias_chs, true)
    provincia.setDisplayName("Provincia")
    provincia.setDefaultValue("Madrid")

    args << provincia

    altitud = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("altitud",true)
    altitud.setDisplayName("Altitud del emplazamiento")
    altitud.setUnits("metros")
    altitud.setDefaultValue(650)
    args << altitud

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    provincia = runner.getStringArgumentValue('provincia', user_arguments)
    altitudEmplazamiento = runner.getDoubleArgumentValue('altitud', user_arguments)

    if (altitudEmplazamiento > 4000)
      runner.registerError("Altura excesiva.")
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("La provincia seleccionada es #{provincia}.")
    valores = getValoresProvincia(model, runner, provincia)
    if valores == false
      return false
    end
    vectorAguaDeRed = valores[0]
    altitudCapital = valores[1]

    factoresdecorreccion = []
    factoresdecorreccion = [0.0066]*3 + [0.0033]*6 + [0.0066]*3
    diffAltitud = altitudEmplazamiento - altitudCapital
    correccion = []
    factoresdecorreccion.each do | temporal |
      correccion << temporal * diffAltitud
    end

    valorfinalAguaDeRed = vectorAguaDeRed.zip(correccion).map { |x, y| x.to_f - y }


    meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
             "septiembre", "octubre", "noviembre", "diciembre"]
    localizar = "CTE_ACS_Temperatura_agua_fria"


    conjuntoDeReglas = nil
    model.getScheduleRulesets.each do | scheduleRuleset |
      if scheduleRuleset.name.get == localizar
        runner.registerInfo("Localizado el conjunto de reglas '#{localizar}'")
        conjuntoDeReglas = scheduleRuleset
        break
      end
    end

    conjuntoDeReglas.scheduleRules.each do | rule |
      day_sch = rule.daySchedule
      day_sch.setName('dia_' + rule.name.get)
      hora = day_sch.times[0]
      day_sch.removeValue(hora)
      day_sch.addValue(hora, valorfinalAguaDeRed[meses.index(rule.name.get)].to_f)
    end

    return true
  end

  def getValoresProvincia(model, runner, provincia)
    salida = []

    filenameAgua = File.dirname(__FILE__) + "/resources/temperaturas_agua_fria.csv"
    temperaturasAguaDeRed = {}
    File.read(filenameAgua).each_line do |line|
      begin
        csv_line = CSV.parse_line(line.strip, {col_sep: ","})
        clave = csv_line[0].to_s
        valor = csv_line[1..csv_line.size]
        temperaturasAguaDeRed[clave] = valor
      rescue
        runner.registerError("Error al leer archivo #{filenameAgua} en línea #{line}")
        return false
      end
    end

    filenameAltitud = File.dirname(__FILE__) + "/resources/altitud_capitales_provincia.csv"
    altitudesProvincia = {}
    File.read(filenameAltitud).each_line do |line|
      begin
        csv_line = CSV.parse_line(line.strip, {col_sep: ","})
        clave = csv_line[0].to_s
        valor = csv_line[1].to_f
        altitudesProvincia[clave] = valor
      rescue
        runner.registerError("Error al leer archivo #{filenameAltitud} en línea #{line}")
        return false
      end
    end

    if temperaturasAguaDeRed.has_key?(provincia)
      vectorAguaDeRed = temperaturasAguaDeRed[provincia]
      runner.registerInfo("Temperatura de agua de red: #{vectorAguaDeRed}")
      salida << vectorAguaDeRed
    else
      runner.registerError("Provincia '#{provincia}' sin datos de temperatura de agua de red")
      return false
    end

    if altitudesProvincia.has_key?(provincia)
      altitud = altitudesProvincia[provincia]
      runner.registerInfo("Altitud de la provincia: #{altitud}")
      salida << altitud
    else
      runner.registerInfo("no encuentro la altitud para la provicia: #{provincia}")
      return false
    end

    return salida
  end

end

# register the measure to be used by the application
TemperaturaDelAguaDeRed.new.registerWithApplication
