## Configurar el archivo de inventario

El *archivo de inventario* contiene información sobre los hosts que administremos con Ansible. Puede contener uno o multiples servidores  y los hosts pueden organizarse en grupos y subgrupos. El archivo de inventario a menudo se utiliza también para configurar variables que serán válidas sólo para hosts o grupos específicos, a fin de usarse dentro de los playbooks y las plantillas. Algunas variables también pueden afectar la forma en que se ejecuta un playbook, como la variable "ansible_python_interpreter".

El archivo se encuentra en la siguiente ruta `/etc/ansible/hosts` 

Ansible crea un archivo de inventario predeterminado en `etc/ansible/hosts`, aunque podemos crear archivos de inventario en cualquier ubicación que nos resulte conveniente. En este caso, deberemos proporcionar la ruta al archivo de inventario personalizado con el parámetro `-i` al ejecutar comandos y playbooks de Ansible. Por lo tanto podremos tener diferentes archivos de inventario para cada proyecto.

El archivo de inventario predeterminado proporcionado por la instalación de Ansible contiene varios ejemplos que podemos utilizar como referencias para configurar nuestro inventario. En el siguiente ejemplo se define un grupo llamado **[servers]** con tres servidores diferentes, cada uno identificado por un alias personalizado: **server1**, **server2** , **server3** y **server4**. 

```
[servers]
server1 ansible_host=192.168.10.50
server2 ansible_host=192.168.10.51
server3 ansible_host=192.168.10.52
server4 ansible_host=192.168.10.53

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

El subgrupo **[all:vars]** establece el parámetro de host "ansible_python_interpreter", que será válido para todos los hosts de este inventario. Este parámetro garantiza que el servidor remoto utilice el ejecutable `/usr/bin/python3` Python 3 en lugar de `/usr/bin/python` (Python 2.7), que no está presente en versiones recientes de Ubuntu.

Para consultar nuestro inventario, podremos ejecutar lo siguiente:

```bash
ansible-inventory --list -y
```

Para consultar un inventario personalizado llamado "hosts", use la opción `-i`

```bash
ansible-inventory -i hosts --list -y
```

Veremos un resultado similar a éste:

```
all:
  children:
    servers:
      hosts:
        server1:
          ansible_host: 192.168.10.50
          ansible_python_interpreter: /usr/bin/python3
        server2:
          ansible_host: 192.168.10.51
          ansible_python_interpreter: /usr/bin/python3
        server3:
          ansible_host: 192.168.10.52
          ansible_python_interpreter: /usr/bin/python3
        server4:
          ansible_host: 192.168.10.53
          ansible_python_interpreter: /usr/bin/python3
    ungrouped: {}
