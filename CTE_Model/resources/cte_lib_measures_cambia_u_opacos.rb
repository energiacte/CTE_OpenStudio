def filtra_superficies(model, condicion:, tipo:)
  # !  __02__ crea un array de elementos segun la condicion y busca un rango de construcciones en el rango de transmitancias.
  # create an array of  objects and find range of starting construction R-value (not just insulation layer)
  # el objeto OS:Surface tiene: handle, name, type, construction name(vacio), space name, condiciones exteriores, vertices
  #                           si la construcción está toma la establecida por defecto
  exterior_surfaces = []
  exterior_surface_constructions = []
  exterior_surface_construction_names = []
  model.getSurfaces.each do |surface|
    # Excluimos las superficies de PTs
    if surface.name.to_s.upcase.include?("PT_") || surface.name.to_s.upcase.include?("_PT")
      next
    end
    if (surface.outsideBoundaryCondition == condicion) && (surface.surfaceType == tipo)
      # el objeto OS:Construction tiene: Handle, name, surface rendering name y varias layers
      exterior_surfaces << surface
      construccion = surface.construction.get # algunas surfaces no tienen construcción.

      # añade la construcción únicamente si no lo ha hecho antes
      if !exterior_surface_construction_names.include?(construccion.name.to_s)
        exterior_surface_constructions << construccion.to_Construction.get
      end
      exterior_surface_construction_names << construccion.name.to_s
      # puts("  __nombre #{surface.name.to_s}, construccion#{construccion.name.to_s}, U= #{construccion.thermalConductance.to_f}")
    end
  end

  if exterior_surfaces.empty?
    runner.registerAsNotApplicable("El modelo no tiene superficies #{tipo} #{condicion}")
    return true
  end

  [exterior_surfaces, exterior_surface_constructions, exterior_surface_construction_names]
end

def construye_hashes(model, runner, exterior_surface_constructions, u_deseada, resistencia_tierra) # condicion y tipo para  lanzar el error
  # !  __03__ recorre todas las construcciones y materiales usados en los muros exterios, los edita y los clona
  # La casuística para decidir como se procede a cambiar la transmitancia del muro es:
  # 1.- si hay una capa de material sin masa (aislamiento o cámara de aire) se modifica su r lo necesario
  # 2.- si NO hay una capa de material sin masa se lanza un error y se interrumpe la ejecución.
  # construye los hashes para hacer un seguimiento y evitar duplicados
  # used to get netArea of new construction and then cost objects of construction it replaced

  constructions_hash_old_new = {}
  constructions_hash_new_old = {} # used to get netArea of new construction and then cost objects of construction it replaced
  materials_hash = {}
  # array and counter for new constructions that are made, used for reporting final condition
  final_constructions_array = []

  # loop through all constructions and materials used on ground floors, edit and clone

  # ! 03_ recorre las construcciones para editar su contenido
  exterior_surface_constructions.each do |exterior_surface_construction|
    construction_layers = exterior_surface_construction.layers
    max_thermal_resistance_material = ""
    max_thermal_resistance_material_index = ""
    # crea un array con los datos de las capas y su orden en la construcción
    materials_in_construction = construction_layers.map.with_index do |layer, i|
      {"name" => layer.name.to_s,
       "index" => i,
       "nomass" => !layer.to_MasslessOpaqueMaterial.empty?,
       "r_value" => layer.to_OpaqueMaterial.get.thermalResistance,
       "mat" => layer}
    end

    no_mass_materials = materials_in_construction.select { |mat| mat["nomass"] == true }
    _mass_materials = materials_in_construction.select { |mat| mat["nomass"] == false }

    # Si hay algún material en no_mass_material -> hay una cámara de aire o capa aislante
    if !no_mass_materials.empty?
      # puts("hay materias aislantes o cámara de aire: sin masa")
      thermal_resistance_values = no_mass_materials.map { |mat| mat["r_value"] } # crea un nuevo array con los valores R mapeando el de materiales
      max_mat_hash = no_mass_materials.select { |mat| mat["r_value"] >= thermal_resistance_values.max }[0] # se queda con el que tiene más resistencia
    else
      # puts("La composición del cerramiento no tiene una capa susceptible de modificar su resistencia -> #{exterior_surface_construction.name}")
      runner.registerError("La composición del cerramiento no tiene una capa susceptible de modificar su resistencia (#{exterior_surface_construction.name}")
      return false
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

    # La resistencia de 0.5 corresponde a una capa de material "terreno" de conductividad (lambda) 2 W/mk de 1 m de profundidad
    resistencia_capa = 1 / u_deseada - resistencia_termica_sin_aislante - resistencia_tierra # siempre que sea positiva, claro, resistencia_tierra = 0.5 para muro terremo

    max_thermal_resistance_material = max_mat_hash["mat"] # objeto OS
    max_thermal_resistance_material_index = max_mat_hash["index"] # indice de la capa
    _max_thermal_resistance = max_thermal_resistance_material.to_OpaqueMaterial.get.thermalResistance
    # puts("max_thermal_resistance -> #{max_thermal_resistance}__")

    if resistencia_capa <= 0
      # puts("#{exterior_surface_construction.name} sin aislante tiene una resistencia superior a la que se pide")
      runner.registerInfo("La U que se pide para los #{exterior_surface_construction.name} (especificar tipo) es mayor que la que tienen las capas sin contar el aislamiento. No se modifica")
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
          target_thickness = starting_thickness / u_deseada / thermal_resistance_values.max
          _final_thickness = new_material_matt.get.setThickness(target_thickness)
        end
        new_material_massless = new_material.to_MasslessOpaqueMaterial
        if !new_material_massless.empty?
          _final_thermal_resistance = new_material_massless.get.setThermalResistance(resistencia_capa)
        end
        new_material_airgap = new_material.to_AirGap
        if !new_material_airgap.empty?
          _final_thermal_resistance = new_material_airgap.get.setThermalResistance(resistencia_capa)
        end
      end
    end
  end
  [constructions_hash_old_new, constructions_hash_new_old, materials_hash, final_constructions_array]
