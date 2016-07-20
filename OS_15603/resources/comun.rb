# coding: utf-8

module Comun

  def self.msg(fichero, cadena)
    File.open(fichero+'.txt', 'a') {|file| file.write(cadena)}
  end

  def self.verificabusqueda(log, nombre,  search, query)
    if search.empty?
      msg(log, "     #{nombre}: *#{query}*\n búsqueda vacía\n")
      return false
    else
      msg(log, "     #{nombre}: correcto\n")
      return search.get
    end
  end

end
