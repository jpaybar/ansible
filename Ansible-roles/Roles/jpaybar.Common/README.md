# jpaybar.Common

Rol de Ansible para la configuración base de servidores **Red Hat Enterprise Linux 8 y 9**.

Aplica la configuración mínima necesaria en cualquier servidor RHEL antes de desplegar servicios: repositorios, paquetes base, zona horaria, NTP, SELinux, `/etc/hosts`, usuarios, sudoers y montajes NFS.

---

## Requisitos

### Nodo de control

- `ansible-core >= 2.16`
- Colecciones requeridas:
  - `ansible.posix`
  - `community.general`

Instalar colecciones:

```bash
ansible-galaxy collection install ansible.posix community.general
```

### Nodos target

- RHEL 8 o RHEL 9
- Acceso SSH con clave pública
- Privilegios `sudo` sin contraseña para el usuario de conexión

#### ⚠️ Prerequisito obligatorio para RHEL 8

Antes de ejecutar el rol en RHEL 8, instalar Python 3.9 y los bindings de SELinux con el módulo `raw` (no requiere Python):

```bash
ansible rhel8 -i Inventories/kvm/hosts.yml \
  -m raw -a "dnf install -y python39 python3-libselinux" \
  --become
```

Configurar el intérprete Python en el inventario para RHEL 8:

```yaml
rhel8:
  ansible_host: 192.168.x.x
  ansible_python_interpreter: /bin/python3.9
```

---

## Compatibilidad

| SO   | Versión | ansible-core     | Estado                      |
| ---- | ------- | ---------------- | --------------------------- |
| RHEL | 8.x     | >= 2.16, <= 2.20 | ✅ Soportado con workarounds |
| RHEL | 9.x     | >= 2.16          | ✅ Soportado                 |

### ⚠️ Limitaciones conocidas en RHEL 8 con ansible-core 2.17+

A partir de `ansible-core 2.17`, los módulos `ansible.builtin.dnf` y `ansible.posix.selinux` no funcionan contra RHEL 8 debido a una incompatibilidad entre los bindings Python del sistema (3.6) y los requisitos de Python del módulo (3.9+).

Este rol aplica los siguientes workarounds para RHEL 8:

- **Instalación de paquetes** — usa `ansible.builtin.command` con `dnf` en lugar del módulo nativo `ansible.builtin.dnf`
- **Configuración de SELinux** — usa `ansible.builtin.lineinfile` + `setenforce` en lugar del módulo `ansible.posix.selinux`

Estos workarounds se eliminarán cuando se publique `ansible-core 2.21` (previsto mayo 2026), que restaura el soporte del módulo `dnf` para RHEL 8 con Python 3.9.

