# jpaybar.Apache2

This role installs Apache2's latest version on `Ubuntu` (18.04, 20.04, 22.04, 24.04) distribution. It enables the default SSL site on port 443 with a self-signed certificate generated automatically during deployment.

## Tested with

| ansible-core | Python |
| ------------ | ------ |
| 2.20.3       | 3.12   |

## Requirements

No requirements needed.

## Role Variables

Variables for the SSL certificate and server configuration are found in `defaults/main.yml`. Distribution-specific variables (packages, modules, certificate paths) are in `vars/ubuntu_vars.yml` and loaded automatically via `tasks/variables.yml`.

| Variable               | Default                       | Description                         |
| ---------------------- | ----------------------------- | ----------------------------------- |
| `apache_server_name`   | `{{ inventory_hostname }}`    | Server name for the SSL certificate |
| `apache_document_root` | `/var/www/html`               | Apache document root                |
| `apache_port`          | `443`                         | Port where Apache listens           |
| `apache_cert_path`     | `/etc/ssl/certs/apache.crt`   | SSL certificate path                |
| `apache_key_path`      | `/etc/ssl/private/apache.key` | SSL certificate key path            |

## Dependencies

There are no dependencies.

## Run this Playbook

```bash
git clone https://github.com/jpaybar/Ansible-roles.git
cd Ansible-roles/jpaybar.Apache2
```

```yaml
---
- hosts: webservers
  become: true
  roles:
    - ../Roles/jpaybar.Apache2
```

## License

BSD

## Author Information

Juan Manuel Payán Barea (Systems Administrator | SysOps | IT Infrastructure)
st4rt.fr0m.scr4tch@gmail.com
[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)
[LinkedIn](https://es.linkedin.com/in/juanmanuelpayan)
