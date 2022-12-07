# Como Escribir Playbooks en Ansible

### Introducción

Ansible es una herramienta de administración que no requiere el uso de un agente instalado en los nodos remotos a configurar. Sólo requiere SSH y Python para comunicarse y ejecutar comandos en servidores administrados.

Ansible permite a los usuarios administrar servidores de dos formas diferentes: mediante comandos ad hoc y mediante playbooks. Los playbooks son archivos YAML que contienen una lista de tareas ordenadas que deben ejecutarse en un servidor remoto para completar una tarea o alcanzar un objetivo determinado, como configurar un entorno LAMP. Los playbooks permiten automatizar completamente la configuración de un servidor y la implementación de aplicaciones, utilizando una sintaxis determinada y una extensa biblioteca de módulos.

## Requisitos

Para tener ansible funcionando en nuestro entorno necesitaremos:

- **Un nodo de control:** el nodo de control de Ansible es la máquina que usaremos para conectarnos y controlar los hosts a través de SSH. El de control puede ser su máquina local o un servidor dedicado a ejecutar Ansible, por ejemplu un sistema Ubuntu 20.04. El nodo de control debe tener un usuario "no-root" con privilegios de sudo.
- **Un par de claves SSH asociadas al usuario "no-root" de su nodo de control**  
- **Uno o más hosts de Ansible:**  un host de Ansible es cualquier máquina que el nodo de control puede configurar de forma automatizada. Para ello cada host de Ansible debe tener la clave pública SSH del nodo de control agregada al fichero "authorized_keys" de un usuario del sistema. Este usuario puede ser root o un usuario normal con privilegios de sudo. 
- **Ansible instalado y configurado en el nodo de control.**
- **Un archivo de inventario Ansible.** Este archivo de inventario debe configurarse en el nodo de control y debe contener todos los hosts Ansible. 

## Creación y ejecución de un playbook

Los playbooks usan el formato YAML para definir una o más operaciones. Una operación es un conjunto de tareas ordenadas que se organizan para automatizar un proceso, como configurar un servidor web o implementar una aplicación en producción.

En un archivo playbook, las reproducciones se definen como una lista YAML. Una operación comienza determinando qué hosts son el objetivo de esa configuración en particular. Esto se hace con la directiva "hosts".

Establecer la directiva "hosts" a "all" es una opción común porque puede limitar los objetivos de un playbook en el tiempo de ejecución con el parámetro -l. Eso le permite ejecutar el mismo playbook en diferentes servidores o grupos de servidores sin la necesidad de cambiar el archivo playbook cada vez.

El siguiente playbook define una operación dirigida a todos los hosts de un inventario "all" determinado. Contiene una única tarea para imprimir un mensaje de depuración.

```yml
---
- hosts: all
  tasks:
    - name: Print message
      debug:
        msg: Hello World
```

Para probar este playbook en los servidores configurados en el archivo de inventario, ejecutamos "ansible-playbook" con los siguientes argumentos; usaremos un archivo de inventario llamado "inventory" y el usuario "user" para conectarnos al servidor remoto

```yml
ansible-playbook -i inventory playbook.yml -u user
```

Se verá un resultado parecido a este:

```
Output
PLAY [all] ***********************************************************************************

TASK [Gathering Facts] ***********************************************************************
ok: [10.20.30.40]

TASK [Update apt cache] **********************************************************************
ok: [10.20.30.40] => {
    "msg": "Hello World"
}

PLAY RECAP ***********************************************************************************
10.20.30.40             : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Como se puede apreciar, aunque hayamos definido solo una tarea dentro del playbook, se enumeraron dos tareas en el resultado de la reproducción. Ansible ejecuta de forma predeterminada una tarea adicional que recopila información, denominada "facts", sobre los nodos remotos. La tarea de recopilación de datos debe realizarse antes de que se ejecuten otras tareas.

## **Cómo definir tareas en un playbook de Ansible**

Una tarea "task" es la unidad de acción más pequeña que puede automatizar con un playbook. Los playbooks suelen contener una serie de tareas que cumplen un objetivo, como configurar un servidor web o implementar una aplicación en entornos remotos.

Ansible ejecuta las tareas en el mismo orden en que se definen dentro de un playbook. Antes de automatizar un procedimiento, como configurar un servidor LAMP, debemos evaluar qué pasos son necesarios para llevar lo acabo de forma manual y el orden en el que deben completarse para hacer lo todo. Luego, podremos determinar qué tareas necesitaremos y qué módulos podremos utilizar para alcanzar los objetivos.

Los módulos ofrecen atajos para ejecutar operaciones que de otro modo tendríamos que ejecutar con comandos bash. 

Este playbook contiene una única tarea que imprime un mensaje en la salida de una operación:

```yml
---
- hosts: all
  tasks:
    - name: Print message
      debug:
        msg: Hello World
