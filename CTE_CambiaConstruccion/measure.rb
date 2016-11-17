#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'json'

#start the measure
class CTE_CambiaConstruccion < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return " CTE_Cambia_construccion"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for model objects --------------------------
    construction_set_handles = OpenStudio::StringVector.new
    construction_set_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    construction_set_args = model.getDefaultConstructionSets
    construction_set_args_hash = {}
    construction_set_args.each do |construction_set_arg|
      construction_set_args_hash[construction_set_arg.name.to_s] = construction_set_arg
    end

    #looping through sorted hash of model objects
    construction_set_args_hash.sort.map do |key, value|
      construction_set_handles << value.handle.to_s
      construction_set_display_names << key
    end

    #add building to string vector with construction set
    building = model.getBuilding
    construction_set_handles << building.handle.to_s
    construction_set_display_names << "<clear field>"

    #make a choice argument for construction set
    construction_set = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("CTE_Construccion_defecto", construction_set_handles, construction_set_display_names)
    construction_set.setDisplayName("Construcción por defecto")
    construction_set.setDefaultValue("<clear field>") #if no construction set is chosen this field will be cleared out
    args << construction_set    
    
    # Frame and Dividers -----------------------------------------------
    frames_handles = OpenStudio::StringVector.new
    frames_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    frames_args = model.getWindowPropertyFrameAndDividers
    frames_args_hash = {}
    frames_args.each do |frames_arg|
      frames_args_hash[frames_arg.name.to_s] = frames_arg
    end

    #looping through sorted hash of model objects
    frames_args_hash.sort.map do |key, value|
      frames_handles << value.handle.to_s
      frames_display_names << key
    end

    #add building to string vector with construction set
    building = model.getBuilding
    frames_handles << building.handle.to_s
    frames_display_names << "<clear field>"

    #make a choice argument for construction set
    framesAndDivider = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("CTE_Carpinteria", frames_handles, frames_display_names)
    framesAndDivider.setDisplayName("Elige la carpintería.")
    framesAndDivider.setDefaultValue("<clear field>") #if no construction set is chosen this field will be cleared out
    args << framesAndDivider

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    argumentos = Hash.new
    JSON.parse(model.building.get.comment[2..-1]).each do | clave, valor |
      argumentos[clave] = valor
    end
    
    user_arguments.each do | name, argument |
      #~ argumentos[name] = argument.printValue
      #~ argumentos[name] = runner.getStringArgumentValue(name, user_arguments).get.name
      argumentos[name] = runner.getOptionalWorkspaceObjectChoiceValue(name, user_arguments,model).get.name
      
    end
    
    
    model.building.get.setComment(argumentos.to_json)
    
    # DEFAULT CONSTRUCTION SET
    #assign the user inputs to variables -------------------------------
    cs_object = runner.getOptionalWorkspaceObjectChoiceValue("CTE_Construccion_defecto", user_arguments, model)

    #check the user_name for reasonableness
    cs_clear_field = false
    construction_set = nil
    if cs_object.empty?
      handle = runner.getStringArgumentValue("CTE_Construccion_defecto", user_arguments)
      if handle.empty?
        runner.registerError("No construction set was chosen.")
      else
        runner.registerError("The selected construction set with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not cs_object.get.to_DefaultConstructionSet.empty?
        construction_set = cs_object.get.to_DefaultConstructionSet.get
      elsif not cs_object.get.to_Building.empty?
        cs_clear_field = true
      else
        runner.registerError("Script Error - argument not showing up as construction set or building.")
        return false
      end
    end

    #reporting initial condition of model
    building = model.getBuilding
    defaultConstructionSet = building.defaultConstructionSet
    if not defaultConstructionSet.empty?
      runner.registerInitialCondition("The initial default construction set for the building is #{defaultConstructionSet.get.name}.")
    else
      runner.registerInitialCondition("The initial model doesn't have a default construction set for the building.")
    end
    
    # alter default construction set as requested
    if cs_clear_field
      building.resetDefaultConstructionSet
    else
      building.setDefaultConstructionSet(construction_set)
    end

    #reporting final condition of model
    defaultConstructionSet = building.defaultConstructionSet
    if not defaultConstructionSet.empty?
      runner.registerFinalCondition("The final default construction set for the building is #{defaultConstructionSet.get.name}.")
    else
      runner.registerFinalCondition("The final model doesn't have a default construction set for the building.")
    end
    
    if construction_set      
      if "ABCDE".include?(construction_set.name.get[-1])
        construccionVentanasName = "CTE_2013_Huecos_zona #{construction_set.name.get[-1]}"
      elsif construction_set.name.get.end_with?("Alfa") 
        construccionVentanasName = "CTE_2013_Huecos_zona alfa"
      end
    else
      puts "Error, no #{construction_set}"
    end     
    
    
    # definir el shadingControl a partir del material de sombra
    materialPersiana = ''
    model.getShadingMaterials.each do | material |
      materialPersiana = material if material.name.get == "CTE_Sombra estacional_Persiana"        
    end
    shadingControl = OpenStudio::Model::ShadingControl.new(materialPersiana)
    
    shadingControl.setName('control persianas')
    horarioPersiana = ''
    model.getSchedules.each do |schedule|
      horarioPersiana = schedule if schedule.name.get == "CTER24B_SombraEstacional"
    end    
    shadingControl.setShadingType("ExteriorShade")
    shadingControl.setShadingControlType('OnIfScheduleAllows')
    shadingControl.setSchedule(horarioPersiana)
    
    
    #assign the user inputs to variables -------------------------------
    fd_object = runner.getOptionalWorkspaceObjectChoiceValue("CTE_Carpinteria", user_arguments, model)

    #check the user_name for reasonableness
    fd_clear_field = false
    frameAndDivider = nil
    if fd_object.empty?
      fd_handle = runner.getStringArgumentValue("CTE_Carpinteria", user_arguments)
      if fd_handle.empty?
        runner.registerError("No se eligió carpintería.")
      else
        runner.registerError("La carpintería seleccionada con handle '#{handle}' no está en el modelo. It may have been removed by another measure.")
      end
      return false
    else
      if not fd_object.get.to_WindowPropertyFrameAndDivider.empty?
        frameAndDivider = fd_object.get.to_WindowPropertyFrameAndDivider.get
      elsif not fd_object.get.to_Building.empty?
        fd_clear_field = true
      else
        runner.registerError("Script Error - argument not showing up as WindowPropertyFrameAndDivider or building.")
        return false
      end
    end
    
    puts "frame and divider #{frameAndDivider}"
    
    # modifca el control y el marco en las ventanas correspondientes
    model.getSubSurfaces.each do | subsurface |
      next if not ['FixedWindow', 'OperableWindow'].include?(subsurface.subSurfaceType)
      
      if not subsurface.construction.empty? and 
          subsurface.construction.get.name.get == construccionVentanasName
          subsurface.setShadingControl(shadingControl)
          subsurface.setWindowPropertyFrameAndDivider(frameAndDivider)
      end
    end
    return true
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
CTE_CambiaConstruccion.new.registerWithApplication
