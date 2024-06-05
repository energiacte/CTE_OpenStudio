# Copyright (c) 2016-2023 Ministerio de Fomento
#                    Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author(s): Rafael Villar Burke <pachi@ietcc.csic.es>,
#            Daniel Jiménez González <dani@ietcc.csic.es>

# Buscar aquí como son los wrappers de OS a objeto Ruby:
# https://openstudio-sdk-documentation.s3.amazonaws.com/cpp/OpenStudio-3.5.1-doc/model/html/annotated.html

def cte_cambia_u_huecos(model, runner, user_arguments)
  runner.registerInfo("CTE: Cambiando la U de huecos")

  # toma el valor de la medida
  u_huecos = runner.getDoubleArgumentValue("CTE_U_huecos", user_arguments)

  # Con valor cero no se cambia la U
  if u_huecos < 0.001
    runner.registerFinalCondition("No se cambia la transmitancia de los huecos (U=0)")
    return true
  end

  # Identifica huecos, construcciones y nombres de construcciones al exterior
  windows = []
  window_constructions = []
  window_construction_names = []
  model.getSpaces.each do |space|
    space.surfaces.each do |surface|
      next unless surface.outsideBoundaryCondition == "Outdoors" && surface.windExposure == "WindExposed"

      surface.subSurfaces.each do |subsur|
        # añade a lista de huecos
        windows << subsur

        window_construction = subsur.construction.get
        # añade la construcción únicamente si no lo ha hecho antes
        unless window_construction_names.include?(window_construction.name.to_s)
          window_constructions << window_construction.to_Construction.get
          window_construction_names << window_construction.name.to_s
        end

        # Informamos de tipos no manejados por la medida
        unless ["FixedWindow", "OperableWindow", "Door"].include?(subsur.subSurfaceType.to_s)
          runner.registerWarning("Hueco #{subsur.name.get} con tipo no cubierto por esta medida #{subsur.subSurfaceType}")
        end
      end
    end
  end

  if windows.empty?
    runner.registerWarning("El modelo no tiene ventanas.")
    return true
  end

  # mapa entre antigua construccion y nueva
  constructions_hash_old_new = {}
  # lista de nuevas construcciones (para condición final)
  final_constructions_array = []

  # Recorre construcciones y materiales usados, edita y clona
  window_constructions.each do |window_construction|
    # Localizamos la capa aislante.
    # En estos huecos solo hay una única capa (¿?) pero usamos código de muros
    materials_in_construction = window_construction.layers.map.with_index do |layer, i|
      {
        "name" => layer.name.to_s,
        "index" => i,
        "nomass" => !layer.to_MasslessOpaqueMaterial.empty?,
        "u_value" => layer.to_SimpleGlazing.get.uFactor,
        "mat" => layer
      }
    end

    if materials_in_construction.length == 1
      max_mat_hash = materials_in_construction[0]
    else
      runner.registerError("Más de una capa en la construcción de hueco #{window_construction.name}")
      return false
    end

    max_thermal_resistance_material = max_mat_hash["mat"] # objeto OS
    max_thermal_resistance_material_index = max_mat_hash["index"] # indice de la capa

    # clona material, cambia nombre y u
    new_material = max_thermal_resistance_material.clone(model)
    new_material = new_material.to_SimpleGlazing.get
    new_material.setName("#{max_thermal_resistance_material.name}_U-value #{u_huecos}")
    new_material.setUFactor(u_huecos)

    # ! 04 modifica la composición
    final_construction = window_construction.clone(model)
    final_construction = final_construction.to_Construction.get
    final_construction.setName("#{window_construction.name} U huecos mod.")
    final_construction.eraseLayer(max_thermal_resistance_material_index)
    final_construction.insertLayer(max_thermal_resistance_material_index, new_material)

    # Guarda en lista de construcciones y en mapping entre construcción anterior y modificada
    final_constructions_array << final_construction
    constructions_hash_old_new[window_construction.name.to_s] = final_construction

    runner.registerInfo("For construction'#{final_construction.name}', material'#{new_material.name}' was altered.")
  end

  # loop through construction sets used in the model
  default_construction_sets = model.getDefaultConstructionSets
  default_construction_sets.each do |default_construction_set|
    next if default_construction_set.directUseCount.zero?

    default_subsurface_const_set = default_construction_set.defaultExteriorSubSurfaceConstructions
    next if default_subsurface_const_set.empty?

    # creating new default construction set
    new_default_construction_set = default_construction_set.clone(model)
    new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get
    new_default_construction_set.setName("#{default_construction_set.name} adj u_huecos")

    # create new surface set and link to construction set
    new_default_subsurface_const_set = default_subsurface_const_set.get.clone(model)
    new_default_subsurface_const_set = new_default_subsurface_const_set.to_DefaultSubSurfaceConstructions.get
    new_default_subsurface_const_set.setName("#{default_subsurface_const_set.get.name}  u_huecos adj")
    new_default_construction_set.setDefaultExteriorSubSurfaceConstructions(new_default_subsurface_const_set)

    # use the hash to find the proper construction and link to new_default_subsurface_const_set
    target_const = new_default_subsurface_const_set.fixedWindowConstruction
    unless target_const.empty?
      target_const_name = target_const.get.name.to_s
      final_construction = constructions_hash_old_new[target_const_name]

      if final_construction
        new_default_subsurface_const_set.setFixedWindowConstruction(final_construction)
      else
        runner.registerWarning("Measure couldn't find the construction named '#{target_const_name}' in the windows construction hash.")
      end
    end

    # swap all uses of the old construction set for the new
    construction_set_sources = default_construction_set.sources
    construction_set_sources.each do |construction_set_source|
      building_source = construction_set_source.to_Building
      # if statement for each type of object than can use a DefaultConstructionSet
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

  # Cambia construcción de huecos a nueva construcción
  windows.each do |window|
    next if window.isConstructionDefaulted || window.construction.empty?
    final_construction = constructions_hash_old_new[window.construction.get.name.to_s]
    if final_construction
      window.setConstruction(final_construction)
    end
  end

  # Cambiamos los frameanddivider de todas las ventanas
  window_frameanddividers = []
  window_frameanddivider_names = []

  windows.each do |window|
    frame = window.windowPropertyFrameAndDivider.get
    unless window_frameanddivider_names.include?(frame.name.to_s)
      frame.setFrameConductance(u_huecos)
      frame.setName("Frame forzado a #{u_huecos}")
      window_frameanddividers << frame
      window_frameanddivider_names << frame.name.to_s
    end
  rescue
    runner.registerWarning("No se ha podido obtener el FrameAndDivider del hueco '#{window.name}'.")
  end

  runner.registerFinalCondition("Modificadas las transmitancias de los huecos #{final_constructions_array.length} construcciones")
  true
end