```

Las tareas "tasks" se definen como una lista dentro de una operación, al mismo nivel que la directiva de "hosts" que define los objetivos de esa operación. La propiedad asociada a la etiqueta "name" define la salida que se mostrará cuando esa tarea esté a punto de ejecutarse.

La tarea de ejemplo invoca el módulo de depuración "debug", que le permite mostrar mensajes en un playbook. Estos mensajes se pueden utilizar para mostrar información de depuración, como el contenido de una variable o el mensaje de salida devuelto por un comando, por ejemplo.

Cada módulo tiene su propio conjunto de opciones y propiedades. El módulo "debug" espera que se imprima una propiedad denominada "msg" que contiene el mensaje. Hay que poner especial atención a la sangría (2 espacios), ya que "msg" debe ser una propiedad dentro de "debug".

## Cómo usar variables en un playbook

Ansible admite el uso de variables para personalizar mejor la ejecución de tareas y playbooks. De esta forma, es posible utilizar el mismo playbook con diferentes objetivos y entornos.

Las variables pueden provenir de diferentes fuentes, como el archivo playbook en sí o archivos de variables externas que se importan en el playbook. 

Para ver cómo funcionan las variables, creamos un playbook que imprimirá el valor de dos variables, "username" y "home":

```yml
---
- hosts: all
  vars:
    - username: user
    - home: /home/user
  tasks:
    - name: print variables
      debug:
        msg: "Username: {{ username }}, Home dir: {{ home }}"
```

La sección "vars" del playbook define una lista de variables que se inyectarán en el alcance de esta operación. Todas las tareas, así como cualquier archivo o plantilla que pueda estar incluido en el playbook, tendrán acceso a estas variables.

Para probar este playbook en los servidores ejecutamos:

```yml
ansible-playbook -i inventory playbook.yml -u user
```

Se verá un resultado parecido a este:

```
Output

PLAY [all] ***********************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [10.20.30.40]

TASK [print variables] ***********************************************************************************************************************************************************************
ok: [10.20.30.40] => {
    "msg": "Username: user, Home dir: /home/user"
}

PLAY RECAP ***********************************************************************************************************************************************************************************
10.20.30.40              : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

La tarea de imprimir variables usará el módulo "debug" para imprimir los valores de las dos variables que definimos en la sección "vars" del playbook.

## Cómo acceder a la información del sistema (Facts)

De forma predeterminada, antes de ejecutar el conjunto de tareas definidas en un playbook, Ansible se tomará unos minutos para recopilar información sobre los sistemas que se están aprovisionando. Esta información, conocida como "Facts", contiene detalles como las interfaces y direcciones de red, el sistema operativo que se ejecuta en los nodos remotos y la memoria disponible, entre otras cosas.

Ansible almacena Facts en formato JSON, con elementos agrupados en nodos. Para verificar qué tipo de información está disponible para los sistemas que está aprovisionando, podemos ejecutar el módulo "setup" con un comando ad hoc:

```yml
ansible all -i inventory -m setup -u user
```

Este comando generará un JSON que contiene información sobre su servidor. Para obtener un subconjunto de esos datos, puede usar el parámetro "filter" y proporcionar un patrón. Por ejemplo, si desea obtener información sobre todas las direcciones IPv4 en los nodos remotos, puede usar el siguiente comando:

```yml
ansible all -i inventory -m setup -a "filter=*ipv4*" -u user
```

Se verá un resultado parecido a este:

```
Output
10.20.30.40 | SUCCESS => {
    "ansible_facts": {
        "ansible_all_ipv4_addresses": [
            "10.20.30.40", 
            "10.20.30.50"
        ], 
        "ansible_default_ipv4": {
            "address": "10.20.30.40", 
            "alias": "eth0", 
            "broadcast": "10.20.30.255", 
            "gateway": "10.20.30.1", 
            "interface": "eth0", 
            "macaddress": "06:c7:91:16:2e:b7", 
            "mtu": 1500, 
            "netmask": "10.20.30.0", 
            "network": "10.20.30.0", 
            "type": "ether"
        }
    }, 
    "changed": false
}
```

Una vez que hayamos encontrado los "facts"que serán útiles para el playbook, podemos crear un playbook en consecuencia. Como ejemplo, el siguiente playbook imprimirá la dirección IPv4 de la interfaz de red predeterminada. De la salida del comando anterior, podemos ver que este valor está disponible a través de "ansible_default_ipv4.address" en el JSON proporcionado por Ansible.

El playbook quedaría de la siguiente forma:

```yml
---
- hosts: all
  tasks:
    - name: print facts
      debug:
        msg: "IPv4 address: {{ ansible_default_ipv4.address }}"
```

Se verá un resultado parecido a este:

```
Output
...

TASK [print facts] ***************************************************************************************************************************************************************************
ok: [server1] => {
    "msg": "IPv4 address: 10.20.30.40"
}

...
```

