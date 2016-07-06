# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class InfiltracionMetodoELA < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return " Infiltracion metodo ELA"
  end

  # human readable description
  def description
    return "Infiltracion ELA"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Infiltracion ELA"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    tipoEdificio = OpenStudio::StringVector.new    
    tipoEdificio << 'nuevo'
    tipoEdificio << 'existente'
    tipo = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("tipoEdificio", tipoEdificio, true)
    tipo.setDisplayName("Indica si el edificio es nuevo o existente.")
    args << tipo
    
    claseVentana = OpenStudio::StringVector.new
    claseVentana << 'clase 1'
    claseVentana << 'clase 2'
    claseVentana << 'clase 3'
    claseVentana << 'clase 4'
    permeabilidad = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("permeabilidadVentanas", claseVentana, true)
    permeabilidad.setDisplayName("Permeabilidad de la carpintería.")
    permeabilidad.setDefaultValue('clase 1')
    args << permeabilidad
    
    return args
  end
  
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end   
    
    f = 'log_infiltracionELA'
    horarios = model.getScheduleRulesets
    horarioInfiltracion = ''
    horarios.each do | horario |
        if horario.name.get == 'CTER24B_HINF'
            horarioInfiltracion = horario
        end    
    end
        
    # msg(f, "#{horarioInfiltracion}\n\n")
    
    msg(f, "__    argumentos   \n")  
    tipoEdificio = runner.getStringArgumentValue('tipoEdificio',user_arguments)    
    claseVentana = runner.getStringArgumentValue('permeabilidadVentanas',user_arguments)    
    msg(f,"tipoEdificio:#{tipoEdificio}\n")    
    msg(f, "__    fin argumentos\n\n")
    
    spaces = model.getSpaces
    msg(f, "numero de espacios: #{spaces.count}\n")    
    a4Pa = 0.11571248 # pow(4/100., 0.67), de 100 a 4 pascasles
    coef = {'nuevo'     => {'opaco' => 16*a4Pa, 'puerta' => 60*a4Pa}, 
            'existente' => {'opaco' => 29*a4Pa, 'puerta' => 60*a4Pa} }
            
    coefVent = {'clase 1'=> 50*a4Pa, 'clase 2'=> 27*a4Pa, 'clase 3'=> 9*a4Pa, 'clase 4'=> 3*a4Pa, }
    
    msg(f, "#{coef}\n\n")    
    msg(f, "**superficies para ELA**\n")
    spaces.each do | espacio|
        msg(f,"__espacio: #{espacio.name} ____\n")
        superficies = espacio.surfaces
        areaOpacos = 0
        areaVentanas = 0
        areaPuertas = 0
        superficies.each do | superficie |
            msg(f, "    __superficie: #{superficie.name}, #{superficie.surfaceType} \n")
            msg(f, "      cond.exter: #{superficie.outsideBoundaryCondition}\n")
            
            if superficie.outsideBoundaryCondition == 'Outdoors'            
                areaOpacos += superficie.netArea
                
                subsurs = superficie.subSurfaces
                subsurs.each do | subsur |
                    msg(f, "      __subSup: #{subsur.name}\n")
                    clavesVentanas = ['FixedWindow', 'OperableWindow', 'SkyLight']
                    clavesPuertas = ['Door', 'GlassDoor', 'OverheadDoor']
                    if clavesVentanas.include?(subsur.subSurfaceType)                        
                        areaVentanas += subsur.grossArea
                    elsif clavesPuertas.include?(subsur.subSurfaceType)                        
                        areaPuertas += subsur.grossArea
                    else
                        msg(f, "!!!!!!tipo subsurface no resuelto:#{subsur.subSurfaceType}\n")
                    end
                end
            # else
                # msg(f, "tipo subsurface no resuelto:#{subsur.subSurfaceType}\n")
            end            
        msg(f, "    __ __ \n")  #subsurfaces
        end
    
    msg(f, "areas totales: \n  opacos#{areaOpacos}, ventanas #{areaVentanas},  puertas #{areaPuertas}\n")
    qt = coef[tipoEdificio]['opaco'] * areaOpacos + 
         coefVent[claseVentana] * areaVentanas +
         coef[tipoEdificio]['puerta'] * areaPuertas
    qt = qt * 2.531513
    areaEquivalente = qt * 1.0758 / 2
     msg(f, "Area equivalente: #{areaEquivalente}\n\n")        
    # msg(f, "__ELAs definidos__\n")
    # areaELA = espacio.spaceInfiltrationEffectiveLeakageAreas
    # msg(f," areaELA: #{areaELA}\n\n")
    espacio.spaceInfiltrationEffectiveLeakageAreas.each do | ela |
        ela.remove
    end
    
    ela = OpenStudio::Model::SpaceInfiltrationEffectiveLeakageArea.new(model)
    ela.setSpace(espacio)
    ela.setStackCoefficient(3e-4)
     ela.setWindCoefficient(3e-4)
    ela.setSchedule(horarioInfiltracion)
    ela.setEffectiveAirLeakageArea(areaEquivalente) 
    ela.setName('ela_'+espacio.name.get.to_s)
    end
    
    # pardillo = idiosincrasia
 
    return true # OS necesita saber que todo acab bien
  end
  
  def msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}  
  end  
  
end # end the measure

# register the measure to be used by the application
InfiltracionMetodoELA.new.registerWithApplication
