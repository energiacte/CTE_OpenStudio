def cte_cambia_u_suelos(model, runner, user_arguments)
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
  loop_through_construction_sets(model, runner, constructions_hash_old_new, condicion: "Outdoors", tipo: "Floor")
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
  loop_through_construction_sets(model, runner, constructions_hash_old_new, condicion: "Ground", tipo: "Floor")
  # link cloned and edited constructions for surfaces with hard assigned constructions
  link_cloned_edited_constructions(exterior_surfaces, constructions_hash_old_new)

  # activa este comentario para verficar que se produce el cambio
  # exterior_surfaces.each do |exterior_surface_construction|
  #   puts("___  #{exterior_surface_construction.name} U=#{exterior_surface_construction.thermalConductance.to_f} ___")
  # end

  runner.registerFinalCondition("The existing insulation for exterior ground floor was set.")
  return true
end #end the measure
