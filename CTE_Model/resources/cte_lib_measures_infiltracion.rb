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
#
# Horarios de infiltración:
# - espacios no habitables o sin equipos de acondicionamiento: permanente
# - espacios habitables acondicionados: horario específico
#
# Nivel de infiltraciones usando el modelo ELA (Effective Leakage Area):
# - fugas por opacos + fugas por huecos + (residencial) fugas por aireadores
#
# En residencial se considera una infiltración adicional por los aireadores (50% infiltrando),
# y consideramos que la podemos aproximar por ventanas en posición de microventilación.
#
# DUDA: Esta última superficie:
# - ¿tiene sentido añadirla o es redundante con la ventilación? En terciario no la añadimos

# Coeficientes para el cálculo de infiltraciones - Modelo Sherman-Grimsrud
# https://bigladdersoftware.com/epx/docs/8-0/engineering-reference/page-048.html
# Método ASHRAE Q = F_sched ·ELA / 1000 · sqrt(COEF_STACK · delta_T + COEF_WIND · v²)
# - ELA, Area (cm²) para 4 Pa de diferencia de presión
# - COEF_STACK - (L/s)²/(cm⁴·K)
# - COEF_WIND - (L/s)²/(cm⁴·(m/s)²)
# - delta_T (entre interior y exterior) - K
# - v - velocidad media aire m/s
# Coefs: https://bigladdersoftware.com/epx/docs/8-0/input-output-reference/page-018.html#zoneinfiltrationeffectiveleakagearea
CTE_COEF_STACK = 0.00029 # Valor para dos plantas de altura
CTE_COEF_WIND = 0.000231 # Valor para dos plantas y entorno urbano

# Coeficientes de caudal a 4 Pa
TO4PA = 0.11571248 # pow(4/100., 0.67), de 100 a 4 Pa
C_OP = {"Nuevo" => 16 * TO4PA,
        "Existente" => 29 * TO4PA}
C_PU = 60 * TO4PA # Permeabilidad puertas a 4Pa
C_HU = {"Clase 1" => 50 * TO4PA,
        "Clase 2" => 27 * TO4PA,
        "Clase 3" => 9 * TO4PA,
        "Clase 4" => 3 * TO4PA}

def cte_horario_de_infiltracion(runner, space, horario_always_on)
  # XXX: La detección de si el espacio es habitable o no depende de que los no habitables
  # tengan su space_type empezando por CTE_N
  no_habitable = space.spaceType.get.name.get.start_with?("CTE_N")

  # Sin equipos = no ideales y lista vacía de equipos
  no_equipment = (
    !space.thermalZone.get.useIdealAirLoads &&
     space.thermalZone.get.zoneConditioningEquipmentListName.empty?
  )

  if no_habitable || no_equipment
    # No habitable o sin equipos
    horario_infiltracion = horario_always_on
  else
    # Con equipos + habitable acondicionado
    horarios = space.defaultScheduleSet.empty? ?
      space.spaceType.get.defaultScheduleSet.get :
      space.defaultScheduleSet.get
    horario_infiltracion = horarios.infiltrationSchedule.get
  end

  horario_infiltracion
end

# Se modelan las infiltraciones usando el método ELA y las permeabilidades
# y parámetros del documento de condic. técnicas
def cte_infiltracion(model, runner, user_arguments) # copiado del residencial
  # busca el horario para hacer always_on
  horario_always_on = model.getScheduleRulesets
    .find { |h| h.name.get == "CTER24B_HINF" } || false

  # hay que tomar el horario del espacio -> zona -> tipo de zona

  tipo_edificio = runner.getStringArgumentValue("CTE_Tipo_edificio", user_arguments)
  clase_ventana = runner.getStringArgumentValue("CTE_Permeabilidad_ventanas", user_arguments)

  runner.registerValue("CTE Tipo de Edificio (Nuevo/Existente)", tipo_edificio)
  runner.registerValue("CTE Clase de permeabilidad de Ventanas", clase_ventana)

  spaces = model.getSpaces
  runner.registerValue("CTE Coeficientes de fugas de opacos a 4Pa", C_OP[tipo_edificio].round(4))
  runner.registerValue("CTE Coeficientes de fugas de puertas a 4Pa", C_PU.round(4))
  runner.registerValue("CTE Coeficientes de fugas de huecos a 4Pa", C_HU[clase_ventana].round(4))

  runner.registerInfo("** Superficies para ELA **")
  # XXX: pensar como interactúa con los espacios distintos a los acondicionados
  # ELA_total para comprobaciones
  ela_total = 0.0
  spaces.each do |space|
    horario_infiltracion = cte_horario_de_infiltracion(runner, space, horario_always_on)
    area_opacos = 0
    area_ventanas = 0
    area_puertas = 0
    # TODO: filtrar superficies NoMass, que son superficies auxiliares
    space.surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" && surface.windExposure == "WindExposed"
        area_opacos += surface.netArea
        surface.subSurfaces.each do |subsur|
          if ["FixedWindow", "OperableWindow", "SkyLight"].include?(subsur.subSurfaceType)
            area_ventanas += subsur.grossArea
          elsif ["Door", "GlassDoor", "OverheadDoor"].include?(subsur.subSurfaceType)
            area_puertas += subsur.grossArea
          else
            runner.registerWarning("Subsuperficie '#{subsur.name}' con tipo desconocido '#{subsur.subSurfaceType}' en superficie '#{surface.name}' del espacio '#{space.name}'")
          end
        end
      end
    end

    uso_edificio = runner.getStringArgumentValue("CTE_Uso_edificio",
      user_arguments)
    # Superficie bocas admisión, según modelo simplificado en residencial
    c_ven = if clase_ventana != "Clase 1" && uso_edificio == "Residencial"
      # Superficie igual a lo que falta para microventilación
      C_HU["Clase 1"] - C_HU[clase_ventana]
    else
      0.0
    end

    # q_total en m3/h a 4 Pa
    q_total = 4.0**0.67 * (C_OP[tipo_edificio] * area_opacos +
                             C_HU[clase_ventana] * area_ventanas +
                             C_PU * area_puertas +
                             # microventilación al 50% de apertura
                             0.50 * c_ven * area_ventanas / (4.0**0.5)
                          )

    area_equivalente = 1.0758287 * 0.50 * q_total # area ELA en cm2 con el 50% del área expuesta
    runner.registerValue("CTE ELA ('#{space.name}')", area_equivalente.round(2), "cm2 a 4Pa")

    # Elimina todos los objetos ELA que pueda haber
    space.spaceInfiltrationEffectiveLeakageAreas.each { |ela| ela.remove }

    # E inserta los nuevos
    ela = OpenStudio::Model::SpaceInfiltrationEffectiveLeakageArea.new(model)
    ela.setSpace(space)
    ela.setStackCoefficient(CTE_COEF_STACK)
    ela.setWindCoefficient(CTE_COEF_WIND)
    ela.setSchedule(horario_infiltracion)
    ela.setEffectiveAirLeakageArea(area_equivalente)
    ela.setName("CTE_ELA_#{space.name}")

    ela_total += area_equivalente
  end
  runner.registerValue("cte_ela_total_espacios", ela_total, "cm2 a 4 Pa")

  true # OS necesita saber que todo acaba bien
end
