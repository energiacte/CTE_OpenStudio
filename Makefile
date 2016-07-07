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
		openstudio:1.12 \
		OpenStudio
# A veces falla DNS en red, probar a ver qué servidor está configurado con:
# $ nmcli dev show | grep 'IP4.DNS'
# y añadir esos servidores, junto con uno público al final (e.g. 8.8.8.8) en /etc/daemon.json:
# {
#    "dns": ["161.111.10.3", "161.111.80.11", "8.8.8.8"]
# }
# y luego $ sudo service docker restart
#
runbash:
	xhost local:root && \
		docker run -it \
		--rm \
		--net=host \
		-e DISPLAY \
		-e QT_GRAPHICSSYSTEM='native' \
		-e QT_X11_NO_MITSHM=1 \
		--device=/dev/dri/card0 \
		-v /tmp/X11-unix:/tmp/X11-unix:ro \
		-v /etc/machine-id:/etc/machine-id:ro \
		-v /var/run/dbus:/var/run/dbus \
		-v ${HOME}/openstudio:/openstudio \
		-v ${HOME}/openstudio/Measures:/root/OpenStudio/Measures \
		openstudio:1.12 \
		bash

runnrel:
	xhost local:root && \
		docker run -it \
		--rm \
		--net=host \
		-e DISPLAY \
		-e QT_GRAPHICSSYSTEM='native' \
		-e QT_X11_NO_MITSHM=1 \
		--device=/dev/dri/card0 \
		-v /tmp/X11-unix:/tmp/X11-unix:ro \
		-v /etc/machine-id:/etc/machine-id:ro \
		-v /var/run/dbus:/var/run/dbus \
		nrel/openstudio \
		bash
create:
	docker build -t openstudio:1.12 .

pullnrel:
	docker pull nrel/openstudio

exportimage:
	docker save -o openstudioimg.tgz openstudio:1.12

importimage:
	docker load -i openstudioimg.tgz

installdocker:
	sysctl net.ipv4.conf.all.forwarding=1
	xhost +
	sudo aptitude install docker.io
	sudo usermod -aG docker `whoami`
# cd /usr/local/share/openstudio-1.12.0/Ruby/openstudio/
# /usr/local/share/openstudio-1.12.0/Ruby/openstudio/examples/RunAllOSMs.rb
