# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class EliminacionDePersianasEspurias < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Eliminacion de persianas espurias"
  end

  # human readable description
  def description
    return "Elimina las definiciones de shading control que no se usan porque, en caso contrario, dan error en la simulacion"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Elimina las definiciones de shading control que no se usan porque, en caso contrario, dan error en la simulacion"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    log = 'log_eliminacionPersianas'
    msg(log, "___ eliminacion de persianas __\n")
    
    model.getShadingControls.each do | persiana |
        msg(log, "  **#{persiana.getString(0).to_s}**\n")
        # msg(log, " string.empy?||#{persiana.getString(3).to_s.empty?}||\n")        
        # msg(log, "______\n")        
        if persiana.getString(3).to_s.empty?
            msg(log, " localizada vacia\n")
            persiana.remove            
        end
    end
    msg(log, "___ quedan __ \n")
    model.getShadingControls.each do | persiana |
        msg(log, " queda la persiana #{persiana}\n")
    end   

    return true

  end

  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end
  
end

# register the measure to be used by the application
EliminacionDePersianasEspurias.new.registerWithApplication
