# Localiza construcciones distintas en superficies y devuelve mapping entre nombre antiguo de construcción y construcción nueva con u deseada
def construye_hashes(model, runner, target_surfaces, u_deseada, resistencia_tierra)
  # Recorre construcciones, clona y cambia por otro con la u_deseada
  # La casuística para decidir como se procede a cambiar la transmitancia del muro es:
  # 1.- si hay una capa de material sin masa (aislamiento o cámara de aire) se modifica su R lo necesario
  # 2.- si NO hay una capa de material sin masa se lanza un error y se interrumpe la ejecución.

  # Construcciones diferentes

  constructions_hash_old_new = {}
  materials_hash = {}

  # Recorre las construcciones para editar su contenido
  target_surfaces
    .uniq { |s| s.construction.get.name }
    .map { |s| s.construction.get.to_Construction.get }
    .each do |target_cons|
    construction_layers = target_cons.layers

    materials_in_construction = construction_layers.map.with_index do |layer, i|
      {
        'name' => layer.name.to_s,
        'index' => i,
        'nomass' => !layer.to_MasslessOpaqueMaterial.empty?,
        'r_value' => layer.to_OpaqueMaterial.get.thermalResistance,
        'mat' => layer
      }
    end

    # Localizamos capa aislante. Deber ser cámara de aire o aislante (no mass material)
    no_mass_materials = materials_in_construction.select { |mat| mat['nomass'] == true }
    if !no_mass_materials.empty?
      # crea un nuevo array con los valores R mapeando el de materiales
      thermal_resistance_values =
        no_mass_materials.map do |mat|
          mat['r_value']
        end
      # se queda con el que tiene más resistencia
      max_mat_hash =
        no_mass_materials.select do |mat|
          mat['r_value'] >= thermal_resistance_values.max
        end[0]
    else
      runner.registerError("La composición del cerramiento no tiene una capa susceptible de modificar su resistencia (#{target_cons.name}")
      return false
    end

    # ! Calcula la resistencia del muro sin la capa aislante
    resistencia_termica_sin_aislante = 0.0
    resistencia_termica_total = 0.0
    target_cons.layers.each_with_index do |material, indice|
      resistencia_termica_material = material.to_OpaqueMaterial.get.thermalResistance.to_f
      resistencia_termica_total += resistencia_termica_material
      # evita sumar la resistencia de la capa aislante
      resistencia_termica_sin_aislante += resistencia_termica_material unless indice == max_mat_hash['index']
    end

    # Siempre que sea positiva, claro, resistencia_tierra = 0.5 para muro terremo
    # La resistencia de 0.5 corresponde a una capa de material "terreno" de conductividad (lambda) 2 W/mk de 1 m de profundidad
    resistencia_capa = 1 / u_deseada - resistencia_termica_sin_aislante - resistencia_tierra

    if resistencia_capa <= 0
      runner.registerInfo("La U requerida a '#{target_cons.name}' es mayor que la construcción sin aislamiento. No se modifica")
    else
      # Material aislante e índice
      target_material = max_mat_hash['mat']
      target_material_idx = max_mat_hash['index']

      new_material = materials_hash[target_material.name.to_s]
      unless new_material
        # Material no modificado con anterioridad. Creamos material y sustituimos
        new_material = target_material.clone(model).to_OpaqueMaterial.get
        new_material.setName("#{target_material.name}_R-value #{resistencia_capa}")
        # Cambiamos el material según su tipo
        # Material
        new_material_matt = new_material.to_Material
        unless new_material_matt.empty?
          starting_thickness = new_material_matt.get.thickness
          target_thickness = starting_thickness / u_deseada / thermal_resistance_values.max
          new_material_matt.get.setThickness(target_thickness)
        end
        # MasslessOpaqueMaterial
        new_material_massless = new_material.to_MasslessOpaqueMaterial
        new_material_massless.get.setThermalResistance(resistencia_capa) unless new_material_massless.empty?
        # AirGap
        new_material_airgap = new_material.to_AirGap
        new_material_airgap.get.setThermalResistance(resistencia_capa) unless new_material_airgap.empty?

        # Añadimos a materiales ya modificados
        materials_hash[target_material.name.to_s] = new_material
      end

      # Clonamos la construcción existente y sustituimos el material aislante
      final_construction = target_cons.clone(model).to_Construction.get
      final_construction.setName("#{target_cons.name} con aislamiento corregido")
      final_construction.eraseLayer(target_material_idx)
      final_construction.insertLayer(target_material_idx, new_material)
      # Mapea construcción nueva desde nombre existente
      constructions_hash_old_new[target_cons.name.to_s] = final_construction
      runner.registerInfo("For construction'#{final_construction.name}', material'#{new_material.name}' was altered.")
    end
  end

  constructions_hash_old_new
