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

# Mapping de temperaturas de altitud y Tªs de agua fría de referencia por capital de provincia
# Provincia => [altitud_referencia,valores_mensuales_temperatura_agua_fria]
CTE_TEMPS_MAP = {
  "A_Coruna" => [0, [10, 10, 11, 12, 13, 14, 16, 16, 15, 14, 12, 11]],
  "Albacete" => [677, [7, 8, 9, 11, 14, 17, 19, 19, 17, 13, 9, 7]],
  "Alicante_Alacant" => [7, [11, 12, 13, 14, 16, 18, 20, 20, 19, 16, 13, 12]],
  "Almeria" => [0, [12, 12, 13, 14, 16, 18, 20, 21, 19, 17, 14, 12]],
  "Avila" => [1054, [6, 6, 7, 9, 11, 14, 17, 16, 14, 11, 8, 6]],
  "Badajoz" => [168, [9, 10, 11, 13, 15, 18, 20, 20, 18, 15, 12, 9]],
  "Barcelona" => [1, [9, 10, 11, 12, 14, 17, 19, 19, 17, 15, 12, 10]],
  "Bilbao_Bilbo" => [214, [9, 10, 10, 11, 13, 15, 17, 17, 16, 14, 11, 10]],
  "Burgos" => [861, [5, 6, 7, 9, 11, 13, 16, 16, 14, 11, 7, 6]],
  "Caceres" => [385, [9, 10, 11, 12, 14, 18, 21, 20, 19, 15, 11, 9]],
  "Cadiz" => [0, [12, 12, 13, 14, 16, 18, 19, 20, 19, 17, 14, 12]],
  "Castellon_Castello" => [18, [10, 11, 12, 13, 15, 18, 19, 20, 18, 16, 12, 11]],
  "Ceuta" => [0, [11, 11, 12, 13, 14, 16, 18, 18, 17, 15, 13, 12]],
  "Ciudad_Real" => [630, [7, 8, 10, 11, 14, 17, 20, 20, 17, 13, 10, 7]],
  "Cordoba" => [113, [10, 11, 12, 14, 16, 19, 21, 21, 19, 16, 12, 10]],
  "Cuenca" => [975, [6, 7, 8, 10, 13, 16, 18, 18, 16, 12, 9, 7]],
  "Girona" => [143, [8, 9, 10, 11, 14, 16, 19, 18, 17, 14, 10, 9]],
  "Granada" => [754, [8, 9, 10, 12, 14, 17, 20, 19, 17, 14, 11, 8]],
  "Guadalajara" => [708, [7, 8, 9, 11, 14, 17, 19, 19, 16, 13, 9, 7]],
  "Huelva" => [50, [12, 12, 13, 14, 16, 18, 20, 20, 19, 17, 14, 12]],
  "Huesca" => [432, [7, 8, 10, 11, 14, 16, 19, 18, 17, 13, 9, 7]],
  "Jaen" => [436, [9, 10, 11, 13, 16, 19, 21, 21, 19, 15, 12, 9]],
  "Las_Palmas_de_Gran_Canaria" => [114, [15, 15, 16, 16, 17, 18, 19, 19, 19, 18, 17, 16]],
  "Leon" => [346, [6, 6, 8, 9, 12, 14, 16, 16, 15, 11, 8, 6]],
  "Lleida" => [131, [7, 9, 10, 12, 15, 17, 20, 19, 17, 14, 10, 7]],
  "Logrono" => [379, [7, 8, 10, 11, 13, 16, 18, 18, 16, 13, 10, 8]],
  "Lugo" => [412, [7, 8, 9, 10, 11, 13, 15, 15, 14, 12, 9, 8]],
  "Madrid" => [589, [8, 8, 10, 12, 14, 17, 20, 19, 17, 13, 10, 8]],
  "Malaga" => [0, [12, 12, 13, 14, 16, 18, 20, 20, 19, 16, 14, 12]],
  "Melilla" => [130, [12, 13, 13, 14, 16, 18, 20, 20, 19, 17, 14, 13]],
  "Murcia" => [25, [11, 11, 12, 13, 15, 17, 19, 20, 18, 16, 13, 11]],
  "Ourense" => [327, [8, 10, 11, 12, 14, 16, 18, 18, 17, 13, 11, 9]],
  "Oviedo" => [214, [9, 9, 10, 10, 12, 14, 15, 16, 15, 13, 10, 9]],
  "Palencia" => [722, [6, 7, 8, 10, 12, 15, 17, 17, 15, 12, 9, 6]],
  "Palma_de_Mallorca" => [1, [11, 11, 12, 13, 15, 18, 20, 20, 19, 17, 14, 12]],
  "Pamplona_Iruna" => [456, [7, 8, 9, 10, 12, 15, 17, 17, 16, 13, 9, 7]],
  "Pontevedra" => [77, [10, 11, 11, 13, 14, 16, 17, 17, 16, 14, 12, 10]],
  "Salamanca" => [770, [6, 7, 8, 10, 12, 15, 17, 17, 15, 12, 8, 6]],
  "San_Sebastian" => [5, [9, 9, 10, 11, 12, 14, 16, 16, 15, 14, 11, 9]],
  "Santa_Cruz_de_Tenerife" => [0, [15, 15, 16, 16, 17, 18, 20, 20, 20, 18, 17, 16]],
  "Santander" => [1, [10, 10, 11, 11, 13, 15, 16, 16, 16, 14, 12, 10]],
  "Segovia" => [1013, [6, 7, 8, 10, 12, 15, 18, 18, 15, 12, 8, 6]],
  "Sevilla" => [9, [11, 11, 13, 14, 16, 19, 21, 21, 20, 16, 13, 11]],
  "Soria" => [984, [5, 6, 7, 9, 11, 14, 17, 16, 14, 11, 8, 6]],
  "Tarragona" => [1, [10, 11, 12, 14, 16, 18, 20, 20, 19, 16, 12, 11]],
  "Teruel" => [995, [6, 7, 8, 10, 12, 15, 18, 17, 15, 12, 8, 6]],
  "Toledo" => [445, [8, 9, 11, 12, 15, 18, 21, 20, 18, 14, 11, 8]],
  "Valencia" => [8, [10, 11, 12, 13, 15, 17, 19, 20, 18, 16, 13, 11]],
  "Valladolid" => [704, [6, 8, 9, 10, 12, 15, 18, 18, 16, 12, 9, 7]],
  "Vitoria_Gasteiz" => [512, [7, 7, 8, 10, 12, 14, 16, 16, 14, 12, 8, 7]],
  "Zamora" => [617, [6, 8, 9, 10, 13, 16, 18, 18, 16, 12, 9, 7]],
  "Zaragoza" => [207, [8, 9, 10, 12, 15, 17, 20, 19, 17, 14, 10, 8]]
}

