# Ansible Roles — jpaybar

Collection of Ansible roles for managing, configuring and deploying infrastructure in enterprise Linux environments.

**By Juan Manuel Payán Barea / jpaybar**
[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

---

## Available Roles

| Role                                                       | Description                                                                   | OS                             | Status |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------ | ------ |
| [jpaybar.Common](Roles/jpaybar.Common/README.md)           | Base server configuration: repos, packages, NTP, SELinux, users, sudoers, NFS | RHEL 8/9                       | ✅      |
| [jpaybar.Hardening](Roles/jpaybar.Hardening/README.md)     | Base hardening: SSH, PAM, sysctl, firewalld, permissions, sudo                | RHEL 8/9                       | ✅      |
| [jpaybar.Apache2](Roles/jpaybar.Apache2/README.md)         | Apache2 web server                                                            | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Mysql](Roles/jpaybar.Mysql/README.md)             | MySQL database                                                                | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Nginx_Proxy](Roles/jpaybar.Nginx_Proxy/README.md) | Nginx reverse proxy with SSL                                                  | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Php-fpm](Roles/jpaybar.Php-fpm/README.md)         | PHP-FPM                                                                       | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |
| [jpaybar.Wordpress](Roles/jpaybar.Wordpress/README.md)     | WordPress deployment                                                          | Ubuntu 18.04/20.04/22.04/24.04 | ✅      |

---

## Projects

### WordPress 3-Tier on KVM/OpenStack

Automated deployment of a 3-tier WordPress stack (Nginx proxy + Apache/PHP app + MySQL) on local KVM or OpenStack infrastructure, provisioned with Terraform and configured with Ansible.

📄 [WordPress README](README_WordPress.md)

---

## Repository Structure

```
Ansible-roles/
├── Inventories/
│   ├── kvm/                   # Static inventory for local KVM VMs
│   │   ├── group_vars/
│   │   │   ├── dbservers.yml
│   │   │   ├── proxy.yml
│   │   │   ├── rhel/          # RHEL group variables (common.yml + common_vault.yml)
│   │   │   │   ├── common.yml
│   │   │   │   ├── common_vault.yml
│   │   │   │   └── hardening.yml
│   │   │   ├── webservers.yml
│   │   │   └── wordpress.yml
│   │   └── hosts.yml
│   └── openstack/             # Dynamic inventory for OpenStack
│       ├── group_vars/
│       │   ├── dbservers.yml
│       │   ├── proxy.yml
│       │   ├── webservers.yml
│       │   └── wordpress.yml
│       └── openstack.yml
├── Playbooks/
│   ├── common.yml              # jpaybar.Common role — RHEL base configuration
│   ├── hardening.yml           # jpaybar.Hardening role — RHEL base hardening
│   ├── site.yml                # Full WordPress stack
│   ├── apache_role_playbook.yml
│   ├── mysql_role_playbook.yml
│   ├── nginx-proxy_role_playbook.yml
│   ├── php-fpm_role_playbook.yml
│   └── wordpress_role_playbook.yml
├── Roles/
│   ├── jpaybar.Common/
│   ├── jpaybar.Hardening/
│   ├── jpaybar.Apache2/
│   ├── jpaybar.Mysql/
│   ├── jpaybar.Nginx_Proxy/
│   ├── jpaybar.Php-fpm/
│   └── jpaybar.Wordpress/
├── ansible.cfg
├── ansible_provision.sh
├── create_rhel_target_vms.sh   # RHEL target VMs provisioning script
├── LICENSE
├── README.md
├── README_es.md
├── README_WordPress.md
└── README_WordPress_es.md
```

---

## Requirements

- `ansible-core >= 2.16`
- Collections:

```bash
ansible-galaxy collection install ansible.posix community.general
```

---

## 👤 Author

**Juan Manuel Payán Barea** — Systems Administrator | SysOps | IT Infrastructure

[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

GitHub: [jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

LinkedIn: [https://es.linkedin.com/in/juanmanuelpayan](https://es.linkedin.com/in/juanmanuelpayan)