end

# Cambia construcciones modificadas en default construction sets
def modify_construction_sets(model, _runner, constructions_hash_old_new, condicion:, tipo:)
  model.getDefaultConstructionSets.each do |default_construction_set|
    next if default_construction_set.directUseCount.zero?

    if condicion == 'Ground'
      default_surface_const_set = default_construction_set.defaultGroundContactSurfaceConstructions
    elsif condicion == 'Outdoors'
      default_surface_const_set = default_construction_set.defaultExteriorSurfaceConstructions
    else
      # "Adiabatic", "Surface", "GroundSlab...", "GroundBasement..."
      puts("XX--->>> error, condicion no reconocida #{condicion}")
    end

    # Construcciones por defecto
    next if default_surface_const_set.empty?

    # creating new default construction set
    new_default_construction_set = default_construction_set.clone(model).to_DefaultConstructionSet.get
    new_default_construction_set.setName("#{default_construction_set.name} adj #{condicion} #{tipo} insulation")

    # create new surface set and link to construction set
    new_default_surface_const_set = default_surface_const_set.get.clone(model).to_DefaultSurfaceConstructions.get
    new_default_surface_const_set.setName("#{default_surface_const_set.get.name} adj #{condicion} #{tipo} insulation")

    if condicion == 'Ground'
      new_default_construction_set.setDefaultGroundContactSurfaceConstructions(new_default_surface_const_set)
    elsif condicion == 'Outdoors'
      new_default_construction_set.setDefaultExteriorSurfaceConstructions(new_default_surface_const_set)
    else
      puts("XX--->>> condicion no reconocida #{condicion}")
    end

    # use the hash to find the proper construction and link to new_default_surface_const_set
    case tipo
    when 'Wall'
      target_const = new_default_surface_const_set.wallConstruction
    when 'Floor'
      target_const = new_default_surface_const_set.floorConstruction
    when 'RoofCeiling'
      target_const = new_default_surface_const_set.roofCeilingConstruction
    end

    # ¿Esto no debería ser imposible ya que todos los elementos posibles tienen valor asignado?
    next if target_const.empty?

    target_const_name = target_const.get.name.to_s
    # Cambiamos la construcción antigua por la nueva

    new_construction = constructions_hash_old_new[target_const_name]
    if new_construction
      case tipo
      when 'Wall'
        new_default_surface_const_set.setWallConstruction(new_construction)
      when 'Floor'
        new_default_surface_const_set.setFloorConstruction(new_construction)
      when 'RoofCeiling'
        new_default_surface_const_set.setRoofCeilingConstruction(new_construction)
      end
    end

    # swap all uses of the old construction set for the new
    default_construction_set.sources.each do |construction_set_source|
      # if statement for each type of object than can use a DefaultConstructionSet
      building_source = construction_set_source.to_Building
      unless building_source.empty?
        building_source = building_source.get
        building_source.setDefaultConstructionSet(new_default_construction_set)
      end

      building_story_source = construction_set_source.to_BuildingStory
      unless building_story_source.empty?
        building_story_source = building_story_source.get
        building_story_source.setDefaultConstructionSet(new_default_construction_set)
      end

      space_type_source = construction_set_source.to_SpaceType
      unless space_type_source.empty?
        space_type_source = space_type_source.get
        space_type_source.setDefaultConstructionSet(new_default_construction_set)
      end

      space_source = construction_set_source.to_Space
      unless space_source.empty?
        space_source = space_source.get
        space_source.setDefaultConstructionSet(new_default_construction_set)
      end
    end
  end
