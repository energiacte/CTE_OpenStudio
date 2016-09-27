Aplicación del CTE DB-HE e ISO/DIS 52000-1:2015 con OpenStudio
==============================================================

Descripción y uso
-----------------

Este proyecto incluye una serie de medidas de OpenStudio que permiten la aplicación del CTE DB-HE y la ISO 52000-1 (UNE EN 15603) con OpenStudio.

Debe partirse de una plantilla apropiada (ver directorio Templates) e incluir las siguientes medidas en OpenStudio:

- CTE_Model en las medidas de modelo
- CTE_Workspace en las medidas de EnergyPlus
- CTE_Report en las medidas de Informe

Si se desea obtener un archivo de vectores energéticos (consumos y producción) para su proceso con **epbdcalc** o **epbdpanel** puede aplicarse la medida CTE_EPBDcalc como medidas de informe.

Para información más detallada de uso consulte el *Manual de uso* en formato PDF que se encuentra en el directorio de instalación.

Créditos y licencia
-------------------

Copyright (c) 2016 Ministerio de Fomento, Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)

El código del proyecto ha sido desarrollado por Daniel Jiménez González y Rafael Villar Burke, del Instituto Eduardo Torroja de Ciencias de la Construcción (IETcc-CSIC) en el ámbito del convenio de colaboración entre el CSIC y el Ministerio de Fomento para el desarrollo de tareas relacionadas con el Código Técnico de la Edificación y se publica bajo una licencia libre.

Se puede consultar la licencia completa en el archivo `LICENSE_ES.txt` y `LICENSE.txt` distribuidos con el código fuente.

La herramienta se distribuye con la esperanza de que resulte útil, pero SIN NINGUNA GARANTÍA, ni garantía MERCANTIL implícita ni la CONVENIENCIA PARA UN PROPÓSITO PARTICULAR.
