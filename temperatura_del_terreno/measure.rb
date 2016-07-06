#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

require 'csv'

## esas direcciones ya no funcionan, mejor esta:
#https://s3.amazonaws.com/openstudio-sdk-documentation/cpp/OpenStudio-1.5.0-doc/utilities_idd/html/classopenstudio_1_1_idd_object_type.html
#start the measure
class TemperaturaDelTerreno < OpenStudio::Ruleset::WorkspaceUserScript

  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return " Temperatura del terreno"
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    zci = OpenStudio::StringVector.new
    zci = ["alfa", "A", "B", "C", "D", "E"] # esto se hace añadiendo con << en lugar de = []
    zci_chs = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('zonaClimaticaInvierno', zci, true)
    zci_chs.setDisplayName("Zona climática de invierno")
    args << zci_chs
    
    zcv = OpenStudio::StringVector.new
    zcv = ["1", "2", "3", "4"]
    zcv_chs = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('zonaClimaticaVerano', zcv, true)
    zcv_chs.setDisplayName("Zona climática de verano")
    args << zcv_chs
    
    canarias = OpenStudio::StringVector.new
    canarias = ["canarias", "peninsula"]
    canarias_chs = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('canarias', canarias, true)
    canarias_chs.setDisplayName('¿Canarias o no canarias?')
    args << canarias_chs

    return args
  end #end the arguments method
  
  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)
  
    zonaClimaticaInvierno = runner.getStringArgumentValue('zonaClimaticaInvierno', user_arguments)
    zonaClimaticaVerano = runner.getStringArgumentValue('zonaClimaticaVerano', user_arguments)
    canarias = runner.getStringArgumentValue('canarias', user_arguments)  
   
    log = 'log_temperaturaDelTerreno'
    
    temperaturaSuelo = getTemperaturasSuelo(log, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)
    
    if not temperaturaSuelo
        runner.registerError("No tengo zona climática #{zonaClimaticaInvierno}#{zonaClimaticaVerano} en #{canarias}") 
        return false
    end
    
       
    # array to hold new IDF objects needed
    string_objects = []

    # add GroundTemperature Object
    string_objects << "
      Site:GroundTemperature:BuildingSurface,     
        #{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},
        #{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo};
        "

    # add all of the strings to workspace
    # this script won't behave well if added multiple times in the workflow. Need to address name conflicts
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      wsObject = workspace.addObject(object)
    end 
    
   msg(log, "___ fin de la medida de Temperatura de Terreno__\n\n") 
   return true
   
   end #end the run method     
  
  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}  
  end    
  
  def getTemperaturasSuelo(log, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)    
    clavecanarias = {'peninsula' => '', 'canarias' => 'c'}
    clavedezona = zonaClimaticaInvierno.downcase + zonaClimaticaVerano + clavecanarias[canarias]    
    msg(log, "clave de zona --> #{clavedezona}\n")
    
    filename = "resources/temp_suelo_resumen.csv" 
    temperaturasPorZona = Hash.new    
    File.read(filename).each_line do |line|
      begin
        csv_line = CSV.parse_line(line.strip, {col_sep: ";", quote_char:"'"})
        clave = csv_line[0].to_s
        valor = csv_line[1].to_f
        temperaturasPorZona[clave] = valor
      rescue
        msg(log, "error con:#{line}\n")
      end
    end
    
    verdatosleidos = 
    if verdatosleidos
        msg(log, "\n__recorro la lectura_\n")
        temperaturasPorZona.each do |key, value|
            msg(log, "  clave #{key}, valor #{value}\n")
        end       
        msg(log, "__fin lectura__\n")    
    end
    
    if temperaturasPorZona.has_key?(clavedezona)
        temperaturasuelo = temperaturasPorZona[clavedezona]
    else
        msg(log, "no encuentro temp para la clave de zona: #{clavedezona}\n")        
        return false
    end
    
    msg(log, "temperatura suelo --> #{temperaturasuelo}\n")    
    msg(log, "__fin getTemperaturasSuelo__\n")    
    
    return temperaturasuelo
    
 end

end #end the measure

#this allows the measure to be use by the application
TemperaturaDelTerreno.new.registerWithApplication