
def loop_through_construction_sets_suelos(model, runner, constructions_hash_old_new, condicion:, tipo:)
  # loop through construction sets used in the model
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
        starting_construction = default_surface_const_set.get.floorConstruction

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
        target_const = new_default_surface_const_set.floorConstruction
        if !target_const.empty?
          target_const = target_const.get.name.to_s
          found_const_flag = false
          constructions_hash_old_new.each do |orig, new|
            if target_const == orig
              final_construction = new
              new_default_surface_const_set.setFloorConstruction(final_construction)
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

# def link_cloned_edited_constructions(exterior_surfaces, constructions_hash_old_new)
#   # link cloned and edited constructions for surfaces with hard assigned constructions
#   exterior_surfaces.each do |exterior_surface|
#     if !exterior_surface.isConstructionDefaulted && !exterior_surface.construction.empty?

#       # use the hash to find the proper construction and link to surface
#       target_const = exterior_surface.construction
#       if !target_const.empty?
#         target_const = target_const.get.name.to_s
#         constructions_hash_old_new.each do |orig, new|
#           if target_const == orig
#             final_construction = new
#             exterior_surface.setConstruction(final_construction)
#           end
#         end
#       end
#     end
#   end
# end

def cte_cambia_u_suelos_exteriores(model, runner, user_arguments)
  # tenemos que testear:
  # 1.- que la medida se aplica pero no queremos cambiar la U
  # 2.- cómo añade una capa aislante o cámara de aire si ya existe una
  # 3.- cómo aborta si no hay capa aislante o cámara de aire
  # 4.- cómo reacciona a que los elementos esté definidos en distintos niveles y de distintas maneras

  runner.registerInfo("CTE: Cambiando la U los suelos exteriores")

  u_suelos = runner.getDoubleArgumentValue("CTE_U_suelos", user_arguments)

  if u_suelos.to_f < 0.001
    runner.registerFinalCondition("No se cambia la transmitancia de los suelos (U=0)")
    return true
  end

  # Suelos exteriores:
  exterior_surfaces, exterior_surface_constructions, _exterior_surface_construction_names = filtra_superficies(model, condicion: "Outdoors", tipo: "Floor")
  constructions_hash_old_new, _constructions_hash_new_old, _materials_hash, _final_constructions_array = construye_hashes(model, runner, exterior_surface_constructions, u_suelos, 0)
  # loop through construction sets used in the model
  loop_through_construction_sets_suelos(model, runner, constructions_hash_old_new, condicion: "Outdoors", tipo: "Floor")
  # link cloned and edited constructions for surfaces with hard assigned constructions
  link_cloned_edited_constructions(exterior_surfaces, constructions_hash_old_new)

  # activa este comentario para verficar que se produce el cambio
  # exterior_surfaces.each do |exterior_surface_construction|
  #   puts("___  #{exterior_surface_construction.name} U=#{exterior_surface_construction.thermalConductance.to_f} ___")
  # end

  # Suelos enterrados:
  exterior_surfaces, exterior_surface_constructions, _exterior_surface_construction_names = filtra_superficies(model, condicion: "Ground", tipo: "Floor")
  constructions_hash_old_new, _constructions_hash_new_old, _materials_hash, _final_constructions_array = construye_hashes(model, runner, exterior_surface_constructions, u_suelos, 0.5)
  # loop through construction sets used in the model
  loop_through_construction_sets_suelos(model, runner, constructions_hash_old_new, condicion: "Ground", tipo: "Floor")
  # link cloned and edited constructions for surfaces with hard assigned constructions
  link_cloned_edited_constructions(exterior_surfaces, constructions_hash_old_new)

  # activa este comentario para verficar que se produce el cambio
  # exterior_surfaces.each do |exterior_surface_construction|
  #   puts("___  #{exterior_surface_construction.name} U=#{exterior_surface_construction.thermalConductance.to_f} ___")
  # end

  runner.registerFinalCondition("The existing insulation for exterior ground floor was set.")
  return true
end #end the measure