```

## Probando la conexión

Después de configurar el archivo de inventario para incluir los servidores, será el momento de verificar si Ansible es capaz de conectarse a estos y ejecutar comandos a través de SSH.

Podemos probar con la cuenta **root** de Ubuntu, dado que suele ser la única cuenta disponible por defecto en los servidores recién creados. Si hemos creado un usuario normal para usar sudo, se recomienda usar esta cuenta como alternativa.

Podemos usar el argumento `-u` para especificar el usuario del sistema remoto. Cuando no se proporcione, Ansible intentará conectarse con el usuario de sistema actual en el nodo de control.

Desde el nodo de control de Ansible, ejecutamos lo siguiente:

```bash
ansible all -m ping -u root
```

Este comando utilizará el módulo `ping` de Ansible para ejecutar una prueba de conectividad en todos los nodos del inventario predeterminado y se conectará como usuario root. El módulo `ping` probará lo siguiente:

- Si es posible acceder a los hosts;
- Si tenemos credenciales SSH válidas;
- Si los hosts pueden ejecutar módulos de Ansible utilizando Python.

El resultado deberá ser similar a este:

```
192.168.10.52 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.10.50 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.10.51 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.10.53 | UNREACHABLE! => {
    "changed": false,
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 192.168.10.53 port 22: Connection timed out",
    "unreachable": true
}
```

La máquina `192.168.10.53` es inalcanzable porque está apagada en este momento

## Ejecutar algunos comandos ad hoc

Después de confirmar que el nodo de control de Ansible puede comunicarse con sus hosts, podemos comenzar a ejecutar comandos ad hoc y playbooks en los servidores.

Cualquier comando que ejecutemos normalmente en un servidor remoto a través de SSH puede ejecutarse con Ansible. Como ejemplo, vamos a verificar la cantidad de espacio libre en disco en todos los servidores:

```bash
ansible all -a "df -h" -u root
```

```
192.168.10.50 | CHANGED | rc=0 >>
Filesystem            Size  Used Avail Use% Mounted on
udev                  222M     0  222M   0% /dev
tmpfs                  48M  964K   47M   2% /run
/dev/sda1              39G  2,3G   37G   6% /
tmpfs                 239M     0  239M   0% /dev/shm
tmpfs                 5,0M     0  5,0M   0% /run/lock
tmpfs                 239M     0  239M   0% /sys/fs/cgroup
/dev/loop0             33M   33M     0 100% /snap/snapd/12704
/dev/loop2             71M   71M     0 100% /snap/lxd/21029
/dev/loop1             56M   56M     0 100% /snap/core18/2128
/home/vagrant/python  238G   76G  163G  32% /home/vagrant/python
vagrant-root          238G   76G  163G  32% /vagrant
tmpfs                  48M     0   48M   0% /run/user/1000
192.168.10.52 | CHANGED | rc=0 >>
Filesystem            Size  Used Avail Use% Mounted on
udev                  222M     0  222M   0% /dev
tmpfs                  48M  956K   47M   2% /run
/dev/sda1              39G  2,2G   37G   6% /
tmpfs                 239M     0  239M   0% /dev/shm
tmpfs                 5,0M     0  5,0M   0% /run/lock
tmpfs                 239M     0  239M   0% /sys/fs/cgroup
/dev/loop0             56M   56M     0 100% /snap/core18/2128
/dev/loop1             33M   33M     0 100% /snap/snapd/12704
/dev/loop2             71M   71M     0 100% /snap/lxd/21029
/home/vagrant/python  238G   76G  163G  32% /home/vagrant/python
vagrant-root          238G   76G  163G  32% /vagrant
tmpfs                  48M     0   48M   0% /run/user/1000
```

Podriamos utilizar el módulo `apt` para instalar la última versión de `vim` en todos los servidores del inventario:

```bash
ansible all -m apt -a "name=vim state=latest" -u root
```

O comprobar el `uptime` de cada host en el grupo `servers` de la siguiente manera:

```bash
ansible servers -a "uptime" -u root
```

Tambien podemos especificar múltiples hosts separándolos con comas:

```bash
ansible server1:server2 -m ping -u root
```

## **Organización de servidores en grupos y subgrupos**

Dentro del archivo de inventario, podemos organizar los servidores en diferentes grupos y subgrupos. Esto nos ayudará a mantener un cierto orden, esta práctica nos permitirá usar variables de grupo, una función que puede facilitar enormemente la administración de múltiples entornos.

Un host puede ser parte de varios grupos. El siguiente archivo de inventario en formato INI muestra una configuración con tres grupos: servers, webservers, dbservers. 

```yaml
[servers]
server1 ansible_host=192.168.10.50
server2 ansible_host=192.168.10.51
server3 ansible_host=192.168.10.52

[webservers]
203.0.113.111
203.0.113.112

[dbservers]
203.0.113.113
server_hostname    #Alias creado en /etc/hosts
```

Si ejecutamos el comando anisble-inventory de la siguiente forma:

```bash
ansible-inventory -i playbooks_ubuntu1804_2004/hosts --list
```

El resultado debería ser algo parecido a lo siguiente:

```bash
{
    "_meta": {
        "hostvars": {
            "server1": {
                "ansible_host": "192.168.10.50",
                "ansible_python_interpreter": "/usr/bin/python3"
            },
            "server2": {
                "ansible_host": "192.168.10.51",
                "ansible_python_interpreter": "/usr/bin/python3"
            },
            "server3": {
                "ansible_host": "192.168.10.52",
                "ansible_python_interpreter": "/usr/bin/python3"
            }
        }
    },
    "all": {
        "children": [
            "dbservers",
            "servers",
            "ungrouped",
            "webservers"
        ]
    },
    "dbservers": {
        "hosts": [
            "203.0.113.113",
            "server_hostname"
        ]
    },
    "servers": {
        "hosts": [
            "server1",
            "server2",
            "server3"
        ]
    },
    "webservers": {
        "hosts": [
            "203.0.113.111",
            "203.0.113.112"
        ]
    }
}
```

## **Configuración de un alias de host**

Podemos usar alias para nombrar servidores de una manera que facilite la referencia a estos más adelante, cuando ejecutemos comandos y playbooks.

Para usar un alias, incluiremos una variable llamada "ansible_host" después del nombre del alias, que contenga la dirección IP o el nombre de host correspondiente del servidor que debe responder a ese alias:

```yaml
[servers]
server1 ansible_host=192.168.10.50
server2 ansible_host=192.168.10.51
server3 ansible_host=192.168.10.52
```

También podemos crear un grupo para agregar los hosts con configuraciones similares y luego configurar sus variables a nivel de grupo:

```yaml
[grupo_a]
server1 ansible_host=192.168.10.50
server2 ansible_host=192.168.10.51

