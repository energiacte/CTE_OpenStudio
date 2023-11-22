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

require "json"

require_relative "resources/cte_lib_measures_addvars"
require_relative "resources/cte_lib_measures_tempaguafria"
require_relative "resources/cte_lib_measures_infiltracion"
require_relative "resources/cte_lib_measures_puentestermicos"
require_relative "resources/cte_lib_measures_cambia_u_opacos"
require_relative "resources/cte_lib_measures_cambia_u_huecos"

# Medida de OpenStudio (ModelUserScript) que modifica el modelo para su uso con el CTE
# Para su correcto funcionamiento esta medida debe emplearse con una plantilla adecuada.
# La plantilla define objetos tipo como horarios, tipos de espacios, etc.
class CTE_Model < OpenStudio::Measure::ModelMeasure
  def name
    "CTE Model"
  end

  def description
    "Define parámetros y aplica medidas para la simulación en condiciones CTE."
  end

  def modeler_description
    "Introduce variables de salida y aplica medidas para cálculo CTE."
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    u_opacos = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_U_opacos", true)
    u_opacos.setDisplayName("U de opacos")
    u_opacos.setUnits("W/m2·K")
    u_opacos.setDefaultValue(10)
    args << u_opacos

    u_huecos = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_U_huecos", true)
    u_huecos.setDisplayName("U de huecos")
    u_huecos.setUnits("W/m2·K")
    u_huecos.setDefaultValue(10)
    args << u_huecos

    usoedificio_chs = OpenStudio::StringVector.new
    usoedificio_chs << "Residencial"
    usoedificio_chs << "Terciario"
    uso_edificio = OpenStudio::Measure::OSArgument.makeChoiceArgument("CTE_Uso_edificio", usoedificio_chs, true)
    uso_edificio.setDisplayName("Uso del edificio")
    # ~ uso_edificio.setDefaultValue('Residencial')
    uso_edificio.setDefaultValue("Terciario")
    args << uso_edificio

    tipo_edificio = OpenStudio::StringVector.new
    tipo_edificio << "Nuevo"
    tipo_edificio << "Existente"
    tipo = OpenStudio::Measure::OSArgument.makeChoiceArgument("CTE_Tipo_edificio", tipo_edificio, true)
    tipo.setDisplayName("Edificio nuevo o existente")
    tipo.setDefaultValue("Nuevo")
    args << tipo

    clase_ventana = OpenStudio::StringVector.new
    clase_ventana << "Clase 1"
    clase_ventana << "Clase 2"
    clase_ventana << "Clase 3"
    clase_ventana << "Clase 4"
    permeabilidad = OpenStudio::Measure::OSArgument.makeChoiceArgument("CTE_Permeabilidad_ventanas", clase_ventana, true)
    permeabilidad.setDisplayName("Permeabilidad de la carpintería.")
    permeabilidad.setDefaultValue("Clase 1")
    args << permeabilidad

    factor_sombras_moviles = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_F_sombras_moviles", true)
    factor_sombras_moviles.setDisplayName("Factor de sombras móviles")
    factor_sombras_moviles.setDefaultValue(0.3)
    args << factor_sombras_moviles

    psi_forjado_cubierta = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_Psi_forjado_cubierta", true)
    psi_forjado_cubierta.setDisplayName("TTL forjado con cubierta")
    psi_forjado_cubierta.setUnits("W/mK")
    psi_forjado_cubierta.setDefaultValue(0.24)
    args << psi_forjado_cubierta

    psi_frente_forjado = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_Psi_frente_forjado", true)
    psi_frente_forjado.setDisplayName("TTL frente forjado")
    psi_frente_forjado.setUnits("W/mK")
    psi_frente_forjado.setDefaultValue(0.1)
    args << psi_frente_forjado

    psi_solera_terreno = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_Psi_solera_terreno", true)
    psi_solera_terreno.setDisplayName("TTL forjado con solera")
    psi_solera_terreno.setUnits("W/mK")
    psi_solera_terreno.setDefaultValue(0.28)
    args << psi_solera_terreno

    psi_forjado_exterior = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_Psi_forjado_exterior", true)
    psi_forjado_exterior.setDisplayName("TTL forjado con suelo exterior")
    psi_forjado_exterior.setDefaultValue(0.23)
    args << psi_forjado_exterior

    psi_contorno_huecos = OpenStudio::Measure::OSArgument.makeDoubleArgument("CTE_Psi_contorno_huecos", true)
    psi_contorno_huecos.setDisplayName("TTL contorno de huecos")
    psi_contorno_huecos.setUnits("W/mK")
    psi_contorno_huecos.setDefaultValue(0.05)
    args << psi_contorno_huecos

    args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    puts("\nCTE_Model measure: Aplicando medida de Modelo.")
    runner.registerInitialCondition("CTE: Aplicando medidas de modelo.")

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      runner.registerError("Parámetros incorrectos")
      return false
    end

    argumentos = {}
    user_arguments.each do |name, argument|
      argumentos[name] = argument.printValue
    end
    model.building.get.setComment(argumentos.to_json)

    # puts('cambia las transmitancias de los opacos')
    # runner.registerInfo('Llamada a la actualización de opacos')
    # result = cte_cambia_u_opacos(model, runner, user_arguments)
    # return result unless result == true

    # puts('cambia las transmitancias de los huecos')
    # runner.registerInfo('Llamada a la actualización de huecos')
    # result = cte_cambia_u_huecos(model, runner, user_arguments)
    # return result unless result == true

    result = cte_addvars(model, runner, user_arguments) # Nuevas variables y meters
    return result unless result == true

    # TODO: comprobar si hay equipo de ACS
    result = cte_tempaguafria(model, runner, user_arguments) # temperatura de agua de red
    return result unless result == true

    result = cte_infiltracion(model, runner, user_arguments)
    return result unless result == true

    result = cte_puentestermicos(model, runner, user_arguments)
    return result unless result == true

    site = model.getSite
    weather_file = site.name.get
    runner.registerValue("CTE_Weather_file", weather_file)

    # Get final condition ================================================
    runner.registerFinalCondition("CTE: Finalizada la aplicación de medidas de modelo.")

    true
  end # end the run method
end # end the measure

CTE_Model.new.registerWithApplication
