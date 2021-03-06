# -*- coding: utf-8 -*-
#
# Copyright (c) 2016 Ministerio de Fomento
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
#            Marta Sorribes Gil <msorribes@ietcc.csic.es>

require "openstudio"
require_relative "cte_query"

# TODO: acabar la tabla de remplazo
REPLACEMENTS ||= {
  'Ñ' => 'N',
  'ñ' => 'N'}
ENCODING_OPTIONS ||= {
  :invalid           => :replace,  # Replace invalid byte sequences
  :replace           => "",        # Use a blank for those replacements
  :universal_newline => true,       # Always break lines with \n
  :fallback => lambda { |char|
  	REPLACEMENTS.fetch(char, "")}}

# TODO: aplicar sanitize a todos los name.get que se vayan (sólo) a representar
module Utils
  def self.sanitizestring(runner, inputstring)
    runner.registerInfo(" para sanitize, recibido |#{inputstring}|")
    return inputstring.encode(Encoding.find('ASCII'), ENCODING_OPTIONS)
  end

  def self.sanitize(runner, input)
  	if input.class == Array
  		salida = []
  		input.each do | elemento |
  			salida << sanitizestring(runner, elemento)
  		end
  	else
  		salida = sanitizestring(runner, input)
  	end
  	return salida
  end
end