[grupo_b]
server3 ansible_host=192.168.10.52
server4 ansible_host=server_hostname

[grupo_a:vars]
ansible_user=operador

[grupo_b:vars]
ansible_user=administrador
```

la salida del comando ansible-inventory sería similar a la siguiente:

```bash
{
    "_meta": {
        "hostvars": {
            "server1": {
                "ansible_host": "192.168.10.50",
                "ansible_user": "operador"
            },
            "server2": {
                "ansible_host": "192.168.10.51",
                "ansible_user": "operador"
            },
            "server3": {
                "ansible_host": "192.168.10.52",
                "ansible_user": "administrador"
            },
            "server4": {
                "ansible_host": "server_hostname",
                "ansible_user": "administrador"
            }
        }
    },
    "all": {
        "children": [
            "grupo_a",
            "grupo_b",
            "ungrouped"
        ]
    },
    "grupo_a": {
        "hosts": [
            "server1",
            "server2"
        ]
    },
    "grupo_b": {
        "hosts": [
            "server3",
            "server4"
        ]
    }
}
```

Como se puede observar, todas las variables de inventario se enumeran dentro del nodo "_meta" en la salida JSON producida por ansible-inventory.

Otras posibles variables en el fichero de inventario (ansible_host, ansible_user, ansible_ssh_private_key_file ):

```yaml
server1 ansible_host=192.168.10.50 ansible_user=user
server2 ansible_host=192.168.10.51

server3 ansible_host=192.168.10.52 ansible_ssh_private_key_file=/home/user/.ssh/id_rsa
server4 ansible_host=192.168.10.53
```

## **Uso de patrones en la ejecución de comandos y playbooks**

Al ejecutar comandos y playbooks con Ansible, debemos proporcionar un destino. Los patrones nos permiten apuntar a hosts, grupos o subgrupos específicos en el archivo de inventario, son muy flexibles y admiten expresiones regulares y comodines.

Consideremos el siguiente archivo de inventario:

```yaml
[webservers]
203.0.113.111
203.0.113.112

[dbservers]
203.0.113.113
server_hostname

[development]
203.0.113.111
203.0.113.113

[production]
203.0.113.112
server_hostname
```

En el caso que necesitaramos ejecutar un comando dirigido solo a los "dbservers" que se ejecutan en "production". En este ejemplo, solo hay uno "server_hostname" que coincide con ese criterio; sin embargo, podría darse el caso de que tengamos un gran grupo de "dbservers" de datos en ese grupo. En lugar de apuntar individualmente a cada servidor, podríamos usar el siguiente patrón:

```bash
ansible dbservers:\&production -m ping
```

El carácter "&" representa la operación lógica "Y", lo que significa que los objetivos válidos deben estar en ambos grupos. Debido a que este es un comando "ad hoc" que se ejecuta en Bash, debemos incluir el carácter "\" escape en la expresión.

El ejemplo anterior apuntaría solo a servidores que están presentes tanto en "dbservers" como en los grupos de producción "production". Si quisiera hacer lo contrario, apuntando solo a servidores que están presentes en "dbservers" pero no en el grupo de producción "production", usaríamos el siguiente patrón en su lugar:

```bash
ansible dbservers:\!production -m ping
```

Para indicar que un objetivo no debe estar en un grupo determinado, puede utilizar el "!" personaje. Una vez más, incluimos el carácter "\" escape en la expresión para evitar errores en la línea de comandos, ya que tanto "&" como "!" son caracteres especiales que Bash puede analizar.

La siguiente tabla contiene algunos ejemplos diferentes de patrones comunes que podemos usar al ejecutar comandos y playbooks con Ansible:

```xml
Patrón                  Resultado del objetivo

all                        Todos los equipos del fichero de inventario
host1                    Un solo equipo (host1)
host1:host2                Ambos equipos host1 y host2
group1                    Un solo grupo (group1)
group1:group2            Todos los servidores en (group1) y (group2)
group1:\&group2            Solo servidores que están tanto en el grupo 1 como en el grupo 2
group1:\!group2            Servidores en el grupo 1 excepto los que también están en el grupo 2
```

Para obtener opciones de patrones más avanzadas, como el uso de patrones posicionales y expresiones regulares para definir objetivos, podemos consultar la documentación oficial de Ansible sobre patrones.

https://docs.ansible.com/ansible/latest/user_guide/intro_patterns.html#advanced-pattern-options
