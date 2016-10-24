Aplicación del CTE DB-HE e ISO/DIS 52000-1:2015 con OpenStudio
==============================================================

Descripción y uso
-----------------

Este proyecto incluye una serie de medidas de OpenStudio que permiten la
aplicación del CTE DB-HE y la ISO 52000-1 (UNE EN 15603) con OpenStudio.

El procedimiento de trabajo es el siguiente:

- Debe tenerse instalada una versión de OpenStudio (v1.12) y de Sketchup, con
  el complemento correspondiente.
- En Sketchup se realiza la modelización de los espacios del edificio, usando
  de base una plantilla (disponible en el directorio /Templates)
- Una vez hecha la modelización de las zonas térmicas en Sketchup, es necesario
  el procedimiento se continúa en la interfaz de OpenStudio.
- Se deben incluir las siguientes medidas en OpenStudio:
    - CTE_Model en las medidas de modelo
         (ver "Model Measures" en "Whole building -> Space types")
    - CTE_Workspace en las medidas de EnergyPlus
         (ver "Workspace Measures" en "Whole building -> Space types")
    - CTE_Report en las medidas de Informe
         (ver "Report Measures" en "Reporting -> QAQC")
- En la medida CTE_Model se deben fijar los parámetros de cálculo deseados
  (caudal de diseño de ventilación, edificio nuevo/existente, eficiencia de
  los ventiladores y recuperadores, transmitancia térmica lineal de los
  puentes térmicos, etc)
- Debe asignarse el archivo de clima
- Además, deben definirse los siguientes aspectos:
  - Las soluciones constructivas
  - Las zonas que disponen de equipos de acondicionamiento (o cálculo con
    cargas ideales)
  - El nivel de ventilación, con objetos OutdoorAir, salvo en el caso de
    espacios habitables de uso residencial, que se manejan automáticamente.
  - La demanda de ACS de las zonas

Si se desea obtener un archivo de vectores energéticos (consumos y producción)
para su proceso con **epbdcalc** o **epbdpanel** puede aplicarse la medida
CTE_EPBDcalc como medida de informe.

Para información más detallada de uso consulte el *Manual de uso* en formato PDF
que se encuentra en el directorio de instalación.

Créditos y licencia
-------------------

Copyright (c) 2016   Ministerio de Fomento,
                     Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)

El código del proyecto ha sido desarrollado por Rafael Villar Burke,
Daniel Jiménez González y Marta Sorribes Gil, del
Instituto Eduardo Torroja de Ciencias de la Construcción (IETcc-CSIC)
en el ámbito del convenio de colaboración entre el CSIC y el Ministerio de
Fomento para el desarrollo de tareas relacionadas con el Código Técnico de la
Edificación y se publica bajo una licencia libre.

Se puede consultar la licencia completa en el archivo `LICENSE_ES.txt` y
`LICENSE.txt` distribuidos con el código fuente.

La herramienta se distribuye con la esperanza de que resulte útil, pero
SIN NINGUNA GARANTÍA, ni garantía MERCANTIL implícita ni la CONVENIENCIA PARA UN
PROPÓSITO PARTICULAR.

