# Depuración y formateo Ruby en contenedor de OpenStudio con VSCode

## Uso de docker

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
      tty: true # docker run -t
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

## Ruby fuera de la máquina remota docker

- Instala `rbenv` para usar otras versiones de Ruby:
  - `sudo apt install git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev`
  - `curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash`
  - `echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc`
  - `echo 'eval "$(rbenv init -)"' >> ~/.bashrc`
  - Activa con `source ~/.bashrc`
    - Aparecerá una función larga al escribir `type rbenv`
- Instala una versión de Ruby más reciente con ruby-build:
  - Ver qué versiones están disponibles con: `rbenv install -l`
  - Instala `rbenv install 3.2.2`
  - Establece como global esa versión: `rbenv global 3.2.2`
  - Comprobamos con `ruby -v`
- Configura la instalación de gemas para que no generen documentación:
  - `echo "gem: --no-document" > ~\.gemrc`
- Consultar dónde se instalan las gemas ahora: `gem env home`
- Instala las mismas gemas y extensiones que dentro del contenedor, que se explican a continuación.

## Ruby dentro del contenedor

- Abrir en la sesión remota una consola (Remote explorer > Adjuntar en nueva ventana)
- Instalar la gema del depurador y de formateo:
  - `echo "gem: --no-document" > ~\.gemrc`
  - `gem install bundler`
  - `gem install ruby-lsp`
  - `gem install debug`
  - `gem install standard`
- Instalar la extensión del depurador de Ruby "VSCode rdbg Ruby Debugger"
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

- Instala "Standard Ruby" (> Preferencias: Abrir configuración de usuario (JSON))

  ```json
    "[ruby]": {
        "editor.defaultFormatter": "testdouble.vscode-standard-ruby",
        "editor.formatOnSave": true,
        "editor.formatOnType": true,
        "editor.tabSize": 2,
        "editor.insertSpaces": true,
        "files.trimTrailingWhitespace": true,
        "files.insertFinalNewline": true,
        "files.trimFinalNewlines": true,
        "editor.rulers": [
        120
        ],
        "editor.semanticHighlighting.enabled": true
    },
  ```

- Instala extensión "Ruby LSP"
- Reinicia ventana: Ctrl+May+P > Desarrollador: Recargar ventana
- ¡Ya se puede depurar en la consola del contenedor!
  - Marca un punto de ruptura en el lateral editor
  - Lanza una ejecución de depuración del script en "Ejecución y depuración"
    - una vez que está seleccionado el lanzador por defecto se puede usar F5
