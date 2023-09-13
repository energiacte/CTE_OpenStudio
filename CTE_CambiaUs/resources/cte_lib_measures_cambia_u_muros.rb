def cte_cambia_u_muros(model, runner, user_arguments)
  # tenemos que testear:
  # 1.- que la medida se aplica pero no queremos cambiar la U
  # 2.- cómo añade una capa aislante o cámara de aire si ya existe una
  # 3.- cómo aborta si no hay capa aislante o cámara de aire
  # 4.- cómo reacciona a que los elementos esté definidos en distintos niveles y de distintas maneras
  runner.registerInfo("CTE: Cambiando la U de muros")

  # toma el valor de la medida
  u_muros = runner.getDoubleArgumentValue("CTE_U_muros", user_arguments)

  if u_muros.to_f < 0.001
    puts('  No se cambia el valor de muros (U = 0)')
    runner.registerFinalCondition("No se desea cambiar la transmitancia de los muros.")
    return true
  end

  u_opacos = u_muros
  # puts("__ Se ha seleccionado un valor de U_muros de #{u_muros} -> R=#{1 / u_muros}.")

  # !  __02__ crea un array de muros exteriores y busca un rango de construcciones en el rango de transmitancias.
  # create an array of exterior walls and find range of starting construction R-value (not just insulation layer)
  # el objeto OS:Surface tiene: handle, name, type, construction name(vacio), space name, condiciones exteriores, vertices
  #                           si la construcción está toma la establecida por defecto

  exterior_surfaces = []
  exterior_surface_constructions = []
  exterior_surface_construction_names = []
  # ext_wall_resistance = []
  # ext_wall_transsmitance = []
  surfaces = model.getSurfaces
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
      # puts("--- transmitancia muro: #{ext_wall_const.thermalConductance.to_f}")
      # ext_wall_resistance << 1 / ext_wall_const.thermalConductance.to_f esto no sé para que vale
      # ext_wall_transsmitance << ext_wall_const.thermalConductance.to_f
    end
  end

  if exterior_surfaces.empty?
    runner.registerAsNotApplicable("El modelo no tiene superficies exteriores.")
    return true
  end

  # !  __03__ recorre todas las construcciones y materiales usados en los muros exterios, los edita y los clona

  # construye los hashes para hacer un seguimiento y evitar duplicados
  constructions_hash_old_new = {}
  constructions_hash_new_old = {} # used to get netArea of new construction and then cost objects of construction it replaced
  materials_hash = {}
  # array and counter for new constructions that are made, used for reporting final condition
  final_constructions_array = []

  # loop through all constructions and materials used on exterior walls, edit and clone
  # puts("__Itera por ")
  # exterior_surface_constructions.each { |elemento| puts(elemento.name) }
  # puts("___")

  "" "
  La casuística para decidir como se procede a cambiar la transmitancia del muro es:
  1.- si hay una capa de material sin masa (aislamiento o cámara de aire) se modifica su r lo necesario
  2.- si NO hay una capa de material sin masa se lanza un error y se interrumpe la ejecución.
  " ""

  #! 04_ recorre las construcciones para editar su contenido
  exterior_surface_constructions.each do |exterior_surface_construction|
    # puts("___(Construccion, U) ->  (#{exterior_surface_construction.name},#{exterior_surface_construction.thermalConductance.to_f})___")
    # runner.registerInfo("nombre de la construcción #{exterior_surface_construction.name}")
    construction_layers = exterior_surface_construction.layers
    max_thermal_resistance_material = ""
    max_thermal_resistance_material_index = ""
    # crea un array con los datos de las capas y su orden en la construcción
    materials_in_construction = construction_layers.map.with_index do |layer, i|
      { "name" => layer.name.to_s,
        "index" => i,
        "nomass" => !layer.to_MasslessOpaqueMaterial.empty?,
        "r_value" => layer.to_OpaqueMaterial.get.thermalResistance,
        "mat" => layer }
    end

    no_mass_materials = materials_in_construction.select { |mat| mat["nomass"] == true }
    mass_materials = materials_in_construction.select { |mat| mat["nomass"] == false }

    if !no_mass_materials.empty? #Entra si hay algún material en no_mass_material -> hay una cámara de aire o capa aislante
      # puts("hay materias aislantes o cámara de aire: sin masa")
      thermal_resistance_values = no_mass_materials.map { |mat| mat["r_value"] } # crea un nuevo array con los valores R mapeando el de materiales
      max_mat_hash = no_mass_materials.select { |mat| mat["r_value"] >= thermal_resistance_values.max }[0] # se queda con el que tiene más resistencia
    else
      puts("La composición del cerramiento no tiene una capa susceptible de modificar su resistencia -> #{exterior_surface_construction.name}")
      runner.registerError("La composición del cerramiento no tiene una capa susceptible de modificar su resistencia (#{exterior_surface_construction.name}")
      return false

      # puts("no hay materias aislantes: sin masa")
      # thermal_conductivity_values = mass_materials.map { |material| material["mat"].to_OpaqueMaterial.get.thermalConductivity.to_f }
      # max_mat_hash = mass_materials.select { |material| material["mat"].to_OpaqueMaterial.get.thermalConductivity.to_f <= thermal_conductivity_values.min }[0]
    end
    # puts("__ se ha tomado como material aislante -->  #{max_mat_hash["name"]}__")

    # ! 04 calcula la resistencia del muro sin la capa aislante
    materiales = exterior_surface_construction.layers
    resistencia_termica_sin_aislante = 0.0
    resistencia_termica_total = 0.0

    materiales.each_with_index do |material, indice|
      resistencia_termica_material = material.to_OpaqueMaterial.get.thermalResistance.to_f
      resistencia_termica_total += resistencia_termica_material
      if indice == max_mat_hash["index"]
        # evita sumar la resistencia de la capa aislante
      else
        resistencia_termica_sin_aislante += resistencia_termica_material
      end
    end

    resistencia_capa = 1 / u_muros - resistencia_termica_sin_aislante # siempre que sea positiva, claro
    # puts("__la resistencia del aislante es #{max_mat_hash["mat"].to_OpaqueMaterial.get.thermalResistance.to_f}")
    # puts("__la resistencia sin aislante es #{resistencia_termica_sin_aislante}")
    # puts("__la resistencia de la capa aislante debe ser #{resistencia_capa}")

    max_thermal_resistance_material = max_mat_hash["mat"] # objeto OS
    max_thermal_resistance_material_index = max_mat_hash["index"] # indice de la capa
    max_thermal_resistance = max_thermal_resistance_material.to_OpaqueMaterial.get.thermalResistance
    # puts("max_thermal_resistance -> #{max_thermal_resistance}__")

    if resistencia_capa <= 0
      puts("#{exterior_surface_construction.name} sin aislante tiene una resistencia superior a la que se pide")
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

  # # activa este comentario para verficar que se produce el cambio
  # exterior_surfaces.each do |exterior_surface_construction|
  #   puts("___(Construccion, U) ->  (#{exterior_surface_construction.name},#{exterior_surface_construction.thermalConductance.to_f})___")
  # end

  runner.registerFinalCondition("The existing insulation for exterior walls was set.")
  return true
end #end the measure