end

def loop_through_construction_sets(model, runner, constructions_hash_old_new, condicion:, tipo:)
  default_construction_sets = model.getDefaultConstructionSets
  default_construction_sets.each do |default_construction_set|
    if default_construction_set.directUseCount > 0
      if condicion == "Ground"
        default_surface_const_set = default_construction_set.defaultGroundContactSurfaceConstructions
      elsif condicion == "Outdoors"
        default_surface_const_set = default_construction_set.defaultExteriorSurfaceConstructions
      else
        puts("XX--->>> error, condicion no reconocida #{condicion}")
      end

      if !default_surface_const_set.empty?
        # _starting_construction = default_surface_const_set.get.wallConstruction

        # creating new default construction set
        new_default_construction_set = default_construction_set.clone(model)
        new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get
        new_default_construction_set.setName("#{default_construction_set.name} adj #{condicion} #{tipo} insulation")

        # create new surface set and link to construction set
        new_default_surface_const_set = default_surface_const_set.get.clone(model)
        new_default_surface_const_set = new_default_surface_const_set.to_DefaultSurfaceConstructions.get
        new_default_surface_const_set.setName("#{default_surface_const_set.get.name} adj #{condicion} #{tipo} insulation")

        if condicion == "Ground"
          new_default_construction_set.setDefaultGroundContactSurfaceConstructions(new_default_surface_const_set)
        elsif condicion == "Outdoors"
          new_default_construction_set.setDefaultExteriorSurfaceConstructions(new_default_surface_const_set)
        else
          puts("XX--->>> error, condicion no reconocida #{condicion}")
        end

        # use the hash to find the proper construction and link to new_default_surface_const_set
        if tipo == "Wall"
          target_const = new_default_surface_const_set.wallConstruction
        elsif tipo == "Floor"
          target_const = new_default_surface_const_set.floorConstruction
        elsif tipo == "RoofCeiling"
          target_const = new_default_surface_const_set.roofCeilingConstruction
        else
          puts("No he reconocido este tipo de cerramiento #{tipo}")
        end
        if !target_const.empty?
          target_const = target_const.get.name.to_s
          found_const_flag = false
          constructions_hash_old_new.each do |orig, new|
            if target_const == orig
              final_construction = new
              if tipo == "Wall"
                new_default_surface_const_set.setWallConstruction(final_construction)
              elsif tipo == "Floor"
                new_default_surface_const_set.setFloorConstruction(final_construction)
              elsif tipo == "RoofCeiling"
                new_default_surface_const_set.setRoofCeilingConstruction(final_construction)
              else
                puts("No he reconocido este tipo de cerramiento #{tipo}")
              end

              found_const_flag = true
            end
          end
          if found_const_flag == false # this should never happen but is just an extra test in case something goes wrong with the measure code
            runner.registerWarning("Measure couldn't find the construction named '#{target_const}' in the #{condicion} surface hash.")
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
end

