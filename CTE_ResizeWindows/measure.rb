# Author: Rafael Villar Burke
# email: pachi@ietcc.csic.es
#
# Measure based on previous measure by Julien Marrec julien.marrec@gmail.com
#
# start the measure
class ResizeExistingWindows < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Reduce huecos en un porcentaje del área"
  end

  # human readable description
  def description
    return "Redimensiona huecos en el porcentaje indicado.
    El objetivo es descontar del area de hueco el area de marco,
    puesto que en OS el area de marco se detrae del muro y no del hueco."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Medida basada en la medida ResizeExistingWindowsToFitWWR"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make double argument for wwr
    frameratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("frameratio",true)
    frameratio.setDisplayName("Fraccion de marco (fraction).")
    frameratio.setDefaultValue(0.20)
    args << frameratio

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    frameratio = runner.getDoubleArgumentValue("frameratio",user_arguments)

    #check reasonableness of fraction
    if frameratio >= 1 or frameratio<=0
      runner.registerError("La fraccion de marco debe ser menor que 1 y mayor que cero.")
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("Fraccion de marco inicial #{OpenStudio::toNeatString(frameratio*100,2,true)}%.")
    area_scale_factor = 1 - frameratio
    scale_factor = area_scale_factor**0.5

    # Loop on surfaces
    surfaces = model.getSurfaces
    counter = 0

    runner.registerInfo("Click on 'Advanced' for a CSV of each subsurface area before and after")
    puts "\n=====================================================\n"
    puts "RESIZING INFORMATION (CSV)"
    puts "Subsurface Name, netArea_before, netArea_after"

    surfaces.each do |surface|
      next if (not surface.surfaceType == "Wall")
      next if (not surface.outsideBoundaryCondition == "Outdoors")
      # Surface has to be Sun Exposed!
      next if (not surface.sunExposure == "SunExposed")
      next if surface.subSurfaces.empty?

      counter += 1
      # Loop on each subSurfaces
      surface.subSurfaces.each do |subsurface|
        # Write before
        print subsurface.name.to_s + "," + subsurface.netArea.to_s
        # Get the centroid
        g = subsurface.centroid
        # Create an array to collect the new vertices (subsurface.vertices is a frozen array)
        vertices = []
        # Loop on vertices
        subsurface.vertices.each do |vertex|
          # A vertex is a Point3d.
          # A diff a 2 Point3d creates a Vector3d
          # Vector from centroid to vertex (GA, GB, GC, etc)
          centroid_vector = vertex - g
          # Resize the vector (done in place) according to scale_factor
          centroid_vector.setLength(centroid_vector.length * scale_factor)
          # Change the vertex
          vertex = g + centroid_vector
          vertices << vertex
        end # end of loop on vertices

        # Assign the new vertices to the subsurface
        subsurface.setVertices(vertices)
        # Append the new Area
        print "," + subsurface.netArea.to_s + "\n"
      end # End of loop on subsurfaces

    end # end of surfaces.each do |surface|

    # report final condition of model
    runner.registerFinalCondition("Finalizados cambios. #{counter} huecos fueron redimensionados")
    return true

  end
end

# register the measure to be used by the application
ResizeExistingWindows.new.registerWithApplication
