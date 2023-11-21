# Depuración y formateo Ruby en contenedor de OpenStudio con VSCode

- Instalar docker y docker-compose
- Instalar extensión VSCode "Docker"
- Instalar extensión VSCode "Remote explorer"
- Crear archivo docker-compose.yaml:

    ```yaml
    # https://code.visualstudio.com/docs/containers/docker-compose
    services:
    dev:
        container_name: os361_dev
        image: nrel/openstudio:3.6.1
        stdin_open: true # docker run -i
        tty: true        # docker run -t
        volumes:
        - ./results:/var/simdata/openstudio/results
        - ./resources:/var/simdata/openstudio/resources
        - ./resources/test/models:/var/simdata/openstudio/resources/models
        - ../eplusctekit/climas:/var/simdata/openstudio/resources/climates
        - ../CTE_OpenStudio:/var/simdata/openstudio/resources/measures
        command: bash
    ```

- Activar contenedor con "Compose up" pulsando con botón derecho sobre el archivo anterior
- Abrir una ventana nueva con una sesión remota en el contenedor en ejecución desde la pestaña de "Remote explorer"
- Instalar en esa sesión la extensión del depurador de Ruby "VSCode rdbg Ruby Debugger"
- Generar una configuración para lanzar sesión de depuración en `.vscode/launch.json`:

    ```json
    {
        // Use IntelliSense para saber los atributos posibles.
        // Mantenga el puntero para ver las descripciones de los existentes atributos.
        // Para más información, visite: https://go.microsoft.com/fwlink/?linkid=830387
        "version": "0.2.0",
        "configurations": [
            {
                "type": "rdbg",
                "name": "Debug current file with rdbg",
                "request": "launch",
                "script": "${file}",
                "args": [],
                "askParameters": true
            },
            {
                "type": "rdbg",
                "name": "Attach with rdbg",
                "request": "attach"
            }
        ]
    }
    ```

- Abrir en la sesión remota una consola e instalar el depurador `gem install debug`
- Instala "Ruby LSP"
- ¡Ya se puede depurar en la consola del contenedor!
  - Marca un punto de parada en el editor
  - Lanza una ejecución de depuración del script en "Ejecución y depuración"
- Instala "Standard Ruby" (puede ser necesario reiniciar VSCode al final)
  - `gem install standard`
  
    ```json
        "[ruby]": {
            "editor.defaultFormatter": "testdouble.vscode-standard-ruby"
        },
    ```
