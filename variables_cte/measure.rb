#see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on mondel objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class VariablesCTE < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Variables CTE"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #assign the user inputs to variables
    # meter_name = runner.getStringArgumentValue("meter_name",user_arguments)
    # reporting_frequency = runner.getStringArgumentValue("reporting_frequency",user_arguments)


    # meters = model.getMeters
   ## reporting initial condition of model
    # runner.registerInitialCondition("The model started with #{meters.size} meter objects.")

    ##flag to add meter
    # add_flag = true

    ## OpenStudio doesn't seemt to like two meters of the same name, even if they have different reporting frequencies.
    # meters.each do |meter|
      # if meter.name == meter_name
      # runner.registerWarning("A meter named #{meter_name} already exists. One will not be added to the model.")
      # if not meter.reportingFrequency == reporting_frequency
        # meter.setReportingFrequency(reporting_frequency)
        # runner.registerInfo("Changing reporting frequency of existing meter to #{reporting_frequency}.")
      # end
      # add_flag = false
      # end
    # end

    # if add_flag
      # meter = OpenStudio::Model::Meter.new(model)
      # meter.setName(meter_name)
      # meter.setReportingFrequency(reporting_frequency)
      # runner.registerInfo("Adding meter for #{meter.name} reporting #{reporting_frequency}")
    # end
    
    meter = OpenStudio::Model::Meter.new(model)
    meter.setName("DistrictHeating:Facility")
    meter.setReportingFrequency("RunPeriod")
    runner.registerInfo("Adding meter for DistrictHeating:Facility reporting RunPeriod")
    
    # esto se comenta para reducir el tiempo de escritura en disco
    # meter = OpenStudio::Model::Meter.new(model)
    # meter.setName("DistrictHeating:Facility")
    # meter.setReportingFrequency("hourly")
    # runner.registerInfo("Adding meter for DistrictHeating:Facility reporting hourly")
    
    meter = OpenStudio::Model::Meter.new(model)
    meter.setName("DistrictCooling:Facility")
    meter.setReportingFrequency("RunPeriod")
    runner.registerInfo("Adding meter for DistrictHeating:Facility reporting RunPeriod")
    
    # esto se comenta para reducir el tiempo de escritura en disco
    # meter = OpenStudio::Model::Meter.new(model)
    # meter.setName("DistrictCooling:Facility")
    # meter.setReportingFrequency("hourly")
    # runner.registerInfo("Adding meter for DistrictHeating:Facility reporting hourly")
    
    #meters = model.getMeters
    #reporting final condition of model
    #runner.registerFinalCondition("The model finished with #{meters.size} meter objects.")
    
    
        # "Zone Mechanical Ventilation No Load Heat Addition Energy",
        # "Zone Mechanical Ventilation No Load Heat Removal Energy",
        # "System Node Standard Density Volume Flow Rate",
    
    variables_mensuales = [
        "Surface Inside Face Conduction Heat Transfer Energy",
        "Surface Window Heat Gain Energy",
        "Surface Window Heat Loss Energy",
        "Surface Window Transmitted Solar Radiation Energy",
        "Surface Window Transmitted Solar Radiation Energy",
        "Zone Total Internal Total Heating Energy",
        "Zone Ideal Loads Zone Total Heating Energy",
        "Zone Ideal Loads Zone Total Cooling Energy",
        "Zone Infiltration Total Heat Gain Energy",
        "Zone Infiltration Total Heat Loss Energy",
        "Zone Mechanical Ventilation Current Density Volume",
        "Zone Ventilation Total Heat Gain Energy",
        "Zone Ventilation Total Heat Loss Energy",
        "Zone Infiltration Standard Density Volume Flow Rate",
        "Zone Infiltration Current Density Volume",
        "Zone Ventilation Standard Density Volume Flow Rate",
        "Zone Ideal Loads Outdoor Air Standard Density Volume Flow Rate",
        "Zone Ideal Loads Supply Air Standard Density Volume Flow Rate",         
        "Site Outdoor Air Drybulb Temperature"
    ]
     
    variables_horarias = [
    "Surface Inside Face Conduction Heat Transfer Energy",
    "Surface Inside Face Conduction Heat Transfer Energy",
    "Surface Inside Face Conduction Heat Transfer Energy",
    "Surface Window Heat Gain Energy",
    "Surface Window Heat Loss Energy",
    "Surface Window Transmitted Solar Radiation Energy",
    "Zone Thermostat Cooling Setpoint Temperature",
    "Zone Thermostat Heating Setpoint Temperature",
    "Zone Total Internal Total Heating Energy",
    "Zone Infiltration Total Heat Gain Energy",
    "Zone Infiltration Total Heat Loss Energy",
    "Zone Ventilation Total Heat Gain Energy",
    "Zone Ventilation Total Heat Loss Energy",
    "Zone Infiltration Current Density Volume",
    "Zone Mechanical Ventilation Current Density Volume",
    "Zone Combined Outdoor Air Total Heat Loss Energy",
    "Zone Combined Outdoor Air Total Heat Gain Energy",
    "Zone Combined Outdoor Air Changes per Hour"
    ]
    
    variables_horarias.each do | variable_name |
        # reporting_frequency = "monthly"
        reporting_frequency = "hourly"
        outputVariable = OpenStudio::Model::OutputVariable.new(variable_name, model)
        outputVariable.setReportingFrequency(reporting_frequency)
        outputVariable.setKeyValue("*")
    end 
    
    variables_mensuales.each do | variable_name |
        reporting_frequency = "monthly"
        #reporting_frequency = "hourly"
        outputVariable = OpenStudio::Model::OutputVariable.new(variable_name, model)
        outputVariable.setReportingFrequency(reporting_frequency)
        outputVariable.setKeyValue("*")
    end 
    
    
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
VariablesCTE.new.registerWithApplication