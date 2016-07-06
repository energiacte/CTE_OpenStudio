class CambioHorarioVeranoInvierno < OpenStudio::Ruleset::WorkspaceUserScript

  def name
    return "Cambio horario verano invierno"
  end
  
  # human readable description
  def description
    return "Cambia la hora los ultimos domingos de marzo y octubre"
  end

  # human readable description of modeling approach
  def modeler_description
    return "En caso de existir cambia los valores del objeto RunPeriodControl_DayLightSavingTime, en caso
            contrario crea el objeto con los valores adecuados"
  end   
  
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end 
  
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)       
    
    f = 'log_cambioHorarioVeranoInvierno'
    msg(f, "__ Ajuste de horario invierno/verano__\n")
    #DO STUFF
    dayligthSavings = workspace.getObjectsByType("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
    if not dayligthSavings.empty?
        dayligthSavings.each do | dayligthSaving |
            msg(f, "  inital value: dayligthSaving.getString(0) -> #{dayligthSaving.getString(0)}\n")
            msg(f, "  inital value: dayligthSaving.getString(1) -> #{dayligthSaving.getString(1)}\n")
            result  = dayligthSaving.setString(0, "Last Sunday in March")
            result1 = dayligthSaving.setString(1, "Last Sunday in October")
            msg(f, "  succesfully written? -----------------------> #{result}\n")
            msg(f, "  succesfully written1? ----------------------> #{result1}\n")
            msg(f, "  final value --------------------------------> #{dayligthSaving.getString(0)}\n")
            msg(f, "  final value1 -------------------------------> #{dayligthSaving.getString(1)}\n")
        end
    else    
        #tableStyle = ops.IdfObject(ops.IddObjectType("RunPeriodControl_DayLightSavingTime".to_IddObjectType))
        dayligthSaving = OpenStudio::IdfObject.new("RunPeriodControl_DayLightSavingTime".to_IddObjectType)
        result  = dayligthSaving.setString(0, "Last Sunday in March")
        result1 = dayligthSaving.setString(1, "Last Sunday in October")
        msg(f, "  succesfully written? -----------------------> #{result}\n")
        msg(f, "  succesfully written1? ----------------------> #{result1}\n")
        msg(f, "  final value --------------------------------> #{dayligthSaving.getString(0)}\n")
        msg(f, "  final value1 -------------------------------> #{dayligthSaving.getString(1)}\n")
        msg(f, "array is empty \n")
        workspace.addObject(dayligthSaving)
    end
    
    msg(f, "\n __ fin del renombrado __\n")       
       
   return true 
   end 
  
  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}  
  end  
  
end #end the measure

#this allows the measure to be use by the application
CambioHorarioVeranoInvierno.new.registerWithApplication