def link_cloned_edited_constructions(exterior_surfaces, constructions_hash_old_new)
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
end

def cambia_transmitancia(model, runner, u_deseada, resistencia_terreno, condicion:, tipo:)
  exterior_surfaces, exterior_surface_constructions, _exterior_surface_construction_names =
    filtra_superficies(model, condicion: condicion, tipo: tipo)
  constructions_hash_old_new, _constructions_hash_new_old, _materials_hash, _final_constructions_array =
    construye_hashes(model, runner, exterior_surface_constructions, u_deseada, resistencia_terreno)
  loop_through_construction_sets(model, runner, constructions_hash_old_new, condicion: condicion, tipo: tipo)
  link_cloned_edited_constructions(exterior_surfaces, constructions_hash_old_new)
  runner.registerFinalCondition("The existing insulation for exterior walls was set.")
end

def cte_cambia_u_opacos(model, runner, user_arguments)
  # tenemos que testear:
  # 1.- que la medida se aplica pero no queremos cambiar la U
  # 2.- cómo añade una capa aislante o cámara de aire si ya existe una
  # 3.- cómo aborta si no hay capa aislante o cámara de aire
  # 4.- cómo reacciona a que los elementos esté definidos en distintos niveles y de distintas maneras

  runner.registerInfo("CTE: Cambiando la U de muros")
  u_muros = runner.getDoubleArgumentValue("CTE_U_muros", user_arguments)
  if u_muros.to_f > 0.001
    # Muros exteriores:
    cambia_transmitancia(model, runner, u_muros, 0, condicion: "Outdoors", tipo: "Wall")
    runner.registerFinalCondition("The existing insulation for exterior walls was set.")
    # Muros enterrados
    cambia_transmitancia(model, runner, u_muros, 0.5, condicion: "Ground", tipo: "Wall")
    runner.registerFinalCondition("The existing insulation for ground walls was set.")
  else
    runner.registerFinalCondition("No se cambia la transmitancia de los muros (U=0)")
  end

  runner.registerInfo("CTE: Cambiando la U los suelos exteriores")
  u_suelos = runner.getDoubleArgumentValue("CTE_U_suelos", user_arguments)
  if u_suelos.to_f > 0.001
    # Suelos exteriores:
    cambia_transmitancia(model, runner, u_suelos, 0, condicion: "Outdoors", tipo: "Floor")
    runner.registerFinalCondition("The existing insulation for exterior floors was set.")
    # Suelos enterrados:
    cambia_transmitancia(model, runner, u_suelos, 0.5, condicion: "Ground", tipo: "Floor")
    runner.registerFinalCondition("The existing insulation for ground floors was set.")
  else
    runner.registerFinalCondition("No se cambia la transmitancia de los suelos (U=0)")
  end

  runner.registerInfo("CTE: Cambiando la U de cubiertas")
  u_cubiertas = runner.getDoubleArgumentValue("CTE_U_cubiertas", user_arguments)
  if u_cubiertas.to_f > 0.001
    cambia_transmitancia(model, runner, u_cubiertas, 0, condicion: "Outdoors", tipo: "RoofCeiling")
    runner.registerFinalCondition("The existing insulation for exterior roof ceiling was set.")
  else
    runner.registerFinalCondition("No se cambia la transmitancia de las cubiertas (U=0)")
  end

  true
end
