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
  zc, peninsulaocanarias = weatherfile.filename.to_s.sub(/.epw$/, '').split('_')
  zci, zcv = zc[0..-2], zc[-1]
  zci = zci.include?('alpha')?  'alfa': zci
  return zci, zcv, peninsulaocanarias
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
  runner.registerValue("ZCI", zonaClimaticaInvierno)
  runner.registerValue("ZCV", zonaClimaticaVerano)
  runner.registerValue("penisulaocanarias", canarias)
  temperaturaSuelo = getTemperaturasSuelo(runner, zonaClimaticaInvierno, zonaClimaticaVerano, canarias)
  if not temperaturaSuelo
    runner.registerError("No se ha encontrado la temperatura del suelo para la zona climática #{zonaClimaticaInvierno}#{zonaClimaticaVerano} en #{canarias}")
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
      runner.registerInfo("Error al leer datos de temperatura de suelo en línea: #{ line }\n")
    end
  end

  if temperaturasPorZona.has_key?(clavedezona)
    temperaturasuelo = temperaturasPorZona[clavedezona]
  else
    runner.registerInfo( "No se localizan las temperaturas para la clave de zona: #{ clavedezona }\n")
    return false
  end

  runner.registerInfo("Temperaturas del suelo: #{temperaturasuelo}")
  return temperaturasuelo
end