## **Cómo usar condicionales en los playbooks de Ansible**

En Ansible, puede definir las condiciones que se evaluarán antes de que se ejecute una tarea. Cuando no se cumple una condición, la tarea se omite. Esto se hace con la palabra clave "when", que acepta expresiones que normalmente se basan en una variable o un hecho.

El siguiente ejemplo define dos variables: "create_user_file" y "user". Cuando "create_user_file" se evalúa como verdadero, se creará un nuevo archivo en el directorio de inicio del usuario definido por la variable de usuario:

```yml
---
- hosts: all
  vars:
    - create_user_file: yes
    - user: user
  tasks:
    - name: create file for user
      file:
        path: /home/{{ user }}/myfile
        state: touch
      when: create_user_file
```

Cuando ejecutemos el playbook, la salida será similar a esto:

```yml
ansible-playbook -i inventory playbook.yml -u user
```

```
Output
...
TASK [create file for user] *****************************************************************************
changed: [10.20.30.40]
...
```

Un uso común de los condicionales en el contexto de los playbooks de Ansible es combinarlos con "register", una palabra clave que crea una nueva variable y le asigna  la salida obtenida de un comando. De esta forma, puede utilizar cualquier comando externo para evaluar la ejecución de una tarea.

Una cosa importante a tener en cuenta es que, de forma predeterminada, Ansible interrumpirá una operación si el comando que está utilizando para evaluar una condición falla. Por esa razón, necesitará incluir una directiva "ignore_errors" configurada a "yes" en dicha tarea, y esto hará que Ansible pase a la siguiente tarea y continúe con la siguiente operación.

El siguiente ejemplo solo creará un nuevo archivo en el directorio de inicio del usuario en caso de que ese archivo aún no exista, lo cual probaremos con un comando "ls". Sin embargo, si el archivo existe, mostraremos un mensaje usando el módulo de "debug".

Este sería nuestro playbook:

```yml
---
- hosts: all
  vars:
    - user: user
  tasks:
    - name: Check if file already exists
      command: ls /home/{{ user }}/myfile
      register: file_exists
      ignore_errors: yes

    - name: create file for user
      file:
        path: /home/{{ user }}/myfile
        state: touch
      when: file_exists is failed

    - name: show message if file exists
      debug:
        msg: The user file already exists.
      when: file_exists is succeeded
```

La primera vez que ejecutamos este playbook, el comando fallará porque el archivo no existe en esa ruta. Luego se ejecutará la tarea que crea el archivo, mientras que la última tarea se omitirá:

```
Output
...

TASK [Check if file already exists] *********************************************************************
fatal: [10.20.30.40]: FAILED! => {"changed": true, "cmd": ["ls", "/home/user/myfile"], "delta": "0:00:00.004258", "end": "2020-10-22 13:10:12.680074", "msg": "non-zero return code", "rc": 2, "start": "2020-10-22 13:10:12.675816", "stderr": "ls: cannot access '/home/user/myfile': No such file or directory", "stderr_lines": ["ls: cannot access '/home/user/myfile': No such file or directory"], "stdout": "", "stdout_lines": []}
...ignoring

TASK [create file for user] *****************************************************************************
changed: [10.20.30.40]

TASK [show message if file exists] **********************************************************************
skipping: [10.20.30.40]
... 
```

Se puede ver que la tarea de creación del archivo para el usuario provocó un cambio en el servidor, lo que significa que se creó correctamente. Ahora, ejecutamos el playbook nuevamente y obtendremos un resultado diferente:

```
Output
...
TASK [Check if file already exists] *********************************************************************
changed: [10.20.30.40]

TASK [create file for user] *****************************************************************************
skipping: [10.20.30.40]

TASK [show message if file exists] **********************************************************************
ok: [10.20.30.40] => {
    "msg": "The user file already exists."
}
...
```

Para más información sobre el uso de condicionales en los playbooks de Ansible, podemos consultar la documentación oficial. https://docs.ansible.com/ansible/latest/user_guide/playbooks_conditionals.html.

## **Cómo usar bucles en Ansible**

Para automatizar la configuración del servidor, a veces necesitaremos repetir la ejecución de la misma tarea usando diferentes valores. Por ejemplo, es posible que debamos cambiar los permisos de varios archivos o crear varios usuarios. Para evitar repetir la misma tarea varias veces, es mejor usar bucles.

En programación, un bucle le permite repetir instrucciones, normalmente hasta que se cumpla una determinada condición. Ansible ofrece diferentes métodos de bucle.

El siguiente ejemplo crea tres archivos diferentes en la ubicación "/tmp". Utiliza el módulo "file" dentro de una tarea que implementa un "loop" usando tres valores diferentes.

```yaml
---
- hosts: all
  tasks:
    - name: creates users files
      file:
        path: /tmp/ansible-{{ item }}
        state: touch
      loop:
        - user1
        - user2
        - user3
```

