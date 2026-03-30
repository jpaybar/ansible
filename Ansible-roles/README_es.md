# Roles Ansible — Despliegue WordPress 3 Capas en OpenStack

###### Por Juan Manuel Payán Barea / jpaybar

st4rt.fr0m.scr4tch@gmail.com

---

## 📌 Descripción general

Este proyecto automatiza el despliegue completo de un stack WordPress sobre una arquitectura de tres capas corriendo en OpenStack, usando roles Ansible modulares y reutilizables.

La infraestructura subyacente (instancias, redes, routers, IPs flotantes y grupos de seguridad) está gestionada por un proyecto Terraform separado. Una vez que la infraestructura está levantada, este proyecto se encarga del provisionamiento software completo: proxy inverso, servidor web, runtime PHP, WordPress y base de datos.

El proyecto aborda varios retos del mundo real que raramente se tratan en tutoriales: inventario dinámico de OpenStack sin prefijos en los nombres de grupo, acceso SSH encadenado mediante ProxyJump a través de múltiples redes aisladas, y separación limpia entre la lógica del rol y los datos específicos del entorno mediante `group_vars`.

---

## 🧪 Entorno

### ☁️ Infraestructura

| Componente     | Detalles                                       |
| -------------- | ---------------------------------------------- |
| Plataforma     | OpenStack                                      |
| Instancias     | Ubuntu Server 24.04                            |
| Flavor         | `m1.custom` — 1 vCPU, 1024 MB RAM, 10 GB disco |
| Redes          | 3 redes aisladas: net1, net2, net3             |
| Acceso externo | IP flotante solo en server1                    |

### 🖥️ Nodo de control

| Componente | Detalles                          |
| ---------- | --------------------------------- |
| SO         | Ubuntu 24.04                      |
| Ansible    | `ansible-core` última versión     |
| Colección  | `openstack.cloud`                 |
| Auth       | `~/.config/openstack/clouds.yaml` |

---

## 🌐 Arquitectura — Flujo de red multicapa

Este despliegue sigue una arquitectura estricta de tres capas. Cada capa corre en una red OpenStack aislada, y el tráfico fluye en una única dirección.

```
Internet
    │
    │  HTTPS (443) — SSL autofirmado
    │  HTTP  (80)  — redirigido a HTTPS
    ▼
┌──────────────────────────────────────┐
│  server1                             │  net1: 192.168.1.0/24
│  Proxy inverso Nginx                 │  IP flotante (punto de entrada público)
│  Certificado SSL autofirmado         │
└────────────────┬─────────────────────┘
                 │  proxy_pass → HTTPS (443) → server2
                 ▼
┌──────────────────────────────────────┐
│  server2                             │  net2: 192.168.2.0/24
│  Apache2 + PHP-fpm + WordPress       │  Certificado SSL autofirmado
│  Sin IP flotante                     │
└────────────────┬─────────────────────┘
                 │  TCP 3306 → server3
                 ▼
┌──────────────────────────────────────┐
│  server3                             │  net3: 192.168.3.0/24
│  MySQL                               │  Sin IP flotante
└──────────────────────────────────────┘
```

**Decisiones clave de red:**

- server1 es la única instancia con IP flotante. Termina el SSL externo (Nginx) y reenvía las peticiones a server2 por HTTPS mediante `proxy_pass`.
- server2 ejecuta Apache2 con su propio certificado autofirmado. No tiene IP pública — solo es alcanzable desde server1 a través de la red interna.
- server3 acepta conexiones en el puerto 3306 exclusivamente desde net2. Completamente aislado del exterior.
- Los routers de OpenStack para net2 y net3 requieren `external_network_id` para habilitar SNAT, permitiendo que ambos servidores lleguen a internet para la instalación de paquetes durante el provisionamiento — aunque no tengan IP flotante.

---

## 🔗 Dependencia: Proyecto Terraform

Este proyecto Ansible **requiere** que la infraestructura esté desplegada previamente con el proyecto Terraform asociado:

