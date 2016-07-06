
require "#{File.dirname(__FILE__)}/os_lib_reporting_SI"
require "#{File.dirname(__FILE__)}/ctegeometria" # que importa el modulo CTEgeo

module CTE_lib

  #======== Elementos generales  ============
  def self.variablesdisponiblesquery
    variablesdisponiblesquery = "
SELECT 
    DISTINCT VariableName, ReportingFrequency 
FROM 
    ReportVariableDataDictionary "
    return variablesdisponiblesquery
  end
 
  
  #======== Tabla general de mediciones =====
  def self.CTE_tabla_general_de_mediciones(model, sqlFile, runner)
    log = 'logpropio.txt'
    medicion_general = {}
    medicion_general[:title] = 'Mediciones Generales CTE'
    medicion_general[:header] = %w(informacion valor unidades)
    medicion_general[:units] = [] #vacio porque son distintas
    medicion_general[:data] = []

    # structure ID / building name
    value = model.getBuilding.name.to_s       
    medicion_general[:data] << ['Nombre del edificio', value, ''] #medicion_general[:data] << [display, value, target_units]
    runner.registerValue('Nombre del edificio', value, '')

    # ZONAS HABITABLES, numero
    medicion_general[:data] << ["<u>Zonas habitables</u>", '', '']    
    numerodezonashabitables = CTEgeo.zonashabitables(sqlFile).count()
    display = 'Número de zonas habitables'
    source_units = ''
    medicion_general[:data] << [display, numerodezonashabitables.to_s, source_units]
    runner.registerValue(display, numerodezonashabitables, source_units)

    #  ZONAS HABITABLES, SUPERFICIE HABITABLE
    superficiehabitable = CTEgeo.superficiehabitable(sqlFile)
    msg(log, "superficie habitable = #{superficiehabitable}\n")
    display = 'Superficie habitable'
    superficiehabitable_neat = OpenStudio.toNeatString(superficiehabitable, 0, true)
    unidades = 'm^2'
    medicion_general[:data] << [display, superficiehabitable_neat, unidades]
    runner.registerValue(display, superficiehabitable, unidades)
   
    # ZONAS HABITABLES, VOLUMEN HABITABLE    
    volumenhabitable = CTEgeo.volumenhabitable(sqlFile)
    display = 'Volumen habitable'
    value = volumenhabitable.round
    medicion_general[:data] << [display, value.to_s, 'm3']
    runner.registerValue(display, value, 'm3')

    #  ZONAS NO HABITABLES, numero
    medicion_general[:data] << ["<u>Zonas no habitables</u>", '', '']    
    zonasnohabitables = CTEgeo.zonasnohabitables(sqlFile).count()
    display = 'Número de zonas no habitables'
    medicion_general[:data] << [display, zonasnohabitables.to_s, '']
    runner.registerValue(display, zonasnohabitables, '')

    # ZONAS NO HABITABLES, SUPERFICIES NO HABITABLES
    superficienohabitable = CTEgeo.superficienohabitable(sqlFile)
    msg(log, "Superficie no habitable = #{superficienohabitable}")    
    display = "Superficie zonas no habitables"
    superficienohabitable_neat = OpenStudio.toNeatString(superficienohabitable, 0, true)
    medicion_general[:data] << [display, superficienohabitable_neat, 'm^2']
    runner.registerValue(display, superficienohabitable.to_s, 'm^2')
	

    # ZONAS NO HABITABLES, VOLUMEN NO HABITABLE
    volumennohabitable = CTEgeo.volumennohabitable(sqlFile)
    msg(log, "Volumen de zonas no habitables = #{volumennohabitable}")
    display = "Volumen de zonas no habitables"
    units = 'm^3'
    volumennohabitable_neat = OpenStudio.toNeatString(volumennohabitable, 0, true)
    medicion_general[:data] << [display, volumennohabitable_neat, units]
    runner.registerValue(display, volumennohabitable.to_s, units)

    # ENVOLVENTE, SUPERFICIES CANDIDATAS a ser envolvente térmica
    medicion_general[:data] << ["<u>Envolvente térmica</u>", '', '']   
    superficiescandidatas = CTEgeo.superficiescandidatas(sqlFile)
    source_units = ''
    value = superficiescandidatas.count()
    medicion_general[:data] << [display, value.to_s, source_units]
    runner.registerValue(display, value, source_units)
    
    # ENVOLVENTE, SUPERFICIES EXTERNAS
    superficiesexternas = CTEgeo.superficiesexternas(sqlFile)
    display = 'Número de superficies externas de zonas habitables'
    source_units = ''
    value = superficiesexternas.count()
    medicion_general[:data] << [display, value.to_s, source_units]
    runner.registerValue(display, value, source_units)
    
    # ENVOLVENTE, AREA EXTERIOR
    areaexterior = CTEgeo.areaexterior(sqlFile)
    display = 'Área de la envolvente térmica que es exterior'
    source_units = 'm^2'
    areaexterior_neat = OpenStudio.toNeatString(areaexterior, 0, true)
    medicion_general[:data] << [display, areaexterior_neat, source_units]
    runner.registerValue(display, areaexterior, source_units)

    # ENVOLVENTE, SUPERFICIES INTERNAS    
    superficiesinternas = CTEgeo.superficiesinternas(sqlFile)
    value = superficiesinternas.count()
    display = 'Número de particiones interiores de las zonas habitables'
    source_units = ''
    medicion_general[:data] << [display, value.to_s, source_units]
    runner.registerValue(display, value, source_units)

    # ENVOLVENTE, SUPERFICIES DE CONTACTO
    superficiescontacto = CTEgeo.superficiescontacto(sqlFile)
    superficiescontacto = superficiescontacto.count()
    display = 'Número de particiones interiores que pertenecen a la envolvente térmica'
    source_units = ''
    medicion_general[:data] << [display, superficiescontacto.to_s, source_units]
    runner.registerValue(display, superficiescontacto, source_units)
    
    # ENVOLVENTE, AREA INTERIOR
    areainterior = CTEgeo.areainterior(sqlFile)
    display = 'Área de la envolvente térmica que es interior'
    source_units = 'm^2'
    areainterior_neat = OpenStudio.toNeatString(areainterior, 0, true)
    medicion_general[:data] << [display, areainterior_neat, source_units]
    runner.registerValue(display, areainterior, source_units)

    areatotal = areaexterior + areainterior
    display = '<b>Área total de la envolvente térmica</b>'
    source_units = 'm^2'
    areatotal_neat = OpenStudio.toNeatString(areatotal, 0, true)
    medicion_general[:data] << [display, areatotal_neat, source_units]
    runner.registerValue(display, areatotal, source_units)

    compacidad = volumenhabitable / areatotal
    display = '<b>Compacidad</b>'
    source_units = ''
    compacidad_neat = OpenStudio.toNeatString(compacidad, 2, true)
    medicion_general[:data] << [display, compacidad_neat, source_units]
    runner.registerValue(display, compacidad, source_units)

    return medicion_general
  end

  def self.flowMurosExteriores(sqlFile)
    log = 'log_demandaComponentes'
    msg(log, "  ..flowMurosExteriores\n")
    flowMurosExterioresQuery = "SELECT * FROM "
    flowMurosExterioresQuery << "(#{superficiesquery}) AS surf "
    flowMurosExterioresQuery << "INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex) "
    flowMurosExterioresQuery << "INNER JOIN Time time USING (TimeIndex) "
    flowMurosExterioresQuery << "WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy' "
    flowMurosExterioresQuery << "AND surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0 "
    #para depuracion --> Optional not initialized (RuntimeError)
    msg(log, "flowMurosExterioresQuery\n")
    msg(log, "#{flowMurosExterioresQuery}")

    flowMurosExterioresInviernoQuery = "SELECT SUM(VariableValue) FROM (#{flowMurosExterioresQuery}) "
    flowMurosExterioresInviernoQuery << "WHERE month IN (1,2,3,4,5,10,11,12)"
    flowMurosExterioresInviernoSearch = sqlFile.execAndReturnFirstDouble(flowMurosExterioresInviernoQuery)
    energianetaInvierno = OpenStudio.convert(flowMurosExterioresInviernoSearch.get, 'J', 'kWh').get
    energianetaInvierno_neat = OpenStudio.toNeatString(energianetaInvierno, 0, true)
    msg(log, "Energia neta muros invierno: #{energianetaInvierno.round}\n")

    flowMurosExterioresVeranoQuery = "SELECT SUM(variableValue) FROM (#{flowMurosExterioresQuery}) "
    flowMurosExterioresVeranoQuery << "WHERE month IN (6,7,8,9)"
    flowMurosExterioresVeranoSearch = sqlFile.execAndReturnFirstDouble(flowMurosExterioresVeranoQuery)
    energianetaVerano = OpenStudio.convert(flowMurosExterioresVeranoSearch.get, 'J', 'kWh').get
    msg(log, "Energia neta muros verano #{energianetaVerano.round}\n")
    msg(log, "\n")
    return [energianetaInvierno, energianetaVerano]
  end

  def self.flowCubiertas(sqlFile)
    log = 'log_demandaComponentes'
    msg(log, "  ..flowCubiertas\n")
    flowCubiertasQuery = "SELECT * FROM "
    flowCubiertasQuery << "(#{superficiesquery}) AS surf "
    flowCubiertasQuery << "INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex) "
    flowCubiertasQuery << "INNER JOIN Time time USING (TimeIndex) "
    flowCubiertasQuery << "WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy' "
    flowCubiertasQuery << "AND surf.ClassName == 'Roof' AND surf.ExtBoundCond == 0 "

    flowCubiertasInviernoQuery = "SELECT SUM(VariableValue) FROM (#{flowCubiertasQuery}) "
    flowCubiertasInviernoQuery << "WHERE month IN (1,2,3,4,5,10,11,12)"
    flowCubiertasInviernoSearch = sqlFile.execAndReturnFirstDouble(flowCubiertasInviernoQuery)
    energianetaInvierno = OpenStudio.convert(flowCubiertasInviernoSearch.get, 'J', 'kWh').get
    energianetaInvierno_neat = OpenStudio.toNeatString(energianetaInvierno, 0, true)
    msg(log, "Energia neta cubiertas invierno: #{energianetaInvierno.round}\n")

    flowCubiertasVeranoQuery = "SELECT SUM(variableValue) FROM (#{flowCubiertasQuery}) "
    flowCubiertasVeranoQuery << "WHERE month IN (6,7,8,9)"
    flowCubiertasVeranoSearch = sqlFile.execAndReturnFirstDouble(flowCubiertasVeranoQuery)
    energianetaVerano = OpenStudio.convert(flowCubiertasVeranoSearch.get, 'J', 'kWh').get
    msg(log, "Energia neta cubiertas verano #{energianetaVerano.round}\n")
    msg(log, "\n")
    return [energianetaInvierno, energianetaVerano]
  end