Cuando ejecutemos el playbook, la salida será similar a esto:

```
Output
...
TASK [creates users files] ******************************************************************************
changed: [10.20.30.40] => (item=user1)
changed: [10.20.30.40] => (item=user2)
changed: [10.20.30.40] => (item=user3)
...
```

Para más información sobre el uso de "loops"en los playbooks de Ansible, podemos consultar la documentación oficial. https://docs.ansible.com/ansible/latest/user_guide/playbooks_loops.html

## **Escalada de privilegios en los playbooks de Ansible**

Al igual que con los comandos que ejecutamos en una terminal, algunas tareas requerirán privilegios especiales para que Ansible las ejecute con éxito en sus nodos remotos.

Es importante comprender cómo funciona la escalada de privilegios en Ansible para que podamos ejecutar las tareas con los permisos adecuados. 

De forma predeterminada, las tareas se ejecutarán como el usuario que se conecta; puede ser "root" o cualquier usuario normal con acceso SSH a los nodos remotos.

Para ejecutar un comando con permisos extendidos, como un comando que requiere "sudo", necesitaremos incluir una directiva "become" definida a "yes" en nuestro playbook. Esto se puede hacer como una configuración global válida para todas las tareas en dicho playbook, o como una instrucción individual aplicada por tarea. Dependiendo de cómo esté configurado nuestro usuario de "sudo" dentro de los nodos remotos, es posible que también deba proporcionar la contraseña de "sudo" del usuario. El siguiente ejemplo actualiza el caché de "apt", esta tarea requiere permisos de "root".

```yaml
---
- hosts: all
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
```

Para ejecutar este playbook, deberemos incluir la opción -K dentro del comando ansible-playbook. Esto hará que Ansible nos solicite la contraseña de "sudo" para el usuario especificado.

```yaml
ansible-playbook -i inventory playbook.yml -u user -K
```

También puede cambiar a qué usuario desea cambiar mientras ejecuta una tarea o playbook. Para hacer eso, configuramos la directiva "Become_user" con el nombre del usuario remoto al que deseamos cambiar. Esto es útil cuando tenemos varias tareas en un playbook que dependen de "sudo", pero también algunas tareas que deberían ejecutarse como su usuario habitual.

El siguiente ejemplo define que todas las tareas de este playbook se ejecutarán con "sudo" de forma predeterminada. Esto se establece en el nivel de ejecución, justo después de la definición de "hosts". La primera tarea crea un archivo en "/tmp" usando privilegios de "root", ya que ese es el valor predeterminado de "Become_user". La última tarea, sin embargo, define su propio "Become_user".

```yaml
---
- hosts: all
  become: yes
  vars:
    user: "{{ ansible_env.USER }}"
  tasks:
    - name: Create root file
      file:
        path: /tmp/my_file_root
        state: touch

    - name: Create user file
      become_user: "{{ user }}"
      file:
        path: /tmp/my_file_{{ user }}
        state: touch
```

El "fact" "ansible_env.USER" contiene el nombre de usuario del usuario que se conecta, que se puede definir en el momento de la ejecución cuando se ejecuta el comando ansible-playbook con la opción -u. Nosotros estamos conectando como "user":

```yaml
ansible-playbook -i inventory playbook.yml -u user-K
```

Esta sería la salida:

```
Output
BECOME password: 

PLAY [all] **********************************************************************************************

TASK [Gathering Facts] **********************************************************************************
ok: [10.20.30.40]

TASK [Create root file] *********************************************************************************
changed: [10.20.30.40]

TASK [Create user file] *********************************************************************************
changed: [10.20.30.40]

PLAY RECAP **********************************************************************************************
10.20.30.40           : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

Cuando el playbook termine de ejecutarse, podremos iniciar sesión en los nodos remotos para verificar que se crearon dos archivos nuevos en "/tmp", cada uno con la información y propietario correspondiente:

```
ssh user@10.20.30.40
```

```
ls -la /tmp/my_file*
```

```
Output
-rw-r--r-- 1 root  root 0 Oct 22 8:49 /tmp/my_file_root
-rw-r--r-- 1 user sudo 0 Oct 22 10:27 /tmp/my_file_user
```

Para obtener información más detallada sobre la escalada de privilegios en Ansible, consulte la documentación. https://docs.ansible.com/ansible/latest/user_guide/become.html

## **Cómo instalar y administrar paquetes del sistema en Ansible**

Automatizar la instalación de los paquetes del sistema es una tarea operativa común en los playbooks, ya que una pila de aplicaciones típica requiere software de diferentes fuentes.

El módulo "apt" administra los paquetes en sistemas operativos basados en Debian como Ubuntu. El siguiente playbook actualizará la caché de "apt" y luego se asegurará de que "Vim" esté instalado en los nodos remotos.

```yaml
---
- hosts: all
  become: yes
  tasks:
    - name: Update apt cache and make sure Vim is installed
      apt:
        name: vim
        update_cache: yes
