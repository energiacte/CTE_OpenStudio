# coding: utf-8
#see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on mondel objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require_relative "resources/cte_lib_measures_addvars.rb"
require_relative "resources/cte_lib_measures_tempaguafria.rb"

# Define parámetros y aplica medidas para uso con el CTE
class CTE_Model < OpenStudio::Ruleset::ModelUserScript

  def name
    return "Variables CTE"
  end

  def description
    return "Define parámetros y aplica medidas para la simulación en condiciones CTE."
  end

  def modeler_description
    return "Introduce variables de salida y aplica medidas para cálculo CTE."
  end

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    provincias_chs = OpenStudio::StringVector.new

    ['A_Coruna', 'Albacete', 'Alicante_Alacant', 'Almeria', 'Avila', 'Badajoz', 'Barcelona', 'Bilbao_Bilbo',
     'Burgos', 'Caceres', 'Cadiz', 'Castellon_Castello', 'Ceuta', 'Ciudad_Real', 'Cordoba', 'Cuenca',
     'Girona', 'Granada', 'Guadalajara', 'Huelva', 'Huesca', 'Jaen', 'Las_Palmas_de_Gran_Canaria', 'Leon',
     'Lleida', 'Logrono', 'Lugo', 'Madrid', 'Malaga', 'Melilla', 'Murcia', 'Ourense', 'Oviedo', 'Palencia',
     'Palma_de_Mallorca', 'Pamplona_Iruna', 'Pontevedra', 'Salamanca', 'San_Sebastian', 'Santa_Cruz_de_Tenerife',
     'Santander', 'Segovia', 'Sevilla', 'Soria', 'Tarragona', 'Teruel', 'Toledo', 'Valencia', 'Valladolid',
     'Vitoria_Gasteiz', 'Zamora', 'Zaragoza'].each{ |prov|  provincias_chs << prov }

    provincia = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('provincia', provincias_chs, true)
    provincia.setDisplayName("Provincia")
    provincia.setDefaultValue("Madrid")

    args << provincia

    altitud = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("altitud", true)
    altitud.setDisplayName("Altitud del emplazamiento")
    altitud.setUnits("metros")
    altitud.setDefaultValue(650)
    args << altitud

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

    cte_addvars(model, runner, user_arguments) # Nuevas variables y meters
    cte_tempaguafria(model, runner, user_arguments) # temperatura de agua de red

    # Get final condition ================================================
    runner.registerFinalCondition("CTE: Finalizada la aplicación de medidas de modelo.")

    return true
  end #end the run method
end #end the measure
CTE_Model.new.registerWithApplication
