def cte_cambia_u_huecos(model, runner, user_arguments)
  runner.registerInfo("CTE: Cambiando la U de huecos")

  # toma el valor de la medida
  u_huecos = runner.getDoubleArgumentValue("CTE_U_huecos", user_arguments)
  puts("__Se ha seleccionado un valor de U_huecos de #{u_huecos} -> R=#{1 / u_huecos}.")

  # ! __01__ si queremos poner valores de seguridad irían aquí

  # ! __02__ recorre las superficies para detectar la ventanas

  # https://openstudio-sdk-documentation.s3.amazonaws.com/cpp/OpenStudio-3.5.1-doc/model/html/classopenstudio_1_1model_1_1_sub_surface.html
  windows = []
  window_constructions = []
  window_construction_names = []
  tipos_cubiertos = ["FixedWindow", "Door"]
  spaces = model.getSpaces
  spaces.each do |space|
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.windExposure == "WindExposed"
        surface.subSurfaces.each do |subsur|
          windows << subsur # también las puertas y esas cosas
          # puts("__subsurface Type #{subsur.subSurfaceType()} -> #{subsur.construction.get.name}")
          if !tipos_cubiertos.include?(subsur.subSurfaceType().to_s)
            puts("Tipo de hueco no cubierto por esta medida #{subsur.subSurfaceType().to_s}")
          end
        end
      end
    end
  end

  if windows.empty?
    runner.registerAsNotApplicable("El modelo no tiene ventanas.")
    return true
  end

  # ! __03__recorre las construcciones y materiales, los clona y los modifica

  # construye los hashes para hacer un seguimiento y evitar duplicados
  constructions_hash_old_new = {}
  constructions_hash_new_old = {} # used to get netArea of new construction and then cost objects of construction it replaced
  frame_hash_old_new = {}
  frame_hash_new_old = {}
  materials_hash = {}
  # array and counter for new constructions that are made, used for reporting final condition
  final_constructions_array = []
  final_frame_array = []

  # loop through all constructions and materials used on exterior walls, edit and clone
  window_constructions.each { |construccion| puts(construccion.name) } #construccion =elemento
  window_constructions.each do |window_construction|
    # runner.registerInfo("nombre de la construcción #{window_construction.name}")
    construction_layers = window_construction.layers
    max_thermal_resistance_material = ""
    max_thermal_resistance_material_index = ""
    # siempre tiene una única capa, pero mantengo el código de la otra medida
    materials_in_construction = construction_layers.map.with_index do |layer, i|
      { "name" => layer.name.to_s,
        "index" => i,
        "nomass" => !layer.to_MasslessOpaqueMaterial.empty?,
        "r_value" => layer.to_SimpleGlazing.get.uFactor,
        "mat" => layer }
    end

    if materials_in_construction.length == 1
      max_mat_hash = materials_in_construction[0]
    end

    window_construccion = subsur.construction.get
    if !window_construction_names.include?(window_construccion.name.to_s)
      window_constructions << window_construccion.to_Construction.get
      window_construction_names << window_construccion.name.to_s
    end
    
    max_thermal_resistance_material = max_mat_hash["mat"] # objeto OS
    max_thermal_resistance_material_index = max_mat_hash["index"] # indice de la capa
    max_thermal_resistance = max_thermal_resistance_material.to_SimpleGlazing.get.uFactor()

    # ! 04 modifica la composición
    final_construction = window_construction.clone(model)
    final_construction = final_construction.to_Construction.get
    final_construction.setName("#{window_construction.name} U huecos mod.")
    final_constructions_array << final_construction
    constructions_hash_old_new[window_construction.name.to_s] = final_construction
    constructions_hash_new_old[final_construction] = window_construction # push the object to hash key vs. name

    # puts("__final construction", final_construction)
    # puts("__layer__", final_construction.layers[0])
    # # buscar aquí como son los wrappers de OS a objeto Ruby:
    # # https://openstudio-sdk-documentation.s3.amazonaws.com/cpp/OpenStudio-3.5.1-doc/model/html/annotated.html
    # simpleGlazing = final_construction.layers[0].to_SimpleGlazing.get
    # puts("__layer__", simpleGlazing.uFactor())
    # simpleGlazing.setUFactor(u_huecos)
    # puts("__final construction", final_construction.layers[0])

    # # find already cloned insulation material and link to construction
    target_material = max_thermal_resistance_material
    found_material = false

    materials_hash.each do |orig, new|
      if target_material.name.to_s == orig
        new_material = new
        materials_hash[max_thermal_resistance_material.name.to_s] = new_material
        final_construction.eraseLayer(max_thermal_resistance_material_index)
        final_construction.insertLayer(max_thermal_resistance_material_index, new_material)
        found_material = true
      end
    end

    # clone and edit insulation material and link to construction
    if found_material == false
      new_material = max_thermal_resistance_material.clone(model)
      new_material = new_material.to_SimpleGlazing.get
      new_material.setName("#{max_thermal_resistance_material.name}_U-value #{u_huecos}")
      materials_hash[max_thermal_resistance_material.name.to_s] = new_material
      final_construction.eraseLayer(max_thermal_resistance_material_index)
      final_construction.insertLayer(max_thermal_resistance_material_index, new_material)
      runner.registerInfo("For construction'#{final_construction.name}', material'#{new_material.name}' was altered.")

      # edit insulation material
      new_material_matt = new_material
      new_material_matt.setUFactor(u_huecos)
    end
  end

  # loop through construction sets used in the model
  default_construction_sets = model.getDefaultConstructionSets
  default_construction_sets.each do |default_construction_set|
    if default_construction_set.directUseCount > 0
      default_subsurface_const_set = default_construction_set.defaultExteriorSubSurfaceConstructions
      if !default_subsurface_const_set.empty?
        starting_construction = default_subsurface_const_set.get.fixedWindowConstruction

        # creating new default construction set
        new_default_construction_set = default_construction_set.clone(model)
        new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get
        new_default_construction_set.setName("#{default_construction_set.name} adj u_huecos")
        puts("__ new_default_construction_set__ #{new_default_construction_set}")

        # create new surface set and link to construction set
        new_default_subsurface_const_set = default_subsurface_const_set.get.clone(model)
        new_default_subsurface_const_set = new_default_subsurface_const_set.to_DefaultSubSurfaceConstructions.get
        new_default_subsurface_const_set.setName("#{default_subsurface_const_set.get.name}  u_huecos adj")
        new_default_construction_set.setDefaultExteriorSubSurfaceConstructions(new_default_subsurface_const_set)
        puts("__ new_default_construction_set__ #{new_default_construction_set}")

        # use the hash to find the proper construction and link to new_default_subsurface_const_set
        target_const = new_default_subsurface_const_set.fixedWindowConstruction
        if !target_const.empty?
          target_const = target_const.get.name.to_s
          found_const_flag = false
          constructions_hash_old_new.each do |orig, new|
            if target_const == orig
              final_construction = new
              new_default_subsurface_const_set.setFixedWindowConstruction(final_construction)
              found_const_flag = true
            end
          end
          if found_const_flag == false # this should never happen but is just an extra test in case something goes wrong with the measure code
            runner.registerWarning("Measure couldn't find the construction named '#{target_const}' in the windows construction hash.")
          end
        end

        # swap all uses of the old construction set for the new
        construction_set_sources = default_construction_set.sources
        construction_set_sources.each do |construction_set_source|
          building_source = construction_set_source.to_Building
          # if statement for each type of object than can use a DefaultConstructionSet
          if !building_source.empty?
            building_source = building_source.get
            building_source.setDefaultConstructionSet(new_default_construction_set)
          end
          building_story_source = construction_set_source.to_BuildingStory
          if !building_story_source.empty?
            building_story_source = building_story_source.get
            building_story_source.setDefaultConstructionSet(new_default_construction_set)
          end
          space_type_source = construction_set_source.to_SpaceType
          if !space_type_source.empty?
            space_type_source = space_type_source.get
            space_type_source.setDefaultConstructionSet(new_default_construction_set)
          end
          space_source = construction_set_source.to_Space
          if !space_source.empty?
            space_source = space_source.get
            space_source.setDefaultConstructionSet(new_default_construction_set)
          end
        end
      end
    end
  end

  # link cloned and edited constructions for surfaces with hard assigned constructions
  windows.each do |window|
    if !window.isConstructionDefaulted && !window.construction.empty?

      # use the hash to find the proper construction and link to surface
      target_const = window.construction
      if !target_const.empty?
        target_const = target_const.get.name.to_s
        constructions_hash_old_new.each do |orig, new|
          if target_const == orig
            final_construction = new
            window.setConstruction(final_construction)
          end
        end
      end
    end
  end

  # ! -1 rutina para cambiar los frameanddivider de todas las ventas

  window_frameanddividers = []
  window_frameanddivider_names = []

  windows.each do |window|
    begin
      frame = window.windowPropertyFrameAndDivider.get
      frame_name = frame.name
      # puts("__frame_name__ #{frame_name}")
      if !window_frameanddivider_names.include?(frame.name.to_s)
        window_frameanddividers << frame
        window_frameanddivider_names << frame.name.to_s
      end
      tiene_marco = true
    rescue
      tiene_marco = false
    end
  end

  window_frameanddividers.each do |frame|
    # transmitancia = frame.frameConductance()
    # puts("transmitancia #{transmitancia}")
    frame.setFrameConductance(u_huecos)
    name = frame.name.to_s
    frame.setName("Frame forzado a #{u_huecos}")
  end

  # if tiene_marco
  #   window_frameanddivider = subsur.windowPropertyFrameAndDivider.get
  #   if !window_frameanddivider_names.include?(window_frameanddivider.name.to_s)
  #     window_frameanddividers << window_frameanddivider.to_WindowPropertyFrameAndDivider.get
  #     window_frameanddivider_names << window_frameanddivider.name.to_s
  #   end
  # end

  spaces.each do |space|
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.windExposure == "WindExposed"
        surface.subSurfaces.each do |subsur|
          puts("__subsurface Type #{subsur.subSurfaceType()} -> #{subsur.construction.get.name}")
          begin
            puts("   #{subsur.windowPropertyFrameAndDivider.get.name}")
          rescue
            puts("   no tiene marco ")
          end
        end
      end
    end
  end

  runner.registerFinalCondition("Modificadas las transmitancias de los huecos.")
  return true
end #end the measure