end

# Cambia construcciones modificadas
def replace_edited_constructions(surfaces, constructions_hash_old_new)
  surfaces = surfaces.select { |surf| !surf.isConstructionDefaulted && !surf.construction.empty? }
  surfaces.each do |surf|
    target_const = surf.construction.get.name.to_s
    new_construction = constructions_hash_old_new[target_const]
    surf.setConstruction(new_construction) if new_construction
  end
end

def cambia_transmitancia(model, runner, u_deseada, resistencia_terreno, condicion:, tipo:)
  # Superficies del tipo y condición de contorno deseadas y que no son puentes térmicos
  surfaces = model.getSurfaces.filter do |s|
    !s.name.to_s.upcase.include?('PT_') &&
      !s.name.to_s.upcase.include?('_PT') &&
      (s.outsideBoundaryCondition == condicion) &&
      (s.surfaceType == tipo)
  end
  constructions_hash_old_new = construye_hashes(model, runner, surfaces, u_deseada, resistencia_terreno)
  modify_construction_sets(model, runner, constructions_hash_old_new, condicion: condicion, tipo: tipo)
  replace_edited_constructions(surfaces, constructions_hash_old_new)
  runner.registerFinalCondition('The existing insulation for exterior walls was set.')
end

def cte_cambia_u_opacos(model, runner, user_arguments)
  # tenemos que testear:
  # 1.- que la medida se aplica pero no queremos cambiar la U
  # 2.- cómo añade una capa aislante o cámara de aire si ya existe una
  # 3.- cómo aborta si no hay capa aislante o cámara de aire
  # 4.- cómo reacciona a que los elementos esté definidos en distintos niveles y de distintas maneras

  runner.registerInfo('CTE: Cambiando la U de muros')
  u_muros = runner.getDoubleArgumentValue('CTE_U_muros', user_arguments)
  if u_muros.to_f > 0.001
    # Muros exteriores:
    cambia_transmitancia(model, runner, u_muros, 0, condicion: 'Outdoors', tipo: 'Wall')
    runner.registerFinalCondition('The existing insulation for exterior walls was set.')
    # Muros enterrados
    cambia_transmitancia(model, runner, u_muros, 0.5, condicion: 'Ground', tipo: 'Wall')
    runner.registerFinalCondition('The existing insulation for ground walls was set.')
  else
    runner.registerFinalCondition('No se cambia la transmitancia de los muros (U=0)')
  end

  runner.registerInfo('CTE: Cambiando la U los suelos exteriores')
  u_suelos = runner.getDoubleArgumentValue('CTE_U_suelos', user_arguments)
  if u_suelos.to_f > 0.001
    # Suelos exteriores:
    cambia_transmitancia(model, runner, u_suelos, 0, condicion: 'Outdoors', tipo: 'Floor')
    runner.registerFinalCondition('The existing insulation for exterior floors was set.')
    # Suelos enterrados:
    cambia_transmitancia(model, runner, u_suelos, 0.5, condicion: 'Ground', tipo: 'Floor')
    runner.registerFinalCondition('The existing insulation for ground floors was set.')
  else
    runner.registerFinalCondition('No se cambia la transmitancia de los suelos (U=0)')
  end

  runner.registerInfo('CTE: Cambiando la U de cubiertas')
  u_cubiertas = runner.getDoubleArgumentValue('CTE_U_cubiertas', user_arguments)
  if u_cubiertas.to_f > 0.001
    cambia_transmitancia(model, runner, u_cubiertas, 0, condicion: 'Outdoors', tipo: 'RoofCeiling')
    runner.registerFinalCondition('The existing insulation for exterior roof ceiling was set.')
  else
    runner.registerFinalCondition('No se cambia la transmitancia de las cubiertas (U=0)')
  end

  true
end
