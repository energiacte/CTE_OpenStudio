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

require 'csv'

def parseweatherfilename(weatherfile)
  zc, peninsulaocanarias = weatherfile.split('_')
  zci = zc[0..-2]
  zcv = zc[-1]
  zci = zci.include?('alpha') ? 'alfa' : zci
  [zci, zcv, peninsulaocanarias]
end

def cte_groundTemperature(runner, _workspace, string_objects)
  weatherfile = get_weather(runner)
  runner.registerInfo("weather file = #{weatherfile}")
  zonaClimaticaInvierno, zonaClimaticaVerano, canarias = parseweatherfilename(weatherfile)
  runner.registerValue('ZCI', zonaClimaticaInvierno)
  runner.registerValue('ZCV', zonaClimaticaVerano)
  runner.registerValue('penisulaocanarias', canarias)
  temperaturaSuelo = getTemperaturasSuelo(runner, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)
  unless temperaturaSuelo
    runner.registerError("No se ha encontrado la temperatura del suelo para la zona climática #{zonaClimaticaInvierno}#{zonaClimaticaVerano} en #{canarias}")
    return false
  end

  # add GroundTemperature Object
  string_objects << "
    Site:GroundTemperature:BuildingSurface,
    #{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},
    #{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo},#{temperaturaSuelo};
    "
  true
end

# Devuelve el nombre del clima
def get_weather(runner)
  # Obtenemos el nombre del archivo climático del runner o del modelo
  if runner.lastEpwFilePath.is_initialized
    weather_s = runner.lastEpwFilePath.get.to_s
    runner.registerValue('Clima obtenido del runner: ', weather_s)
    puts('XXXX')
  else
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Could not load last OpenStudio model, cannot find climate.')
      return false
    end

    model = model.get
    if model.getWeatherFile.path.is_initialized
      weather_s = model.getWeatherFile.path.get.to_s
      runner.registerValue('Clima obtenido del modelo (WeatherFile):', weather_s)
      puts('YYYY')
    elsif model.getSite.name.is_initialized
      weather_s = model.getSite.name.get.to_s
      runner.registerValue('Clima obtenido del Site:', weather_s)
      puts('ZZZZ')
    else
      runner.registerError('No se ha localizado el clima')
      return false
    end
  end
  # En algunos casos tenemos un path como: weather_s = file:file/D3_peninsula.epw
  _name, _match, weather_file = weather_s.rpartition('/')
  weather_file.gsub('.epw', '')
end

def getTemperaturasSuelo(runner, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)
  clavecanarias = { 'peninsula' => '', 'canarias' => 'c', 'ceutamelilla' => 'c', 'balears' => 'c' }
  clavedezona = zonaClimaticaInvierno.downcase + zonaClimaticaVerano + clavecanarias[canarias]
  runner.registerInfo("clave de zona --> #{clavedezona}\n")

  filename = "#{File.dirname(__FILE__)}/temp_suelo_resumen.csv"
  temperaturasPorZona = {}
  File.read(filename).each_line do |line|
    csv_line = CSV.parse_line(line.strip, { col_sep: ';', quote_char: "'" })
    clave = csv_line[0].to_s
    valor = csv_line[1].to_f
    temperaturasPorZona[clave] = valor
  rescue StandardError
    runner.registerInfo("Error al leer datos de temperatura de suelo en línea: #{line}\n")
  end

  if temperaturasPorZona.key?(clavedezona)
    temperaturasuelo = temperaturasPorZona[clavedezona]
  else
    runner.registerInfo("No se localizan las temperaturas para la clave de zona: #{clavedezona}\n")
    return false
  end

  runner.registerInfo("Temperaturas del suelo: #{temperaturasuelo}")
  temperaturasuelo
end