```

La eliminación de un paquete se realiza de manera similar, el único cambio es que debemos definir el estado ("state") del paquete como "absent". La directiva "state" tiene un valor predeterminado a "present", que asegurará que el paquete esté instalado en el sistema, independientemente de la versión. El paquete se instalará si no está presente. Para asegurarse de tener la última versión de un paquete, puede utilizar la directiva "state" como "latest" en su lugar. Esto hará que "apt" actualice el paquete solicitado si no está en su última versión.

Debemos proporcionar la opción -K cuando ejecutemos este playbook, ya que requiere permisos sudo:

```yaml
ansible-playbook -i inventory playbook.yml -u user -K
```

```
Output
BECOME password: 

PLAY [all] **********************************************************************************************

TASK [Gathering Facts] **********************************************************************************
ok: [10.20.30.40]

TASK [Update apt cache and make sure Vim is installed] **************************************************
ok: [10.20.30.40]

PLAY RECAP **********************************************************************************************
10.20.30.40                : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Para instalar varios paquetes, podemos utilizar un "loop" y junto con un "array" que contenga los nombres de los paquetes que deseamos instalar. En el siguiente playbook nos aseguraremos de que los paquetes "vim", "unzip" y "curl" estén instalados y en su última versión.

```yaml
---
- hosts: all
  become: yes
  tasks:
    - name: Update apt cache and make sure Vim, Curl and Unzip are installed
      apt:
        name: "{{ item }}"
        update_cache: yes
      loop:
        - vim
        - curl
        - unzip
```

Al ejecutar nuestro playbook la salida sería algo similar a lo siguiente:

```
Output
BECOME password: 

PLAY [all] ***************************************************************************************************************************************

TASK [Gathering Facts] ***************************************************************************************************************************
ok: [10.20.30.40]

TASK [Update apt cache and make sure Vim, Curl and Unzip are installed] **************************************************************************
ok: [10.20.30.40] => (item=vim)
ok: [10.20.30.40] => (item=curl)
changed: [10.20.30.40] => (item=unzip)

PLAY RECAP ***************************************************************************************************************************************
10.20.30.40            : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Para obtener más detalles sobre cómo administrar los paquetes del sistema, incluido cómo eliminar paquetes y cómo utilizar las opciones avanzadas de "apt", puede consultar la documentación oficial. https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html

## Cómo crear y usar plantillas en los playbooks

Las plantillas nos permiten crear nuevos archivos en los nodos utilizando modelos predefinidos basados en el sistema de plantillas "Jinja2". Las plantillas de Ansible generalmente se guardan como archivos ".tpl" y admiten el uso de variables, bucles y expresiones condicionales.

Las plantillas se usan comúnmente para configurar servicios basados en valores que son proporcionados por variables que se pueden definir en el propio playbook, en archivos de definición de variables o a través de "facts". Esto nos permite crear configuraciones más versátiles que adaptan su comportamiento en función de la información definida.

Para probar esta caracteristica con un ejemplo práctico, crearemos un nuevo directorio para contener los archivos (plantillas ) dentro del directorio que contiene el "playbook.yml":

```bash
mkdir ~/ansible/files
```

A continuación, creamos un nuevo archivo de plantilla para una página HTML. Después, crearemos un playbook que configurará los nodos remotos para servir la página con Nginx:

```bash
nano ~/ansible/files/landing-page.html.j2
```

Añadimos el siguiente contenido al archivo de plantilla:

```jinja2
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{{ page_title }}</title>
  <meta name="description" content="Created with Ansible">
</head>
<body>
    <h1>{{ page_title }}</h1>
    <p>{{ page_description }}</p>
</body>
</html>
```

Esta plantilla utiliza dos variables que deben proporcionarse y que estarán definidas en el propio playbook: "page_title" y "page_description".

El siguiente playbook define las variables necesarias, instala Nginx y luego aplica la plantilla especificada para reemplazar la página de destino predeterminada de Nginx que se encuentra en "/var/www/html/index.nginx-debian.html". La última tarea usa el módulo "ufw" para habilitar el acceso "tcp" en el puerto 80, en caso de que tengamos el firewall habilitado.

```yaml
---
- hosts: all
  become: yes
  vars:
    page_title: My Landing Page
    page_description: This is my landing page description.
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: latest

    - name: Apply Page Template
      template:
        src: files/landing-page.html.j2
        dest: /var/www/html/index.nginx-debian.html

    - name: Allow all access to tcp port 80
      ufw:
        rule: allow
        port: '80'
        proto: tcp
```

Debemos proporcionar la opción -K cuando ejecutemos este playbook, ya que requiere permisos sudo:

```bash
ansible-playbook -i inventory playbook.yml -u user -K
```

```
Output
BECOME password: 

PLAY [all] **********************************************************************************************