# Obtén la capital de provincia y altitud del clima dado
# TODO: Lo ideal sería leer la provincia y la altitud del archivo de climas
def get_site_prov_alt(weather_file)
  if weather_file.include?("canarias")
    capital_prov = "Las_Palmas_de_Gran_Canaria"
    altitud_emplazamiento = 114.0
  else
    zonaclimatica = weather_file[0, 2]
    capital_prov, altitud_emplazamiento = {
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
    }[zonaclimatica]
  end

  [capital_prov, altitud_emplazamiento]
end

# Obtén diferencia de altitud con la capital y
# temperatura de agua de red de la capital para el clima dado
def get_water_temps(runner, weather_file)
  capital_prov, altitud_emplazamiento = get_site_prov_alt(weather_file)

  altitud_capital, temps_agua_red = CTE_TEMPS_MAP[capital_prov]

  if altitud_capital.nil? || temps_agua_red.nil?
    runner.registerError("Capital de provincia '#{capital_prov}' sin datos de temperatura de agua de red")
    return false
  end

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
  # Obtenemos el nombre del archivo climático del runner o del modelo
  # TODO: Es posible que el archivo de climas venga en algún caso con su path completo? Por ahora no hemos tenido ese caso
  if runner.lastEpwFilePath.is_initialized
    weather_file = runner.lastEpwFilePath.get.to_s
  elsif model.getWeatherFile.path.is_initialized
    weather_file = model.getWeatherFile.path.get.to_s
  end

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
