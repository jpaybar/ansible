# RHAAP: De la instalación a la automatización real

## Red Hat Ansible Automation Platform 2.4 — Configuración y puesta en marcha

###### Por Juan Manuel Payán Barea / jpaybar

[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

---

## Índice

1. [Descripción general](#1-descripción-general)
2. [Entorno](#2-entorno)
3. [Requisitos previos](#3-requisitos-previos)
4. [Estructura del proyecto](#4-estructura-del-proyecto)
5. [Filosofía de configuración en AAP](#5-filosofía-de-configuración-en-aap)
6. [Secuencia de configuración](#6-secuencia-de-configuración)
   - [Organización](#61-organización)
   - [Credencial SSH](#62-credencial-ssh)
   - [Inventario](#63-inventario)
   - [Proyecto](#64-proyecto)
   - [Colecciones requeridas](#65-colecciones-requeridas-requirementsyml)
   - [Test de conectividad](#66-test-de-conectividad-comando-ad-hoc)
   - [Plantilla de trabajo](#67-plantilla-de-trabajo)
   - [Lanzar el job](#68-lanzar-el-job-y-verificar-el-despliegue)
7. [Control de acceso basado en roles (RBAC)](#7-control-de-acceso-basado-en-roles-rbac)
8. [Execution Environments (EE)](#8-execution-environments-ee)
   - [EE moderno vs EE legacy](#81-ee-moderno-vs-ee-legacy)
   - [Configurar el EE legacy](#82-configurar-el-ee-legacy-ee-29-rhel8)
   - [Demostración de incompatibilidad](#83-demostración-de-incompatibilidad)
9. [Problemas conocidos y soluciones](#9-problemas-conocidos-y-soluciones)
10. [Documentación oficial](#10-documentación-oficial)

---

## 1. Descripción general

📌 Este proyecto documenta la **configuración inicial de Red Hat Ansible Automation Platform 2.4** una vez completada la instalación automatizada del laboratorio ([RHAAP_2.4_deployment](https://github.com/jpaybar/ansible/blob/main/RHAAP_2.4_deployment/README_es.md)).

El objetivo es llevar la plataforma desde un estado recién instalado hasta un entorno completamente operativo capaz de ejecutar automatizaciones reales. Se demuestra el ciclo completo: organización → credenciales → inventario → proyecto → plantilla de trabajo → ejecución, incluyendo RBAC con usuarios diferenciados y gestión de múltiples Execution Environments para playbooks modernos y legacy.

### ¿Qué se despliega?

Se utiliza el stack de WordPress en tres capas (proxy Nginx + Apache/PHP + MySQL) como carga de trabajo de referencia, ejecutado desde AAP contra VMs KVM/libvirt:

| Capa          | Servidor  | IP              | Rol                      |
| ------------- | --------- | --------------- | ------------------------ |
| Proxy         | `server1` | 192.168.122.35  | Nginx reverse proxy      |
| Web           | `server2` | 192.168.122.165 | Apache + PHP + WordPress |
| Base de datos | `server3` | 192.168.122.28  | MySQL                    |

Adicionalmente se despliega un stack WordPress LAMP en un único nodo (`server-legacy`, Ubuntu 18.04) usando un playbook legacy con Ansible 2.9 para demostrar la gestión simultánea de múltiples versiones de Ansible desde AAP.

---

## 2. Entorno

🧪 El laboratorio ha sido configurado y probado con la siguiente infraestructura:

### 🖥️ Sistema anfitrión

* SO: Ubuntu 24.04
* CPU: AMD Ryzen 5 3600 (6 núcleos)
* RAM: 32 GB
* Almacenamiento: SSD NVMe

### ⚙️ Plataforma AAP

| Componente     | Hostname                   | IP              | Rol                |
| -------------- | -------------------------- | --------------- | ------------------ |
| Controller     | rhaap-controller.lab.local | 192.168.122.101 | UI, API, scheduler |
| Execution node | rhaap-execution.lab.local  | 192.168.122.102 | Ejecución de jobs  |
| Database       | rhaap-database.lab.local   | 192.168.122.103 | PostgreSQL         |

### 💻 VMs destino (stack WordPress 3 capas)

| VM      | SO           | IP              | Rol                      |
| ------- | ------------ | --------------- | ------------------------ |
| server1 | Ubuntu 24.04 | 192.168.122.35  | Nginx reverse proxy      |
| server2 | Ubuntu 24.04 | 192.168.122.165 | Apache + PHP + WordPress |
| server3 | Ubuntu 24.04 | 192.168.122.28  | MySQL                    |

### 💻 VM destino (playbook legacy)

| VM            | SO           | IP             | Rol            |
| ------------- | ------------ | -------------- | -------------- |
| server-legacy | Ubuntu 18.04 | 192.168.122.99 | WordPress LAMP |

---

## 3. Requisitos previos

* RHAAP 2.4 instalado y operativo ([RHAAP_2.4_deployment](../RHAAP_2.4_deployment/README_es.md))
* VMs destino levantadas con `setup_target_vms.sh` (Ubuntu 24.04)
* VM legacy levantada con `setup_legacy_vm.sh` (Ubuntu 18.04)
* Acceso al portal Red Hat con suscripción Developer activa
* Repo [jpaybar/ansible](https://github.com/jpaybar/ansible) accesible desde el controller

---

## 4. Estructura del proyecto

```
RHAAP_2.4_configuration/
├── setup_target_vms.sh       # Levanta las 3 VMs destino Ubuntu 24.04
├── setup_legacy_vm.sh        # Levanta la VM legacy Ubuntu 18.04
├── hosts.yml                 # Inventario generado (VMs 3 capas)
├── hosts_legacy.yml          # Inventario generado (VM legacy)
├── pics/                     # Capturas de pantalla
├── README.md                 # Documentación en inglés
└── README_es.md              # Documentación en español
```

---

## 5. Filosofía de configuración en AAP

⚠️ Antes de empezar es fundamental entender la separación de responsabilidades en AAP. A diferencia de Ansible CLI donde todo va en el inventario o en `ansible.cfg`, en AAP cada concepto tiene su lugar:

| Concepto                    | Dónde va en AAP                   |
| --------------------------- | --------------------------------- |
| Hosts y grupos              | **Inventario**                    |
| Usuario SSH y clave privada | **Credencial de tipo Máquina**    |
| Playbooks y roles           | **Proyecto** (apuntando a GitHub) |
| Qué ejecutar y contra qué   | **Plantilla de trabajo**          |

Esto permite reutilizar cada elemento de forma independiente. Una misma credencial puede usarse en múltiples plantillas, igual que un inventario.

> ⚠️ El inventario de AAP **no debe contener** `ansible_user` ni `ansible_ssh_private_key_file`. Esas variables las gestiona AAP a través de las Credenciales.

---

## 6. Secuencia de configuración

### 6.1 Organización

`Acceso → Organizaciones → Añadir`

La organización es el contenedor principal de todos los recursos en AAP: inventarios, credenciales, proyectos y plantillas pertenecen siempre a una organización.

| Campo                  | Valor                                              |
| ---------------------- | -------------------------------------------------- |
| Nombre                 | `jpaybar`                                          |
| Descripción            | `Organización principal del laboratorio RHAAP 2.4` |
| Número máximo de hosts | (vacío, sin límite)                                |
| Credenciales de Galaxy | Ansible Galaxy (valor por defecto)                 |

![Organización](pics/organizacion.png)

---

### 6.2 Credencial SSH

`Recursos → Credenciales → Añadir`

Las credenciales de tipo **Máquina** almacenan de forma segura el usuario SSH y la clave privada. La clave nunca se expone en texto plano en los jobs.

| Campo                               | Valor                        |
| ----------------------------------- | ---------------------------- |
| Nombre                              | `jpaybar_ssh_key`            |
| Tipo de credencial                  | `Máquina`                    |
| Organización                        | `jpaybar`                    |
| Usuario                             | `ubuntu`                     |
| Clave privada SSH                   | Contenido de `~/.ssh/id_rsa` |
| Método de escalación de privilegios | `sudo`                       |

```bash
cat ~/.ssh/id_rsa
```

![Credencial SSH](pics/credencial_ssh.png)

---

### 6.3 Inventario

`Recursos → Inventarios → Añadir → Agregar inventario`

AAP soporta tres tipos de inventario:

| Tipo                               | Descripción                                                             |
| ---------------------------------- | ----------------------------------------------------------------------- |
| **Agregar inventario**             | Estático. Los hosts se definen manualmente.                             |
| **Agregar inventario inteligente** | Combina hosts de varios inventarios con filtros. Uso avanzado.          |
| **Add constructed inventory**      | Genera hosts dinámicamente según variables y condiciones. Uso avanzado. |

#### Configuración

| Campo            | Valor                                          |
| ---------------- | ---------------------------------------------- |
| Nombre           | `jpaybar_inventory`                            |
| Organización     | `jpaybar`                                      |
| Variables (YAML) | `ansible_python_interpreter: /usr/bin/python3` |

#### Grupos y hosts

| Grupo        | Host      | IP              |
| ------------ | --------- | --------------- |
| `proxy`      | `server1` | 192.168.122.35  |
| `webservers` | `server2` | 192.168.122.165 |
| `dbservers`  | `server3` | 192.168.122.28  |
| `wordpress`  | `server2` | 192.168.122.165 |

#### Variables por grupo

Con inventario manual en AAP, el `group_vars` del repo **no se carga automáticamente** — Ansible solo lo lee cuando usa un fichero de inventario. Las variables deben definirse en cada grupo:

**Grupo `proxy`:**

```yaml
---
app_server_ip: "{{ hostvars[groups['webservers'][0]]['ansible_host'] }}"
```

**Grupo `webservers`:**

```yaml
---
ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
```

**Grupo `dbservers`:**

```yaml
---
ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mysql_db_name: "wordpress"
mysql_user_name: "test"
mysql_user_password: "test"
```

**Grupo `wordpress`:**

```yaml
---
wp_db_host: "{{ hostvars[groups['dbservers'][0]]['ansible_host'] }}"
proxy_server: "{{ hostvars[groups['proxy'][0]]['ansible_host'] }}"
```

> 💡 **Solución correcta a futuro:** Configurar una **Fuente de inventario** apuntando al `hosts.yml` del repo. AAP cargará el inventario y el `group_vars` automáticamente, igual que desde CLI.

![Inventario](pics/inventario.png)

---

### 6.4 Proyecto

`Recursos → Proyectos → Añadir`

El proyecto conecta AAP con el repositorio GitHub donde están los roles y playbooks. AAP clona el repo en `/var/lib/awx/projects/`.

| Campo                     | Valor                                              |
| ------------------------- | -------------------------------------------------- |
| Nombre                    | `jpaybar_wordpress`                                |
| Organización              | `jpaybar`                                          |
| Tipo de fuente de control | `Git`                                              |
| URL                       | `https://github.com/jpaybar/ansible`               |
| Rama                      | `main`                                             |
| Opciones                  | ✅ Revisión de actualización durante el lanzamiento |

Una vez guardado, AAP sincroniza el repo automáticamente. Estado esperado: **✅ Correctamente**.

![Proyecto](pics/proyecto.png)

---

### 6.5 Colecciones requeridas: `requirements.yml`

AAP ejecuta los playbooks dentro de un Execution Environment que solo incluye las colecciones por defecto. El módulo `mysql_user` pertenece a `community.mysql` y no está incluido. Sin el fichero `requirements.yml` el job falla con:

```
ERROR! couldn't resolve module/action 'mysql_user'
```

**Fichero:** `collections/requirements.yml` (en la raíz del repo)

```yaml
---
collections:
  - name: community.mysql
  - name: community.general
```

> ⚠️ AAP busca el `requirements.yml` en `collections/requirements.yml` relativo a la raíz del proyecto. Si se coloca en un subdirectorio no lo detecta.

---

### 6.6 Test de conectividad (comando ad-hoc)

`Recursos → Inventarios → jpaybar_inventory → Hosts → Ejecutar comando`

Antes de lanzar el job real se verifica la conectividad SSH desde el execution node.

> 💡 **¿Qué es un comando ad-hoc?** Ejecuta un módulo de Ansible directamente contra hosts sin playbook. Equivale a `ansible all -m ping` desde CLI.

| Campo                | Valor                           |
| -------------------- | ------------------------------- |
| Módulo               | `ping`                          |
| Entorno de ejecución | `Default execution environment` |
| Credencial           | `jpaybar_ssh_key`               |

> ⚠️ El execution node tiene su propio `~/.ssh/known_hosts` vacío. El `StrictHostKeyChecking=no` en las variables de grupo es imprescindible para evitar timeouts por confirmación de fingerprint.

![Ping ad-hoc](pics/ping_adhoc.png)

---

### 6.7 Plantilla de trabajo

`Recursos → Plantillas → Añadir → Añadir plantilla de trabajo`

> 💡 **¿Qué es una Plantilla de flujo de trabajo?** Encadena Job Templates en secuencia con condiciones. Es el equivalente a un pipeline CI/CD. No se usa en este paso.

| Campo                | Valor                              |
| -------------------- | ---------------------------------- |
| Nombre               | `jpaybar_wordpress_deploy`         |
| Tipo de trabajo      | `Ejecutar`                         |
| Inventario           | `jpaybar_inventory`                |
| Proyecto             | `jpaybar_wordpress`                |
| Entorno de ejecución | `Default execution environment`    |
| Playbook             | `Ansible-roles/Playbooks/site.yml` |
| Credenciales         | `jpaybar_ssh_key`                  |

![Plantilla de trabajo](pics/plantilla_trabajo.png)

---

### 6.8 Lanzar el job y verificar el despliegue

`Recursos → Plantillas → jpaybar_wordpress_deploy → 🚀`

AAP delega la ejecución al **execution node** (`192.168.122.102`), no al controller. Resultado esperado: **✅ Correcto** con WordPress accesible en `http://192.168.122.35/wordpress`.

![Job exitoso](pics/job_exitoso.png)

---

## 7. Control de acceso basado en roles (RBAC)

Los usuarios en AAP se crean como tipo `Normal` y los privilegios se asignan mediante **roles sobre recursos concretos**, no a nivel de tipo de usuario.

### Tipos de usuario

| Tipo                        | Descripción                                     |
| --------------------------- | ----------------------------------------------- |
| `Normal`                    | Sin privilegios de sistema. Permisos via roles. |
| `Auditor del sistema`       | Solo lectura de todos los recursos de AAP.      |
| `Administrador del sistema` | Control total equivalente al usuario `admin`.   |

### Usuarios creados

`Acceso → Usuarios → Añadir`

| Usuario     | Tipo   | Organización |
| ----------- | ------ | ------------ |
| `operator`  | Normal | `jpaybar`    |
| `developer` | Normal | `jpaybar`    |

### Roles asignados

`Acceso → Usuarios → [usuario] → Roles → Añadir roles`

| Usuario     | Recurso                    | Tipo de recurso      | Rol       |
| ----------- | -------------------------- | -------------------- | --------- |
| `operator`  | `jpaybar_wordpress_deploy` | Plantilla de trabajo | `Execute` |
| `developer` | `jpaybar_wordpress_deploy` | Plantilla de trabajo | `Admin`   |
| `developer` | `jpaybar_wordpress`        | Proyecto             | `Uso`     |

### Verificación

* `operator` — solo ve la plantilla y puede lanzarla. No puede modificar nada ni acceder a credenciales, proyectos o inventarios.
* `developer` — puede ver y modificar la plantilla y usar el proyecto. No administra la plataforma.

![RBAC usuarios](pics/rbac_usuarios.png)

---

## 8. Execution Environments (EE)

Los Execution Environments son contenedores OCI que definen el entorno de ejecución: versión de Ansible, colecciones y dependencias Python. Permiten gestionar simultáneamente playbooks modernos y legacy sin conflictos de versiones.

### Tipos de EE en AAP 2.4

| EE                                    | Uso                                                |
| ------------------------------------- | -------------------------------------------------- |
| `Default execution environment`       | EE estándar. Ansible core más reciente.            |
| `Control Plane Execution Environment` | Uso interno del controller. **No usar para jobs.** |
| `Minimal execution environment`       | Sin colecciones. Para casos muy específicos.       |

### 8.1 EE moderno vs EE legacy

| EE            | Ansible core | Caso de uso                |
| ------------- | ------------ | -------------------------- |
| Default EE    | 2.15+        | Roles y playbooks actuales |
| `ee-29-rhel8` | 2.9          | Playbooks legacy sin FQCN  |

> 💡 **¿Qué son los FQCN?** A partir de Ansible 2.10 se recomienda usar el nombre completo del módulo (`ansible.builtin.apt` en lugar de `apt`). Los playbooks antiguos usan la forma corta, que fue eliminada definitivamente en ansible-core 2.16.

### 8.2 Configurar el EE legacy: `ee-29-rhel8`

Red Hat proporciona en su registry una imagen oficial con Ansible 2.9. No es necesario construir ni descargar imágenes manualmente — AAP lo gestiona automáticamente a través de las credenciales de registro.

#### Paso 1 — Crear credencial de registro

`Recursos → Credenciales → Añadir`

| Campo                | Valor                               |
| -------------------- | ----------------------------------- |
| Nombre               | `redhat_registry`                   |
| Tipo de credencial   | `Registro de contenedor`            |
| URL de autenticación | `registry.redhat.io`                |
| Usuario              | usuario Red Hat (portal.redhat.com) |
| Contraseña           | contraseña Red Hat                  |

#### Paso 2 — Registrar el EE en AAP

`Administración → Entornos de ejecución → Añadir`

| Campo                  | Valor                                                                            |
| ---------------------- | -------------------------------------------------------------------------------- |
| Nombre                 | `ee-29-rhel8`                                                                    |
| Imagen                 | `registry.redhat.io/ansible-automation-platform-21/ee-29-rhel8:latest`           |
| Extraer                | `Solo si no está presente`                                                       |
| Descripción            | `Ansible 2.9 - EE legacy para compatibilidad con playbooks anteriores a AAP 2.x` |
| Organización           | `jpaybar`                                                                        |
| Credencial de registro | `redhat_registry`                                                                |

**Opciones del campo Extraer:**

| Valor                      | Comportamiento                                         |
| -------------------------- | ------------------------------------------------------ |
| `Siempre`                  | Descarga la imagen del registry antes de cada job      |
| `Solo si no está presente` | Descarga solo la primera vez, reutiliza la copia local |
| `Nunca`                    | Asume que la imagen ya está en local, no descarga      |

![EE configurado](pics/ee_29_rhel8.png)

#### Paso 3 — VM legacy Ubuntu 18.04

```bash
./setup_legacy_vm.sh
```

El script verifica que la imagen base esté disponible e indica cómo descargarla si no está. Genera el inventario `hosts_legacy.yml` con la IP asignada por DHCP.

| Recurso | Valor                     |
| ------- | ------------------------- |
| vCPUs   | 2                         |
| RAM     | 2 GB                      |
| Disco   | 10 GB                     |
| SO      | Ubuntu 18.04 LTS (Bionic) |

#### Paso 4 — Inventario legacy

`Recursos → Inventarios → Añadir → Agregar inventario`

| Campo        | Valor                      |
| ------------ | -------------------------- |
| Nombre       | `jpaybar_inventory_legacy` |
| Organización | `jpaybar`                  |

Host añadido (`Hosts → Añadir`): `server-legacy` con `ansible_host: <IP asignada>`

#### Paso 5 — Plantilla de trabajo legacy

| Campo                | Valor                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------- |
| Nombre               | `jpaybar_wordpress_legacy`                                                               |
| Inventario           | `jpaybar_inventory_legacy`                                                               |
| Proyecto             | `jpaybar_wordpress`                                                                      |
| Entorno de ejecución | `ee-29-rhel8`                                                                            |
| Playbook             | `Ansible-playbooks/WORDPRESS_LAMP_ubuntu1804_2004/playbook.yml`                          |
| Credenciales         | `jpaybar_ssh_key`                                                                        |
| Variables            | `ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"` |

### 8.3 Demostración de incompatibilidad

El playbook legacy incluye `tasks/pre_checks.yml` con validaciones de sistema (RAM, disco, SO) invocado mediante `include` — sintaxis eliminada en ansible-core 2.16.

**Con `Default execution environment` (ansible-core 2.15+):**

```
ERROR! [DEPRECATED]: ansible.builtin.include has been removed.
Use include_tasks or import_tasks instead.
```

**Con `ee-29-rhel8` (Ansible 2.9):**

```
PLAY RECAP
server-legacy : ok=21 changed=9 unreachable=0 failed=0 skipped=4 rescued=0 ignored=1
```

Esto demuestra el valor real de gestionar múltiples EE en AAP: ejecutar el mismo playbook en el EE correcto sin modificar el código legacy.

![Fallo EE moderno](pics/fallo_ee_moderno.png)
![Éxito EE legacy](pics/exito_ee_legacy.png)

---

## 9. Problemas conocidos y soluciones

### ⚠️ `mysql_user` no encontrado

**Síntoma:** El job falla con `ERROR! couldn't resolve module/action 'mysql_user'`.

**Causa:** La colección `community.mysql` no está incluida en el EE por defecto.

**Solución:** Añadir `collections/requirements.yml` en la raíz del repo con `community.mysql` y `community.general`.

---

### ⚠️ Timeout de fingerprint SSH

**Síntoma:** Los jobs fallan con `Connection timed out during banner exchange`.

**Causa:** El execution node no ha conectado previamente a las VMs destino y espera confirmación de fingerprint de forma interactiva.

**Solución:** Añadir `StrictHostKeyChecking=no` y `UserKnownHostsFile=/dev/null` en las variables de grupo del inventario.

---

### ⚠️ El `group_vars` del repo no se carga en AAP

**Síntoma:** Variables definidas en `group_vars/` del repo no están disponibles en los jobs.

**Causa:** Con inventario manual en AAP, Ansible no busca `group_vars` en el repo — solo lo hace cuando usa un fichero de inventario.

**Solución:** Definir las variables manualmente en cada grupo del inventario de AAP, o configurar una Fuente de inventario apuntando al `hosts.yml` del repo.

---

## 10. Documentación oficial

📚 Para información técnica detallada sobre AAP 2.4:

🔗 https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4

| Recurso                   | URL                                                                                                                                                               |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Documentación AAP 2.4     | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4                                                                                  |
| Execution Environments    | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html/automation_controller_user_guide/assembly-controller-execution-environments |
| Red Hat Container Catalog | https://catalog.redhat.com/software/containers/search?q=ansible+execution+environment                                                                             |
| Portal Red Hat            | https://access.redhat.com                                                                                                                                         |
| Logs AAP                  | `/var/log/tower/`                                                                                                                                                 |
| Estado servicios AAP      | `automation-controller-service status`                                                                                                                            |

---

## 👤 Información del autor

**Juan Manuel Payán Barea** — Administrador de Sistemas | SysOps | Infraestructura IT

st4rt.fr0m.scr4tch@gmail.com  
GitHub: https://github.com/jpaybar  
LinkedIn: https://es.linkedin.com/in/juanmanuelpayan