TASK [Gathering Facts] **********************************************************************************
ok: [10.20.30.40]

TASK [Install Nginx] ************************************************************************************
changed: [10.20.30.40]

TASK [Apply Page Template] ******************************************************************************
changed: [10.20.30.40]

TASK [Allow all access to tcp port 80] ******************************************************************
changed: [10.20.30.40]

PLAY RECAP **********************************************************************************************
10.20.30.40                : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Cuando el playbook haya terminado, podremos acceder a la dirección IP del servidor web desde el navegador. Y veremos una página como esta:

<img src="file:///C:/Users/adm_payanjuanm/Desktop/Captura.PNG" title="" alt="Captura.PNG" data-align="center">

Eso significa que el playbook funcionó como se esperaba y la página Nginx predeterminada fue reemplazada por la plantilla que habiamos creado.

## **Cómo definir y usar "handlers" en un playbook**

Los "handlers" son tareas especiales que solo se ejecutan cuando se activan a través de la directiva "notify". Los "handlers" se ejecutan al final del playbook, una vez que se terminan todas las tareas.

En Ansible, los "handlers" se utilizan normalmente para iniciar, recargar, reiniciar y detener servicios. Si un playbook implica cambiar archivos de configuración, lo más aconsejable es que reiniciemos el servicio asociado para que los cambios surtan efecto. En este caso, deberemos definir un "handler" para ese servicio e incluir la directiva "notify" en cualquier tarea que requiera ese "handler".

Teniendo en cuenta tal escenario, así es como se vería un "handler" para reiniciar el servicio Nginx:

```yaml
...
  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

Para activar este "handler", deberemos incluir una directiva "nofify" en cualquier tarea que requiera un reinicio en el servidor Nginx.

El siguiente playbook reemplaza el directorio raíz (definido en la variable "doc_root") predeterminado  de Nginx usando el módulo "built-in" llamado "replace". Este módulo busca patrones en un archivo basado en una expresión regular definida por "regexp", y luego reemplaza cualquier coincidencia encontrada con el contenido definido por "replace". Posteriormente, la tarea envía una notificación al "handler" llamado "Restart Nginx" para que se reinicie el servidor web. Lo que eso significa es que no importa cuántas veces active el reinicio, solo sucederá cuando todas las tareas hayan terminado y los "handlers" comiencen a ejecutarse. Además, cuando no se encuentren coincidencias, no se realizarán cambios en el sistema y, por lo tanto, el "handler" no se activa.

```yaml
---
- hosts: all
  become: yes
  vars:
    page_title: My Second Landing Page
    page_description: This is my second landing page description.
    doc_root: /var/www/mypage

  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: latest

    - name: Make sure new doc root exists
      file:
        path: "{{ doc_root }}"
        state: directory
        mode: '0755'

    - name: Apply Page Template
      template:
        src: files/landing-page.html.j2
        dest: "{{ doc_root }}/index.html"

    - name: Replace document root on default Nginx configuration
      replace:
        path: /etc/nginx/sites-available/default
        regexp: '(\s+)root /var/www/html;(\s+.*)?$'
        replace: \g<1>root {{ doc_root }};\g<2>
      notify: Restart Nginx

    - name: Allow all access to tcp port 80
      ufw:
        rule: allow
        port: '80'
        proto: tcp

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

Una cosa importante a tener en cuenta cuando se utilizan "handlers" es que solo se activan cuando la tarea que define el "notify" provoca un cambio en el servidor. Teniendo en cuenta este playbook, la primera vez que ejecute la tarea con el módulo "replace", cambiará el archivo de configuración de Nginx y, por lo tanto, se ejecutará el reinicio. Sin embargo, en ejecuciones posteriores, dado que la cadena que se reemplazará ya no está presente en el archivo, la tarea no causará ningún cambio y no activará la ejecución del "handler".

