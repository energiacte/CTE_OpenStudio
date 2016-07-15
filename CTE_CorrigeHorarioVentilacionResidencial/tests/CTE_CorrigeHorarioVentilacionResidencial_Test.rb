######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.  
#  All rights reserved.
#  
#  This library is free software you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'minitest/autorun'

class CTE_CorrigeHorarioVentilacionEnEplus_Test < MiniTest::Unit::TestCase

  def test_CorrigeHorarioVentilacionEnEplus

    # create an instance of the measure
    measure = CTE_CorrigeHorarioVentilacionEnEplus.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/cubitoygarajenhideal.idf")
    source_idf = OpenStudio::WorkSpace::load(path)
    if source_idf.empty?
      runner.registerError("Cannot load #{ path }")
      return false
    end
    idf = source_idf.get.toIdfFile()
    workspace.addObjects(idf.objects)

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.idf")
    workspace.save(output_file_path, true)

  end


end