module CTE_tables
  #======== Elementos generales  ============
  # variablesdisponiblesquery = "SELECT DISTINCT VariableName, ReportingFrequency FROM ReportVariableDataDictionary "

  #======== Tabla general de mediciones =====
  def self.tabla_mediciones_generales(model, sqlFile, runner)
    # TODO: descomponer superficies externas de la envolvente por tipos (muros, cubiertas, huecos, lucernarios, etc)
    buildingName = model.getBuilding.name.get
    # Zonas habitables
    zonasHabitables = CTE_Query.zonasHabitables(sqlFile)
    superficieHabitable = CTE_Query.superficieHabitable(sqlFile).round(2)
    volumenHabitable = CTE_Query.volumenHabitable(sqlFile).round(2)
    # Zonas no habitables
    zonasNoHabitables = CTE_Query.zonasNoHabitables(sqlFile)
    superficieNoHabitable = CTE_Query.superficieNoHabitable(sqlFile).round(2)
    volumenNoHabitable = CTE_Query.volumenNoHabitable(sqlFile).round(2)
    # Envolvente térmica
    superficiesExteriores = CTE_Query.envolventeSuperficiesExteriores(sqlFile)
    areaexterior = CTE_Query.envolventeAreaExterior(sqlFile).round(2)
    superficiesInteriores = CTE_Query.envolventeSuperficiesInteriores(sqlFile)
    areainterior = CTE_Query.envolventeAreaInterior(sqlFile).round(2)
    areatotal = areaexterior + areainterior
    compacidad = (volumenHabitable / areatotal).round(2)

    runner.registerInfo("* Iniciando mediciones (edificio #{ buildingName })")
    runner.registerValue("Zonas habitables", "#{ zonasHabitables }")
    runner.registerValue("Zonas habitables, número", zonasHabitables.count())
    runner.registerValue("Zonas habitables, superficie", superficieHabitable, 'm^2')
    runner.registerValue("Zonas habitables, volumen", volumenHabitable, 'm^3')
    runner.registerValue("Zonas no habitables", "#{ zonasNoHabitables }")
    runner.registerValue("Zonas no habitables, número", zonasNoHabitables.count())
    runner.registerValue("Zonas no habitables, superficie", superficieNoHabitable, 'm^2')
    runner.registerValue("Zonas no habitables, volumen", volumenNoHabitable, 'm^3')
    runner.registerValue('Envolvente Térmica, superficies exteriores', superficiesExteriores.count())
    runner.registerValue('Envolvente Térmica, superficies interiores', superficiesInteriores.count())
    runner.registerValue('Envolvente Térmica, área de superficies exteriores', areaexterior, 'm^2')
    runner.registerValue('Envolvente Térmica, área de superficies interiores', areainterior, 'm^2')
    runner.registerValue('Envolvente Térmica, área total', areatotal, 'm^2')
    runner.registerValue('Compacidad', compacidad)

    medicion_general = {}
    medicion_general[:title] = "Mediciones (edificio #{ buildingName })"
    medicion_general[:header] = ['', '#', 'Superficie', 'Volumen']
    medicion_general[:units] = ['', '', 'm²', 'm³']
    medicion_general[:data] = []
    medicion_general[:data] << ['<b>Edificio</b>', '', superficieHabitable + superficieNoHabitable, volumenHabitable + volumenNoHabitable]
    medicion_general[:data] << ["<u>Zonas habitables</u>", zonasHabitables.count(), superficieHabitable, volumenHabitable]
    medicion_general[:data] << ["<u>Zonas no habitables</u>", zonasNoHabitables.count(), superficieNoHabitable, volumenNoHabitable]
    medicion_general[:data] << ["<u>Envolvente térmica</u>", '', areatotal, '']
    medicion_general[:data] << ['- Exterior', '', areaexterior, '']
    medicion_general[:data] << ['- Interior', '', areainterior, '']
    medicion_general[:data] << ['<b>Compacidad</b>', "<b>#{ compacidad }</b>", areatotal, volumenHabitable]
    runner.registerInfo("* Finalizadas mediciones (edificio #{ buildingName })")

    return medicion_general
  end

 def self.energyConsumptionByVectorAndUse(sqlFile, vectorName, useName)
    # las unidades son Julios a tenor de la informacion del SQL:
    # SELECT distinct  reportname, units FROM TabularDataWithStrings
    # los reports son LIKE 'BUILDING ENERGY PERFORMANCE - %'
    result = [0.0] * 12
    meses = (1..12).to_a
    meses.each do | mesNumber |
      endfueltype    = OpenStudio::EndUseFuelType.new(vectorName)
      endusecategory = OpenStudio::EndUseCategoryType.new(useName)
      monthofyear    = OpenStudio::MonthOfYear.new(mesNumber)
      valor = sqlFile.energyConsumptionByMonth(
                    endfueltype, endusecategory, monthofyear).to_f
      result[mesNumber-1] += valor
    end
    return result
  end

  def self.energyConsumptionByUses(sqlFile, useNames)
    useNames = [useNames] unless useNames.class == Array

    result = 0
    useNames.each do | end_use |
      query_all = "
      SELECT
        SUM(Value)
      FROM
        tabulardatawithstrings
      WHERE
        ReportName='AnnualBuildingUtilityPerformanceSummary'
        AND TableName='End Uses'
        AND RowName= '#{end_use}'
        AND ColumnName IN  ('Electricity', 'Natural Gas', 'Additional Fuel',
                    'District Cooling', 'District Heating') "
      search = sqlFile.execAndReturnFirstDouble(query_all)
      result += search.get
    end

    return OpenStudio.convert(result, 'GJ', 'kWh').get
  end



  def self.tabla_de_energias(model, sqlFile, runner)

    superficiehabitable = CTE_Query.superficieHabitable(sqlFile)

    usosEPB = {'Heating'=> 0, 'Cooling'=> 0, 'Water Systems'=> 0}
    #~ usosNoEPB = {'Interior Lighting'=> 0, 'Exterior Lighting'=> 0, 'Interior Equipment'=> 0,
            #~ 'Exterior Equipment'=> 0, 'Fans'=> 0, 'Pumps'=> 0, 'Heat Rejection'=> 0,
            #~ 'Humidification'=> 0, 'Heat Recovery'=> 0, 'Refrigeration'=> 0, 'Generators'=> 0}

    usosNoEPB = {'Interior Lighting'=> 0, 'Interior Equipment'=> 0,
            'Fans'=> 0, 'Pumps'=> 0, }

    traduce = {'Heating'=> 'Calefacción', 'Cooling'=> 'Refrigeración',
      'Water Systems'=> 'ACS', 'Interior Lighting'=> 'Iluminación',
      'Interior Equipment'=> 'Equipos','Fans'=> 'Ventiladores',
      'Pumps'=> 'Bombas'}

    totalUsosEPB = 0
    usosEPB.each do | clave, dummy |
      valor = energyConsumptionByUses(sqlFile, clave)
      usosEPB[clave] = valor
      totalUsosEPB += valor
    end

    totalUsosNoEPB = 0
    usosNoEPB.each do | clave, dummy |
      valor = energyConsumptionByUses(sqlFile, clave)
      usosNoEPB[clave] = valor
      totalUsosNoEPB += valor
    end

    #~ runner.registerValue('Energia Neta (Net Site Energy)', energianeta, 'kWh')
    #~ runner.registerValue('Intensidad energética (EUI)', intensidadEnergetica, 'kWh/m^2')

    general_table = {}
    general_table[:title] = 'Consumo Neto (Energía Final)'
    general_table[:header] =['', 'Energía', 'Energía/Sup. Acond.']
    general_table[:units] = ['', 'kWh', 'kWh/m²']
    general_table[:data] = []
    general_table[:data] << ['<b>Servicios EPB + No EPB</b>',
      (totalUsosEPB+totalUsosNoEPB).round(0),
      "<b>#{((totalUsosEPB+totalUsosNoEPB)/superficiehabitable).round(1)}</b>"]
    general_table[:data] << ['<b>Servicios EPB</b>', totalUsosEPB.round(0),
        "<b>#{(totalUsosEPB/superficiehabitable).round(1)}</b>"]
    usosEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", valor.round(0), (valor/superficiehabitable).round(1)]
    end

    general_table[:data] << ['<b>Servicios No EPB</b>', totalUsosNoEPB.round(0),
        "<b>#{(totalUsosNoEPB/superficiehabitable).round(1)}</b>"]
    usosNoEPB.each do | clave, valor |
      general_table[:data] << [" - #{traduce[clave]}", valor.round(0), (valor/superficiehabitable).round(1)]
    end
    return general_table
  end

  def self.areaPorOrientacion_discontinuo(sqlFile, limite1, limite2, tipo)
    salida = []
    construcciones_search = "SELECT DISTINCT Name FROM (#{CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES})
      WHERE (Azimuth > #{limite1} OR Azimuth < #{limite2} )
      AND ClassName IN (#{tipo}) "
    construcciones = CTE_tables.getValueOrFalse(sqlFile.execAndReturnVectorOfString(construcciones_search))
    if construcciones != false
      construcciones.each do | construccion |
        area_search = "SELECT SUM(Area) FROM (#{CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES})
          WHERE (Azimuth > #{limite1} OR Azimuth < #{limite2} )
          AND ClassName IN (#{tipo})
          AND Name == '#{construccion}' "
        area = sqlFile.execAndReturnFirstDouble(area_search).get
        salida << [construccion, area] #"construccion: #{construccion}, #{area}"
      end
    end
    return salida
  end

  def self.areaPorOrientacion_continuo(sqlFile, limite1, limite2, tipo)
    salida = []
    construcciones_search = "SELECT DISTINCT Name FROM (#{CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES})
      WHERE (Azimuth > #{limite1} AND Azimuth < #{limite2} )
      AND ClassName IN (#{tipo}) "
    construcciones = CTE_tables.getValueOrFalse(sqlFile.execAndReturnVectorOfString(construcciones_search))

    if construcciones != false
      construcciones.each do | construccion |
        area_search = "SELECT SUM(Area) FROM (#{CTE_Query::ENVOLVENTE_EXTERIOR_CONSTRUCCIONES})
          WHERE (Azimuth > #{limite1} AND Azimuth < #{limite2} )
          AND ClassName IN (#{tipo})
          AND Name == '#{construccion}' "
        area = sqlFile.execAndReturnFirstDouble(area_search).get
        salida << [construccion, area]
      end
    end
    return salida
  end

  def self.areaPorOrientacion(sqlFile, limite1, limite2, tipo)
    if limite1 > limite2
      return areaPorOrientacion_discontinuo(sqlFile, limite1, limite2, tipo)
    else
      return areaPorOrientacion_continuo(sqlFile, limite1, limite2, tipo)
    end
  end



  def self.tabla_mediciones_por_orientaciones(model, sqlFile, runner)
    # orientación del edificio.
    search = "SELECT Value FROM TabularDataWithStrings WHERE RowName == 'North Axis Angle' "
    northAxisAngle = CTE_tables.getValueOrFalse(sqlFile.execAndReturnFirstDouble(search))
    c_norte    =  22.5 - northAxisAngle
    c_noreste  =  60.0 - northAxisAngle
    c_este     = 111.0 - northAxisAngle
    c_sureste  = 162.0 - northAxisAngle
    c_sur      = 198.0 - northAxisAngle
    c_suroeste = 249.0 - northAxisAngle
    c_oeste    = 300.0 - northAxisAngle
    c_noroeste = 337.5 - northAxisAngle

    cuadrantes = [c_norte, c_noroeste, c_este, c_sureste, c_sur, c_suroeste, c_oeste, c_noroeste]

    cuadrantes.each_with_index do | valor, indice |
      while valor < 0.0 do
        valor += 360
      end
      cuadrantes[indice] = valor
    end
    c_norte, c_noroeste, c_este, c_sureste, c_sur, c_suroeste, c_oeste, c_noroeste = cuadrantes

    contenedor_general = {}
    contenedor_general[:title] = "Mediciones por orientaciones"
    contenedor_general[:header] = ['area']
    contenedor_general[:units] = ['m2']
    contenedor_general[:data] = []

    def self.anadir_area(etiqueta, c1, c2, sqlFile, contenedor_general)
      area = areaPorOrientacion(sqlFile, c1, c2, "\'Wall\', \'Window\'")
      if not area.empty?
        area.each do | construccion, metros |
          contenedor_general[:data] << [etiqueta, construccion, metros.round(2)]
        end
      end
    end

    anadir_area('norte',   c_noroeste, c_norte,   sqlFile, contenedor_general)
    anadir_area('noreste', c_norte,    c_noreste, sqlFile, contenedor_general)
    anadir_area('este',    c_noreste,  c_este,    sqlFile, contenedor_general)
    anadir_area('sureste', c_este,     c_sureste, sqlFile, contenedor_general)
    anadir_area('sur',     c_sureste,  c_sur,     sqlFile, contenedor_general)
    anadir_area('suroeste',c_sur,      c_suroeste,sqlFile, contenedor_general)
    anadir_area('oeste'   ,c_suroeste, c_oeste,   sqlFile, contenedor_general)
    anadir_area('noroeste',c_oeste,    c_noroeste,sqlFile, contenedor_general)

    return contenedor_general
  end

  def self.tabla_mediciones_elementos_with_film(model, sqlFile, runner)
    factor_AU = 0
    area_total = 0

    contenedor_general = {}
    contenedor_general[:title] = "Mediciones elementos de la envolvente con Rsi"
    contenedor_general[:header] = ['Elemento', 'Superficie', 'U with film']
    contenedor_general[:units] = ['', 'm²', 'W/m²K']
    contenedor_general[:data] = []
    contenedor_general[:factor_AU] = 0
    contenedor_general[:area_total] = 0

    superficiesQuery = "SELECT SurfaceName FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
    WHERE ClassName IN ('Wall', 'Roof', 'Floor')"

    superficies = getValueOrFalse(sqlFile.execAndReturnVectorOfString(superficiesQuery))
    superficies.each do | surfaceName |
      areaQuery = "SELECT Area From Surfaces WHERE SurfaceName = '#{ surfaceName }'"
      area = getValueOrFalse(sqlFile.execAndReturnFirstDouble(areaQuery))
      ufilmQuery = "SELECT Value FROM TabularDataWithStrings
        WHERE ColumnName = 'U-Factor with Film' AND RowName = '#{ surfaceName }'"
      ufilm = getValueOrFalse(sqlFile.execAndReturnFirstDouble(ufilmQuery))
      factor_AU += area*ufilm
      area_total += area
      contenedor_general[:data] << [surfaceName, area.round(2), ufilm.round(3)]
    end

    superficiesQuery = "SELECT SurfaceName FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
    WHERE ClassName IN ('Window')"

    superficies = getValueOrFalse(sqlFile.execAndReturnVectorOfString(superficiesQuery))
    superficies.each do | subSurfaceName |
      glassAreaQuery = "
        SELECT Value
        FROM TabularDataWithStrings
        WHERE RowName = '#{ subSurfaceName }'
          AND TableName = 'Exterior Fenestration'
          AND ColumnName = 'Glass Area' "
      glassArea = getValueOrFalse(sqlFile.execAndReturnFirstDouble(glassAreaQuery))

      glassUfactorQuery = "
        SELECT Value
        FROM TabularDataWithStrings
        WHERE RowName = '#{ subSurfaceName }'
          AND TableName = 'Exterior Fenestration'
          AND ColumnName = 'Glass U-Factor' "
      glassUfactor = getValueOrFalse(sqlFile.execAndReturnFirstDouble(glassUfactorQuery))

      glassUFactorWithFilm = glassUfactor/(1 + 0.17*glassUfactor)

      factor_AU += glassArea * glassUFactorWithFilm
      area_total += glassArea

      frameAreaQuery = "
        SELECT Value
        FROM TabularDataWithStrings
        WHERE RowName = '#{ subSurfaceName }'
          AND TableName = 'Exterior Fenestration'
          AND ColumnName = 'Frame Area' "
      frameArea = getValueOrFalse(sqlFile.execAndReturnFirstDouble(frameAreaQuery))

      frameUfactorQuery = "
        SELECT Value
        FROM TabularDataWithStrings
        WHERE RowName = '#{ subSurfaceName }'
          AND TableName = 'Exterior Fenestration'
          AND ColumnName = 'Frame Conductance' "
      frameUfactor = getValueOrFalse(sqlFile.execAndReturnFirstDouble(frameUfactorQuery))

      frameUFactorWithFilm = frameUfactor/(1 + 0.17*frameUfactor)

      factor_AU += frameArea * frameUFactorWithFilm
      area_total += frameArea

      windowUfactorWithFilm = (glassArea * glassUFactorWithFilm + frameArea * frameUFactorWithFilm) \
                                /(glassArea + frameArea)
      windowArea = glassArea + frameArea

      contenedor_general[:data] << [subSurfaceName, windowArea.round(2), windowUfactorWithFilm.round(3)]
    end

    contenedor_general[:factor_AU] = factor_AU
    contenedor_general[:area_total] = area_total
    return contenedor_general
  end

  def self.tabla_mediciones_envolvente(model, sqlFile, runner)

    indicesquery = "SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
                    UNION
                    SELECT ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES })"
    indices  = sqlFile.execAndReturnVectorOfString(indicesquery).get

    data = []
    indices.each do | indiceconstruccion |
      query = "SELECT SUM(Area) FROM
                   (SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_EXTERIORES })
                    UNION ALL
                    SELECT Area, ConstructionIndex FROM (#{ CTE_Query::ENVOLVENTE_SUPERFICIES_INTERIORES }))
               WHERE ConstructionIndex == #{ indiceconstruccion }"
      area = sqlFile.execAndReturnFirstDouble(query).get
      nombre = sqlFile.execAndReturnFirstString("SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
      uvalue = sqlFile.execAndReturnFirstDouble("SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} ").get
      unless nombre.include?("_PSI")
        data << ["#{ nombre }".encode("UTF-8", invalid: :replace, undef: :replace), area, uvalue]
      end
    end

    contenedor_general = {}
    contenedor_general[:title] = "Mediciones elementos de la envolvente"
    contenedor_general[:header] = ['Construcción', 'Superficie', 'U']
    contenedor_general[:units] = ['', 'm²', 'W/m²K']
    contenedor_general[:data] = []
    data.each do | nombre, area, uvalue |
      contenedor_general[:data] << [nombre, area.round(2), uvalue.round(3)]
    end

    return contenedor_general
  end

  def self.tabla_mediciones_puentes_termicos(model, runner)

    coeficienteAcoplamiento = {}
    ttl_puenteTermico = {}
    model.getSurfaces.each do |surface|
      if surface.name.get.include? "_pt"
        tipoPT = surface.name.get.split('_pt')[1]
        unless coeficienteAcoplamiento.keys.include?(tipoPT)
          coeficienteAcoplamiento[tipoPT] = 0.0
          ttl_puenteTermico[tipoPT] = 0.0
        end
        coeficienteAcoplamiento[tipoPT] += surface.grossArea.round(2)
        ttl_puenteTermico[tipoPT] = surface.construction.get.name.get.split('PSI')[1].to_f
      end
    end

    contenedor_general = {}
    contenedor_general[:title] = "Mediciones de puentes térmicos"
    contenedor_general[:header] = ['Tipo', 'Coef. acoplamiento', 'Longitud', 'PSI']
    contenedor_general[:units] = ['', 'W/K', 'm', 'W/mK']
    contenedor_general[:data] = []
    contenedor_general[:factor_LPsi] = 0
    factor_LPsi = 0
    
    coeficienteAcoplamiento.each do | key, value |
      psi = ttl_puenteTermico[key]
      contenedor_general[:data] << [key, value.round(0), (value/psi).round(0), psi.round(2)]
      factor_LPsi += value
    end

    contenedor_general[:factor_LPsi] = factor_LPsi
    return contenedor_general


  end

  # Tabla de aire exterior
  def self.tabla_de_aire_exterior(model, sqlFile, runner)

    # XXX: Zone Combined Outdoor Air Changes per Hour is not includen in the OutdoorAirSummary,
    # it has to be read from general variable data in the SQL file.

    # data for query
    report_name = 'OutdoorAirSummary'
    table_name = 'Average Outdoor Air During Occupied Hours'
    columns = ['', 'Ventilación mecánica media',
          'Infiltración media', 'Ventilación simple media', 'Ventilación combinada media']

    variableNamesForColumns = {
      'Ventilación mecánica media' => 'Avg. Mechanical Ventilation',
      'Infiltración media' => 'Avg. Infiltration',
      'Ventilación simple media' => 'Avg. Simple Ventilation',
      'Ventilación combinada media' => 'Zone Combined Outdoor Air Changes per Hour'}

    # populate dynamic rows
    # los rows son las filas, es decir las zonas térmicas
    rows_name_query = "SELECT DISTINCT  RowName FROM tabulardatawithstrings WHERE ReportName='#{report_name}' and TableName='#{table_name}'"
    row_names = sqlFile.execAndReturnVectorOfString(rows_name_query).get
    rows = []
    row_names.each do |row_name|
      rows << row_name
    end

    # create table
    table = {}
    table[:title] = 'Renovación del aire exterior (medias)'
    table[:header] = columns
    table[:units] = ['', 'ach', 'ach', 'ach', 'ach']
    table[:source_units] = [ '', 'ach', 'ach', 'ach', 'ach']
    table[:data] = []

    medias = {}
    table[:header].each do | columna|
      medias[columna] = 0
    end
    totalVolume = 0

    # run query and populate table
    rows.each do |row| # va zona a zona
      query = "SELECT Volume FROM Zones WHERE ZoneName='#{row}' "
      zoneVolume = sqlFile.execAndReturnFirstDouble(query).to_f
      totalVolume += zoneVolume
      row_data = [row]
      column_counter = -1
      table[:header].each do |header| #va columna a columna
        column_counter += 1
        next if header == ''

        if header.include? 'combinada'
          query = "SELECT
              AVG(VariableValue)
            FROM
              ReportVariableData AS rvd
              INNER JOIN ReportVariableDataDictionary AS rvdd ON rvdd.ReportVariableDataDictionaryIndex = rvd.ReportVariableDataDictionaryIndex
            WHERE
              rvdd.VariableName = 'Zone Combined Outdoor Air Changes per Hour'
              AND ReportingFrequency ='Monthly'
              AND KeyValue = '#{row}'"
        else  header.include? 'media'
          query = "SELECT
              Value
            FROM
              tabulardatawithstrings
            WHERE
              ReportName='#{report_name}' and TableName='#{table_name}'
              and RowName= '#{row}' and ColumnName= '#{variableNamesForColumns[header].gsub('Avg. ', '')}'"
        end

        results = sqlFile.execAndReturnFirstDouble(query)
        row_data_ip = OpenStudio.convert(results.to_f,
                      table[:source_units][column_counter],
                      table[:units][column_counter]).get
        row_data << row_data_ip.round(2)

        # para la media de todo el edificio
        medias[header] += row_data_ip * zoneVolume
      end

      table[:data] << row_data
    end

    row_data = ['Total edificio']
    table[:header].each do |header|
      next if header == ''
      row_data << (medias[header] / totalVolume).round(2)
    end
    table[:data] << row_data

    return table
  end


  def self.tabla_demanda_por_componentes(model, sqlFile, runner, periodo)
    runner.registerInfo("__ inicidada demanda por componentes__#{periodo}\n")

    superficiehabitable =  CTE_Query.superficieHabitable(sqlFile).round(2)
    temporada = {'invierno' => 'calefaccion', 'verano'   => 'refrigeracion' }[periodo]
    color = {'invierno' => '#EF1C21', 'verano'   => '#008FF0' }[periodo]
    data = []

    # paredes aire ext.
    airWallHeat =   _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                    periodo, 'Wall', "AND ExtBoundCond = 0 AND SurfaceName NOT LIKE '%_PT%'") / superficiehabitable
    data << [airWallHeat, temporada, 'Paredes Exteriores']

    # paredes terreno
    groundWallHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                    periodo, 'Wall', "AND ExtBoundCond = -1") / superficiehabitable
    data << [groundWallHeat, temporada, 'Paredes Terreno']

    # paredes interiores
    indoorWallHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                        periodo, 'Wall', "AND ExtBoundCond NOT IN (0, -1)") / superficiehabitable
    data << [indoorWallHeat, temporada, 'Paredes Interiores']

    # XXX: no tenemos el balance de las particiones interiores entre zonas
    # cubiertas
    roofHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                        periodo, 'Roof', "AND ExtBoundCond = 0") / superficiehabitable
    data << [roofHeat, temporada, 'Cubiertas']

    # suelos aire ext
    airFloorHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                          periodo, 'Floor', "AND ExtBoundCond = 0") / superficiehabitable
    data << [airFloorHeat, temporada, 'Suelos Aire']

    # suelos terreno
    groundFloorHeat = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                              periodo, 'Floor', "AND ExtBoundCond = -1") / superficiehabitable
    data << [groundFloorHeat, temporada, 'Suelos Terreno']

    # puentes termicos
    thermalBridges = _componentValueForPeriod(sqlFile, 'Surface Inside Face Conduction Heat Transfer Energy',
                                    periodo, 'Wall', "AND SurfaceName LIKE '%_PT%'") / superficiehabitable
    data << [thermalBridges, temporada, 'Puentes Termicos']

    # #solar y transmisión ventanas
    windowRadiation = _componentValueForPeriod(sqlFile, 'Surface Window Transmitted Solar Radiation Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    data << [windowRadiation, temporada, 'Solar Ventanas']
    windowTransmissionGain = _componentValueForPeriod(sqlFile, 'Surface Window Heat Gain Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    windowTransmissionLoss = _componentValueForPeriod(sqlFile, 'Surface Window Heat Loss Energy', periodo, 'Window', "AND ExtBoundCond = 0") / superficiehabitable
    windowTransmission = windowTransmissionGain - windowTransmissionLoss - windowRadiation
    data << [windowTransmission, temporada, 'Transmision Ventanas']
    # fuentes internas
    internalHeating = _zoneValueForPeriod(sqlFile, "Zone Total Internal Total Heating Energy", periodo) / superficiehabitable
    data << [internalHeating, temporada, 'Fuentes Internas']
    # ventilacion + infiltraciones
    ventGain = _zoneValueForPeriod(sqlFile, "Zone Combined Outdoor Air Sensible Heat Gain Energy", periodo) / superficiehabitable
    ventLoss = _zoneValueForPeriod(sqlFile, "Zone Combined Outdoor Air Sensible Heat Loss Energy", periodo) / superficiehabitable
    airHeatBalance = ventGain - ventLoss
    data << [airHeatBalance, temporada, 'Ventilación + Infiltraciones']

    # total
    total = data.map{ | value, label, label_x | value }.reduce(:+)
    data << [total, temporada, 'Total']

    orden_eje_x = []
    medicion_general = {}
    medicion_general[:title] = "Demandas por componentes en #{periodo} [kWh/m²]"
    medicion_general[:header] = [
      '', 'Paredes Exteriores', 'Paredes Terreno', 'Paredes Interiores',
      'Cubiertas', 'Suelos Aire', 'Suelos Terreno', 'Puentes Termicos',
      'Solar Ventanas', 'Transmisión Ventanas',
      'Fuentes Internas',
      'Ventilación + Infiltraciones', 'Total'
    ]
    medicion_general[:units] = [''] + ['kWh/m²'] * (medicion_general[:header].size - 1)
    medicion_general[:chart_type] = 'vertical_stacked_bar'
    medicion_general[:chart_attributes] = {
      value: medicion_general[:title],
      label_x: 'Componente',
      sort_yaxis: [],
      sort_xaxis: orden_eje_x
    }
    medicion_general[:chart] = []

    valores_fila = [periodo] #la fila de la tabla en cuestión
    data.each do | value, label, label_x |
      medicion_general[:chart] << JSON.generate(
        label: label,
        label_x: label_x,
        value: value,
        color: color
      )
      valores_fila << value.round(2)
      orden_eje_x << label_x
    end
    medicion_general[:data] = [] << valores_fila

    return medicion_general
  end

  def self._componentValueForPeriod(sqlFile, variableName, periodo, className, extraCond, unitsSource='J', unitsTarget='kWh')
    # XXX: Esto no funciona porque no se limitan las superficies a las que forman parte de la envolvente sino que son todas las
    # XXX: de las zonas habitables
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    supHab AS (#{ CTE_Query::ZONASHABITABLES_SUPERFICIES })
SELECT
    SUM(VariableValue)
FROM
    supHab
    INNER JOIN ReportVariableDataDictionary AS rvdd ON supHab.SurfaceName = rvdd.KeyValue
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time AS time USING (TimeIndex)
WHERE
    VariableName = '#{ variableName }'
    AND ReportingFrequency = 'Monthly'
    AND ClassName = '#{ className }'
    AND Month IN #{ meses }
    #{ extraCond }
"

    return OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, unitsSource, unitsTarget).get
  end

  def self._zoneValueForPeriod(sqlFile, variableName, periodo, unitsSource='J', unitsTarget='kWh')
    meses = (periodo == 'invierno') ? "(1,2,3,4,5,10,11,12)" : "(6,7,8,9)"
    query = "
WITH
    zonashabitables AS (#{ CTE_Query::ZONASHABITABLES })
SELECT
    SUM(VariableValue)
FROM
    zonashabitables
    INNER JOIN ReportVariableDataDictionary
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time USING (TimeIndex)
WHERE
    VariableName = '#{ variableName }'
    AND ReportingFrequency = 'Monthly'
    AND KeyValue = ZoneName
    AND Month IN #{ meses }
"
    return OpenStudio.convert(sqlFile.execAndReturnFirstDouble(query).get, unitsSource, unitsTarget).get
  end

  def self.output_data_end_use_table(model, sqlFile, runner)
    # end use data output
    output_data_end_use = {}
    output_data_end_use[:title] = 'Consumo de energía final por servicio'
    output_data_end_use[:header] = ['Servicio', 'Consumo']
    output_data_end_use[:units] = ['', 'kWh']
    output_data_end_use[:data] = []
    output_data_end_use[:chart_type] = 'simple_pie'
    output_data_end_use[:chart] = []

    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD', '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    # loop through fuels for consumption tables
    OpenStudio::EndUseCategoryType.getValues.each_with_index do |end_use, index|
      # get end uses
      end_use = OpenStudio::EndUseCategoryType.new(end_use).valueDescription #aquí es un nombre de categoría:
        # Heating, Cooling, Interior Lighting, Exterior Lighting, Interior Equipment, Exterior Equipment,
        # Fans, Pumps, Heat Rejection, Humidification, Heat Recovery, Water Systems, Refrigeration, Generators

      query_elec = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Electricity'"
      query_gas = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Natural Gas'"
      query_add = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'Additional Fuel'"
      query_dc = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'District Cooling'"
      query_dh = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' and TableName='End Uses' and RowName= '#{end_use}' and ColumnName= 'District Heating'"
      results_elec = sqlFile.execAndReturnFirstDouble(query_elec).get
      results_gas = sqlFile.execAndReturnFirstDouble(query_gas).get
      results_add = sqlFile.execAndReturnFirstDouble(query_add).get
      results_dc = sqlFile.execAndReturnFirstDouble(query_dc).get
      results_dh = sqlFile.execAndReturnFirstDouble(query_dh).get
      total_end_use = results_elec + results_gas + results_add + results_dc + results_dh
      value = OpenStudio.convert(total_end_use, 'GJ', 'kWh').get
      end_use_trans = self.translate(end_use)
      output_data_end_use[:data] << [end_use_trans, '%.0f' % value]
      runner.registerValue("CTE Uso energia final - #{end_use_trans}", value, 'kWh')
      if value > 0
        output_data_end_use[:chart] << JSON.generate(label: end_use_trans, value: value, color: end_use_colors[index])
      end
    end

    return output_data_end_use
  end

  def self.getValueOrFalse(search)
    return (if search.empty? then false else search.get end)
  end

  def self.translate(key)
    # Traducción de diversos elementos de la interfaz
    { 'Heating' => 'Calefacción',
      'Cooling' => 'Refrigeración',
      'Interior Lighting' => 'Iluminación interior',
      'Exterior Lighting' => 'Iluminación exterior',
      'Interior Equipment' => 'Equipos (interiores)',
      'Exterior Equipment' => 'Equipos (exteriores)',
      'Fans' => 'Ventiladores',
      'Pumps' => 'Bombas',
      'Heat Rejection' => 'Disipación de calor',
      'Humidification' => 'Humidificación',
      'Heat Recovery' => 'Recuperación de calor',
      'Water Systems' => 'Sistemas de agua',
      'Refrigeration' => 'Equipos frigoríficos',
      'Generators' => 'Equipos de generación',
      'Electricity' => 'Electricidad',
      'Natural Gas' => 'Gas Natural',
      'Additional Fuel' => 'Otro combustible',
      'District Cooling' => 'Demanda de refrigeración',
      'District Heating' => 'Demanda de calefacción',
      'Water' => 'Agua',
      'Photovoltaic' => 'Fotovoltaica',
      'Wind' => 'Eólica',
      'During Heating' => 'Con calefacción',
      'During Cooling' => 'Con refrigeración',
      'During Occupied Heating' => 'Con calefacción y ocupación',
      'During Occupied Cooling' => 'Con refrigeración y ocupación',
      'Gross Window-Wall Ratio' => 'Porcentaje bruto de huecos en fachada',
      'Weather File' => 'Archivo de clima',
      'Latitude' => 'Latitud',
      'Longitude' => 'Longitud',
      'Elevation' => 'Altitud',
      'Time Zone' => 'Zona horaria',
      'North Axis Angle' => 'Ángulo respecto al norte',
      'Area' => 'Área',
      'Conditioned (Y/N)' => 'Acondicionada (S/N)',
      'Part of Total Floor Area (Y/N)' => 'Parte del área total (S/N)',
      'Volume' => 'Volumen',
      'Multiplier' => 'Multiplicador',
      'Gross Wall Area' => 'Superficie bruta de muro',
      'Window Glass Area' => 'Superficie acristalada',
      'Lighting' => 'Iluminación',
      'People' => 'Ocupación',
      'Plug and Process' => 'Carga enchufada y de procesos',
      'Total Energy' => 'Energía total',
      'Energy Per Total Building Area' => 'Energía / sup. útil',
      'Energy Per Conditioned Building Area' => 'Energía / sup. acondicionada',
      'Total Site Energy' => 'Energía final total',
      'Net Site Energy' => 'Energía final neta',
      'Total Source Energy' => 'Energía primaria total',
      'Net Source Energy' => 'Energía primaria neta',
      'Total' => 'Total',
      'Conditioned Total' => 'Total Acondicionada',
      'Unconditioned Total' => 'Total No acondicionada',
      'Not Part of Total' => 'Fuera del total',
      'Heating/Cooling' => 'Calefacción/Refrigeración',
      'Calculated Design Load' => 'Carga térmica de diseño calculada',
      'User Design Load' => 'Carga de diseño de usuario',
      'Design Load With Sizing Factor' => 'Carga térmica para dimensionado',
      'Calculated Design Air Flow' => 'Flujo de aire de diseño',
      'User Design Air Flow' => 'Flujo de aire de usuario',
      'Design Air Flow  With Sizing Factor' => 'Flujo de aire de dimensionado',
      'Date/Time Of Peak' => 'Fecha/hora pico',
      'Outdoor Temperature at Peak Load' => 'Temperatura exterior con carga pico',
      'Outdoor Humidity Ratio at Peak Load' => 'Humedad exterior con carga pico'
    }.fetch(key) { |nokey| nokey }
  end


end
