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

CTE_HORARIOSAGUA = 'CTE_ACS_Temperatura_agua_fria'.freeze

# Introduce perfiles mensuales de la temperatura de agua de red en funcion de la provincia y corregida con la altitud
# TODO: Detectar caso en el que no está definida la demanda de ACS (no hay circuito) para evitar el fallo (¿Localizar WaterEquipment?).
def cte_tempaguafria(model, runner, user_arguments)
  runner.registerInfo('CTE: fijando temperatura de agua de red')

  localidades_de_referencia = {
    'A3' => ['Cadiz', 0],
    'A4' => ['Almeria', 0],
    'B3' => ['Valencia', 8],
    'B4' => ['Sevilla', 9],
    'C1' => ['Bilbao_Bilbo', 214],
    'C2' => ['Barcelona', 1],
    'C3' => ['Granada', 754],
    'C4' => ['Toledo', 445],
    'D1' => ['Vitoria_Gasteiz', 512],
    'D2' => ['Zamora', 617],
    'D3' => ['Madrid', 589],
    'E1' => ['Burgos', 861]
  }

  # Lee los valores de las provincias
  temps_agua_file = File.dirname(__FILE__) + '/temperaturas_agua_fria.csv'
  temps_agua_red = {}
  File.read(temps_agua_file).each_line do |line|
    begin
      next if line.start_with?('#')

      csv_line = CSV.parse_line(line.strip, { col_sep: ',' })
      prov = csv_line[0].to_s
      altref = csv_line[1].to_f
      temps = csv_line[2..csv_line.size].map { |v| v.to_f }
      temps_agua_red[prov] = [altref, temps]
    rescue StandardError
      runner.registerError("Error al leer archivo #{temps_agua_file} en línea #{line}")
      return false
    end
  end

  # Variables
  provincia = runner.getStringArgumentValue('CTE_Provincia', user_arguments)
  if provincia != 'Automatico'
    altitud_emplazamiento = runner.getDoubleArgumentValue('CTE_Altitud', user_arguments)
    if altitud_emplazamiento > 4000
      runner.registerError("Altitud excesiva del emplazamiento: #{altitud_emplazamiento}")
      return false
    end
  elsif provincia == 'Automatico'
    site = model.getSite
    weather_file = site.name.get
    if weather_file.include?('canarias')
      provincia = 'Las_Palmas_de_Gran_Canaria'
      altitud_emplazamiento = 114.0
    else
      zonaclimatica = weather_file[0, 2]
      provincia, altitud_emplazamiento = localidades_de_referencia[zonaclimatica]
    end
  else
    runner.registerError("Error al seleccionar la provincia #{provincia}")
    return false
  end

  if temps_agua_red.key?(provincia)
    altitud_capital, temps_agua_red = temps_agua_red[provincia]
    runner.registerInfo("Altitud de la provincia: #{altitud_capital}")
    runner.registerInfo("Temperatura de agua de red: #{temps_agua_red}")
  else
    runner.registerError("Provincia '#{provincia}' sin datos de temperatura de agua de red")
    return false
  end

  runner.registerValue('CTE_Provincia_AF', provincia)
  diff_altitud = altitud_emplazamiento - altitud_capital

  factores_correccion_mensual = [0.0066 * diff_altitud] * 3 + [0.0033 * diff_altitud] * 6 + [0.0066 * diff_altitud] * 3
  temps_agua_red_corregidas = temps_agua_red.zip(factores_correccion_mensual).map { |x, y| x - y }
  runner.registerValue('CTE Temperaturas de agua de red', '[' + temps_agua_red_corregidas.join(',') + ']')

  conjunto_reglas = nil
  model.getScheduleRulesets.each do |schedule_ruleset|
    if schedule_ruleset.name.get == CTE_HORARIOSAGUA
      conjunto_reglas = schedule_ruleset
      break
    end
  end

  if nil == conjunto_reglas
    runner.registerWarning("No se ha localizado el conjunto de reglas '#{ CTE_HORARIOSAGUA }' que definen la temperatura del agua fría de red. ¿Ha definido una instalación de ACS?")
  else
    meses = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
    runner.registerInfo("Localizado el conjunto de reglas '#{CTE_HORARIOSAGUA}'")
    conjunto_reglas.scheduleRules.each do |rule|
      day_sch = rule.daySchedule
      hora = day_sch.times[0]
      rule_name = rule.name.get

      day_sch.setName('dia_' + rule_name)
      day_sch.removeValue(hora)
      day_sch.addValue(hora, temps_agua_red_corregidas[meses.index(rule_name)].to_f)
    end
  end

  return true
end
