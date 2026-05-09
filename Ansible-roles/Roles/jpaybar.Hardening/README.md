# jpaybar.Hardening

Rol de Ansible para hardening básico de sistemas **RHEL 8** y **RHEL 9**.

No implementa la normativa CIS completa, sino un conjunto de controles base que eliminan vectores de ataque comunes sin romper la operativa del sistema.

---

## Requisitos

- Ansible >= 2.12
- Colección `ansible.posix` (`ansible-galaxy collection install ansible.posix`)
- El usuario de ejecución debe tener privilegios `root` o `sudo`
- `authselect` disponible en el sistema (viene por defecto en RHEL 8/9)

---

## Variables

Todas las variables configurables están en `defaults/main.yml`. Las variables internas (no modificar) están en `vars/main.yml`.

### Control de secciones

| Variable                       | Valor por defecto | Descripción                         |
| ------------------------------ | ----------------- | ----------------------------------- |
| `hardening_enable_packages`    | `true`            | Gestión de paquetes y crypto-policy |
| `hardening_enable_ssh`         | `true`            | Endurecimiento SSH                  |
| `hardening_enable_auth`        | `true`            | PAM, pwquality, faillock            |
| `hardening_enable_sysctl`      | `true`            | Parámetros del kernel               |
| `hardening_enable_services`    | `true`            | Deshabilitar servicios inseguros    |
| `hardening_enable_firewall`    | `true`            | Configuración de firewalld          |
| `hardening_enable_permissions` | `true`            | Permisos de ficheros críticos       |
| `hardening_enable_sudo`        | `true`            | Configuración de sudo               |

### SSH

| Variable                               | Valor por defecto | Descripción                           |
| -------------------------------------- | ----------------- | ------------------------------------- |
| `hardening_ssh_permit_root_login`      | `"no"`            | PermitRootLogin                       |
| `hardening_ssh_password_auth`          | `"no"`            | PasswordAuthentication                |
| `hardening_ssh_ports`                  | `[22]`            | Puertos de escucha SSH                |
| `hardening_ssh_client_alive_interval`  | `300`             | Timeout de sesión inactiva (s)        |
| `hardening_ssh_client_alive_count_max` | `0`               | Máx. paquetes keepalive sin respuesta |
| `hardening_ssh_max_auth_tries`         | `4`               | Máx. intentos de autenticación        |

### Contraseñas y cuentas (PAM)

| Variable                           | Valor por defecto | Descripción                                       |
| ---------------------------------- | ----------------- | ------------------------------------------------- |
| `hardening_pwquality_minlen`       | `12`              | Longitud mínima de contraseña                     |
| `hardening_faillock_deny`          | `5`               | Intentos antes de bloquear cuenta                 |
| `hardening_faillock_unlock_time`   | `900`             | Segundos de bloqueo (15 min)                      |
| `hardening_system_account_uid_min` | `100`             | UID mínimo para tocar shell de cuentas de sistema |

### Firewall

| Variable                               | Valor por defecto | Descripción                             |
| -------------------------------------- | ----------------- | --------------------------------------- |
| `hardening_firewalld_default_zone`     | `public`          | Zona por defecto                        |
| `hardening_firewalld_allowed_services` | `[ssh]`           | Servicios permitidos (whitelist)        |
| `hardening_firewalld_extra_ports`      | `[]`              | Puertos adicionales, ej: `['8080/tcp']` |
| `hardening_firewalld_log_denied`       | `false`           | Activar log de tráfico denegado         |

---

## Uso

```yaml
- hosts: servers
  become: true
  roles:
    - role: jpaybar.Hardening
```

### Solo una sección (tags)

```bash
ansible-playbook site.yml --tags ssh
ansible-playbook site.yml --tags auth,sysctl
```

### Modo comprobación (sin cambios)

```bash
ansible-playbook -C -D site.yml
```

### Deshabilitar una sección para un host concreto

En `host_vars/mi_servidor.yml`:

```yaml
hardening_enable_firewall: false
```

---

## Dependencias

Ninguna.

---

## Author Information

Juan Manuel Payán Barea (Systems Administrator | SysOps | IT Infrastructure) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