Referencia: [ansible/ansible#86432](https://github.com/ansible/ansible/pull/86432) — fix previsto en ansible-core 2.21. Consulta el 
[roadmap oficial](https://docs.ansible.com/projects/ansible/devel/roadmap/ROADMAP_2_21.html) para la fecha de lanzamiento actualizada.

---

## Variables

Todas las variables tienen valores por defecto en `defaults/main.yml`. Sobrescríbelas en `group_vars/rhel/vars.yml` para aplicarlas a todo el grupo, en `host_vars/<hostname>.yml` para un host específico, o directamente en el playbook si solo aplica a una ejecución concreta.

```bash
group_vars/
└── rhel/
├── vars.yml ← variables para todo el grupo rhel
└── vault.yml ← credenciales cifradas con ansible-vault

host_vars/
├── rhel8.yml ← variables específicas de rhel8
└── rhel9.yml ← variables específicas de rhel9
```

### repos.yml

| Variable                              | Tipo   | Default                              | Descripción                                    |
| ------------------------------------- | ------ | ------------------------------------ | ---------------------------------------------- |
| `common_rhsm_enabled`                 | bool   | `false`                              | Registrar con Red Hat via subscription-manager |
| `common_rhsm_username`                | string | `""`                                 | Usuario Red Hat (usar ansible-vault)           |
| `common_rhsm_password`                | string | `""`                                 | Contraseña Red Hat (usar ansible-vault)        |
| `common_local_repo_enabled`           | bool   | `false`                              | Habilitar repositorio local adicional          |
| `common_local_repo_name`              | string | `"local"`                            | Nombre del fichero .repo                       |
| `common_local_repo_description`       | string | `"Repositorio local"`                | Descripción del repo                           |
| `common_local_repo_baseos_baseurl`    | string | `"http://repo.local/rhel/baseos"`    | URL BaseOS                                     |
| `common_local_repo_appstream_baseurl` | string | `"http://repo.local/rhel/appstream"` | URL AppStream                                  |
| `common_local_repo_gpgcheck`          | bool   | `false`                              | Verificación GPG                               |
| `common_local_repo_gpgkey`            | string | `file:///etc/pki/rpm-gpg/...`        | Ruta clave GPG                                 |
| `common_local_repo_metadata_expire`   | string | `"-1"`                               | Expiración de metadatos                        |
| `common_local_repo_cost`              | int    | `500`                                | Prioridad del repo                             |

### packages.yml

| Variable                | Tipo   | Default      | Descripción                                    |
| ----------------------- | ------ | ------------ | ---------------------------------------------- |
| `common_packages`       | list   | ver defaults | Lista de paquetes base a instalar              |
| `common_packages_state` | string | `"present"`  | Estado de los paquetes (present/latest/absent) |

### timezone.yml

| Variable          | Tipo   | Default           | Descripción               |
| ----------------- | ------ | ----------------- | ------------------------- |
| `common_timezone` | string | `"Europe/Madrid"` | Zona horaria del servidor |

### ntp.yml

| Variable                     | Tipo   | Default         | Descripción                |
| ---------------------------- | ------ | --------------- | -------------------------- |
| `common_ntp_servers`         | list   | pool.ntp.org x3 | Lista de servidores NTP    |
| `common_ntp_service_enabled` | bool   | `true`          | Habilitar servicio chrony  |
| `common_ntp_service_state`   | string | `"started"`     | Estado del servicio chrony |

### selinux.yml

| Variable                | Tipo   | Default       | Descripción                                    |
| ----------------------- | ------ | ------------- | ---------------------------------------------- |
| `common_selinux_state`  | string | `"enforcing"` | Estado SELinux (enforcing/permissive/disabled) |
| `common_selinux_policy` | string | `"targeted"`  | Política SELinux                               |

### hosts.yml

| Variable              | Tipo   | Default       | Descripción                                  |
| --------------------- | ------ | ------------- | -------------------------------------------- |
| `common_manage_hosts` | bool   | `true`        | Gestionar /etc/hosts con hosts del play      |
| `common_hosts_domain` | string | `"lab.local"` | Dominio para construir el FQDN               |
| `common_extra_hosts`  | list   | `[]`          | Hosts fijos adicionales fuera del inventario |

### users.yml

| Variable       | Tipo | Default | Descripción                    |
| -------------- | ---- | ------- | ------------------------------ |
| `common_users` | list | `[]`    | Lista de usuarios base a crear |

Ejemplo:

```yaml
common_users:
  - name: sysadmin
    groups: wheel
    shell: /bin/bash
    ssh_key: "{{ lookup('file', 'files/public_keys/sysadmin.pub') }}"
    state: present
    remove: false
  - name: developer
    groups: ""
    shell: /bin/bash
    ssh_key: "{{ lookup('file', 'files/public_keys/developer.pub') }}"
    state: present
    remove: false
```

> **Nota:** Las claves públicas SSH van en `files/public_keys/<nombre>.pub` — 
> sustituye los ficheros placeholder por las claves reales de cada usuario. 
> Las claves públicas no son secretas y pueden subirse a Git.  
> Para creación masiva de usuarios ver: 
> [Create_bulk_user_accounts_from_csv_file](https://github.com/jpaybar/ansible/blob/main/Ansible-playbooks/Create_bulk_user_accounts_from_csv_file/README.md)

### sudoers.yml

| Variable         | Tipo | Default | Descripción               |
| ---------------- | ---- | ------- | ------------------------- |
| `common_sudoers` | list | `[]`    | Lista de entradas sudoers |

Ejemplo:

```yaml
common_sudoers:
  - name: sysadmin
    user: sysadmin
    commands: ALL
    nopasswd: true
  - name: developer
    user: developer
    commands: /usr/bin/systemctl restart httpd
    nopasswd: false
```

### nfs.yml

| Variable             | Tipo   | Default       | Descripción                    |
| -------------------- | ------ | ------------- | ------------------------------ |
| `common_nfs_enabled` | bool   | `false`       | Habilitar montajes NFS cliente |
| `common_nfs_package` | string | `"nfs-utils"` | Paquete cliente NFS            |
| `common_nfs_mounts`  | list   | `[]`          | Lista de montajes NFS          |

Ejemplo:

```yaml
common_nfs_mounts:
  - src: "192.168.1.100:/exports/data"
    path: /mnt/data
    opts: "rw,sync,hard,intr"
    state: mounted
```

---

## Uso

### Playbook básico

```yaml
---
- name: Configuración base de servidores RHEL
  hosts: rhel
  become: true
  gather_facts: true
  roles:
    - role: jpaybar.Common
```

### Lanzar el rol completo

```bash
ansible-playbook Playbooks/common.yml -i Inventories/kvm/hosts.yml
```

### Lanzar solo una tarea específica

```bash
# Solo paquetes
ansible-playbook Playbooks/common.yml -i Inventories/kvm/hosts.yml --tags packages

# Solo NTP y timezone
ansible-playbook Playbooks/common.yml -i Inventories/kvm/hosts.yml --tags ntp,timezone

# Solo usuarios y sudoers
ansible-playbook Playbooks/common.yml -i Inventories/kvm/hosts.yml --tags users,sudoers
```

### Tags disponibles

| Tag        | Tarea                         |
| ---------- | ----------------------------- |
| `repos`    | Configuración de repositorios |
| `packages` | Instalación de paquetes base  |
| `timezone` | Configuración de zona horaria |
| `ntp`      | Configuración de NTP (chrony) |
| `selinux`  | Configuración de SELinux      |
| `hosts`    | Gestión de /etc/hosts         |
| `users`    | Creación de usuarios base     |
| `sudoers`  | Configuración de sudoers      |
| `nfs`      | Configuración de montajes NFS |

---

## Credenciales con ansible-vault

La estructura para vault ya está preparada en `group_vars/rhel/`:

1. Editar `group_vars/rhel/vault.yml` y sustituir los comentarios por las credenciales reales:

```yaml
vault_rhsm_username: "tu_usuario@redhat.com"
vault_rhsm_password: "tu_password"
```

2. Descomentar en `group_vars/rhel/vars.yml` las referencias al vault:

```yaml
common_rhsm_username: "{{ vault_rhsm_username }}"
common_rhsm_password: "{{ vault_rhsm_password }}"
```

3. Habilitar el registro en `group_vars/rhel/vars.yml`:

```yaml
common_rhsm_enabled: true
```

4. Cifrar el fichero vault:

```bash
ansible-vault encrypt group_vars/rhel/vault.yml



# Ver el contenido del fichero cifrado
ansible-vault view group_vars/rhel/vault.yml

# Editar el fichero cifrado
ansible-vault edit group_vars/rhel/vault.yml
```

5. Lanzar con vault:

```bash
ansible-playbook Playbooks/common.yml -i Inventories/kvm/hosts.yml --ask-vault-pass
```

---

## Estructura del rol

```
jpaybar.Common/
├── defaults/
│   └── main.yml          # Variables por defecto
├── files/
│   └── public_keys/      # Claves públicas SSH de usuarios base
│       ├── sysadmin.pub
│       └── developer.pub
├── handlers/
│   └── main.yml          # restart chrony, remount nfs
├── tasks/
│   ├── main.yml          # Orquestador — valida SO y llama a cada tarea
│   ├── repos.yml
│   ├── packages.yml
│   ├── timezone.yml
│   ├── ntp.yml
│   ├── selinux.yml
│   ├── hosts.yml
│   ├── users.yml
│   ├── sudoers.yml
│   └── nfs.yml
└── templates/
    ├── chrony.conf.j2
    ├── local.repo.j2
    └── sudoers_entry.j2
```

---

## Author Information

Juan Manuel Payán Barea (Systems Administrator | SysOps | IT Infrastructure) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
