## **Comandos ad hoc de Ansible**

Los comandos "ad hoc" de Ansible nos permiten controlar desde uno a cientos de sistemas.

A diferencia de los playbooks, que consisten en colecciones de tareas que se pueden reutilizar, los comandos "ad hoc" son tareas que no se realizan con frecuencia, como reiniciar un servicio o recuperar información sobre los sistemas remotos que administra Ansible.

Vamos a ver algunos comandos "ad hoc" de Ansible para realizar tareas comunes, como instalar paquetes, copiar archivos y reiniciar servicios en uno o más servidores remotos, desde un nodo de control de Ansible.

## **Probando la conexión a los hosts remotos**

El siguiente comando probará la conectividad entre un nodo de control de Ansible y todos los hosts. Este comando utiliza el usuario del sistema actual y su clave SSH correspondiente como inicio de sesión remoto e incluye la opción -m, que le indica a Ansible que ejecute el módulo de "ping". También cuenta con el indicador "-i", que le dice a Ansible que haga ping a los hosts enumerados en el archivo de inventario especificado.

```bash
ansible all -i hosts1 -m ping
```

la salida debería ser similar a la siguiente: 

```bash
server2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
server1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
server3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

Una vez que recibe una respuesta "pong" de un host, significa que la conexión está activa y está listo para ejecutar comandos de Ansible en ese servidor.

## **Opciones de conexión**

De forma predeterminada, Ansible intenta conectarse a los nodos remotos con el mismo nombre que el usuario actual del sistema, utilizando su par de claves SSH correspondiente.

Para conectarse como un usuario remoto diferente, ejecutamos el comando con el parametro "-u" y el nombre del usuario deseado:

```bash
ansible all -i servers_list -m ping -u vagrant
```

Debemos de tener en cuenta el parametro "-k" (minuscula) con el cual nos pedirá la contraseña de conexión "ssh", ya que sino lo especificamos y estamos trabajando en la terminal con otro usuario nos dará error de conexión:

```bash

```

Si estamos utilizando una clave SSH personalizada para conectarnos a los servidores remotos, en el caso de tener varias, podemos proporcionarla en el momento de la ejecución con la opción "--private-key":

```bash
ansible all -i servers_list -m ping --private-key=~/.ssh/clave_rsa_2
```

Una vez que podemos conectarnos usando las opciones apropiadas, podemos ajustar el archivo de inventario para configurar automáticamente el usuario remoto y clave privada, en caso de que sean diferentes de los valores predeterminados asignados por Ansible. Entonces, no necesitaremos proporcionar esos parámetros en la línea de comando.

El siguiente archivo de inventario de ejemplo configura la variable "ansible_user" solo para el servidor server1:

```
server1 ansible_host=192.168.10.50 ansible_user=vagrant
server2 ansible_host=192.168.10.51
server3 ansible_host=192.168.10.52
```

Si ejecutamos el comando "ad hoc":

```bash
ansible all -i servers_list -m ping
```

El resultado sería algo similar a esto:

```bash
server1 | UNREACHABLE! => {
    "changed": false,
    "msg": "Failed to connect to the host via ssh: vagrant@192.168.10.50: Permission denied (publickey,password).",
    "unreachable": true
}
server3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
server2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

No podemos acceder a "server1" ya que hemos especificado que el usuario para la conexión de Ansible será "vagrant" y actualmente en el nodo de control estamos trabajando con el usuario "linuxuser", por lo que podremos acceder a "server2" y "server3" pero no a "server1"



Si deseamos usar la misma configuración para varios servidores, podemos usar un grupo secundario para eso:

```yaml
[grupo_a]
192.168.10.50
192.168.10.51

[grupo_b]
192.168.10.52


[grupo_a:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=/home/vagrant/.ssh/id_rsa/custom_id
```

Esta configuración de ejemplo asignará un usuario personalizado y una clave SSH solo para conectarse a los servidores enumerados en "grupa_a".





## **Definición de objetivos para la ejecución de comandos**

Al ejecutar comandos "ad hoc" con Ansible, podemos actuar sobre hosts individuales, así como sobre una combinación de grupos, hosts y subgrupos. Por ejemplo, así es como verificaríamos la conectividad de cada host en un grupo llamado "servers":

```bash
ansible servers -i hosts -m ping
```

También podemos especificar varios hosts y grupos separándolos con dos puntos:

```bash
ansible server1:server2:dbservers -i hosts -m ping
```

