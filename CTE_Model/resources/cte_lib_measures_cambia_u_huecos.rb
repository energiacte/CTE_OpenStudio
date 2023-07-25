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
  window_frameanddividers = []
  window_frameanddivider_names = []
  puts(" __huecos__ recorriendo las ventanas")
  spaces = model.getSpaces
  spaces.each do |space|
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.windExposure == "WindExposed"
        surface.subSurfaces.each do |subsur|
          # puts("__ ventana ___", subsur.name)

          windows << subsur

          begin
            frame = subsur.windowPropertyFrameAndDivider.get
            tiene_marco = true
          rescue
            tiene_marco = false
          end

          window_construccion = subsur.construction.get
          if !window_construction_names.include?(window_construccion.name.to_s)
            window_constructions << window_construccion.to_Construction.get
            window_construction_names << window_construccion.name.to_s
          end

          if tiene_marco
            window_frameanddivider = subsur.windowPropertyFrameAndDivider.get
            if !window_frameanddivider_names.include?(window_frameanddivider.name.to_s)
              window_frameanddividers << window_frameanddivider.to_WindowPropertyFrameAndDivider.get
              window_frameanddivider_names << window_frameanddivider.name.to_s
            end
          end

          # window_construction_names << window_construccion.name.to_s
          # ext_wall_resistance << 1 / ext_wall_const.thermalConductance.to_f
          # ext_wall_transsmitance << ext_wall_const.thermalConductance.to_f

          # puts(subsur.construction.get.name)
          # puts(subsur.subSurfaceType())
          # puts(subsur.windowPropertyFrameAndDivider())

          # puts('__ frame__ ', frame)
          # puts('__ frame conductance__ ', frame.frameConductance())
          # frame.setFrameConductance(2.25)
          # puts('__ frame conductance__ ', frame.frameConductance())

        end
      end
    end
  end
  puts("__ cosas__", window_construction_names, window_frameanddivider_names)
  puts("... ya ...")

  if windows.empty?
    runner.registerAsNotApplicable("El modelo no tiene ventanas.")
    return true
  end

  # ! __03__recorre las cosntrucciones y materiales, los clona y los modifica

  # construye los hashes para hacer un seguimiento y evitar duplicados
  constructions_hash_old_new = {}
  constructions_hash_new_old = {} # used to get netArea of new construction and then cost objects of construction it replaced
  frame_hash_old_new = {}
  frame_hash_new_old = {}
  materials_hash = {}
  # array and counter for new constructions that are made, used for reporting final condition
  final_constructions_array = []
  final_frame_array= []


  # loop through all constructions and materials used on exterior walls, edit and clone
  window_constructions.each { |construccion| puts(construccion.name) } #construccion =elemento
  # puts("___")
  window_constructions.each do |window_construction|
    puts("___Nombre de la construcción #{window_construction.name}___")
    # puts(exterior_surface_construction.name)
    runner.registerInfo("nombre de la construcción #{window_construction.name}")
    # construction_layers = window_construction.layers
    # siempre tiene una única capa

    # puts(construction_layers)
    # puts(construction_layers.length)
    # puts(construction_layers.length == 1)
    
    default_construction_sets = model.getDefaultConstructionSets
    puts('__ default contructions sets__', default_construction_sets.length)
    # * ¿cual es el default construction set que está activo?
    default_construction_sets.each do |default_construction_set|
      puts("nombre #{default_construction_set.name}")
      puts("usos -> #{default_construction_set.directUseCount}")
    end

    target_material = max_thermal_resistance_material

    # ! 04 calcula la transmitancia de la capa de muro.
    final_construction = window_construction.clone(model)
    final_construction = final_construction.to_Construction.get
    final_construction.setName("#{window_construction.name} con transmitanca corregida")
    final_constructions_array << final_construction
    constructions_hash_old_new[window_construction.name.to_s] = final_construction
    constructions_hash_new_old[final_construction] = window_construction # push the object to hash key vs. name

    puts("__final construction", final_construction)
    puts("__layer__", final_construction.layers[0])
    # buscar aquí como son los wrappers de OS a objeto Ruby:
    # https://openstudio-sdk-documentation.s3.amazonaws.com/cpp/OpenStudio-3.5.1-doc/model/html/annotated.html
    simpleGlazing = final_construction.layers[0].to_SimpleGlazing.get
    puts("__layer__", simpleGlazing.uFactor())
    simpleGlazing.setUFactor(u_huecos)
    puts("__final construction", final_construction.layers[0])

    max_thermal_resistance_material_index = 0

    # find already cloned insulation material and link to construction
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
      new_material = new_material.to_OpaqueMaterial.get
      new_material.setName("#{max_thermal_resistance_material.name}_R-value #{resistencia_capa}")
      materials_hash[max_thermal_resistance_material.name.to_s] = new_material
      final_construction.eraseLayer(max_thermal_resistance_material_index)
      final_construction.insertLayer(max_thermal_resistance_material_index, new_material)
      runner.registerInfo("For construction'#{final_construction.name}', material'#{new_material.name}' was altered.")

      # edit insulation material
      new_material_matt = new_material.to_Material
      if !new_material_matt.empty?
        starting_thickness = new_material_matt.get.thickness
        target_thickness = starting_thickness / u_opacos / thermal_resistance_values.max
        final_thickness = new_material_matt.get.setThickness(target_thickness)
      end
      new_material_massless = new_material.to_MasslessOpaqueMaterial
      if !new_material_massless.empty?
        puts("__!new_material_massless.empty?__")
        final_thermal_resistance = new_material_massless.get.setThermalResistance(resistencia_capa)
      end
      new_material_airgap = new_material.to_AirGap
      if !new_material_airgap.empty?
        final_thermal_resistance = new_material_airgap.get.setThermalResistance(resistencia_capa)
      end
    end
  end

  runner.registerFinalCondition("Modificadas las transmitancias de los huecos.")
  return true
end #end the measure