🔗 [Terraform_project-02-base-infra-terraform](https://github.com/jpaybar/Terraform_project-02-base-infra-terraform)

El proyecto Terraform se encarga de:

- Crear las tres instancias con metadatos semánticos de Nova (`role`, `application`, `environment`)
- Asignar IPs fijas por red y la IP flotante en server1
- Crear y adjuntar grupos de seguridad (puertos 22, 80, 443, 3306)
- Configurar routers y redes con las reglas SNAT correctas

Los metadatos Nova definidos por Terraform son el puente entre ambos proyectos: el inventario dinámico de Ansible lee esos metadatos para construir los grupos automáticamente — sin necesidad de configurar IPs manualmente.

**Salida de `terraform apply` — IPs asignadas:**

![Terraform output](pics/01-Terraform_output_final.png)

**OpenStack Horizon — instancias en ejecución:**

![OpenStack instancias](pics/02-Openstack_instancias.png)

**OpenStack Horizon — topología de red:**

![OpenStack topología](pics/03-Openstack_topologia_red.png)

---

## 📂 Estructura del proyecto

```
Ansible-roles/
├── ansible.cfg                          # Configuración SSH y conexión
├── ansible_provision.sh                 # Script pre-vuelo (ejecutar con source)
├── Inventories/
│   ├── openstack.yml                    # Configuración del plugin de inventario dinámico
│   ├── hosts.yml                        # Inventario estático (fallback / referencia)
│   └── group_vars/
│       ├── proxy.yml                    # Variables para la capa de proxy inverso
│       ├── webservers.yml               # Configuración SSH ProxyJump para server2
│       ├── dbservers.yml                # SSH doble salto para server3 + variables BD
│       └── wordpress.yml                # Variables de runtime de WordPress
├── Playbooks/
│   ├── site.yml                         # Playbook principal — despliegue del stack completo
│   ├── apache_role_playbook.yml         # Playbooks individuales por rol (para pruebas)
│   ├── mysql_role_playbook.yml
│   ├── nginx-proxy_role_playbook.yml
│   ├── php-fpm_role_playbook.yml
│   └── wordpress_role_playbook.yml
└── Roles/
    ├── jpaybar.Nginx_Proxy/             # Proxy inverso + SSL autofirmado + redirección HTTP→HTTPS
    ├── jpaybar.Apache2/                 # Apache2 + SSL autofirmado
    ├── jpaybar.Php-fpm/                 # Runtime PHP-fpm
    ├── jpaybar.Wordpress/               # Descarga, configuración y despliegue de WordPress
    └── jpaybar.Mysql/                   # MySQL, creación de base de datos y usuario
```

---

## 🎭 Roles Ansible

Todos los roles siguen la convención de nomenclatura `jpaybar.NombreRol` y están diseñados para ser **portables e independientes de la infraestructura**. Ningún rol contiene IPs, hostnames ni credenciales hardcodeadas — todos los datos específicos del entorno provienen de `group_vars/`.

Cada rol soporta múltiples versiones de Ubuntu (18.04, 20.04, 22.04, 24.04) mediante ficheros de variables específicos por SO, cargados en tiempo de ejecución con `include_tasks`.

| Rol                   | Responsabilidad                                                                                                                               |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `jpaybar.Nginx_Proxy` | Instala Nginx, genera certificado SSL autofirmado, despliega el VirtualHost con redirección HTTP→HTTPS y `proxy_pass` hacia server2 por HTTPS |
| `jpaybar.Apache2`     | Instala Apache2, genera certificado SSL autofirmado, configura el VirtualHost para WordPress                                                  |
| `jpaybar.Php-fpm`     | Instala PHP-fpm y los módulos requeridos por WordPress, con versión adaptada a la release de Ubuntu                                           |
| `jpaybar.Wordpress`   | Descarga WordPress, despliega `wp-config.php` desde una plantilla Jinja2 poblada con valores de `group_vars`                                  |
| `jpaybar.Mysql`       | Instala MySQL, crea la base de datos y el usuario, configura `bind-address` para aceptar conexiones remotas desde net2                        |

### Playbook principal — `Playbooks/site.yml`

```yaml
---
- hosts: dbservers
  become: true
  roles:
    - ../Roles/jpaybar.Mysql

- hosts: webservers
  become: true
  roles:
    - ../Roles/jpaybar.Apache2
    - ../Roles/jpaybar.Php-fpm

- hosts: wordpress
  become: true
  roles:
    - ../Roles/jpaybar.Wordpress

- hosts: proxy
  become: true
  roles:
    - ../Roles/jpaybar.Nginx_Proxy
```

El orden de despliegue es intencional: primero la base de datos, luego el servidor web y PHP, después WordPress (que necesita la base de datos ya configurada), y finalmente el proxy (que necesita conocer la IP de server2). Los grupos `dbservers`, `webservers`, `wordpress` y `proxy` coinciden exactamente con los grupos generados por el inventario dinámico a partir de los metadatos de Terraform.

---

## 📋 Inventario dinámico de OpenStack

### Por qué inventario dinámico

En un entorno cloud, las IPs cambian con cada `terraform apply`. Un inventario estático con IPs hardcodeadas se vuelve inválido tras cada redespliegue. El plugin `openstack.cloud.openstack` resuelve esto consultando la API de OpenStack en tiempo de ejecución — el inventario siempre está sincronizado con la infraestructura real.

### Configuración del plugin — `Inventories/openstack.yml`

```yaml
plugin: openstack.cloud.openstack
cloud: openstack
expand_hostvars: true
fail_on_errors: true
legacy_groups: false

compose:
  ansible_user: "'ubuntu'"
  ansible_ssh_private_key_file: "'~/.ssh/id_rsa'"
  ansible_python_interpreter: "'/usr/bin/python3'"

groups:
  proxy:      openstack.metadata.role == 'proxy'
  webservers: openstack.metadata.role == 'webserver'
  dbservers:  openstack.metadata.role == 'database'
  wordpress:  openstack.metadata.get('application') == 'wordpress'
  production: openstack.metadata.environment == 'production'
```

### El problema del prefijo en `keyed_groups`

`keyed_groups` es la opción más documentada para agrupar hosts por metadatos en OpenStack, pero siempre añade un prefijo al nombre del grupo que no se puede eliminar. Por ejemplo, si los metadatos de la instancia son `role=proxy`, el nombre de grupo generado es `meta-proxy` — nunca simplemente `proxy`.

Esto rompe la correspondencia directa entre grupos del inventario, nombres de directorios en `group_vars/` y targets de hosts en `site.yml`, obligando a workarounds en todas las capas.

**Solución:** usar `groups` con condiciones Jinja2 en lugar de `keyed_groups`. Con `groups`, el operador define el nombre exacto del grupo — sin prefijo, sin sufijo, sin postprocesado.

### `legacy_groups: false`

Sin esta opción, el plugin genera automáticamente docenas de grupos basados en nombres de instancia, flavors, imágenes e IDs de tenant. El resultado es un inventario ilegible lleno de entradas irrelevantes. Deshabilitar los grupos legacy es imprescindible en cualquier proyecto real.

### Verificar el inventario

```bash
# Vista en árbol de grupos y hosts
ansible-inventory -i Inventories/openstack.yml --graph

# Salida esperada:
# @all:
#   |--@proxy:
#   |  |--server1
#   |--@webservers:
#   |  |--server2
#   |--@dbservers:
#   |  |--server3
#   |--@wordpress:
#   |  |--server2
#   |--@production:
#   |  |--server1
#   |  |--server2
#   |  |--server3

# Salida completa con variables de host resueltas
ansible-inventory -i Inventories/openstack.yml --list
```

**Inventario dinámico resuelto — estructura de grupos limpia a partir de metadatos de OpenStack:**

![Inventario dinámico](pics/04-Inventario_dinamico_ansible.png)

---

## 📁 `group_vars` — Separación de responsabilidades

### Principio de diseño

Un rol Ansible es un **componente reutilizable**. Un rol que embebe IPs o credenciales queda atado a un único entorno y no puede reutilizarse sin modificaciones. La separación estricta entre **lógica del rol** y **datos del entorno** es lo que hace a un rol verdaderamente portable.

La convención usada en este proyecto:

- `Roles/jpaybar.X/defaults/` — valores por defecto genéricos (puertos estándar, nombres de paquetes)
- `Roles/jpaybar.X/vars/` — variables internas del rol, no destinadas a ser sobreescritas
- `Inventories/group_vars/` — **todo lo específico del entorno**: IPs, credenciales, argumentos de conexión SSH

### `group_vars/proxy.yml` — Capa de proxy inverso

```yaml
---
app_server_ip: "{{ hostvars[groups['webservers'][0]]['ansible_host'] }}"
```

La IP de server2 nunca está hardcodeada. Se resuelve dinámicamente en tiempo de ejecución desde el inventario usando `hostvars`. Si la IP cambia tras un `terraform destroy/apply`, no hay que editar ningún fichero — el inventario dinámico actualiza el valor automáticamente.

### `group_vars/webservers.yml` — Acceso SSH a la capa web

```yaml
---
ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o ProxyJump=ubuntu@{{ hostvars[groups['proxy'][0]]['ansible_host'] }}"
```

server2 no tiene IP flotante. Esta variable indica a Ansible que llegue a server2 saltando a través de server1. La IP flotante de server1 se resuelve dinámicamente desde el inventario.

### `group_vars/dbservers.yml` — Acceso SSH a la capa de base de datos (doble salto)

```yaml
---
ansible_ssh_common_args: >-
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ForwardAgent=yes
  -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o ForwardAgent=yes -W %h:%p
     -J ubuntu@{{ hostvars[groups['proxy'][0]]['ansible_host'] }}
     ubuntu@{{ hostvars[groups['webservers'][0]]['ansible_host'] }}"

mysql_db_name: "wordpress"
mysql_user_name: "test"
mysql_user_password: "test"
```

server3 está en net3 — una red no accesible directamente desde server1. La cadena de conexión es: **máquina local → server1 (IP flotante) → server2 (net2) → server3 (net3)**. Este doble salto requiere un `ProxyCommand` con un flag `-J` embebido, combinado con `ForwardAgent=yes` para propagar la clave SSH a través de todos los saltos sin copiar la clave privada a ningún servidor intermedio.

### `group_vars/wordpress.yml` — Variables de runtime de WordPress

```yaml
---
wp_db_host: "{{ hostvars[groups['dbservers'][0]]['ansible_host'] }}"
proxy_server: "{{ hostvars[groups['proxy'][0]]['ansible_host'] }}"
```

Tanto el host de la base de datos como la IP del proxy usados en `wp-config.php` se resuelven dinámicamente. La plantilla Jinja2 `wp-config.php.j2` consume estas variables directamente — sin edición manual entre despliegues.

### Índice de grupo en `hostvars` vs referencia por nombre de host

Usar `hostvars['server2']['ansible_host']` acopla el rol a un nombre de instancia concreto en OpenStack. Si la instancia se renombra, el rol falla silenciosamente. Usar `hostvars[groups['webservers'][0]]['ansible_host']` siempre resuelve el primer host del grupo — resistente a renombrados de instancia y redespliegues completos.

---

## 🔑 Acceso SSH multi-salto con ProxyJump

### El problema

server2 y server3 no tienen IP flotante. Solo son accesibles desde dentro de las redes internas de OpenStack. Ansible necesita llegar a ellos desde la máquina local, que está fuera de esas redes.

La solución es usar server1 como bastión SSH: la máquina local se conecta a server1 mediante su IP flotante, y desde ahí salta a server2 o server3 a través de las IPs de red interna.

### `ansible.cfg` — Configuración de conexión

```ini
[defaults]
host_key_checking = False
timeout = 60

[privilege_escalation]
become_timeout = 60

[ssh_connection]
# Cubre la verificación de clave de host a nivel SSH para todas las conexiones
# incluyendo los intermediarios de ProxyJump.
# host_key_checking=False solo afecta a la conexión Ansible final, no a los
# procesos SSH hijo generados para los saltos intermedios.
ssh_args = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

### Por qué importa `~/.ssh/config` con ProxyJump

Cuando Ansible establece una conexión ProxyJump, genera procesos SSH hijo para gestionar los saltos intermedios. Estos procesos hijo **no heredan** `ansible_ssh_common_args` de `ansible.cfg` ni de `group_vars` — leen `~/.ssh/config` directamente.

Si `StrictHostKeyChecking` no está deshabilitado ahí, el proceso hijo falla al verificar la clave de host del bastión — especialmente tras un `terraform destroy/apply` que recrea instancias con nuevas claves SSH. El script `ansible_provision.sh` asegura que las entradas necesarias estén presentes en `~/.ssh/config` antes de ejecutar el playbook.

### Propagación de clave SSH — Agent Forwarding

Las instancias de OpenStack se crean con la clave pública inyectada vía cloud-init. La clave privada nunca necesita copiarse a ningún servidor. En su lugar, `ForwardAgent=yes` propaga las credenciales del agente SSH local a lo largo de toda la cadena de conexión, de forma que cada salto se autentica con la misma clave ya cargada en el agente local.

```bash
# Cargar la clave en el agente SSH local antes de ejecutar el playbook
ssh-add ~/.ssh/id_rsa
```

---

## ⚙️ Script pre-vuelo — `ansible_provision.sh`

El script automatiza los pasos necesarios antes de lanzar el playbook y garantiza que el entorno SSH esté correctamente configurado.

```bash
#!/bin/bash

SSH_CONFIG="$HOME/.ssh/config"

declare -A SSH_HOSTS=(
    ["172.20.0.*"]=""
    ["192.168.1.*"]=""
    ["192.168.2.*"]=""
    ["192.168.3.*"]=""
)

for host in "${!SSH_HOSTS[@]}"; do
    if ! grep -q "Host $host" "$SSH_CONFIG"; then
        echo "" >> "$SSH_CONFIG"
        echo "Host $host" >> "$SSH_CONFIG"
        echo "    StrictHostKeyChecking no" >> "$SSH_CONFIG"
        echo "    UserKnownHostsFile /dev/null" >> "$SSH_CONFIG"
        echo "SSH entry added for $host"
    fi
done

ssh-add ~/.ssh/id_rsa

ansible-playbook -i Inventories/openstack.yml Playbooks/site.yml
```

> ⚠️ **Este script debe ejecutarse con `source`**, no con `bash`:
> 
> ```bash
> source ansible_provision.sh
> ```
> 
> Ejecutarlo como subproceso (`bash ansible_provision.sh`) genera un shell hijo. El `ssh-add` dentro de él carga la clave en el agente del shell hijo, que se destruye al salir el subproceso. El shell padre — donde Ansible realmente corre — nunca ve la clave cargada. Usar `source` ejecuta todos los comandos en el contexto del shell actual, que es el que Ansible utiliza.

**Ejecución del script pre-vuelo — agente SSH cargado, playbook lanzado:**

![ansible_provision.sh](pics/05-Ansible_provision_script.png)

---

## 🚀 Uso

### Prerequisitos

- Infraestructura OpenStack desplegada con el proyecto Terraform asociado
- Colección `openstack.cloud` instalada:

```bash
ansible-galaxy collection install openstack.cloud
```

- `clouds.yaml` con credenciales OpenStack en `~/.config/openstack/clouds.yaml`
- Clave SSH registrada en OpenStack y disponible localmente en `~/.ssh/id_rsa`

### Despliegue completo

```bash
# 1. Clonar el repositorio
git clone https://github.com/jpaybar/Ansible-roles.git
cd Ansible-roles

# 2. Verificar que el inventario dinámico se resuelve correctamente
ansible-inventory -i Inventories/openstack.yml --graph

# 3. Ejecutar el script pre-vuelo
source ansible_provision.sh
```

### Verificación post-despliegue

```bash
# Ping a todos los hosts a través de la cadena ProxyJump
ansible -i Inventories/openstack.yml all -m ping

# Comprobar que WordPress es accesible por HTTPS
curl -k https://<FLOATING_IP>

# Verificar que HTTP redirige a HTTPS
curl -I http://<FLOATING_IP>
```

**Ansible Play Recap — 0 fallos en los 3 hosts:**

![Play Recap](pics/06-Play_recap.png)

---

## 🧠 Decisiones de diseño

### `groups` vs `keyed_groups` en el inventario dinámico

`keyed_groups` es la opción más documentada para agrupar por metadatos en OpenStack, pero siempre produce nombres de grupo con prefijos (`meta-proxy`, `openstack_proxy`) que no pueden eliminarse. Esto fuerza una nomenclatura divergente entre grupos del inventario, nombres de directorios en `group_vars/` y targets de hosts en `site.yml` — un problema de mantenimiento en todas las capas.

Usar `groups` con condiciones Jinja2 da control total sobre los nombres de grupo. El mismo nombre se usa de forma consistente en inventario, `group_vars` y playbooks.

### Variables del rol vs `group_vars`

Poner IPs o credenciales en `vars/` o `defaults/` de un rol ata ese rol a un único entorno. Cualquier cambio en la infraestructura obliga a modificar el rol. Mantener todos los datos específicos del entorno en `group_vars/` significa que los roles no se tocan entre despliegues — solo cambia el inventario.

### Índice de grupo en `hostvars` vs nombre de instancia

`hostvars['server2']['ansible_host']` se rompe si la instancia se renombra en OpenStack. `hostvars[groups['webservers'][0]]['ansible_host']` siempre resuelve el primer host del grupo — resistente a renombrados de instancia y redespliegues completos.

### Doble salto SSH para server3

server3 está en net3, que no es directamente accesible desde server1. Un simple `ProxyJump` solo cubre un salto de red. El `ProxyCommand` con el flag `-J` embebido construye la cadena completa: local → server1 → server2 → server3. `ForwardAgent=yes` garantiza que la clave SSH esté disponible en cada paso sin copiar la clave privada a ningún servidor intermedio.

### Routers OpenStack y SNAT

Los routers de net2 y net3 requieren `external_network_id` en Terraform aunque server2 y server3 no tengan IP flotante. Sin él, OpenStack no configura SNAT, y esas instancias no tienen salida a internet — provocando que `apt install` falle silenciosamente durante el provisionamiento con Ansible. Esta es una mala configuración habitual en setups OpenStack multi-red.

### `source` vs `bash` para el script de provisionamiento

Ejecutar `bash ansible_provision.sh` genera un subshell. El `ssh-add` dentro de él carga la clave en el agente del subshell, que se destruye al salir. El shell padre — donde Ansible realmente corre — nunca ve la clave. `source` ejecuta los comandos en el shell actual, por lo que el estado del agente persiste correctamente.

---

## 📸 Resultado del despliegue

**Proxy inverso Nginx — certificado SSL autofirmado servido por HTTPS:**

![Certificado autofirmado](pics/07-Certificado_autofirmado_nginx.png)

**Asistente de instalación de WordPress — accesible a través del proxy Nginx:**

![WordPress site](pics/08-Wordpress_site.png)

---

## 📚 Referencias

- [Ansible — plugin de inventario openstack.cloud.openstack](https://docs.ansible.com/ansible/latest/collections/openstack/cloud/openstack_inventory.html)
- [OpenStack SDK — configuración de clouds.yaml](https://docs.openstack.org/openstacksdk/latest/user/config/configuration.html)
- [Jeff Geerling — Ansible for DevOps](https://www.ansiblefordevops.com/)
- [Proyecto Terraform asociado](https://github.com/jpaybar/Terraform_project-02-base-infra-terraform)

---

## 👤 Información del autor

**Juan Manuel Payán Barea**
Administrador de Sistemas | SysOps | Infraestructura IT

st4rt.fr0m.scr4tch@gmail.com

GitHub: https://github.com/jpaybar
LinkedIn: https://es.linkedin.com/in/juanmanuelpayan