Para incluir una excepción en un patrón, usaremos un signo de exclamación, precedido por el carácter de escape "\", de la siguiente manera. Este comando se ejecutará en todos los servidores del "group1", excepto en el "server2":

```bash
ansible group1:\!server2 -i hosts -m ping
```

En caso de que desee ejecutar un comando solo en servidores que forman parte del group1 y del group2, por ejemplo, debemos usar "&" en su lugar. Debemos ponerle el prefijo "\" carácter de escape:

```bash
ansible group1:\&group2 -i hosts -m ping
```



## **Ejecución de módulos de Ansible**

Los módulos de Ansible son fragmentos de código que se pueden invocar desde playbooks y también desde la línea de comandos para facilitar la ejecución de procedimientos en nodos remotos. Los ejemplos incluyen el módulo "apt", que se usa para administrar los paquetes del sistema en "Ubuntu", y el módulo "user", que se usa para administrar los usuarios del sistema. El comando "ping" también es un módulo, que generalmente se usa para probar la conexión desde el nodo de control a los hosts.

Para ejecutar un módulo con argumentos, debemos incluir el indicador -a seguido de las opciones apropiadas entre comillas dobles, así:

```bash
ansible "target"-i hosts -m "module"-a "module options"
```

Ejemplo, uso del módulo "apt" para instalar el paquete "tree" en "server1":

```bash
ansible server1 -i hosts -m apt -a "name=tree"
```



## **Ejecutar comandos Bash**

Cuando no se proporciona un módulo a través de la opción -m, el módulo "command" se usa de forma predeterminada para ejecutar el comando especificado en los servidores remotos.

Esto nos permite ejecutar prácticamente cualquier comando que normalmente podríamos ejecutar a través de un terminal SSH, siempre que el usuario que se conecte tenga permisos suficientes y no haya indicaciones interactivas.

Este sería un ejemplo del comando "uptime" en todos los servidores del inventario especificado:

```bash
ansible all -i hosts -a "uptime"


```



## **Escalada de privilegios para ejecutar comandos con sudo**

Si el comando o módulo que deseamos ejecutar en los hosts remotos requiere privilegios de sistema extendidos o un usuario de sistema diferente, deberemos usar la escalada de privilegios de Ansible.

Por ejemplo, si deseamos ejecutar el comando "tail" para ver los últimos mensajes de registro de errores de "Nginx" en un servidor llamado "server1", deberemos incluir la opción --become de la siguiente manera:

```bash
ansible server1 -i hosts -a "tail /var/log/nginx/error.log" --become
```

Esto sería el equivalente a ejecutar un comando "sudo tail /var/log/nginx/error.log" en el host remoto, usando el usuario del sistema local actual o el usuario remoto configurado dentro del archivo de inventario.

La escalada de privilegios, como "sudo", a menudo requieren que confirmemos nuestras credenciales solicitando que proporcionemos nuestra contraseña de usuario. Eso haría que Ansible fallara en la ejecución de un comando o playbook. Para evitar esto, podemos usar la opción "--ask-become-pass" o "-K" para que Ansible nos solicite esa contraseña de sudo:

```bash
ansible server1 -i hosts -a "tail /var/log/nginx/error.log" --become -K
```



## **Instalación y eliminación de paquetes**

El siguiente ejemplo usa el módulo "apt" para instalar el paquete "nginx" en todos los nodos del archivo de inventario:

```bash
ansible all -i hosts -m apt -a "name=nginx" --become -K
```

Para eliminar un paquete, debemos incluir el argumento "state" y configurarlo como "absent".

```bash
ansible all -i hosts -m apt -a "name=nginx state=absent" --become  -K
```



## **Copiando documentos**

Con el módulo "copy", puede copiar archivos entre el nodo de control y los nodos administrados, en cualquier dirección. El siguiente comando copia un archivo de texto local a todos los hosts remotos en el archivo de inventario especificado:

```bash
ansible all -i hosts -m copy -a "src=./file.txt dest=~/myfile.txt"
```

Para copiar un archivo desde el servidor remoto a su nodo de control, incluya la opción remote_src:

```bash
ansible all -i hosts -m copy -a "src=~/myfile.txt remote_src=yes dest=./file.txt"
```



## **Cambio de permisos de archivo**

Para modificar permisos en archivos y directorios en nodos remotos, puede usar el módulo "file".

El siguiente comando ajustará los permisos en un archivo llamado "file.txt" ubicado en /var/www en el host remoto. Establecerá el umask del archivo en 600, lo que habilitará los permisos de lectura y escritura solo para el propietario actual del archivo. Además, establecerá la propiedad de ese archivo en un usuario y un grupo llamado "vagrant":

