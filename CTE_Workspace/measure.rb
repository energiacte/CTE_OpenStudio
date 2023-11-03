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

require_relative "resources/cte_lib_measures_zoneairbalance.rb"
require_relative "resources/cte_lib_measures_groundtemperature.rb"
require_relative "resources/cte_lib_measures_horarioestacional.rb"

# Medida de OpenStudio (WorkspaceUserScript) que modifica el modelo de EnergyPlus para uso con el CTE
# Esta medida se aplica a modelos transformados por medidas de modelo CTE
# y generados a partir de una plantilla apropiada
class CTE_Workspace < OpenStudio::Ruleset::WorkspaceUserScript

  def name
    return "Aplica las medidas al Workspace"
  end

  def description
    return "Modificaciones del IDF para calculo CTE DB-HE."
  end

  def modeler_description
    return "Fija temperaturas del terreno, balance de aire exterior y horario de verano."
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    runner.registerInitialCondition("CTE: aplicando medidas de Workspace")

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      runner.registerError("Parámetros incorrectos")
      return false
    end

    string_objects = []

    runner.registerInfo("[1/4] - Introducción de balance de aire exterior")
    result = cte_addAirBalance(runner, workspace, string_objects)
    return result unless result == true

    runner.registerInfo("[2/4] - Fija la temperatura del terreno")
    result = cte_groundTemperature(runner, workspace, string_objects)
    return result unless result == true


    runner.registerInfo("[3/4] - Incorpora objetos definidos en cadenas al workspace")
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      workspace.addObject(object)
    end

    runner.registerInfo("[4/4] - Introduce el cambio de hora los últimos domingos de marzo y octubre")
    result = cte_horarioestacional(runner, workspace)
    return result unless result == true

    # Añade report con detalles de vértices en superficies
    # SELECT * FROM TabularDataWithStrings WHERE ReportName = 'InitializationSummary' AND TableName = 'HeatTransfer Surface'
    # https://bigladdersoftware.com/epx/docs/23-2/input-output-reference/input-for-output.html#outputsurfaceslist
    # Object names must be in the E+ idd or the OS IDD (ProposedEnergy+.idd)
    object = OpenStudio::IdfObject.new("Output:Surfaces:List".to_IddObjectType)
    sf_list = workspace.addObject(object).get
    sf_list.setString(0, "DetailsWithVertices")

    return true
  end

end #end the measure

#this allows the measure to be use by the application
CTE_Workspace.new.registerWithApplication