```
Output
BECOME password: 

PLAY [all] **********************************************************************************************

TASK [Gathering Facts] **********************************************************************************
ok: [10.20.30.40]

TASK [Install Nginx] ************************************************************************************
ok: [10.20.30.40]

TASK [Make sure new doc root exists] ********************************************************************
changed: [10.20.30.40]

TASK [Apply Page Template] ******************************************************************************
changed: [10.20.30.40]

TASK [Replace document root on default Nginx configuration] *********************************************
changed: [10.20.30.40]

TASK [Allow all access to tcp port 80] ******************************************************************
ok: [10.20.30.40]

RUNNING HANDLER [Restart Nginx] *************************************************************************
changed: [10.20.30.40]

PLAY RECAP **********************************************************************************************
10.20.30.40                : ok=7    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Si miras la salida, verás que el "handler" con nombre "Restart Nginx" se ejecuta justo al final del playbook. Si va a su navegador y accede a la dirección IP del servidor, verá la siguiente página:

<img src="file:///C:/Users/adm_payanjuanm/Desktop/Captura.PNG" title="" alt="Captura.PNG" data-align="center">

En esta última parte, conectaremos todos los puntos y crearemos un playbook que automatice la configuración de un servidor Nginx remoto para alojar un sitio web HTML estático.

# **Cómo implementar un sitio web HTML estático con Ansible en Ubuntu 20.04 (Nginx)**

En este punto ya estamos familiarizados con la instalación de paquetes del sistema, la aplicación de plantillas y el uso de "handlers" en los playbooks. 

Crearemos un directorio en el nodo de control de Ansible donde configuraremos los archivos de Ansible (playbook y 2 directorios uno llamado "files" para las plantillas y otro llamado "vars" para las variables ) y un sitio web HTML estático de demostración para implementarlo en el servidor remoto.

## **Creación de una plantilla para la configuración de Nginx**

Ahora crearemos la plantilla de Nginx necesaria para configurar el servidor web remoto. Crearemos una nueva carpeta dentro del directorio que contiene el playbook llamado "files" para los archivos de plantillas:

```bash
mkdir files
```

Creamos un fichero para la plantilla:

```bash
nano files/nginx.conf.j2
```

Este archivo de plantilla contiene la configuración del servidor Nginx para un sitio web HTML estático. Utiliza tres variables: "document_root", "app_root" y "server_name". Definiremos estas variables más adelante en un fichero llamado "default.yml" dentro de la carpeta "vars" que crearemos en el directorio raíz que contiene el playbook. 

```jinja2
server {
  listen 80;

  root {{ document_root }}/{{ app_root }};
  index index.html index.htm;

  server_name {{ server_name }};

  location / {
   default_type "text/html";
   try_files $uri.html $uri $uri/ =404;
  }
}
```

## Creación del fichero de variables default.yml

A continuación, crearemos un fichero llamado "default.yml" dentro de la carpeta "vars" donde configuraremos las variables que vamos a usar:

```bash
mkdir vars
```

```bash
nano vars/default.yml
```

Dentro de este fichero, crearemos tres variables: "server_name", "document_root", "app_root" y "http_port". Estas variables se utilizan en la plantilla de configuración de Nginx para definir el nombre de dominio o la dirección IP a la que responderá el servidor web, la ruta completa a la ubicación de los archivos del sitio web en el servidor, el directorio que contiene el propio sitio HTML y el puerto en el que escuchará el servidor web Nginx. Para "server_name", usaremos el "fact" llamdo  "ansible_default_ipv4.address" porque contiene la dirección IP del servidor remoto, pero podriamos reemplazar este valor con el nombre de host.

```yaml
---
server_name: "{{ ansible_default_ipv4.address }}"
document_root: "/var/www/html"
app_root: "html_site"
http_port: "80"
```

## **Estructura del directorio de trabajo**

Tras crear los directorios para variables, plantillas y la pagina web, asi como los ficheros correspondientes y el fichero principal playbook.yml, la estructura de directorios quedaría de la siguiente forma:

```bash
user@controlnode:~$ tree
.
├── files
│ └── nginx.conf.j2
├── html_site
│ └── index.html
├── playbook.yml
└── vars
 └── default.yml
```

## **Creación de nuestro playbook.yml**

El contenido de nuestro playbook sería el siguiente:

```yaml
---
- hosts: all    ##Se aplica a todos los nodos del inventario
  become: yes    ##Ejecuta todas las tareas como "root"     
  vars_files:    ##Declaramos el fichero que contiene las variables
    - vars/default.yml 
  tasks:    ##Definimos las tareas a realizar

    ###Actualizamos la cache apt e instalamos la última version de Nginx###
    ###https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html###
    - name: Update apt cache and install Nginx
      apt:
        name: nginx
        state: latest
        update_cache: yes

    ###Copiamos el directorio con nuestra web al directorio raíz###
    ###https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html###
    - name: Copy website files to the server's document root
      copy:
        src: "{{ app_root }}"
        dest: "{{ document_root }}"
        mode: preserve

    ###Copiamos nuestra plantilla de configuracion de Nginx###
    ###https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html###
    - name: Apply Nginx template
      template:
        src: files/nginx.conf.j2
        dest: /etc/nginx/sites-available/default
      notify: Restart Nginx

    ###Activamos nuestro sitio web###
    ###https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html###
    - name: Enable new site
      file:
        src: /etc/nginx/sites-available/default
        dest: /etc/nginx/sites-enabled/default
        state: link
      notify: Restart Nginx

    ###Permitimos el acceso al puerto 80 tcp en el firewall###
    ###https://docs.ansible.com/ansible/latest/collections/community/general/ufw_module.html###
    - name: Allow all access to tcp port 80
      ufw:
        rule: allow
        port: "{{ http_port }}"
        proto: tcp

  ###Declaramos los "handlers" que posteriormente llamaremos con el###
  ###statement "notify" desde la tarea correspondiente, en este caso###
  ###reiniciamos el servicio de Nginx###
  ###https://docs.ansible.com/ansible/latest/user_guide/playbooks_handlers.html###
  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