```bash
ansible all -i hosts -m file -a "dest=/var/www/file.txt mode=600 owner=vagrant group=vagrant" --become  -K


```

Debido a que el archivo se encuentra en un directorio que normalmente es propiedad de root, es posible que necesitemos permisos sudo para modificar sus propiedades. Es por eso que incluimos las opciones --become y -K. Estos utilizarán el sistema de escalada de privilegios de Ansible para ejecutar el comando con privilegios extendidos y nos pedirá que proporcionemos la contraseña sudo para el usuario remoto.



## **Servicios de reinicio**

Podemos usar el módulo "service" para administrar los servicios que se ejecutan en los nodos remotos administrados por Ansible. Esto requerirá privilegios de sistema extendidos, así que debemos asegurarnos de que el usuario remoto tenga permisos sudo, por lo que debemos incluir la opción "--become" para usar el sistema de escalada de privilegios de Ansible. El uso de "-K" nos pedirá que proporcionemos la contraseña de sudo para el usuario que se conecta.

Para reiniciar el servicio nginx en todos los hosts en un grupo llamado "webservers", por ejemplo:

```bash
ansible webservers -i hosts -m service -a "name=nginx state=restarted" --become  -K
```



## **Reinicio de servidores**

Aunque Ansible no tiene un módulo dedicado para reiniciar servidores, podemos ejecutar un comando "bash" que llame al comando "/sbin/reboot" en el host remoto.

Reiniciar el servidor requerirá privilegios de sistema extendidos, así que debemos asegurarnos de que el usuario remoto tenga permisos "sudo" e incluir la opción "--become" para usar el sistema de escalada de privilegios de Ansible. El uso de "-K" nos pedirá que proporcionemos la contraseña de "sudo" para el usuario que se conecta.

La ejecución del comando sería como sigue:

```bash
ansible webservers -i hosts -a "/sbin/reboot"  --become  -K
```



## **Recopilación de información sobre nodos remotos**

El módulo "setup" devuelve información detallada sobre los sistemas remotos administrados por Ansible, también conocidos como "system facts".

Para obtener los "system facts" para el "server1", ejecutaremos:

```bash
ansible server1 -i hosts -m setup
```

Esto imprimirá una gran cantidad de datos JSON que contienen detalles sobre el entorno del servidor remoto. Para imprimir solo la información más relevante, podemos incluir el argumento "gather_subset=min" de la siguiente manera:

```bash
ansible server1 -i hosts -m setup -a "gather_subset=min"
```

Para imprimir solo elementos específicos del JSON, podemos usar el argumento de filtro. Esto aceptará un patrón comodín usado para hacer coincidir cadenas, similar a "fnmatch". Por ejemplo, para obtener información sobre las interfaces de red "ipv4" e "ipv6", podemos usar `*ipv*` como filtro:

```bash
ansible server1 -i hosts -m setup -a "filter=*ipv*"
```

```
server1 | SUCCESS => {
    "ansible_facts": {
        "ansible_all_ipv4_addresses": [
            "203.0.113.111", 
            "10.0.0.1"
        ], 
        "ansible_all_ipv6_addresses": [
            "fe80::a4f5:16ff:fe75:e758"
        ], 
        "ansible_default_ipv4": {
            "address": "203.0.113.111", 
            "alias": "eth0", 
            "broadcast": "203.0.113.111", 
            "gateway": "203.0.113.1", 
            "interface": "eth0", 
            "macaddress": "a6:f5:16:75:e7:58", 
            "mtu": 1500, 
            "netmask": "255.255.240.0", 
            "network": "203.0.113.0", 
            "type": "ether"
        }, 
        "ansible_default_ipv6": {}
    }, 
    "changed": false
}
```

Si desea verificar el uso del disco, podemos ejecutar un comando Bash llamando a la utilidad "df", de la siguiente manera:

```bash
ansible all -i hosts -a "df -h"
```

```
server1 | CHANGED | rc=0 >>
Filesystem      Size  Used Avail Use% Mounted on
udev            3.9G     0  3.9G   0% /dev
tmpfs           798M  624K  798M   1% /run
/dev/vda1       155G  2.3G  153G   2% /
tmpfs           3.9G     0  3.9G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/vda15      105M  3.6M  101M   4% /boot/efi
tmpfs           798M     0  798M   0% /run/user/0
```