def self.flowSuelosTerreno(sqlFile)
    log = 'log_demandaComponentes'
    msg(log, "  ..flowSuelosTerreno\n")
    flowSuelosTerrenoQuery = "SELECT * FROM "
    flowSuelosTerrenoQuery << "(#{superficiesquery}) AS surf "
    flowSuelosTerrenoQuery << "INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex) "
    flowSuelosTerrenoQuery << "INNER JOIN Time time USING (TimeIndex) "
    flowSuelosTerrenoQuery << "WHERE surf.VariableName == 'Surface Inside Face Conduction Heat Transfer Energy' "
    flowSuelosTerrenoQuery << "AND surf.ClassName == 'Floor' AND surf.ExtBoundCond == -1 "

    flowSuelosTerrenoInviernoQuery = "SELECT SUM(VariableValue) FROM (#{flowSuelosTerrenoQuery}) "
    flowSuelosTerrenoInviernoQuery << "WHERE month IN (1,2,3,4,5,10,11,12)"
    flowSuelosTerrenoInviernoSearch = sqlFile.execAndReturnFirstDouble(flowSuelosTerrenoInviernoQuery)
    energianetaInvierno = OpenStudio.convert(flowSuelosTerrenoInviernoSearch.get, 'J', 'kWh').get
    energianetaInvierno_neat = OpenStudio.toNeatString(energianetaInvierno, 0, true)
    msg(log, "Energia neta suelos invierno: #{energianetaInvierno.round}\n")

    flowSuelosTerrenoVeranoQuery = "SELECT SUM(variableValue) FROM (#{flowSuelosTerrenoQuery}) "
    flowSuelosTerrenoVeranoQuery << "WHERE month IN (6,7,8,9)"
    flowSuelosTerrenoVeranoSearch = sqlFile.execAndReturnFirstDouble(flowSuelosTerrenoVeranoQuery)
    energianetaVerano = OpenStudio.convert(flowSuelosTerrenoVeranoSearch.get, 'J', 'kWh').get
    msg(log, "Energia neta suelos verano #{energianetaVerano.round}\n")
    msg(log, "\n")
    return [energianetaInvierno, energianetaVerano]
  end

  def self.flowVentanas(sqlFile)
    log = 'log_demandaComponentes'
    msg(log, "  ..flowVentanas\n")
    variable =   {  'heat gain' => 'Surface Window Heat Gain Energy',
                'heat loss' => 'Surface Window Heat Loss Energy',
                'transmitted solar' => 'Surface Window Transmitted Solar Radiation Energy'}

    flowVentanasInvierno = lambda do | var | "SELECT SUM(variableValue) FROM
    (#{superficiesquery}) AS surf
    INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time time USING (TimeIndex)
    WHERE surf.VariableName == '#{variable[var]}'
    AND surf.ClassName == 'Window'
    AND month IN (1,2,3,4,5,10,11,12)"
    end

    flowVentanasVerano = lambda do | var | "SELECT SUM(variableValue) FROM
    (#{superficiesquery}) AS surf
    INNER JOIN ReportVariableData rvd  USING (ReportVariableDataDictionaryIndex)
    INNER JOIN Time time USING (TimeIndex)
    WHERE surf.VariableName == '#{variable[var]}'
    AND surf.ClassName == 'Window'
    AND month IN (6,7,8,9)"
    end


    heatGainInviernoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasInvierno.call('heat gain'))
    heatGainInvierno = OpenStudio.convert(heatGainInviernoSearch.get, 'J', 'kWh').get

    heatGainVeranoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasVerano.call('heat gain'))
    heatGainVerano = OpenStudio.convert(heatGainVeranoSearch.get, 'J', 'kWh').get

    heatLossInviernoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasInvierno.call('heat loss'))
    heatLossInvierno = OpenStudio.convert(heatLossInviernoSearch.get, 'J', 'kWh').get

    heatLossVeranoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasVerano.call('heat loss'))
    heatLossVerano = OpenStudio.convert(heatLossVeranoSearch.get, 'J', 'kWh').get

    transmittedInviernoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasInvierno.call('transmitted solar'))
    transmittedInvierno = OpenStudio.convert(transmittedInviernoSearch.get, 'J', 'kWh').get

    transmittedVeranoSearch = sqlFile.execAndReturnFirstDouble(flowVentanasVerano.call('transmitted solar'))
    transmittedVerano = OpenStudio.convert(transmittedVeranoSearch.get, 'J', 'kWh').get


    return {'HGi' => heatGainInvierno, 'HGv' => heatGainVerano,
            'HLi' => heatLossInvierno, 'HLv' => heatLossVerano,
            'TSi' => transmittedInvierno, 'TSv' => transmittedVerano,}
    #return 14

  end

  def self.timeindexquery
    timeindexquery =  "SELECT TimeIndex, Month, Day, Hour FROM ReportVariableDataDictionary "
    timeindexquery << "INNER JOIN  ReportVariableData USING (ReportVariableDataDictionaryIndex) "
    timeindexquery << "INNER JOIN Time USING (TimeIndex) "
    timeindexquery << "WHERE (VariableName = 'Zone Thermostat Cooling Setpoint Temperature' OR VariableName = 'Zone Thermostat Heating Setpoint Temperature') "
    timeindexquery << "AND ReportingFrequency == 'Hourly' "
    timeindexquery << "AND VariableValue < 95 "
    timeindexquery << "AND VariableValue > -45 "
    timeindexquery
  end



  def self.valoresZonas(sqlFile, variable, log)
    msg(log, "\n.. variable: '#{variable}'\n")
    respuesta = "SELECT SUM(VariableValue) FROM "#, ZoneName, VariableName, month, variablevalue, variableUnits, reportingfrequency FROM
    respuesta << "(#{CTEgeo.zonashabitablesquery})
    INNER JOIN ReportVariableDataDictionary rvdd
    INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
    INNER JOIN (#{timeindexquery}) USING (TimeIndex)
    WHERE rvdd.variableName == '#{variable}' "

    queryInvierno = respuesta + "AND month IN (1,2,3,4,5,10,11,12)"
    queryVerano = respuesta + "AND month IN (6,7,8,9)"

    # searchInvierno = sqlFile.execAndReturnVectorOfString(queryInvierno) #execAndReturnFirstDouble(query)
    # searchVerano = sqlFile.execAndReturnVectorOfString(queryVerano) #execAndReturnFirstDouble(query)
    searchInvierno = sqlFile.execAndReturnFirstDouble(queryInvierno)
    searchVerano = sqlFile.execAndReturnFirstDouble(queryVerano)

    #msg(log, "search: *#{search}*\n")

    if searchInvierno.empty?
      msg(log, "     searchInvierno: *#{queryInvierno}*\n búsqueda vacía\n")
    else
      msg(log, "     searchInvierno: correcto\n")
    end

    if searchVerano.empty?
      msg(log, "     searchVerano: *#{queryVerano}*\n búsqueda vacía\n")
    else
      msg(log, "     searchVerano:    correcto\n")
    end

    salida = {'valInv' => OpenStudio.convert(searchInvierno.get, 'J', 'kWh').get,
              'valVer' => OpenStudio.convert(searchVerano.get,   'J', 'kWh').get   }
    msg(log, "     salida #{salida}\n")
    return [salida['valInv'], salida['valVer']]
  end

  def self.demanda_por_componentes_invierno(model, sqlFile, runner)
    return demanda_por_componentes(model, sqlFile, runner, 'invierno')
  end

  def self.demanda_por_componentes_verano(model, sqlFile, runner)
    return demanda_por_componentes(model, sqlFile, runner, 'verano')
  end
  
  def self.mediciones_murosexeriores(model, sqlFile, runner)
    log = 'log_mediciones exteriores'
    
    contenedor_general = {}
    contenedor_general[:title] = "mediciones muros exteriores"
    contenedor_general[:header] = ['construccion', 'GrossArea', 'U']
    contenedor_general[:units] = [] 
    contenedor_general[:data] = []
    
    indicesconstruccionquery = "SELECT DISTINCT ConstructionIndex FROM (#{CTEgeo.murosexterioresenvolventequery})"
       
    msg(log, "query indices de construcción: #{indicesconstruccionquery}")
    indicesconstruccionsearch  = sqlFile.execAndReturnVectorOfString(indicesconstruccionquery).get
    indicesconstruccionsearch.each do | indiceconstruccion |
      query = "SELECT SUM(GrossArea) FROM (#{CTEgeo.murosexterioresenvolventequery}) WHERE ConstructionIndex == #{indiceconstruccion} "
      area = sqlFile.execAndReturnFirstDouble(query).get
      msg(log, "\narea:\n#{area}\n")
      nombrequery = "SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      nombre = sqlFile.execAndReturnFirstString(nombrequery)
      msg(log, "\nnombre:\n#{nombre}\n")
      uvaluequery = "SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      uvalue = sqlFile.execAndReturnFirstString(uvaluequery)
      contenedor_general[:data] << [nombre, area, uvalue]
    end

    msg(log, "indices de construcción: #{indicesconstruccionsearch}") 
    return contenedor_general
  end
  
  def self.mediciones_cubiertas(model, sqlFile, runner)
    log = 'log_mediciones exteriores'
    
    contenedor_general = {}
    contenedor_general[:title] = "mediciones cubiertas exteriores"
    contenedor_general[:header] = ['construccion', 'GrossArea', 'U']
    contenedor_general[:units] = [] 
    contenedor_general[:data] = []
    
    indicesconstruccionquery = "SELECT DISTINCT ConstructionIndex FROM (#{CTEgeo.cubiertassexterioresenvolventequery})"
       
    msg(log, "query indices de construcción cubiertas: #{indicesconstruccionquery}")
    indicesconstruccionsearch  = sqlFile.execAndReturnVectorOfString(indicesconstruccionquery).get
    indicesconstruccionsearch.each do | indiceconstruccion |
      query = "SELECT SUM(GrossArea) FROM (#{CTEgeo.cubiertassexterioresenvolventequery}) WHERE ConstructionIndex == #{indiceconstruccion} "
      area = sqlFile.execAndReturnFirstDouble(query).get
      msg(log, "\narea:\n#{area}\n")
      nombrequery = "SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      nombre = sqlFile.execAndReturnFirstString(nombrequery)
      msg(log, "\nnombre:\n#{nombre}\n")
      uvaluequery = "SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      uvalue = sqlFile.execAndReturnFirstString(uvaluequery)
      contenedor_general[:data] << [nombre, area, uvalue]
    end

    msg(log, "indices de construcción: #{indicesconstruccionsearch}")
    return contenedor_general
  end
  
  def self.mediciones_suelosterreno(model, sqlFile, runner)
    log = 'log_mediciones exteriores'
    
    contenedor_general = {}
    contenedor_general[:title] = "mediciones suelos terreno"
    contenedor_general[:header] = ['construccion', 'GrossArea', 'U']
    contenedor_general[:units] = [] 
    contenedor_general[:data] = []
    
    indicesconstruccionquery = "SELECT DISTINCT ConstructionIndex FROM (#{CTEgeo.suelosterrenoenvolventequery})"
       
    msg(log, "query indices de construcción cubiertas: #{indicesconstruccionquery}")
    indicesconstruccionsearch  = sqlFile.execAndReturnVectorOfString(indicesconstruccionquery).get
    indicesconstruccionsearch.each do | indiceconstruccion |
      query = "SELECT SUM(GrossArea) FROM (#{CTEgeo.suelosterrenoenvolventequery}) WHERE ConstructionIndex == #{indiceconstruccion} "
      area = sqlFile.execAndReturnFirstDouble(query).get
      msg(log, "\narea:\n#{area}\n")
      nombrequery = "SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      nombre = sqlFile.execAndReturnFirstString(nombrequery)
      msg(log, "\nnombre:\n#{nombre}\n")
      uvaluequery = "SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      uvalue = sqlFile.execAndReturnFirstString(uvaluequery)
      contenedor_general[:data] << [nombre, area, uvalue]
    end

    msg(log, "indices de construcción: #{indicesconstruccionsearch}")
    
    return contenedor_general
  end

  def self.mediciones_huecos(model, sqlFile, runner)
    log = 'log_mediciones exteriores'
    
    contenedor_general = {}
    contenedor_general[:title] = "mediciones huecos"
    contenedor_general[:header] = ['construccion', 'GrossArea', 'U']
    contenedor_general[:units] = [] 
    contenedor_general[:data] = []
    
    indicesconstruccionquery = "SELECT DISTINCT ConstructionIndex FROM (#{CTEgeo.huecosenvolventequery})"
       
    msg(log, "query indices de construcción cubiertas: #{indicesconstruccionquery}")
    indicesconstruccionsearch  = sqlFile.execAndReturnVectorOfString(indicesconstruccionquery).get
    indicesconstruccionsearch.each do | indiceconstruccion |
      query = "SELECT SUM(GrossArea) FROM (#{CTEgeo.huecosenvolventequery}) WHERE ConstructionIndex == #{indiceconstruccion} "
      area = sqlFile.execAndReturnFirstDouble(query).get
      msg(log, "\narea:\n#{area}\n")
      nombrequery = "SELECT Name FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      nombre = sqlFile.execAndReturnFirstString(nombrequery)
      msg(log, "\nnombre:\n#{nombre}\n")
      uvaluequery = "SELECT Uvalue FROM Constructions WHERE ConstructionIndex == #{indiceconstruccion} "
      uvalue = sqlFile.execAndReturnFirstString(uvaluequery)
      contenedor_general[:data] << [nombre, area, uvalue]
    end

    msg(log, "indices de construcción: #{indicesconstruccionsearch}")
    
    return contenedor_general
  end
  
  
  def self.demanda_por_componentes(model, sqlFile, runner, periodo)
    log = 'log_demandaComponentes'
    msg(log, "__ inicidada demanda por componentes__#{periodo}\n")
    
    superficiehabitable =  CTEgeo.superficieHabitable(sqlFile)
    
    
    
    suphab = OpenStudio.toNeatString(superficiehabitable, 0, true).to_f


    otrasearch = sqlFile.execAndReturnVectorOfString("#{CTEgeo.zonashabitablesquery}")
    if otrasearch.empty?
      msg(log, "     otrasearch: \n*#{otrasearch}*\nbúsqueda vacía\n")
    else
      msg(log, "     otrasearch: correcto\n")
    end

    
    msg(log, ".. resultado de superficie habitable:\n#{superficiehabitable}\n")
    
    orden_eje_x = []
    end_use_colors = ['#EF1C21', '#0071BD', '#F7DF10', '#DEC310', '#4A4D4A', '#B5B2B5', '#FF79AD',
    '#632C94', '#F75921', '#293094', '#CE5921', '#FFB239', '#29AAE7', '#8CC739']

    medicion_general = {}
    medicion_general[:title] = "Demandas por componentes en #{periodo}"
    medicion_general[:header] = ['', 'Paredes E', 'Cubiertas', 'SuelosT', 'PuentesT','SolarVen', 'TransVen', 'FuentesI', 'Infiltr', 'Ventil', 'Total']

    medicion_general[:units] = [] #vacio porque son distintas
    medicion_general[:data] = []
    medicion_general[:chart_type] = 'vertical_stacked_bar'
    medicion_general[:chart_attributes] = { value: medicion_general[:title], label_x: 'Componente', sort_yaxis: [], sort_xaxis: orden_eje_x }
    medicion_general[:chart] = []

    valores_fila = [periodo] #la fila de la tabla en cuestión
    valores_data = []
    indice = {'invierno' => 0, 'verano' => 1}
    temporada = {'invierno' => {'ppal' => 'calefaccion',   'segun' => 'calef_par'},
                 'verano'   => {'ppal' => 'refrigeracion', 'segun' => 'refri_par'} }
    colores = {'invierno' => {'ppal' => '#EF1C21', 'segun' => '#F78D90'},
               'verano'   => {'ppal' => '#008FF0','segun' => '#7FC7F7'} }

    registraValores = lambda do | data, label, tipo, signo |
      medicion_general[:chart] << JSON.generate(label:temporada[periodo][tipo],
      label_x: label, value: signo * data[indice[periodo]]/suphab, color: colores[periodo][tipo])
      if tipo == 'ppal'
        valores_fila << (data[indice[periodo]]/suphab).round
        valores_data << data[indice[periodo]]/suphab
      end
      orden_eje_x << label
      msg(log, "#{signo * data[indice[periodo]]/suphab}\n")
    end

    # paredes exteriores
    registraValores.call(flowMurosExteriores(sqlFile), 'Paredes Exteriores', 'ppal', 1)
        # cubiertas
    registraValores.call(flowCubiertas(sqlFile), 'Cubiertas', 'ppal', 1)
    # suelos terreno
    registraValores.call(flowSuelosTerreno(sqlFile), 'SuelosT', 'ppal', 1)
    # puentes termicos
    valores_fila << 'sin calcular'
    #solar y transmisión ventanas
    energiaVentanas = flowVentanas(sqlFile)
    msg(log, "#{energiaVentanas}\n")
    # label = ['wHeGa', 'wHeLo', 'wSoVe', 'wTrVe']
    registraValores.call([energiaVentanas['TSi'], energiaVentanas['TSv']], 'Solar Ventanas', 'ppal', 1)

    transmisionVentanasInvierno = energiaVentanas['HGi'] - energiaVentanas['HLi'] -energiaVentanas['TSi']
    transmisionVentanaVerano = energiaVentanas['HGv'] - energiaVentanas['HLv'] -energiaVentanas['TSv']
    registraValores.call([transmisionVentanasInvierno, transmisionVentanaVerano], 'Transmision Ventanas', 'ppal', 1)

   # suelos terreno
    registraValores.call(valoresZonas(sqlFile, "Zone Total Internal Total Heating Energy", log), 'Fuentes Internas', 'ppal', 1)

    # infiltracion
    heatGain = valoresZonas(sqlFile, "Zone Infiltration Total Heat Gain Energy", log)
    heatLoss = valoresZonas(sqlFile, "Zone Infiltration Total Heat Loss Energy", log)
    # registraValores.call(heatGain, 'InfGain', 'segun', 1)
    # registraValores.call(heatLoss, 'InfLoss', 'segun', -1)
    registraValores.call([heatGain[0] - heatLoss[0], heatGain[1] - heatLoss[1]], 'Infiltación', 'ppal', 1)

    # ventilacion
        
    # ventGain = valoresZonas(sqlFile, "Zone Ventilation Total Heat Gain Energy", log)
    # ventLoss = valoresZonas(sqlFile, "Zone Ventilation Total Heat Loss Energy", log)
    
    ventGain = valoresZonas(sqlFile, "Zone Combined Outdoor Air Total Heat Gain Energy", log)
    ventLoss = valoresZonas(sqlFile, "Zone Combined Outdoor Air Total Heat Loss Energy", log)
    # registraValores.call(ventGain, 'VenGain', 'segun', 1)
    # registraValores.call(ventLoss, 'VenLoss', 'segun', -1)
    registraValores.call([ventGain[0]-ventLoss[0], ventGain[1]-ventLoss[1]], 'Ventilación', 'ppal', 1)

    #total
    total = 0
    valores_data.each do | valor |
      if valor.to_f == valor
        total += valor
      end
    end
    total = total*suphab

    registraValores.call([total, total], 'Total', 'ppal', 1)

    medicion_general[:data] << valores_fila
    return medicion_general

  end
  def self.msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end
end

# Búqueda de ejemplo
# SELECT * FROM
# (SELECT zones.ZoneIndex, zones.ZoneName  FROM Zones zones
# LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex)
# LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex)
# WHERE zl.Name != 'CTE_NOHABITA' AND zl.Name != 'CTE_N' )
# INNER JOIN ReportVariableDataDictionary
# INNER JOIN ReportVariableData USING (ReportVariableDataDictionaryIndex)
# INNER JOIN
  # (SELECT TimeIndex, Month, Day, Hour FROM ReportVariableDataDictionary rvdd
  # INNER JOIN  ReportVariableData USING (ReportVariableDataDictionaryIndex)
  # INNER JOIN Time time USING (TimeIndex)
  # WHERE VariableName = 'Zone Thermostat Cooling Setpoint Temperature'
  # AND ReportingFrequency == 'Hourly' AND Month = 8 AND Day = 15 AND VariableValue < 95 AND VariableValue > -45 ) USING (TimeIndex)
# WHERE variableName == 'Zone Total Internal Total Heating Energy'

# query indices de construcción: 
# SELECT DISTINCT ConstructionIndex 
# FROM 
	# (SELECT * 
  # FROM 
    # (SELECT * 
    # FROM 
      # (SELECT * 
      # FROM Surfaces surf 
      # INNER JOIN ( SELECT *  
        # FROM Zones zones 
        # LEFT OUTER JOIN ZoneInfoZoneLists zizl USING (ZoneIndex) 
        # LEFT OUTER JOIN ZoneLists zl USING (ZoneListIndex) 
        # WHERE zl.Name != 'CTE_NOHABITA' AND zl.Name != 'CTE_N'  ) AS zones 
        # ON surf.ZoneIndex = zones.ZoneIndex
        # WHERE surf.ClassName <> 'Window' AND surf.ClassName <> 'Internal Mass' ) 
      # WHERE ExtBoundCond = -1 OR ExtBoundCond = 0 ) AS surf 
    # WHERE surf.ClassName == 'Wall' AND surf.ExtBoundCond == 0 )
