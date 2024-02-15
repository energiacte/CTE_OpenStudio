# A veces falla DNS en red, probar a ver qué servidor está configurado con:
# $ nmcli dev show | grep 'IP4.DNS'
# y añadir esos servidores, junto con uno público al final (e.g. 8.8.8.8) en /etc/daemon.json:
# {
#    "dns": ["161.111.10.3", "161.111.80.11", "8.8.8.8"]
# }
# y luego $ sudo service docker restart
#
curr_dir=$(realpath .)
os_version=3.6.1
local_os_mount_point=${HOME}/openstudio

runprueba:
	$(info [INFO] Arrancando consola de bash en contenedor de OpenStudio)
	$(info [INFO] Directorio de medidas de ~/openstudio/Measures conectado a /root/OpenStudio/Measures)
	$(info [INFO] Puede acceder al directorio de tests de cada medida y ejecutar ruby test.rb)
	docker run -it \
	--rm \
	--net=host \
	-v ${local_os_mount_point}:/var/simdata/openstudio \
	-v ${curr_dir}:/root/OpenStudio/Measures \
	-w /root/OpenStudio/Measures \
	nrel/openstudio:$(os_version) \
	bash


runnrel:
	$(info [INFO] Arrancando consola de bash en contenedor de OpenStudio)
	$(info [INFO] Directorio de medidas de ~/openstudio/Measures conectado a /root/OpenStudio/Measures)
	$(info [INFO] Puede acceder al directorio de tests de cada medida y ejecutar ruby test.rb)
	docker run -it \
	--rm \
	--net=host \
	-v ${local_os_mount_point}:/var/simdata/openstudio \
	-v ${local_os_mount_point}/Measures:/root/OpenStudio/Measures \
	-v ${local_os_mount_point}/sandBox:/root/OpenStudio/sandBox \
	-v /mnt/vegacte/03-CTE_en_curso/salaSert/git/OSCTEModels:/root/OpenStudio/Models \
	-v /mnt/vegacte/03-CTE_en_curso/salaSert/git/suspat:/root/OpenStudio/suspat \
	-w /root/OpenStudio/Measures \
	nrel/openstudio:$(os_version) \
	bash

# Hay artefactos de dibujado en QT5 con docker por funcionar como root. Se solucionan ejecutando QT_GRAPHICSSYSTEM=native OpenStudio
# aunque por alguna razón no funciona al pasarlo en el entorno...
# Esta es la OpenStudioApp que se distribuía en versiones antiguas
# TODO: ver si hay un contenedor para OSApp más nueva
run_old:
	xhost local:root && \
		docker run -it \
		--rm \
		--net=host \
		-e DISPLAY \
		-e QT_GRAPHICSSYSTEM='native' \
		-e QT_X11_NO_MITSHM=1 \
		--device=/dev/dri/card0 \
		-v /tmp/X11-unix:/tmp/X11-unix:ro \
		-v /etc/localtime:/etc/localtime:ro \
		-v /etc/machine-id:/etc/machine-id:ro \
		-v /var/run/dbus:/var/run/dbus \
		-v ${local_os_mount_point}:/openstudio \
		-v ${local_os_mount_point}/Measures:/root/OpenStudio/Measures \
		-w /root/OpenStudio/Measures \
		nrel/openstudio:1.13.4 \
		OpenStudio

#create:
#	docker build -t openstudio:1.12 .

pullnrel:
	docker pull nrel/openstudio

#exportimage:
#	docker save -o openstudioimg.tgz openstudio:1.12

#importimage:
#	docker load -i openstudioimg.tgz

installdocker:
	sysctl net.ipv4.conf.all.forwarding=1
	xhost +
	sudo aptitude install docker.io
	sudo usermod -aG docker `whoami`

test:
	$(info [INFO] Arrancando consola de bash en contenedor de OpenStudio)
	$(info [INFO] Directorio de medidas de ~/openstudio/Measures conectado a /root/OpenStudio/Measures)
	$(info [INFO] Puede acceder al directorio de tests de cada medida y ejecutar ruby test.rb)
	docker run -it \
	--rm \
	--net=host \
	-v ${local_os_mount_point}:/var/simdata/openstudio \
	-v ${curr_dir}:/root/OpenStudio/Measures \
	-w /root/OpenStudio/Measures \
	nrel/openstudio:$(os_version) \
	bash -c 'make all_tests'

test_model:
	cd ./CTE_Model/tests/ && ruby *.rb

test_workspace:
	cd ./CTE_Workspace/tests/ && ruby *.rb

test_informehe:
	cd ./CTE_InformeDBHE/tests/ && ruby *.rb

test_osreportsi:
	cd ./OS_Report_SI/tests/ && ruby *.rb

all_tests: test_model test_workspace test_informehe test_osreportsi