## **Parámetros útiles del comando ansible-playbook**

**--syntax-check**

```bash
ansible-playbook -i hosts playbook.yml --syntax-check
```

```bash
playbook: playbook.yml
```

**--list-hosts**

```bash
ansible-playbook -i hosts playbook.yml --list-hosts
```

```bash
playbook: playbook.yml

  play #1 (all): all    TAGS: []
    pattern: ['all']
    hosts (3):
      server1
      server2
      server3
```

**--list-tasks**

```bash
ansible-playbook -i hosts playbook.yml --list-tasks
```

```bash
playbook: playbook.yml

  play #1 (all): all    TAGS: []
    tasks:
      Install prerequisites     TAGS: [aptitude setup]
      Install Apache    TAGS: [apache2 setup]
      Create document root      TAGS: [creating document-root]
      Copy index test page      TAGS: [copying template index.html]
      Set up Apache virtualhost TAGS: [apache virtualhost setup]
      Enable new site   TAGS: [enable new site]
      Disable default Apache site       TAGS: [disable default-site]
```

**--list-tags**

```bash
ansible-playbook -i hosts playbook.yml --list-tags
```

```bash
playbook: playbook.yml

  play #1 (all): all    TAGS: []
      TASK TAGS: [apache virtualhost setup, apache2 setup, aptitude setup, copying template index.html, creating document-root, disable default-site, enable new site]
```

**--tags**

Para ejecutar solo tareas que están marcadas con etiquetas específicas, podemos usar el argumento --tags, junto con el nombre de la etiqueta/as que queremos ejecutar:

```bash
ansible-playbook -i hosts playbook.yml --tags='aptitude setup','apache2 setup'
```

```
PLAY [all] *************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************
ok: [server2]
ok: [server1]
ok: [server3]

TASK [Install prerequisites] *******************************************************************************************
changed: [server2] => (item=aptitude)
changed: [server3] => (item=aptitude)
changed: [server1] => (item=aptitude)

TASK [Install Apache] **************************************************************************************************
changed: [server3]
changed: [server1]
changed: [server2]

PLAY RECAP *************************************************************************************************************
server1                    : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
server2                    : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
server3                    : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

**--skip-tags**

Para omitir tareas que están marcadas con ciertas etiquetas podemos usar el argumento --skip-tags junto con los nombres de las etiquetas que deseamos excluir de la ejecución:

```bash
ansible-playbook -i hosts playbook.yml --skip-tags='aptitude setup'
```

```
PLAY [all] *************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************
ok: [server1]
ok: [server2]
ok: [server3]

TASK [Install Apache] **************************************************************************************************
changed: [server1]
changed: [server2]
changed: [server3]

TASK [Create document root] ********************************************************************************************
changed: [server3]
changed: [server2]
changed: [server1]

TASK [Copy index test page] ********************************************************************************************
changed: [server2]
changed: [server3]
changed: [server1]

TASK [Set up Apache virtualhost] ***************************************************************************************
changed: [server1]
changed: [server2]
changed: [server3]

TASK [Enable new site] *************************************************************************************************
changed: [server3]
changed: [server1]
changed: [server2]

TASK [Disable default Apache site] *************************************************************************************
changed: [server1]
changed: [server2]
changed: [server3]

RUNNING HANDLER [Reload Apache] ****************************************************************************************
changed: [server2]
changed: [server1]
changed: [server3]

PLAY RECAP *************************************************************************************************************
server1                    : ok=8    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
server2                    : ok=8    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
server3                    : ok=8    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

**--start-at-task**

Otra forma de controlar el flujo de ejecución de un playbook es iniciar dicho playbook en una determinada tarea. 

```bash
ansible-playbook -i hosts playbook.yml --start-at-task='Create document root'
```

**Flag  -l (limit)**

Muchos playbooks configuran su objetivo como "all" de forma predeterminada, y a veces, deseamos limitarlo a un grupo o un único servidor. Podemos usar -l (limit) para configurar el grupo objetivo o el servidor en esa ejecución:

```bash
ansible-playbook -l server1 -i hosts playbook.yml
```

**Controlar la información de salida (-v, -vv, -vvv, -vvvv)**

Si se producen errores al ejecutar los playbooks, podemos aumentar el nivel de detalle de la salida para obtener más información sobre el problema que se está produciendo. Podemos hacerlo incluyendo la opción -v en el comando:

```bash
ansible-playbook -i hosts playbook.yml -v
```

Si necesitamos más detalles, podemos usar -vv o -vvv en su lugar. Si no podemos conectar a los nodos remotos, podemos usar -vvvv para obtener información de la conexión en modo "debug":

```bash
ansible-playbook -i hosts playbook.yml -vvvv
```
