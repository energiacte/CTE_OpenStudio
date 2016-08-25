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

def parseweatherfilename(weatherfile)
  return 'D', '3', 'peninsula'
end

def cte_groundTemperature(runner, workspace, string_objects)
     
  model = runner.lastOpenStudioModel
  if model.empty?
    runner.registerError("Could not load last OpenStudio model, cannot apply measure.")
  return false
  end
  
  model = model.get  
  weatherfile = model.weatherFile.get.path.get
  runner.registerInfo("weather file = #{weatherfile}")
  zonaClimaticaInvierno, zonaClimaticaVerano, canarias = parseweatherfilename(weatherfile)
  
  runner.registerInfo("El parser lee #{weatherfile} y entiende #{zonaClimaticaInvierno}, #{zonaClimaticaVerano} y #{canarias}")
  temperaturaSuelo = getTemperaturasSuelo(runner, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)    
  if not temperaturaSuelo
    runner.registerError("No tengo zona climática #{zonaClimaticaInvierno}#{zonaClimaticaVerano} en #{canarias}") 
    return false
  end
  
  # add GroundTemperature Object
  string_objects << "
    Site:GroundTemperature:BuildingSurface,     
    #{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},
    #{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo};
    "
  
  return true
  
end 
  
def getTemperaturasSuelo(runner, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)    
  clavecanarias = {'peninsula' => '', 'canarias' => 'c'}
  clavedezona = zonaClimaticaInvierno.downcase + zonaClimaticaVerano + clavecanarias[canarias]    
  runner.registerInfo("clave de zona --> #{clavedezona}\n")
    
  filename =  "#{File.dirname(__FILE__)}/temp_suelo_resumen.csv"
  temperaturasPorZona = Hash.new    
  File.read(filename).each_line do |line|
    begin
      csv_line = CSV.parse_line(line.strip, {col_sep: ";", quote_char:"'"})
      clave = csv_line[0].to_s
      valor = csv_line[1].to_f
      temperaturasPorZona[clave] = valor
    rescue
      runner.registerInfo("error con:#{line}\n")
    end
  end
    
  verdatosleidos = 
  if verdatosleidos
    runner.registerInfo("\n__recorro la lectura_\n")
    temperaturasPorZona.each do |key, value|
      runner.registerInfo("  clave #{key}, valor #{value}\n")
    end       
    runner.registerInfo(runner.registerInfo, "__fin lectura__\n")    
  end
    
  if temperaturasPorZona.has_key?(clavedezona)
    temperaturasuelo = temperaturasPorZona[clavedezona]
  else
    runner.registerInfo( "no encuentro temp para la clave de zona: #{clavedezona}\n")        
    return false
  end
    
  runner.registerInfo("temperatura suelo --> #{temperaturasuelo}\n")    
    
  return temperaturasuelo
    
end


