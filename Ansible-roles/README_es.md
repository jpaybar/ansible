# Ansible Roles — jpaybar

Colección de roles Ansible para la gestión, configuración y despliegue de infraestructura en entornos Linux empresariales.

**By Juan Manuel Payán Barea / jpaybar**
[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

---

## Roles disponibles

| Rol                                                        | Descripción                                                                             | SO                             | Estado |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------ | ------ |
| [jpaybar.Common](Roles/jpaybar.Common/README.md)           | Configuración base de servidores: repos, paquetes, NTP, SELinux, usuarios, sudoers, NFS | RHEL 8/9                       | ✅      |
| [jpaybar.Apache2](Roles/jpaybar.Apache2/README.md)         | Servidor web Apache2                                                                    | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Mysql](Roles/jpaybar.Mysql/README.md)             | Base de datos MySQL                                                                     | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Nginx_Proxy](Roles/jpaybar.Nginx_Proxy/README.md) | Proxy inverso Nginx con SSL                                                             | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Php-fpm](Roles/jpaybar.Php-fpm/README.md)         | PHP-FPM                                                                                 | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Wordpress](Roles/jpaybar.Wordpress/README.md)     | Despliegue WordPress                                                                    | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |

---

## Proyectos

### WordPress 3-Tier sobre KVM/OpenStack

Despliegue automatizado de un stack WordPress de 3 capas (proxy Nginx + app Apache/PHP + MySQL) sobre infraestructura KVM local u OpenStack, con aprovisionamiento vía Terraform y configuración vía Ansible.

📄 [README WordPress](README_WordPress.md)

---

## Estructura del repositorio

```
Ansible-roles/
├── Inventories/
│   ├── kvm/                   # Inventario estático para VMs locales KVM
│   │   ├── group_vars/
│   │   │   ├── dbservers.yml
│   │   │   ├── proxy.yml
│   │   │   ├── rhel/          # Variables grupo RHEL (vars.yml + vault.yml)
│   │   │   ├── webservers.yml
│   │   │   └── wordpress.yml
│   │   └── hosts.yml
│   └── openstack/             # Inventario dinámico para OpenStack
│       ├── group_vars/
│       │   ├── dbservers.yml
│       │   ├── proxy.yml
│       │   ├── webservers.yml
│       │   └── wordpress.yml
│       └── openstack.yml
├── Playbooks/
│   ├── common.yml              # Rol jpaybar.Common — configuración base RHEL
│   ├── site.yml                # Stack WordPress completo
│   ├── apache_role_playbook.yml
│   ├── mysql_role_playbook.yml
│   ├── nginx-proxy_role_playbook.yml
│   ├── php-fpm_role_playbook.yml
│   └── wordpress_role_playbook.yml
├── Roles/
│   ├── jpaybar.Common/
│   ├── jpaybar.Apache2/
│   ├── jpaybar.Mysql/
│   ├── jpaybar.Nginx_Proxy/
│   ├── jpaybar.Php-fpm/
│   └── jpaybar.Wordpress/
├── README.md
├── README_es.md
├── ansible.cfg
├── ansible_provision.sh
├── LICENSE
├── README_WordPress_es.md
├── README_WordPress.md
└── create_rhel_target_vms.sh   # Script de aprovisionamiento de VMs RHEL
```

---

## Requisitos

- `ansible-core >= 2.16`
- Colecciones:

```bash
ansible-galaxy collection install ansible.posix community.general
```

---

## 👤 Información del autor

**Juan Manuel Payán Barea** Administrador de Sistemas | SysOps | Infraestructura IT

[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

GitHub: [jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

LinkedIn: [https://es.linkedin.com/in/juanmanuelpayan](https://es.linkedin.com/in/juanmanuelpayan)
