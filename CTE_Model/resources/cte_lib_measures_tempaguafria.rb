# coding: utf-8# -*- coding: utf-8 -*-
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
require 'fileutils'

# Introduce perfiles mensuales de la temperatura de agua de red en funcion de la provincia y corregida con la altitud
# TODO: Detectar caso en el que no está definida la demanda de ACS (no hay circuito) para evitar el fallo (¿Localizar WaterEquipment?).
def cte_tempaguafria(model, runner, user_arguments)

  runner.registerInfo("CTE: fijando temperatura de agua de red")

  localidades_de_referencia = {
    'A3'=> ['Cadiz', 0],
    'A4'=> ['Almeria', 0],
    'B3'=> ['Valencia', 8],
    'B4'=> ['Sevilla', 9],
    'C1'=> ['Bilbao_Bilbo', 214],
    'C2'=> ['Barcelona', 1],
    'C3'=> ['Granada', 754],
    'C4'=> ['Toledo', 445],
    'D1'=> ['Vitoria_Gasteiz', 512],
    'D2'=> ['Zamora', 617],
    'D3'=> ['Madrid', 589],
    'E1'=> ['Burgos', 861]}
  
  # Lee los valores de las provincias
  filenameAgua = File.dirname(__FILE__) + "/temperaturas_agua_fria.csv"
  temperaturasAguaDeRed = {}
  File.read(filenameAgua).each_line do |line;csv_line, prov, temps, altref|
    begin
      next if line.start_with?('#')
      csv_line = CSV.parse_line(line.strip, {col_sep: ","})
      prov = csv_line[0].to_s
      altref = csv_line[1].to_f
      temps = csv_line[2..csv_line.size].map{ |val| val.to_f }
      temperaturasAguaDeRed[prov] = [altref, temps]
    rescue
      runner.registerError("Error al leer archivo #{filenameAgua} en línea #{line}")
      return false
    end
  end
  
  
  # Variables
  provincia = runner.getStringArgumentValue('CTE_Provincia', user_arguments)
  if provincia != 'Automatico'
    altitudEmplazamiento = runner.getDoubleArgumentValue('CTE_Altitud', user_arguments)
    if (altitudEmplazamiento > 4000)
      runner.registerError("Altitud excesiva del emplazamiento: #{ altitudEmplazamiento }")
      return false
    end
  elsif provincia == 'Automatico'
    site = model.getSite
    weather_file = site.name.get
    if weather_file.include?('canarias')
      provincia = 'Las_Palmas_de_Gran_Canaria'
      altitudEmplazamiento = 114.0
    else
      zonaclimatica = weather_file[0,2]
      provincia, altitudEmplazamiento = localidades_de_referencia[zonaclimatica]
    end
  else
    runner.registerError("Error al seleccionar la provincia #{provincia}")
    return false
  end

  if temperaturasAguaDeRed.has_key?(provincia)
    altitudCapital, temperaturasAguaDeRed = temperaturasAguaDeRed[provincia]
    runner.registerInfo("Altitud de la provincia: #{ altitudCapital }")
    runner.registerInfo("Temperatura de agua de red: #{ temperaturasAguaDeRed }")
  else
    runner.registerError("Provincia '#{provincia}' sin datos de temperatura de agua de red")
    return false
  end

  runner.registerValue("CTE_Provincia_AF", provincia)
  diffAltitud = altitudEmplazamiento - altitudCapital

  factoresCorreccionMensual = [0.0066 * diffAltitud] * 3 + [0.0033 * diffAltitud] * 6 + [0.0066 * diffAltitud] * 3
  temperaturasAguaDeRedCorregidas = temperaturasAguaDeRed.zip(factoresCorreccionMensual).map { |x, y| x - y }
  runner.registerValue('CTE Temperaturas de agua de red', "[" + temperaturasAguaDeRedCorregidas.join(',') + "]")

  cte_horariosAgua = "CTE_ACS_Temperatura_agua_fria"
  conjuntoDeReglas = nil
  model.getScheduleRulesets.each do | scheduleRuleset |
    if scheduleRuleset.name.get == cte_horariosAgua
      conjuntoDeReglas = scheduleRuleset
      break
    end
  end

  if nil == conjuntoDeReglas
    runner.registerWarning("No se ha localizado el conjunto de reglas '#{ cte_horariosAgua }' que definen la temperatura del agua fría de red. ¿Ha definido una instalación de ACS?")
  else
    meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
             "septiembre", "octubre", "noviembre", "diciembre"]
    runner.registerInfo("Localizado el conjunto de reglas '#{ cte_horariosAgua }'")
    conjuntoDeReglas.scheduleRules.each do | rule |
      day_sch = rule.daySchedule
      hora = day_sch.times[0]
      ruleName = rule.name.get

      day_sch.setName('dia_' + ruleName)
      day_sch.removeValue(hora)
      day_sch.addValue(hora, temperaturasAguaDeRedCorregidas[meses.index(ruleName)].to_f)
    end
  end

  return true
end


