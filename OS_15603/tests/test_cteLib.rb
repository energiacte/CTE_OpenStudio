#! /usr/bin/ruby
# coding: utf-8

require "#{File.dirname(__FILE__)}/../resources/ctelib.rb"

#require 'minitest/autorun'
require 'test/unit'
require 'sqlite3'


# este test está pensado para que sea paralelo a test_pyOS
# osea que no tiene nada que ver con los objetos openstudio.. model, etc,
# unicamente con las lecturas SQL


class Cte_lib_Test < Test::Unit::TestCase

    def setup
        @cur = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"
    end

    def test_variables_disponibles
        stm = @cur.prepare CTE_lib.variablesdisponiblesquery
        rs = stm.execute
        assert_equal(rs.count,47)
    end

    def test_zonasHabitables
        stm = @cur.prepare CTE_lib.zonashabitablesquery
        rs = stm.execute
        assert_equal(rs.count,1)
    end

    def test_zonasNoHabitables
        stm = @cur.prepare CTE_lib.zonasnohabitablesquery
        assert_equal(stm.execute.count,1)
    end

    def test_superficies
        stm = @cur.prepare CTE_lib.superficiesquery
        assert_equal(stm.execute.count, 8)
    end

    def test_superficiescandidatas
        stm = @cur.prepare CTE_lib.superficiescandidatasquery
        assert_equal(stm.execute.count, 6)
    end

    def test_superficiesexternas
        stm = @cur.prepare CTE_lib.superficiesexternasquery
        assert_equal(stm.execute.count, 5)
    end

    def test_superficiesinternas
        stm = @cur.prepare CTE_lib.superficiesinternasquery
        assert_equal(stm.execute.count, 1)
    end

    def test_superficiescontacto
        stm = @cur.prepare CTE_lib.superficiescontactoquery
        assert_equal(stm.execute.count, 1)
    end

    def test_murosexterires
        stm = @cur.prepare CTE_lib.murosexterioresenvolventequery
        assert_equal(stm.execute.count, 3)
    end

    def test_cubiertasexteriores
        stm = @cur.prepare CTE_lib.cubiertassexterioresenvolventequery
        assert_equal(stm.execute.count, 1)
    end

    def test_suelosterreno
        stm = @cur.prepare CTE_lib.suelosterrenoenvolventequery
        assert_equal(stm.execute.count, 1)
    end

    def test_huecos
        stm = @cur.prepare CTE_lib.huecosenvolventequery
        rs =  stm.execute
        #~ puts rs.columns
        assert_equal(rs.count, 1)
        #~ puts '\n\rhola'
        #~ rs.each do |row|
            #~ puts row['SurfaceName']
            #~ puts row.join "\s"
        #~ end
        #~ puts '\n\rhola'
    end

    #~ def test_CambioHorarioVeranoInvierno
        #~ stm = @cur.prepare CTE_lib.flowmurosexterioresquery
        #~ rs = stm.execute
    #~ end
end

@cur = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"
stm = @cur.prepare CTE_lib.huecosenvolventequery
puts stm.execute.count

    #~ ### VARIABLES DISPONIBLES

    #~ ### ZONAS HABITABLES
    #~ def test_variablesDisponibles

        #~ #zonashabitablessearch = sqlFile.execAndReturnVectorOfString("#{zonashabitablesquery}")
        #~ # no podemos hacer test de esto porque tendríamos que cargar openstudio y, aún así,
        #~ # no sé como cargar un modelo concreto.

        #~ #numerodezonas = zonashabitablessearch.get.count()
        #~ #assert_equal(numerodezonas, 47)

        #~ db = SQLite3::Database.open "cubito+garaje_eplusoutZAB.sql"

        #~ dburi = os.path.abspath(os.path.join(currpath, '../examples/cubito+garaje_eplusoutZAB.sql'))
        #~ assert len(pyos.variablesDisponibles(dburi)) == 47
