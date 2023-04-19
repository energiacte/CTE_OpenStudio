# A veces falla DNS en red, probar a ver qué servidor está configurado con:
# $ nmcli dev show | grep 'IP4.DNS'
# y añadir esos servidores, junto con uno público al final (e.g. 8.8.8.8) en /etc/daemon.json:
# {
#    "dns": ["161.111.10.3", "161.111.80.11", "8.8.8.8"]
# }
# y luego $ sudo service docker restart
#
runnrel:
	$(info [INFO] Arrancando consola de bash en contenedor de OpenStudio)
	$(info [INFO] Directorio de medidas de ~/openstudio/Measures conectado a /root/OpenStudio/Measures)
	$(info [INFO] Puede acceder al directorio de tests de cada medida y ejecutar ruby test.rb)
	docker run -it \
	--rm \
	--net=host \
	-v ${HOME}/openstudio:/var/simdata/openstudio \
	-v ${HOME}/openstudio/Measures:/root/OpenStudio/Measures \
	-v ${HOME}/openstudio/sandBox:/root/OpenStudio/sandBox \
	-v /mnt/vegacte/03-CTE_en_curso/salaSert/git/OSCTEModels:/root/OpenStudio/Models \
	-v /mnt/vegacte/03-CTE_en_curso/salaSert/git/suspat:/root/OpenStudio/suspat \
	nrel/openstudio:3.5.1 \
	bash

# Hay artefactos de dibujado en QT5 con docker por funcionar como root. Se solucionan ejecutando QT_GRAPHICSSYSTEM=native OpenStudio
# aunque por alguna razón no funciona al pasarlo en el entorno...
run:
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
		-v ${HOME}/openstudio:/openstudio \
		-v ${HOME}/openstudio/Measures:/root/OpenStudio/Measures \
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
	cd ./CTE_Model/tests/ && ruby e.rb
	cd ./CTE_Workspace/tests/ && ruby *.rb
	cd ./CTE_InformeDBHE/tests/ && ruby *.rb
	cd ./CTE_EPBDcalc/tests/ && ruby *.rb
	cd ./OS_Report_SI/tests/ && ruby *.rb

