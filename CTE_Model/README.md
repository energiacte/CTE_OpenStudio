# medida CTE_Model

Medida de OpenStudio para ajustar los modelos a la normativa española.

Además implementa opciones que permiten variar parámetros de los diseños pensadas para las simulaciones de poblaciones de edificios.

## Ajuste de los modelos al CTE.

Se trata de ajustar valores y parámetros de los modelos y funcionamiento del programa de simulación para que se ajusten a la normativa española, el Código Técnico de la Edificación.

Estos ajustes son:

- Uno
- Dos

## Modificación de los parámetros de los modelos cuyo fin es la simulación del parque y otros estudios generícos.



- CTE_Model:
    - Llevar la gestión de las sombras estacionales de CTE_CambiaConstruccion
      a CTE_Model
    - temperatura_del_agua_de_red:
      Detectar el caso en el que no hay definida demanda de ACS (no hay
      circuito) y evitar el fallo en ese caso.
      Usar WaterEquipment detectando objetos por tipo (los objetos del model
      son subtipo del workspace?): model.getObjectsByTypeAndName("OS:WaterUse:Equipment:Definition".to_IddObjectType,'Water Fixture Definition').empty?
    - Añadir capas ficticias (0,5m terreno + capa ficticia) a suelos siguiendo
      esquema de UNE EN ISO 13770 en lugar de dejarlo como proceso manual.

    - Puentes térmicos de esquina (y pilares embebidos en fachada)
    - Definir envolvente por espacios en area total y no por definición estricta,
      ya que es más flexible.