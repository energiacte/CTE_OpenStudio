# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require 'csv'
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
    provincias_display = OpenStudio::StringVector.new
    provincias_chs = OpenStudio::StringVector.new

    nombresProvincias = ['A_Coruna', 'Albacete', 'Alicante_Alacant', 'Almeria', 'Avila', 'Badajoz', 'Barcelona', 'Bilbao_Bilbo',
    'Burgos', 'Caceres', 'Cadiz', 'Castellon_Castello', 'Ceuta', 'Ciudad_Real', 'Cordoba', 'Cuenca',
    'Girona', 'Granada', 'Guadalajara', 'Huelva', 'Huesca', 'Jaen', 'Las_Palmas_de_Gran_Canaria', 'Leon',
    'Lleida', 'Logrono', 'Lugo', 'Madrid', 'Malaga', 'Melilla', 'Murcia', 'Ourense', 'Oviedo', 'Palencia',
    'Palma_de_Mallorca', 'Pamplona_Iruna', 'Pontevedra', 'Salamanca', 'San_Sebastian', 'Santa_Cruz_de_Tenerife',
    'Santander', 'Segovia', 'Sevilla', 'Soria', 'Tarragona', 'Teruel', 'Toledo', 'Valencia', 'Valladolid',
    'Vitoria_Gasteiz', 'Zamora', 'Zaragoza']
    nombresProvincias.each do | nombreProvincia |
        provincias_chs << nombreProvincia
    end

    provincia = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('provincia', provincias_chs, true)
    provincia.setDisplayName("Provincia")
    args << provincia
    
    altitud = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("altitud",true)
    altitud.setDisplayName("Altitud del emplazamiento")
    altitud.setUnits("metros")
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
    altitudEmplazamiento = runner.getDoubleArgumentValue('altitud',user_arguments)    

    # check the space_name for reasonableness
    if provincia.empty?
      runner.registerError("No se ha especificado provincia.")
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("La provincia seleccionada es #{provincia}.")

    f = 'temperaturaDeRed'
    msg(f, "La provincia seleccionada es #{provincia}.\n")

    verdatosleidos = false
    valores = getValoresProvincia(model, f, provincia, verdatosleidos)
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
    msg(f, "__localizar scheduleRuleset__\n")
    localizar = "CTE_ACS_Temperatura_agua_fria"
    msg(f, "    localizando #{localizar}\n")
    conjuntoDeReglas = getScheduleRulesetByName(model, localizar)[0]
    conjuntoDeReglas.scheduleRules.each do | rule |
        msg(f, " regla: #{rule.name.get}\n")
        msg(f, " temperatura: #{valorfinalAguaDeRed[meses.index(rule.name.get)].to_f}\n")
        msg(f, "schedule rule index= #{rule.ruleIndex}\n")
        ruleIndex = rule.ruleIndex
        day_sch = rule.daySchedule
        day_sch.setName('dia_'+rule.name.get)
        msg(f, "    ruleIndex = #{ruleIndex}\n")
         
        hora = day_sch.times[0]
        day_sch.removeValue(hora)
        day_sch.addValue(hora, valorfinalAguaDeRed[meses.index(rule.name.get)].to_f)         
        msg(f, "    values = #{day_sch.values}\n")
        # day_sch.times.each do | time |
            # msg(f, " --- #{time.days()}, #{time.hours()}\n")
        # end
    end
    
    return true
  end

  def getValoresProvincia(model, f, provincia, verdatosleidos)
    salida = []
    filenameAgua = "resources/temperaturas_agua_fria.csv"
    filenameAltitud = "resources/altitud_capitales_provincia.csv"
    teperaturasAguaDeRed = Hash.new
    File.read(filenameAgua).each_line do |line|
        begin
            csv_line = CSV.parse_line(line.strip, {col_sep: ","})
            clave = csv_line[0].to_s
            valor = csv_line[1..csv_line.size]
            teperaturasAguaDeRed[clave] = valor
        rescue
            msg(f, "error con:#{line}\n")
        end
    end

    if verdatosleidos
        msg(f, "\n__recorro la lectura_\n")
        teperaturasAguaDeRed.each do |key, value|
            msg(f, "  clave #{key}, valor #{value}\n")
        end
        msg(f, "__fin lectura__\n")
    end

    if teperaturasAguaDeRed.has_key?(provincia)
        vectorAguaDeRed = teperaturasAguaDeRed[provincia]
    else
        msg(f, "no encuentro vector de temperaturas para la provicia: #{provincia}\n")
        return false
    end

    msg(f, "temperatura red --> #{vectorAguaDeRed}\n")
    msg(f, "__fin getTemperaturas agua de red__\n\n")
    salida << vectorAguaDeRed
    
    altitudesProvincia = Hash.new
    File.read(filenameAltitud).each_line do |line|
        begin
            csv_line = CSV.parse_line(line.strip, {col_sep: ","})
            clave = csv_line[0].to_s
            valor = csv_line[1].to_f
            altitudesProvincia[clave] = valor
        rescue
            msg(f, "error con:#{line}\n")
        end
    end

    if verdatosleidos
        msg(f, "\n__recorro la lectura_\n")
        altitudesProvincia.each do |key, value|
            msg(f, "  clave #{key}, valor #{value}\n")
        end
        msg(f, "__fin lectura__\n")
    end

    if altitudesProvincia.has_key?(provincia)
        altitud = altitudesProvincia[provincia]
    else
        msg(f, "no encuentro la altitud para la provicia: #{provincia}\n")
        return false
    end

    msg(f, "altitud de la provincia: --> #{altitud}\n")
    msg(f, "__fin getAltitud__\n\n")    
    
    salida << altitud
    
    msg(f, salida)
    
    return salida
  end

  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end


  def getScheduleRulesetByName(model, nombre)
    scheduleRulesets = model.getScheduleRulesets
    salida = []
    scheduleRulesets.each do | scheduleRuleset |
        #msg(f, "#{scheduleRuleset.name.get == nombre}\n")
        if scheduleRuleset.name.get == nombre
            salida << scheduleRuleset
            #msg(f, "__SII!!!__\n")
        end
    end

    return salida
  end

end

# register the measure to be used by the application
TemperaturaDelAguaDeRed.new.registerWithApplication
