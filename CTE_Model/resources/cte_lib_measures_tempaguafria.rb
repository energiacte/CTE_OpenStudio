# coding: utf-8
# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require 'csv'
require 'fileutils'

# Introduce perfiles mensuales de la temperatura de agua de red en funcion de la provincia y corregida con la altitud
def cte_tempaguafria(model, runner, user_arguments)

  runner.registerInfo("CTE: fijando temperatura de agua de red")

  # Variables
  provincia = runner.getStringArgumentValue('provincia', user_arguments)
  altitudEmplazamiento = runner.getDoubleArgumentValue('altitud', user_arguments)
  if (altitudEmplazamiento > 4000)
    runner.registerError("Altitud excesiva del emplazamiento: #{ altitudEmplazamiento }")
    return false
  end

  # Calcula temperatura de agua de red
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

  if temperaturasAguaDeRed.has_key?(provincia)
    puts temperaturasAguaDeRed[provincia]
    altitudCapital, temperaturasAguaDeRed = temperaturasAguaDeRed[provincia]
    runner.registerInfo("Altitud de la provincia: #{ altitudCapital }")
    runner.registerInfo("Temperatura de agua de red: #{ temperaturasAguaDeRed }")
  else
    runner.registerError("Provincia '#{provincia}' sin datos de temperatura de agua de red")
    return false
  end

  diffAltitud = altitudEmplazamiento - altitudCapital

  factoresCorreccionMensual = [0.0066 * diffAltitud] * 3 + [0.0033 * diffAltitud] * 6 + [0.0066 * diffAltitud] * 3
  temperaturasAguaDeRedCorregidas = temperaturasAguaDeRed.zip(factoresCorreccionMensual).map { |x, y| x - y }

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
