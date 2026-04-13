# RHAAP: Automatización con Ansible a nivel empresarial

## Red Hat Ansible Automation Platform 2.4

###### Por Juan Manuel Payán Barea / jpaybar

[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

---

## Índice

1. [Descripción general](#1-descripción-general)
2. [Entorno](#2-entorno)
3. [Requisitos previos](#3-requisitos-previos)
4. [Estructura del proyecto](#4-estructura-del-proyecto)
5. [Fichero `.env`](#5-fichero-env)
6. [Script `deploy-rhaap-lab.sh`](#6-script-deploy-rhaap-labsh)
   - [Validaciones previas](#61-validaciones-previas)
   - [Recursos de las VMs](#62-recursos-de-las-vms)
   - [Configuración SSH del host](#63-configuración-ssh-del-host)
   - [Cloud-init por VM](#64-cloud-init-por-vm)
   - [Despliegue de VMs](#65-despliegue-de-vms)
7. [Script `prepare-rhaap-install.sh`](#7-script-prepare-rhaap-installsh)
   - [Espera de cloud-init](#71-espera-de-cloud-init)
   - [Distribución de claves SSH entre VMs](#72-distribución-de-claves-ssh-entre-vms)
   - [Copia y verificación del bundle](#73-copia-y-verificación-del-bundle)
   - [Procesado del inventario](#74-procesado-del-inventario)
   - [Descompresión y colocación del inventario](#75-descompresión-y-colocación-del-inventario)
8. [Script `main.sh` — Punto de entrada único](#8-script-mainsh--punto-de-entrada-único)
9. [Fichero `inventory`](#9-fichero-inventory)
10. [Lanzar la instalación](#10-lanzar-la-instalación)
11. [Primeros pasos tras la instalación](#11-primeros-pasos-tras-la-instalación)
    - [Suscripción de AAP](#paso-1--suscripción-de-aap)
    - [Usuario y Automation Analytics](#paso-2--usuario-y-automation-analytics)
    - [Acuerdo de licencia (EULA)](#paso-3--acuerdo-de-licencia-eula)
    - [Verificaciones iniciales](#post-wizard-verificaciones-iniciales)
    - [Estructura básica de AAP](#paso-4--estructura-básica-de-aap--flujo-de-configuración-inicial)
12. [Problemas conocidos y soluciones](#12-problemas-conocidos-y-soluciones)
13. [Documentación oficial](#13-documentación-oficial)

---

## 1. Descripción general

📌 Este proyecto proporciona un despliegue completamente automatizado de **Red Hat Ansible Automation Platform 2.4** sobre tres máquinas virtuales KVM/libvirt con RHEL 9.7.

Incluye el provisionamiento de las VMs mediante cloud-init, la preparación del entorno y el despliegue de AAP 2.4 mediante un enfoque reproducible y basado en scripts Bash.

El objetivo es simplificar el proceso de instalación ofreciendo a la vez un entorno práctico para aprendizaje, pruebas y experimentación con la plataforma de automatización empresarial de Red Hat.

> **¿Por qué AAP 2.4 y no 2.5?**  
> AAP 2.5 impone una topología *Growth* que requiere un nodo *gateway* separado, elevando a cuatro el mínimo de VMs y superando los límites prácticos de RAM del host sobre el que se crea la infraestructura. AAP 2.4 permite un despliegue funcional con tres nodos.

### Arquitectura

| VM         | Hostname                   | IP              | Rol                                        |
| ---------- | -------------------------- | --------------- | ------------------------------------------ |
| controller | rhaap-controller.lab.local | 192.168.122.101 | Automation Controller (UI, API, scheduler) |
| execution  | rhaap-execution.lab.local  | 192.168.122.102 | Execution Node (ejecución de jobs)         |
| database   | rhaap-database.lab.local   | 192.168.122.103 | PostgreSQL (gestionado por el installer)   |

* **Red:** `default` (NAT de libvirt, `192.168.122.0/24`)
* **IPs estáticas:** reservadas en el DHCP de dnsmasq mediante MACs fijas
* **SO invitado:** RHEL 9.7 (imagen KVM cloud `.qcow2`)
* **Aprovisionamiento inicial:** cloud-init (user-data)

---

## 2. Entorno

🧪 El despliegue ha sido probado con la siguiente configuración:

### 🖥️ Sistema anfitrión

* SO: Ubuntu 24.04
* CPU: AMD Ryzen 5 3600 (6 núcleos)
* RAM: 32 GB
* Almacenamiento: SSD NVMe

### ⚙️ Virtualización

* Hipervisor: KVM (libvirt)
* Red: Red `default` de libvirt (NAT, `192.168.122.0/24`)
* IPs estáticas via reservas DHCP en dnsmasq

### 💻 Máquinas virtuales

| VM         | vCPU | RAM  | Disco |
| ---------- | ---- | ---- | ----- |
| controller | 2    | 8 GB | 40 GB |
| execution  | 2    | 4 GB | 20 GB |
| database   | 2    | 4 GB | 20 GB |

* SO: RHEL 9.7 (imagen KVM cloud `.qcow2`)
* Cloud-init habilitado en todas las VMs

---

## 3. Requisitos previos

### 🖥️ En el host KVM

* KVM/libvirt instalado y activo (`libvirtd` en marcha)
* `virt-install`, `qemu-img` y `virsh` disponibles
* `envsubst` (paquete `gettext`)
* Red `default` de libvirt activa
* Acceso a internet para el registro en RHSM y descarga desde `registry.redhat.io`

### 📦 Imagen base

La imagen base requerida es la **RHEL 9.7 KVM Guest Image**:

```
/var/lib/libvirt/user-images/rhel-9.7-x86_64-kvm.qcow2
```

Descárgala desde [access.redhat.com/downloads](https://access.redhat.com/downloads) y colócala en el directorio con los permisos adecuados:

```bash
sudo chown root:libvirt /var/lib/libvirt/user-images/rhel-9.7-x86_64-kvm.qcow2
sudo chmod 0664 /var/lib/libvirt/user-images/rhel-9.7-x86_64-kvm.qcow2
```

### 📦 Bundle AAP 2.4

Descarga el bundle desde el portal Red Hat y colócalo en el mismo directorio que los scripts:

```
ansible-automation-platform-setup-bundle-2.4-16-x86_64.tar.gz
```

---

## 4. Estructura del proyecto

```
RHAAP_2.4_deployment/
├── .gitignore
├── .env                          # Credenciales
├── main.sh                       # Punto de entrada: orquesta el despliegue completo
├── deploy-rhaap-lab.sh           # Fase 1: crea y configura las tres VMs
├── prepare-rhaap-install.sh      # Fase 2: prepara el controller para ./setup.sh
├── inventory                     # Plantilla de inventario AAP 2.4 (con placeholders)
├── pics/                         # Capturas de pantalla
├── README.md                     # Documentación en inglés
├── README_es.md                  # Documentación en español
└── ansible-automation-platform-setup-bundle-2.4-16-x86_64.tar.gz   # Bundle AAP 2.4---
```

## 5. Fichero `.env`

Todas las credenciales se centralizan en `.env`. Añadir a `.gitignore`.

```bash
# .env
export RH_USERNAME="usuario@redhat.com"
export RH_PASSWORD="tu_password_rhn"
export ADMIN_PASSWORD="password_admin_aap"
export PG_PASSWORD="password_postgresql"
```

> El uso de `export` es obligatorio. Tanto `deploy-rhaap-lab.sh` como `prepare-rhaap-install.sh` hacen `source .env` y las variables deben estar exportadas para que los subshells (`envsubst`, cloud-init) puedan acceder a ellas.

---

## 6. Script `deploy-rhaap-lab.sh`

Crea y configura las tres VMs del lab. Puede ejecutarse directamente o a través de `main.sh`.

### 6.1 Validaciones previas

Antes de crear nada, el script verifica:

* Que el directorio de almacenamiento `/var/lib/libvirt/user-images` existe.
* Que la imagen base `rhel-9.7-x86_64-kvm.qcow2` está presente en ese directorio.

Si alguna condición no se cumple, el script aborta con un mensaje de error descriptivo e instrucciones de resolución.

### 6.2 Recursos de las VMs

Los recursos se definen mediante arrays asociativos, lo que facilita añadir o modificar nodos sin tocar la lógica del script:

| VM         | RAM (MB) | vCPUs | Disco |
| ---------- | -------- | ----- | ----- |
| controller | 8192     | 2     | 40 GB |
| execution  | 4096     | 2     | 20 GB |
| database   | 4096     | 2     | 20 GB |

Los discos se crean como imágenes **copy-on-write (COW)** sobre la imagen base con `qemu-img create -f qcow2 -b`, de modo que la imagen base nunca se modifica.

Las IPs y MACs son estáticas y se registran en el DHCP de dnsmasq de libvirt mediante `virsh net-update` antes de arrancar cada VM, garantizando que la IP asignada siempre coincide con la definida en el inventario.

### 6.3 Configuración SSH del host

El script gestiona `~/.ssh/config` en el host:

* Si no existe, lo crea con permisos `600`.
* Añade un bloque para las tres IPs de los nodos con `StrictHostKeyChecking no` y `UserKnownHostsFile /dev/null`, evitando prompts de verificación de host en re-despliegues.
* El bloque solo se añade una vez; en re-despliegues detecta que ya existe y no lo duplica.

Además, antes de crear cada VM, limpia su entrada en `~/.ssh/known_hosts` para evitar conflictos de fingerprint.

### 6.4 Cloud-init por VM, requisitos definidos por Red Hat a nivel OS

Para cada VM se genera un fichero `user-data` en `/tmp/rhaap-user-data-<vm>` con:

* **Hostname y FQDN** (`rhaap-<vm>` / `rhaap-<vm>.lab.local`)
* **`/etc/hosts`** con los tres nodos del lab gestionado por `write_files` (`manage_etc_hosts: false`)
* **Clave SSH pública** del host inyectada en `root` para acceso directo
* **`runcmd`** que ejecuta en el primer arranque:
  * Registro en RHSM (`subscription-manager register --auto-attach`) con credenciales del `.env`
  * `dnf update -y`
  * SELinux en modo `enforcing`
  * `firewalld` y `chronyd` habilitados
  * Reinicio de `sshd`

### 6.5 Despliegue de VMs

Para cada VM el script ejecuta en orden:

1. Elimina la VM si ya existía (incluido su almacenamiento), permitiendo re-despliegues limpios.
2. Crea el disco COW.
3. Registra la reserva DHCP en dnsmasq.
4. Genera el cloud-init.
5. Lanza `virt-install --import --noautoconsole`.

Al finalizar imprime un resumen con hostname, FQDN, IP, RAM y vCPUs de cada VM.

---

## 7. Script `prepare-rhaap-install.sh`

Prepara el controller para que el installer pueda ejecutarse con `./setup.sh`. Se conecta al controller por SSH y realiza todas las operaciones necesarias de forma remota.

### 7.1 Espera de cloud-init

Antes de hacer nada, el script espera a que el controller haya completado su inicialización:

```bash
ssh root@192.168.122.101 "cloud-init status --wait"
```

Esto bloquea hasta que cloud-init devuelve `done`, garantizando que el sistema está registrado en RHSM y completamente configurado antes de continuar.

![cloud-init status done](pics/03_cloud_init_status_done.png)

### 7.2 Distribución de claves SSH entre VMs

El installer de AAP necesita que el controller pueda conectarse por SSH a todos los nodos (incluido él mismo) sin contraseña. El script:

1. Genera una clave SSH `rsa 4096` en `/root/.ssh/id_rsa` del controller si no existe.
2. Recupera la clave pública del controller.
3. La distribuye a los tres nodos (añade a `authorized_keys` de `root`).
4. Puebla el `known_hosts` del controller con los fingerprints de los tres nodos mediante `ssh-keyscan`.

### 7.3 Copia y verificación del bundle

El bundle se copia al controller con `scp` y se verifica comparando el tamaño en bytes (`stat -c%s`) entre el fichero local y el remoto. Si los tamaños no coinciden el script aborta indicando posible corrupción en la transferencia.

### 7.4 Procesado del inventario

El fichero `inventory` contiene placeholders (`${ADMIN_PASSWORD}`, `${PG_PASSWORD}`, `${RH_USERNAME}`, `${RH_PASSWORD}`). El script los sustituye con `envsubst` antes de copiar el inventario al controller:

```bash
envsubst < inventory > /tmp/inventory-processed
scp /tmp/inventory-processed root@192.168.122.101:/root/inventory
```

Las variables están disponibles porque `prepare-rhaap-install.sh` hace `source .env` al inicio y el `.env` las declara con `export`.

### 7.5 Descompresión y colocación del inventario

* El bundle se descomprime en `/root` del controller con `tar xzf`.
* El nombre del directorio extraído se detecta automáticamente (`ls -td ansible-automation-platform-*/`), sin asumir una versión concreta.
* El inventario procesado se copia dentro de ese directorio, sobreescribiendo el `inventory` de ejemplo que incluye el bundle.
* El `.tar.gz` se elimina del controller para liberar espacio.

---

## 8. Script `main.sh` — Punto de entrada único

`main.sh` orquesta el despliegue completo en dos fases:

```
FASE 1 → deploy-rhaap-lab.sh       (crea las VMs)
FASE 2 → prepare-rhaap-install.sh  (prepara el controller)
```

Entre las dos fases espera a que las tres VMs sean accesibles por SSH antes de continuar:

```bash
until ssh -o ConnectTimeout=5 -o BatchMode=yes "root@<IP>" true; do
    sleep 10
done
```

**Uso:**

```bash
./main.sh
```

Al lanzar `./main.sh` el script ejecuta las validaciones previas, reutiliza la clave SSH existente y configura el acceso SSH al lab:

![main.sh inicio y validaciones previas](pics/01_main_sh_inicio_validaciones.png)

Al finalizar la Fase 2 muestra el resumen "Lab listo" con las instrucciones para lanzar el installer y confirma que las tres VMs están en estado `running`:

![main.sh lab listo y virsh list](pics/02_main_sh_lab_listo_virsh_list.png)

---

## 9. Fichero `inventory`

El inventario define la topología de AAP 2.4 para el installer:

```ini
[automationcontroller]
controller ansible_host=192.168.122.101

[automationcontroller:vars]
peers=execution_nodes          # El controller inicia el peering hacia los execution nodes

[execution_nodes]
execution ansible_host=192.168.122.102

[database]
database ansible_host=192.168.122.103

# Opcionales 
#[automationeda]
#[automationhub]

[all:vars]
ansible_user=root
admin_password=${ADMIN_PASSWORD}
pg_host=192.168.122.103
pg_port=5432
pg_database='awx'
pg_username='awx'
pg_password=${PG_PASSWORD}
pg_sslmode='prefer'
registry_url='registry.redhat.io'
registry_username=${RH_USERNAME}
registry_password=${RH_PASSWORD}
```

> Los valores `${VARIABLE}` son placeholders que `envsubst` sustituye con los valores del `.env` antes de copiar el inventario al controller.

---

## 10. Lanzar la instalación

Una vez que `main.sh` (o `prepare-rhaap-install.sh`) finaliza correctamente, la instalación se lanza manualmente desde el controller:

```bash
ssh root@192.168.122.101
cd /root/ansible-automation-platform-*/
./setup.sh
```

El installer (`setup.sh`) es un playbook Ansible que utiliza el `inventory` del directorio actual. El proceso completo puede variar dependiendo de la velocidad de descarga.

Al finalizar, el `PLAY RECAP` mostrará `failed=0` en todos los nodos y el mensaje **"The setup process completed successfully."**:

![setup.sh PLAY RECAP completado](pics/04_setup_sh_play_recap_ok.png)

La UI web estará disponible en:

| Recurso                  | URL                                 |
| ------------------------ | ----------------------------------- |
| Automation Controller UI | `https://192.168.122.101`           |
| Usuario                  | `admin`                             |
| Contraseña               | Valor de `ADMIN_PASSWORD` en `.env` |

> El certificado SSL es autofirmado.

![AAP UI login](pics/05_aap_ui_login.png)

---

## 11. Primeros pasos tras la instalación

> **Entorno:** 3 VMs RHEL en KVM/libvirt — controller (`192.168.122.101`), execution node, database  
> **Acceso inicial:** `https://192.168.122.101` — el aviso de certificado autofirmado es normal, continuar.

![Error certificado HTTPS](pics/p2_01_error_certificado_https.png)

![Login Ansible Automation Platform](pics/p2_02_login_ansible_automation_platform.png)

---

### Paso 1 — Suscripción de AAP

Es la pantalla que ves al arrancar. Tienes 4 métodos para activar la licencia:

| Método                        | Cuándo usarlo                                               |
| ----------------------------- | ----------------------------------------------------------- |
| **Manifiesto de suscripción** | Entornos sin acceso a internet (subir `.zip` del portal RH) |
| **Username and Password**     | Lo más rápido si el controller tiene salida a internet      |
| **Service Account**           | Pipelines CI/CD, acceso OAuth                               |
| **Red Hat Satellite**         | Entornos con Satellite gestionando suscripciones            |

#### Opción recomendada para este lab: Username and Password

1. Haz clic en la pestaña **"Username and Password"**
2. Introduce tus credenciales de **Red Hat Developer** (las mismas del portal `access.redhat.com`)
3. Pulsa **"Obtener suscripciones"** — el controller se conecta a `subscription.rhsm.redhat.com`
4. Selecciona la suscripción **"Red Hat Ansible Automation Platform"** que aparece asociada a tu Developer Sub
5. Pulsa **"Siguiente"**

![Configuración suscripción — Username and Password](pics/p2_03_configuracion_suscripcion_usuario_password.png)

> **Nota:** Si el controller NO tiene salida a internet, usa el método **Manifiesto de suscripción**:
> 
> - Entra en [access.redhat.com → Subscriptions → Subscription Allocations](https://access.redhat.com/management/subscription_allocations)
> - Crea una allocation para AAP, exporta como `.zip`
> - Sube el `.zip` en el campo "Manifiesto de suscripción de Red Hat"

---

### Paso 2 — Usuario y Automation Analytics

Esta pantalla gestiona únicamente la telemetría. No hay campos de usuario admin aquí;
el usuario `admin` ya fue creado durante la instalación con el `admin_password`
definido en el inventario.

#### 2.1 Automation Analytics (telemetría)

Por defecto aparecen marcados dos checkboxes:

- **Análisis de usuarios** — datos de uso enviados a Red Hat para mejorar el producto
- **Automation Analytics** — métricas de ejecución de playbooks enviadas a Red Hat

En un lab, desmarca ambos. No aportan nada y requieren credenciales de service account
(Red Hat Client ID / Client Secret) que no es necesario configurar.

![Configuración Analytics](pics/p2_04_configuracion_analytics.png)

Pulsa **"Siguiente"**.

---

> **Nota:** Si en algún momento necesitas resetear la contraseña del usuario `admin`,
> ejecuta desde el controller:
> 
> ```bash
> awx-manage changepassword admin
> ```

---

### Paso 3 — Acuerdo de licencia (EULA)

Lee y acepta los términos. Pulsa **"Enviar"**. Tras aceptar, se redirige al Dashboard principal de AAP.

![Aceptación licencia EULA](pics/p2_05_aceptacion_licencia_eula.png)

---

### Post-wizard: verificaciones iniciales

Una vez dentro del dashboard, comprueba lo siguiente antes de continuar.

#### Verificar que el Execution Node está registrado

Navega a `Administración → Grupos de instancias → default → pestaña "Instancias"`.

Deberías ver dos nodos en estado **Listo**:

| IP / hostname   | Tipo      |
| --------------- | --------- |
| 192.168.122.101 | hybrid    |
| 192.168.122.102 | execution |

![Dashboard instancias — Grupos de instancias](pics/p2_06_dashboard_instancias.png)

Si el execution node aparece como **No disponible**, comprueba el servicio `receptor` en la VM de ejecución:

```bash
systemctl status receptor
```

![Terminal estado receptor](pics/p2_07_terminal_estado_receptor.png)

#### Verificar la conexión con la base de datos

No existe una pantalla de base de datos en la UI de RHAAP 2.4. Verifica directamente desde el controller:

```bash
awx-manage check_migrations
```

Debe devolver `No changes detected`.

![Terminal check migrations](pics/p2_08_terminal_check_migrations.png)

#### Verificar licencia activa

No hay acceso directo a Subscription desde el menú lateral. Navega a `Ajustes → Subscripción → Configuración de la suscripción`. Debe mostrar el tipo de suscripción, fecha de expiración y número de hosts gestionados.

![Detalles suscripción](pics/p2_09_detalles_suscripcion.png)

---

### Paso 4 — Estructura básica de AAP — Flujo de configuración inicial

Una vez validado el entorno, el flujo normal de configuración es secuencial:
cada elemento depende del anterior.

---

#### 1. Organizations

`Acceso → Organizaciones`

La organización es el contenedor lógico de todo en AAP: usuarios, equipos,
inventarios, proyectos y credenciales pertenecen siempre a una organización.
En un lab puedes usar la organización `Default` que viene creada de serie.
En entornos reales se crean organizaciones por equipo, cliente o entorno
(producción, desarrollo, etc.).

![Organizaciones](pics/p2_10_organizaciones.png)

#### 2. Credentials

`Recursos → Credenciales → Añadir`

Las credenciales almacenan de forma segura los secretos que AAP necesita para
conectarse a los hosts gestionados. El tipo más habitual en un lab es
**Machine**, donde defines el usuario SSH y la clave privada. AAP nunca
expone el valor de la credencial una vez guardada. Otros tipos útiles:
**Source Control** (para repos Git privados) y **Vault** (para Ansible Vault).

![Credenciales](pics/p2_11_credenciales.png)

#### 3. Inventories

`Recursos → Inventarios → Añadir`

El inventario define qué hosts va a gestionar AAP. Hay dos modalidades:

- **Estático** — introduces los hosts a mano o importas un fichero INI/YAML
- **Dinámico** — usas un *Inventory Source* que consulta una fuente externa
  (OpenStack, AWS, Azure, un script, etc.) y sincroniza los hosts automáticamente

En un lab con VMs fijas el inventario estático es suficiente. El inventario
dinámico es lo habitual en producción.

![Inventarios](pics/p2_12_inventarios.png)

#### 4. Projects

`Recursos → Proyectos → Añadir`

Un proyecto apunta a un repositorio Git (GitHub, GitLab, Gitea, etc.) donde
están tus playbooks. AAP clona el repositorio en el controller y lo
sincroniza cada vez que lanzas un job o manualmente. Debes tener creada
previamente una credencial de tipo **Source Control** si el repositorio es
privado. Si es público, no necesitas credencial.

![Proyectos](pics/p2_13_proyectos.png)

#### 5. Job Templates

`Recursos → Plantillas → Añadir → Job Template`

El Job Template es la unidad ejecutable de AAP. Asocia en un único objeto:

- **Inventario** — sobre qué hosts se ejecuta
- **Proyecto** — de qué repositorio se toma el playbook
- **Playbook** — qué fichero `.yml` dentro del proyecto se lanza
- **Credenciales** — con qué usuario y clave SSH se conecta a los hosts
- **Execution Environment** — en qué entorno de contenedor se ejecuta el job

Aquí también se configuran variables extra, límites de hosts, modo check, etc.

![Plantillas Job](pics/p2_14_plantillas_job.png)

![Detalle Job Template](pics/p2_15_detalle_job_template.png)

#### 6. Lanzar un Job

`Recursos → Plantillas → [tu template] → Launch`

Al lanzar el Job Template, AAP delega la ejecución al **Execution Node**
(`192.168.122.102`). Puedes seguir la ejecución en tiempo real desde
`Vistas → Trabajos`. Verifica que el job aparece asignado al execution node
y no al controller — eso confirma que la malla Receptor funciona correctamente.

---

## 12. Problemas conocidos y soluciones

### ⚠️ Error en el mesh de receptor

**Síntoma:** El installer falla con un error de topología del mesh de receptor indicando que el controller no puede conectar con el execution node.

**Causa:** Sin la directiva `peers=execution_nodes` en `[automationcontroller:vars]`, el controller no sabe que debe establecer un enlace de malla hacia los execution nodes.

**Solución:** Ya está incluida en el inventario:

```ini
[automationcontroller:vars]
peers=execution_nodes
```

---

## 13. Documentación oficial

📚 Para información técnica detallada y configuración avanzada, consulta la documentación oficial de Red Hat Ansible Automation Platform:

🔗 https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4

🧠 **Por qué es importante**

* Proporciona explicaciones detalladas de cada componente y servicio de la plataforma
* Cubre configuraciones avanzadas más allá de este laboratorio
* Útil para resolución de problemas y escenarios de producción real

👉 Este proyecto se centra en un despliegue práctico y simplificado sobre KVM, mientras que la documentación oficial proporciona la referencia técnica completa.

| Recurso                   | URL                                                                              |
| ------------------------- | -------------------------------------------------------------------------------- |
| Portal Red Hat            | https://access.redhat.com                                                        |
| Subscription Allocations  | https://access.redhat.com/management/subscription_allocations                    |
| Documentación AAP 2.4     | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4 |
| Resetear contraseña admin | `awx-manage changepassword admin` (en el controller)                             |
| Logs instalación          | `/var/log/tower/`                                                                |
| Estado servicios AAP      | `automation-controller-service status`                                           |

---

## 👤 Información del autor

**Juan Manuel Payán Barea** Administrador de Sistemas | SysOps | Infraestructura IT

st4rt.fr0m.scr4tch@gmail.com  
GitHub: https://github.com/jpaybar  
LinkedIn: https://es.linkedin.com/in/juanmanuelpayan
