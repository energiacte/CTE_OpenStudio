# coding: utf-8
# Author(s): Daniel Jiménez González, Rafael Villar Burke
# email: danielj@ietcc.csic.es, pachi@ietcc.csic.es
#
# Measure based on previous measure in the BCL "Assign ConstructionSet to Building" by David Goldwasser
# Change constructionSet of Building and assign FrameAndDivider to windows that inherit from the defaultConstructionSet

require 'json'

class CTE_CambiaConstruccion < OpenStudio::Measure::ModelMeasure
#class CTE_CambiaConstruccion < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "CTE_Cambia_construccion"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

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

    # Initial condition of model ------------------------------------------------
    building = model.getBuilding
    defaultConstructionSet = building.defaultConstructionSet
    if not defaultConstructionSet.empty?
      defaultextsurfcons = defaultConstructionSet.get.defaultExteriorSubSurfaceConstructions
      if defaultextsurfcons.empty?
        defaultWindowConstructionName = ''
      else
        windowconst = defaultextsurfcons.get.fixedWindowConstruction
        defaultWindowConstructionName = windowconst.empty? ? '' : windowconst.get.name
      end
      runner.registerInitialCondition("The initial default construction set for the building is #{defaultConstructionSet.get.name} and it's window name is #{defaultWindowConstructionName }.")
    else
      runner.registerInitialCondition("The initial model doesn't have a default construction set for the building.")
    end

    # Localiza ConstructionSet seleccionado -------------------------------------
    cs_param_object = runner.getOptionalWorkspaceObjectChoiceValue("CTE_Construccion_defecto", user_arguments, model)

    construction_set = nil
    reset_cset = false
    if cs_param_object.empty?
      handle = runner.getStringArgumentValue("CTE_Construccion_defecto", user_arguments)
      if handle.empty?
        runner.registerError("No se seleccionó ConstructionSet.")
      else
        runner.registerError("No se encuentra el ConstructionSet '#{handle}'. Pudo eliminarlo otra medida.")
      end
      return false
    else
      if not cs_param_object.get.to_DefaultConstructionSet.empty? # hay un objeto defaultConstructionSet -> cambiamos a ese
        construction_set = cs_param_object.get.to_DefaultConstructionSet.get
      elsif not cs_param_object.get.to_Building.empty? # hay un objeto Building -> reseteamos
        reset_cset = true
      else
        runner.registerError("Script Error - argument not showing up as construction set or building.")
        return false
      end
    end

    # MODIFICA ConstructionSet -------------------------------------------------------
    # alter default construction set as requested
    if reset_cset == true
      building.resetDefaultConstructionSet
    else
      building.setDefaultConstructionSet(construction_set)
    end

    # Localiza FrameAndDivider seleccionado ---------------------------------------
    fd_object = runner.getOptionalWorkspaceObjectChoiceValue("CTE_Carpinteria", user_arguments, model)

    reset_fd = false
    frame_and_divider = nil
    if fd_object.empty?
      fd_handle = runner.getStringArgumentValue("CTE_Carpinteria", user_arguments)
      if fd_handle.empty?
        runner.registerError("No se seleccionó carpintería.")
      else
        runner.registerError("No se encuentra el WindowPropertyFrameAndDivider '#{handle}'. Pudo eliminarla otra medida.")
      end
      return false
    else
      if not fd_object.get.to_WindowPropertyFrameAndDivider.empty? # hay FrameAndDivider -> cambia
        frame_and_divider = fd_object.get.to_WindowPropertyFrameAndDivider.get
      elsif not fd_object.get.to_Building.empty? # hay Building -> reset
        reset_fd = true
      else
        runner.registerError("Script Error - argument not showing up as WindowPropertyFrameAndDivider or building.")
        return false
      end
    end

    # TODO: caso con reset_fd: recorre subsurfaces y .resetWindowPropertyFrameAndDivider
    if reset_fd == true
      model.getSubSurfaces.each do | subsurface |
        next if not ['FixedWindow', 'OperableWindow'].include?(subsurface.subSurfaceType)
        subsurface.resetWindowPropertyFrameAndDivider
      end
    end

    changed_subsurfaces = 0
    changed_shadowcontrols = 0
    # Cambio de FrameAndDivider de Ventanas con construcción por defecto del construction set =========
    if reset_cset != true and reset_fd != true
      # Localiza material de sombra estacional ----------------------------------------
      materialPersiana = model.getShadingMaterials.detect{ |material | material.name.get.start_with?("CTE_Sombra") }
      defaultextsurfcons = construction_set.defaultExteriorSubSurfaceConstructions
      if defaultextsurfcons.empty?
        target_window_construction_name = ''
      else
        windowconst = defaultextsurfcons.get.fixedWindowConstruction
        target_window_construction_name = windowconst.empty? ? '' : windowconst.get.name
      end

      if target_window_construction_name != ''
        # GENERA SHADINGCONTROL ---------------------
        shadingControl = OpenStudio::Model::ShadingControl.new(materialPersiana)
        shadingControl.setName('Control sombra estacional')
        horarioPersiana = model.getSchedules.detect{ |schedule| schedule.name.get == "CTER24B_SombraEstacional" }
        shadingControl.setShadingType("ExteriorShade")
        shadingControl.setShadingControlType('OnIfScheduleAllows')
        shadingControl.setSchedule(horarioPersiana)

        # MODIFICA SHADINGCONTROL Y FRAMEANDIVIDER PARA LAS CONSTRUCCIONES DE HUECO SELECCIONADAS
        model.getSubSurfaces.each do | subsurface |
          next if not ['FixedWindow', 'OperableWindow'].include?(subsurface.subSurfaceType)
          next if subsurface.construction.empty?
          if subsurface.construction.get.name.to_s == target_window_construction_name.to_s
            changed_subsurfaces += 1
            subsurface.resetShadingControl
            surface = subsurface.surface
            unless surface.empty?
              space = surface.get.space
              unless space.empty?
                spacetype = space.get.spaceType
                unless spacetype.empty?
                  spacetypename = spacetype.get.name
                  if spacetypename.get.start_with?('CTE_AR')
                      changed_shadowcontrols += 1
                      subsurface.setShadingControl(shadingControl) # Shading control solo en residencial
                  end
                end
              end
            end
            subsurface.setWindowPropertyFrameAndDivider(frame_and_divider)
          end
        end
      end
    end

    #reporting final condition of model
    defaultConstructionSet = building.defaultConstructionSet
    if not defaultConstructionSet.empty?
      constructionset_name = defaultConstructionSet.get.name
      frameanddivider_name = frame_and_divider ? frame_and_divider.name.get : ''
    else
      constructionset_name = '<vacio>'
      frameanddivider_name = '<vacio>'
    end

    runner.registerFinalCondition("The final default construction set for the building is '#{ constructionset_name }' with FrameAndDivider '#{ frameanddivider_name }'. Changed #{ changed_subsurfaces } subsurfaces and #{ changed_shadowcontrols } ShadingControl objects.")

    #Guardamos datos en Modelo
    argumentos = Hash.new
    unless model.building.get.comment.empty?
      json = JSON.parse(model.building.get.comment[2..-1])
      json.each do | clave, valor |
        argumentos[clave] = valor
      end
    end
    argumentos["CTE_ConstructionSet"] = constructionset_name.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
    argumentos["CTE_Carpinteria"] = frameanddivider_name.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
    model.building.get.setComment(argumentos.to_json)

    return true
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
CTE_CambiaConstruccion.new.registerWithApplication
