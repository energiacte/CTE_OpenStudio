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

require 'json'

require_relative "resources/cte_lib_measures_addvars.rb"
require_relative "resources/cte_lib_measures_tempaguafria.rb"
require_relative "resources/cte_lib_measures_ventilacion.rb"
require_relative "resources/cte_lib_measures_infiltracion.rb"
require_relative "resources/cte_lib_measures_puentestermicos.rb"

# Medida de OpenStudio (ModelUserScript) que modifica el modelo para su uso con el CTE
# Para su correcto funcionamiento esta medida debe emplearse con una plantilla adecuada.
# La plantilla define objetos tipo como horarios, tipos de espacios, etc.
class CTE_Model < OpenStudio::Ruleset::ModelUserScript

  def name
    return "CTE Model"
  end

  def description
    return "Define parámetros y aplica medidas para la simulación en condiciones CTE."
  end

  def modeler_description
    return "Introduce variables de salida y aplica medidas para cálculo CTE."
  end

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    usoedificio_chs = OpenStudio::StringVector.new
    usoedificio_chs << 'Residencial'
    usoedificio_chs << 'Terciario'
    usoEdificio = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('CTE_Uso_edificio', usoedificio_chs, true)
    usoEdificio.setDisplayName("Uso del edificio")
    #~ usoEdificio.setDefaultValue('Residencial')
    usoEdificio.setDefaultValue('Terciario')
    args << usoEdificio

    tipoEdificio = OpenStudio::StringVector.new
    tipoEdificio << 'Nuevo'
    tipoEdificio << 'Existente'
    tipo = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("CTE_Tipo_edificio", tipoEdificio, true)
    tipo.setDisplayName("Edificio nuevo o existente")
    tipo.setDefaultValue('Nuevo')
    args << tipo

    provincias_chs = OpenStudio::StringVector.new

    ['A_Coruna', 'Albacete', 'Alicante_Alacant', 'Almeria', 'Avila', 'Badajoz', 'Barcelona', 'Bilbao_Bilbo',
     'Burgos', 'Caceres', 'Cadiz', 'Castellon_Castello', 'Ceuta', 'Ciudad_Real', 'Cordoba', 'Cuenca',
     'Girona', 'Granada', 'Guadalajara', 'Huelva', 'Huesca', 'Jaen', 'Las_Palmas_de_Gran_Canaria', 'Leon',
     'Lleida', 'Logrono', 'Lugo', 'Madrid', 'Malaga', 'Melilla', 'Murcia', 'Ourense', 'Oviedo', 'Palencia',
     'Palma_de_Mallorca', 'Pamplona_Iruna', 'Pontevedra', 'Salamanca', 'San_Sebastian', 'Santa_Cruz_de_Tenerife',
     'Santander', 'Segovia', 'Sevilla', 'Soria', 'Tarragona', 'Teruel', 'Toledo', 'Valencia', 'Valladolid',
     'Vitoria_Gasteiz', 'Zamora', 'Zaragoza'].each{ |prov|  provincias_chs << prov }

    provincia = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('CTE_Provincia', provincias_chs, true)
    provincia.setDisplayName("Provincia")
    provincia.setDefaultValue("Madrid")

    args << provincia

    altitud = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Altitud", true)
    altitud.setDisplayName("Altitud del emplazamiento")
    altitud.setUnits("metros")
    altitud.setDefaultValue(650)
    args << altitud

    design_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Design_flow_rate", true)
    design_flow_rate.setDisplayName("Caudal de diseno de ventilacion del edificio (residencial)")
    design_flow_rate.setUnits("ren/h")
    design_flow_rate.setDefaultValue(0.63)
    args << design_flow_rate

    heat_recovery = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Heat_recovery", true)
    heat_recovery.setDisplayName("Eficiencia del recuperador de calor")
    heat_recovery.setUnits("adimensional")
    heat_recovery.setDefaultValue(0.0)
    args << heat_recovery

    fan_sfp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Fan_sfp", true)
    fan_sfp.setDisplayName("Consumo específico de ventiladores (SFP)")
    fan_sfp.setUnits("kPa")
    fan_sfp.setDefaultValue(2.5)
    args << fan_sfp

    fan_ntot = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Fan_ntot", true)
    fan_ntot.setDisplayName("Eficiencia global de ventiladores (n_tot)")
    fan_ntot.setUnits("adimensional")
    fan_ntot.setDefaultValue(0.5)
    args << fan_ntot

    tipoFlujo = OpenStudio::StringVector.new
    tipoFlujo << 'Simple flujo'
    tipoFlujo << 'Doble flujo'
    fan_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("CTE_Fan_type", tipoFlujo, true)
    fan_type.setDisplayName("Tipo de sistema de ventilación")
    fan_type.setDefaultValue('Simple flujo')
    args << fan_type

    claseVentana = OpenStudio::StringVector.new
    claseVentana << 'Clase 1'
    claseVentana << 'Clase 2'
    claseVentana << 'Clase 3'
    claseVentana << 'Clase 4'
    permeabilidad = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("CTE_Permeabilidad_ventanas", claseVentana, true)
    permeabilidad.setDisplayName("Permeabilidad de la carpintería.")
    permeabilidad.setDefaultValue('Clase 1')
    args << permeabilidad

    psiForjadoCubierta = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Psi_forjado_cubierta", true)
    psiForjadoCubierta.setDisplayName("TTL forjado con cubierta")
    psiForjadoCubierta.setUnits("W/mK")
    psiForjadoCubierta.setDefaultValue(0.24)
    args << psiForjadoCubierta

    psiFrenteForjado = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Psi_frente_forjado", true)
    psiFrenteForjado.setDisplayName("TTL frente forjado")
    psiFrenteForjado.setUnits("W/mK")
    psiFrenteForjado.setDefaultValue(0.1)
    args << psiFrenteForjado

    psiSoleraTerreno = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Psi_solera_terreno", true)
    psiSoleraTerreno.setDisplayName("TTL forjado con solera")
    psiSoleraTerreno.setUnits("W/mK")
    psiSoleraTerreno.setDefaultValue(0.28)
    args << psiSoleraTerreno

    psiForjadoExterior = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Psi_forjado_exterior", true)
    psiForjadoExterior.setDisplayName("TTL forjado con suelo exterior")
    psiForjadoExterior.setDefaultValue(0.23)
    args << psiForjadoExterior


    psiContornoHuecos = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Psi_contorno_huecos", true)
    psiContornoHuecos.setDisplayName("TTL contorno de huecos")
    psiContornoHuecos.setUnits("W/mK")
    psiContornoHuecos.setDefaultValue(0.05)
    args << psiContornoHuecos


    coefStack = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Coef_stack", true)
    coefStack.setDisplayName("Coeficiente de Stack")
    coefStack.setDefaultValue(0.00029)
    args << coefStack

    coefWind = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("CTE_Coef_wind", true)
    coefWind.setDisplayName("Coeficiente de Viento")
    coefWind.setDefaultValue(0.000231)
    args << coefWind

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    runner.registerInitialCondition("CTE: Aplicando medidas de modelo.")

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      runner.registerError("Parámetros incorrectos")
      return false
    end

    argumentos = Hash.new
    user_arguments.each do | name, argument |
      argumentos[name] = argument.printValue
    end
    model.building.get.setComment(argumentos.to_json)


    result = cte_addvars(model, runner, user_arguments) # Nuevas variables y meters
    return result unless result == true

    #TODO: comprobar si hay equipo de ACS
    result = cte_tempaguafria(model, runner, user_arguments) # temperatura de agua de red
    return result unless result == true

    result = cte_ventresidencial(model, runner, user_arguments) # modelo de ventilación para residencial
    return result unless result == true

    result = cte_infiltracion(model, runner, user_arguments)
    return result unless result == true

    result = cte_puentestermicos(model, runner, user_arguments)
    return result unless result == true

    # Get final condition ================================================
    runner.registerFinalCondition("CTE: Finalizada la aplicación de medidas de modelo.")

    return true
  end #end the run method
end #end the measure
CTE_Model.new.registerWithApplication
