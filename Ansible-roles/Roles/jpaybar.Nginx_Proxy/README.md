jpaybar.Nginx_Proxy
=========

This role installs and configures Nginx as a **reverse proxy with SSL** on `Ubuntu` (18.04, 20.04, 22.04, 24.04) distributions.

It generates a self-signed SSL certificate, configures HTTP to HTTPS redirection, and proxies HTTPS traffic to a backend application server (WordPress over Apache/PHP-FPM).

Tested with
-----------

| ansible-core | Python |
| ------------ | ------ |
| 2.20.3       | 3.12   |

Requirements
------------

No requirements needed.

Role Variables
--------------

Variables are defined in `defaults/main.yml`:

| Variable          | Default                    | Description                                                             |
| ----------------- | -------------------------- | ----------------------------------------------------------------------- |
| `proxy_hostname`  | `{{ inventory_hostname }}` | Hostname of the proxy server (used in SSL certificate and Nginx config) |
| `app_server_port` | `443`                      | Port where the backend application server listens                       |

The variable `app_server_ip` must be defined in the inventory or `group_vars` — it points to the backend WordPress application server.

Example:

```yaml
# group_vars/proxy.yml
proxy_hostname: "server1"
app_server_port: 443
app_server_ip: "192.168.122.x"
```

What this role does
-------------------

- Installs `nginx` and `openssl`
- Creates `/etc/nginx/ssl/` directory
- Generates a **self-signed SSL certificate** valid for 365 days (`nginx.crt` / `nginx.key`)
- Deploys the Nginx virtualhost configuration from template `wordpress_proxy.conf.j2`:
  - Redirects all HTTP traffic (port 80) to HTTPS (port 443)
  - Proxies HTTPS requests to the backend application server
  - Disables SSL verification on the backend connection (self-signed cert on app server)
  - Sets standard proxy headers: `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`
- Enables the site and removes the default Nginx site
- Ensures Nginx is started and enabled at boot

Dependencies
------------

This role is designed to work as part of the **WordPress 3-Tier** stack:

- Backend app server must be running Apache2 + PHP-FPM + WordPress (`jpaybar.Apache2`, `jpaybar.Php-fpm`, `jpaybar.Wordpress`)
- `app_server_ip` must be reachable from the proxy server

Run this Playbook
-----------------

A quick start:

```bash
git clone https://github.com/jpaybar/ansible.git
cd ansible/Ansible-roles
```

Once you have cloned the repository, run the role this way:

```bash
ansible-playbook -i Inventories/kvm/hosts.yml Playbooks/nginx-proxy_role_playbook.yml
```

or with user/password authentication:

```bash
ansible-playbook -i Inventories/kvm/hosts.yml Playbooks/nginx-proxy_role_playbook.yml -u user -k
```

This is the playbook:

```yaml
---
- hosts: proxy
  become: true
  roles:
    - ../Roles/jpaybar.Nginx_Proxy
```

To run the full WordPress 3-Tier stack:

```bash
ansible-playbook -i Inventories/kvm/hosts.yml Playbooks/site.yml
```

License
-------

BSD

Author Information
------------------

Juan Manuel Payán Barea    (Systems Administrator | SysOps | IT Infrastructure)    st4rt.fr0m.scr4tch@gmail.com

https://github.com/jpaybar

https://es.linkedin.com/in/juanmanuelpayan
