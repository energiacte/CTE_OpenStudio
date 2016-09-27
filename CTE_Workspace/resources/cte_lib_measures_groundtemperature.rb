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

require 'csv'

def parseweatherfilename(weatherfile)
  # TODO: implementar
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
