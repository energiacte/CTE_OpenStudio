# Copyright (c) 2016-2023 Ministerio de Fomento
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

require "csv"
require "fileutils"

CTE_HORARIOSAGUA = "CTE_ACS_Temperatura_agua_fria".freeze

CAPITAL_Y_ALT_REF_FOR_CLIMATEZONE = {
  "A3" => ["Cadiz", 0],
  "A4" => ["Almeria", 0],
  "B3" => ["Valencia", 8],
  "B4" => ["Sevilla", 9],
  "C1" => ["Bilbao_Bilbo", 214],
  "C2" => ["Barcelona", 1],
  "C3" => ["Granada", 754],
  "C4" => ["Toledo", 445],
  "D1" => ["Vitoria_Gasteiz", 512],
  "D2" => ["Zamora", 617],
  "D3" => ["Madrid", 589],
  "E1" => ["Burgos", 861]
}

# Mapping de temperaturas de altitud y Tªs de agua fría de referencia por capital de provincia
# TODO: Pasar a código y eliminar achivo
# ["A_Coruna", "Albacete", "Alicante_Alacant", "Almeria", "Avila", "Badajoz", "Barcelona", "Bilbao_Bilbo",
# "Burgos", "Caceres", "Cadiz", "Castellon_Castello", "Ceuta", "Ciudad_Real", "Cordoba", "Cuenca",
# "Girona", "Granada", "Guadalajara", "Huelva", "Huesca", "Jaen", "Las_Palmas_de_Gran_Canaria", "Leon",
# "Lleida", "Logrono", "Lugo", "Madrid", "Malaga", "Melilla", "Murcia", "Ourense", "Oviedo", "Palencia",
# "Palma_de_Mallorca", "Pamplona_Iruna", "Pontevedra", "Salamanca", "San_Sebastian", "Santa_Cruz_de_Tenerife",
# "Santander", "Segovia", "Sevilla", "Soria", "Tarragona", "Teruel", "Toledo", "Valencia", "Valladolid",
# "Vitoria_Gasteiz", "Zamora", "Zaragoza"]
def cte_temps_map(runner)
  temps_agua_file = File.dirname(__FILE__) + "/temperaturas_agua_fria.csv"
  temps_agua_red = {}
  File.read(temps_agua_file).each_line do |line|
    next if line.start_with?("#")

    csv_line = CSV.parse_line(line.strip, {col_sep: ","})
    prov = csv_line[0].to_s
    altref = csv_line[1].to_f
    temps = csv_line[2..csv_line.size].map { |v| v.to_f }
    temps_agua_red[prov] = [altref, temps]
  rescue
    runner.registerError("Error al leer archivo #{temps_agua_file} en línea #{line}")
    return nil
  end

  temps_agua_red
end

# Obtén la capital de provincia y altitud del clima dado
# TODO: Lo ideal sería leer la provincia y la altitud del archivo de climas
def get_site_prov_alt(weather_file)
  if weather_file.include?("canarias")
    capital_prov = "Las_Palmas_de_Gran_Canaria"
    altitud_emplazamiento = 114.0
  else
    zonaclimatica = weather_file[0, 2]
    capital_prov, altitud_emplazamiento = CAPITAL_Y_ALT_REF_FOR_CLIMATEZONE[zonaclimatica]
  end

  return capital_prov, altitud_emplazamiento
end

# Obtén diferencia de altitud con la capital y
# temperatura de agua de red de la capital para el clima dado
def get_water_temps(runner, weather_file)
  capital_prov, altitud_emplazamiento = get_site_prov_alt(weather_file)

  temps_agua_red = cte_temps_map(runner)
  if temps_agua_red.nil? || !temps_agua_red.key?(capital_prov)
    runner.registerError("Capital de provincia '#{capital_prov}' sin datos de temperatura de agua de red")
    return false
  end
  altitud_capital, temps_agua_red = temps_agua_red[capital_prov]

  runner.registerValue("Capital de referencia AF", capital_prov)
  runner.registerInfo("Altitud de la capital de provincia: #{altitud_capital}")
  runner.registerInfo("Temperatura de agua de red: #{temps_agua_red}")

  diff_altitud = altitud_emplazamiento - altitud_capital
  factores_correccion_mensual = [0.0066 * diff_altitud] * 3 + [0.0033 * diff_altitud] * 6 + [0.0066 * diff_altitud] * 3

  temps_agua_red.zip(factores_correccion_mensual).map { |x, y| x - y }
end

MESES = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]

# Introduce perfiles mensuales de la temperatura de agua de red en funcion de la provincia y corregida con la altitud
# TODO: Detectar caso en el que no está definida la demanda de ACS (no hay circuito) para evitar el fallo (¿Localizar WaterEquipment?).
def cte_tempaguafria(model, runner, user_arguments)
  weather_file = model.getSite.name.get
  water_temps = get_water_temps(runner, weather_file)

  runner.registerValue("CTE Temperaturas de agua de red", "[" + water_temps.join(",") + "]")

  conjunto_reglas = model.getScheduleRulesets.find { |schedule_ruleset| schedule_ruleset.name.get == CTE_HORARIOSAGUA }

  if conjunto_reglas.nil?
    runner.registerWarning("No se ha localizado el conjunto de horarios de temperatura de agua fría de red '#{CTE_HORARIOSAGUA}'. ¿Ha definido una instalación de ACS?")
    return false
  end

  runner.registerInfo("Localizado el conjunto de reglas '#{CTE_HORARIOSAGUA}'")
  conjunto_reglas.scheduleRules.each do |rule|
    day_sch = rule.daySchedule
    hora = day_sch.times[0]
    rule_name = rule.name.get

    day_sch.setName("dia_" + rule_name)
    day_sch.removeValue(hora)
    day_sch.addValue(hora, water_temps[MESES.index(rule_name)].to_f)
  end

  true
end
