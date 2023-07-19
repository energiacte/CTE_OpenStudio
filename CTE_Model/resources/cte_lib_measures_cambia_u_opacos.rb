def cte_cambia_u_opacos(model, runner, user_arguments)
  runner.registerInfo("CTE: Cambiando la U de opacos")

  # toma el valor de la medida
  u_opacos = runner.getDoubleArgumentValue("CTE_U_opacos", user_arguments)
  puts("Se ha seleccionado un valor de U_opacos de #{u_opacos}")

  # ! __01__ verifica que el valor de entrada está dentro de un rango
  min_expected_u_value = 0.1 # si units
  max_expected_r_value = 1 / min_expected_u_value
  max_expected_u_value = 70 # si units
  min_expected_r_value = 1 / max_expected_u_value

  if (u_opacos < min_expected_u_value) || (u_opacos > max_expected_u_value)
    runner.registerError("El valor de U proporcionado (#{u_opacos} está fuera del rango indicado en cte_lib_measures_cambia_u_opacos")
    return false
  end

  # !  __02__ crea un array de muros exteriores y busca un rango de construcciones en el rango de transmitancias.
  # create an array of exterior walls and find range of starting construction R-value (not just insulation layer)
  # el objeto OS:Surface tiene: handle, name, type, construction name(vacio), space name, condiciones exteriores, vertices
  #                           si la construcción está toma la establecida por defecto
  surfaces = model.getSurfaces
  exterior_surfaces = []
  exterior_surface_constructions = []
  exterior_surface_construction_names = []
  ext_wall_resistance = []
  ext_wall_transsmitance = []
  surfaces.each do |surface|
    if (surface.outsideBoundaryCondition == "Outdoors") && (surface.surfaceType == "Wall")
      # el objeto OS:Construction tiene: Handle, name, surface rendering name y varias layers
      exterior_surfaces << surface
      ext_wall_const = surface.construction.get # algunas surfaces no tienen construcción.

      # añade la construcción únicamente si no lo ha hecho antes
      if !exterior_surface_construction_names.include?(ext_wall_const.name.to_s)
        exterior_surface_constructions << ext_wall_const.to_Construction.get
      end
      exterior_surface_construction_names << ext_wall_const.name.to_s
      ext_wall_resistance << 1 / ext_wall_const.thermalConductance.to_f
      ext_wall_transsmitance << ext_wall_const.thermalConductance.to_f
    end
  end

  if exterior_surfaces.empty?
    runner.registerAsNotApplicable("El modelo no tiene superficies exteriores.")
    return true
  end

  # puts("__construcciones exteriores__ #{exterior_surface_constructions.class}")
  # puts(exterior_surface_constructions)

  # !  __03__ recorre todas las construcciones y materiales usados en los muros exterios, los edita y los clona
  
  # construye los hashes para hacer un seguimiento y evitar duplicados
  constructions_hash_old_new = {}
  constructions_hash_new_old = {} # used to get netArea of new construction and then cost objects of construction it replaced
  materials_hash = {}
  # array and counter for new constructions that are made, used for reporting final condition
  final_constructions_array = []

  # loop through all constructions and materials used on exterior walls, edit and clone
  puts("Itera por #{exterior_surface_constructions}")
  exterior_surface_constructions.each do |exterior_surface_construction|
     puts("___Nombre de la construcción #{exterior_surface_construction.name}___")
    # puts(exterior_surface_construction.name)
    runner.registerInfo("nombre de la construcción #{exterior_surface_construction.name}")
    construction_layers = exterior_surface_construction.layers
    max_thermal_resistance_material = ""
    max_thermal_resistance_material_index = ""
    materials_in_construction = construction_layers.map.with_index do |layer, i|
      { "name" => layer.name.to_s,
        "index" => i,
        "nomass" => !layer.to_MasslessOpaqueMaterial.empty?,
        "r_value" => layer.to_OpaqueMaterial.get.thermalResistance,
        "mat" => layer }
    end
    # puts("_____ #{materials_in_construction.class}")
    #puts(materials_in_construction)
    # materials_in_construction.each { |elemento| puts("#{elemento["name"]} #{elemento["nomass"]}") }
    # puts("_____")    

    puts('__separa mass de nomass__')
    no_mass_materials = materials_in_construction.select { |mat| mat["nomass"] == true }
    mass_materials = materials_in_construction.select { |mat| mat["nomass"] == false }

    if !no_mass_materials.empty? #Entra si hay algún material en no_mass_material. Los aislantes son no_mass
      puts("hay materias aislantes: sin masa")
      thermal_resistance_values = no_mass_materials.map { |mat| mat["r_value"] } # crea un nuevo array con los valores R mapeando el de materiales
      max_mat_hash = no_mass_materials.select { |mat| mat["r_value"] >= thermal_resistance_values.max }[0] # se queda con el que tiene más resistencia
    else
      puts("no hay materias aislantes: sin masa")
      thermal_conductivity_values = mass_materials.map { |material| material["mat"].to_OpaqueMaterial.get.thermalConductivity.to_f }
      max_mat_hash = mass_materials.select { |material| material["mat"].to_OpaqueMaterial.get.thermalConductivity.to_f <= thermal_conductivity_values.min }[0]

      # thermal_resistance_per_thickness_values = materials_in_construction.map { |mat| mat["r_value"] / mat["mat"].thickness }
      # target_index = thermal_resistance_per_thickness_values.index(thermal_resistance_per_thickness_values.max)
      # max_mat_hash = materials_in_construction.select { |mat| mat["index"] == target_index }
      # thermal_resistance_values = materials_in_construction.map { |mat| mat["r_value"] }
    end
    puts("__max_mat_hash__")
    puts(" aislante es el material #{max_mat_hash['name']}")#max_mat_hash.each { |elemento| puts (elemento) }
    puts("______")

    # ! 04 calcula la resistencia del muro sin la capa aislante
    materiales = exterior_surface_construction.layers
    resistencia_termica_total = 0.0
    materiales.each_with_index do |material, indice|
      if indice == max_mat_hash["index"]
        # evita sumar la resistencia de la capa aislante    
      else
        resistencia_termica_material = material.to_OpaqueMaterial.get.thermalResistance.to_f
        resistencia_termica_total += resistencia_termica_material
      end
    end

    resistencia_capa = 1 / u_opacos - resistencia_termica_total # siempre que sea positiva, claro
    puts("__la resistencia de la capa aislante debe ser #{resistencia_capa}")



    max_thermal_resistance_material = max_mat_hash["mat"] # objeto OS
    max_thermal_resistance_material_index = max_mat_hash["index"] # indice de la capa
    max_thermal_resistance = max_thermal_resistance_material.to_OpaqueMaterial.get.thermalResistance
    puts("max_thermal_resistance -> #{max_thermal_resistance}__")

    # la resitencia de la capa encontrada es menor que la mínima esperada entonces no tenemos capa aislante
    # if max_thermal_resistance <= min_expected_r_value #unit_helper(min_expected_r_value_ip, 'ft^2*h*R/Btu', 'm^2*K/W')
    #   runner.registerWarning("Construction '#{exterior_surface_construction.name}' does not appear to have an insulation layer and was not altered.")
    # if (max_thermal_resistance >= 1 / u_opacos)
    #   runner.registerInfo("The insulation layer of construction #{exterior_surface_construction.name} exceeds the requested R-Value. It was not altered.")
    if resistencia_capa <= 0
      runner.registerInfo("La U que se pide para los opacos mayor que la que tienen las capas sin contar el aislamiento. No se modifica")
    else
      # clone the construction
      final_construction = exterior_surface_construction.clone(model)
      final_construction = final_construction.to_Construction.get
      final_construction.setName("#{exterior_surface_construction.name} con aislamiento corregido")
      final_constructions_array << final_construction
      constructions_hash_old_new[exterior_surface_construction.name.to_s] = final_construction
      constructions_hash_new_old[final_construction] = exterior_surface_construction # push the object to hash key vs. name

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
          puts('__!new_material_massless.empty?__')
          final_thermal_resistance = new_material_massless.get.setThermalResistance(resistencia_capa)
        end
        new_material_airgap = new_material.to_AirGap
        if !new_material_airgap.empty?
          final_thermal_resistance = new_material_airgap.get.setThermalResistance(resistencia_capa)
        end
      end
    end
  end

  # loop through construction sets used in the model
  default_construction_sets = model.getDefaultConstructionSets
  default_construction_sets.each do |default_construction_set|
    if default_construction_set.directUseCount > 0
      default_surface_const_set = default_construction_set.defaultExteriorSurfaceConstructions
      if !default_surface_const_set.empty?
        starting_construction = default_surface_const_set.get.wallConstruction

        # creating new default construction set
        new_default_construction_set = default_construction_set.clone(model)
        new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get
        new_default_construction_set.setName("#{default_construction_set.name} adj ext wall insulation")

        # create new surface set and link to construction set
        new_default_surface_const_set = default_surface_const_set.get.clone(model)
        new_default_surface_const_set = new_default_surface_const_set.to_DefaultSurfaceConstructions.get
        new_default_surface_const_set.setName("#{default_surface_const_set.get.name} adj ext wall insulation")
        new_default_construction_set.setDefaultExteriorSurfaceConstructions(new_default_surface_const_set)

        # use the hash to find the proper construction and link to new_default_surface_const_set
        target_const = new_default_surface_const_set.wallConstruction
        if !target_const.empty?
          target_const = target_const.get.name.to_s
          found_const_flag = false
          constructions_hash_old_new.each do |orig, new|
            if target_const == orig
              final_construction = new
              new_default_surface_const_set.setWallConstruction(final_construction)
              found_const_flag = true
            end
          end
          if found_const_flag == false # this should never happen but is just an extra test in case something goes wrong with the measure code
            runner.registerWarning("Measure couldn't find the construction named '#{target_const}' in the exterior surface hash.")
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
  exterior_surfaces.each do |exterior_surface|
    if !exterior_surface.isConstructionDefaulted && !exterior_surface.construction.empty?

      # use the hash to find the proper construction and link to surface
      target_const = exterior_surface.construction
      if !target_const.empty?
        target_const = target_const.get.name.to_s
        constructions_hash_old_new.each do |orig, new|
          if target_const == orig
            final_construction = new
            exterior_surface.setConstruction(final_construction)
          end
        end
      end
    end
  end

  # report strings for final condition
  # final_string = [] # not all exterior wall constructions, but only new ones made. If wall didn't have insulation and was not altered we don't want to show it
  # affected_area_si = 0
  # totalCost_of_affected_area = 0
  # yr0_capital_totalCosts = 0
  # final_constructions_array.each do |final_construction|
  #   # unit conversion of wall insulation from SI units (M^2*K/W) to IP units (ft^2*h*R/Btu)
  #   final_conductance_ip = unit_helper(1 / final_construction.thermalConductance.to_f, "m^2*K/W", "ft^2*h*R/Btu")
  #   final_string << "#{final_construction.name} (R-#{(format "%.1f", final_conductance_ip)})"
  #   affected_area_si += final_construction.getNetArea

  #   # loop through lifecycle costs getting total costs under "Construction" or "Salvage" category and add to counter if occurs during year 0
  #   const_LCCs = final_construction.lifeCycleCosts
  #   const_LCCs.each do |const_LCC|
  #     if (const_LCC.category == "Construction") || (const_LCC.category == "Salvage")
  #       if const_LCC.yearsFromStart == 0
  #         yr0_capital_totalCosts += const_LCC.totalCost
  #       end
  #     end
  #   end
  end

  # add not applicable test if there were exterior roof constructions but non of them were altered (already enough insulation or doesn't look like insulated wall)
  if affected_area_si == 0
    runner.registerAsNotApplicable("No exterior walls were altered.")
    return true
    # affected_area_ip = affected_area_si
  else
    # ip construction area for reporting
    affected_area_ip = unit_helper(affected_area_si, "m^2", "ft^2")
  end

  # report final condition
  runner.registerFinalCondition("The existing insulation for exterior walls was set to R-#{r_value}. This was accomplished for an initial cost of #{one_time_retrofit_cost_ip} ($/sf) and an increase of #{material_cost_increase_ip} ($/sf) for construction. This was applied to #{neat_numbers(affected_area_ip, 0)} (ft^2) across #{final_string.size} exterior wall constructions: #{final_string.sort.join(", ")}.")

  puts("fin del cambio de U")
  return true
end #end the measure
