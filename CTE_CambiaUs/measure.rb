# -*- coding: utf-8 -*-
#
# Copyright (c) 2023 Ministerio de Fomento
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

require "json"
require_relative "resources/cte_lib_measures_cambia_u_muros.rb"
require_relative "resources/cte_lib_measures_cambia_u_cubiertas.rb"
require_relative "resources/cte_lib_measures_cambia_u_huecos.rb"
require_relative "resources/cte_lib_measures_cambia_u_suelos_terreno.rb"
require_relative "resources/cte_lib_measures_cambia_u_suelos_exterior.rb"

# Medida de OpenStudio (ModelUserScript) que modifica el modelo para su uso con el CTE
# Para su correcto funcionamiento esta medida debe emplearse con una plantilla adecuada.
# La plantilla define objetos tipo como horarios, tipos de espacios, etc.
class CTE_CambiaUs < OpenStudio::Measure::ModelMeasure
  def name
    return "CTE Cambia Us"
  end

  def description
    return "Modifica los valores de las transmitancias por tipo de elemento."
  end

  def modeler_description
    return "Busca los objetos referidos y modifica su transmitancia."
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    u_muros = OpenStudio::Measure::OSArgument::makeDoubleArgument("CTE_U_muros", true)
    u_muros.setDisplayName("U de muros")
    u_muros.setUnits("W/m2·K")
    u_muros.setDefaultValue(10)
    args << u_muros

    u_cubiertas = OpenStudio::Measure::OSArgument::makeDoubleArgument("CTE_U_cubiertas", true)
    u_cubiertas.setDisplayName("U de cubiertas")
    u_cubiertas.setUnits("W/m2·K")
    u_cubiertas.setDefaultValue(10)
    args << u_cubiertas

    u_suelos = OpenStudio::Measure::OSArgument::makeDoubleArgument("CTE_U_suelos", true)
    u_suelos.setDisplayName("U de suelos")
    u_suelos.setUnits("W/m2·K")
    u_suelos.setDefaultValue(10)
    args << u_suelos

    u_huecos = OpenStudio::Measure::OSArgument::makeDoubleArgument("CTE_U_huecos", true)
    u_huecos.setDisplayName("U de huecos")
    u_huecos.setUnits("W/m2·K")
    u_huecos.setDefaultValue(10)
    args << u_huecos

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    puts("Medida -> CTE_Cambia Us")
    runner.registerInitialCondition("CTE: Cambiando las transmitancias de los elementos CTE_CambiaUs.")

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      runner.registerError("Parámetros incorrectos")
      return false
    end

    argumentos = Hash.new
    user_arguments.each do |name, argument|
      argumentos[name] = argument.printValue
    end
    model.building.get.setComment(argumentos.to_json)

    puts("--> (cte_lib) cambia las transmitancias de los muros")
    runner.registerInfo("Llamada a la actualización de muros")
    result = cte_cambia_u_muros(model, runner, user_arguments)
    return result unless result == true

    puts("--> (cte_lib) cambia las transmitancias de las cubiertas")
    runner.registerInfo("Llamada a la actualización de cubiertas")
    result = cte_cambia_u_cubiertas(model, runner, user_arguments)
    return result unless result == true

    puts("--> (cte_lib) cambia las transmitancias de los suelos en contacto con el terreno")
    runner.registerInfo("Llamada a la actualización de los suelos en contacto con el terreno")
    result = cte_cambia_u_suelos_terreno(model, runner, user_arguments)
    return result unless result == true

    puts("--> (cte_lib) cambia las transmitancias de los suelos exteriores")
    runner.registerInfo("Llamada a la actualización de los suelos exteriores")
    result = cte_cambia_u_suelos_exteriores(model, runner, user_arguments)
    return result unless result == true

    puts("--> (cte_lib) cambia las transmitancias de los huecos")
    runner.registerInfo("Llamada a la actualización de los huecos")
    result = cte_cambia_u_huecos(model, runner, user_arguments)
    return result unless result == true

    # result = cte_addvars(model, runner, user_arguments) # Nuevas variables y meters
    # return result unless result == true

    # site = model.getSite
    # weather_file = site.name.get
    # runner.registerValue("CTE_Weather_file", weather_file)

    # Get final condition ================================================
    runner.registerFinalCondition("CTE: Finalizado el cambio de las transmitancias de los elementos.")

    return true
  end #end the run method
end #end the measure

CTE_CambiaUs.new.registerWithApplication
