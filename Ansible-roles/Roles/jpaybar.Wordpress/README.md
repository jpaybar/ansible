jpaybar.Wordpress
=========

This role installs WordPress on `Ubuntu` (18.04, 20.04, 22.04, 24.04), `Debian` (10, 11) and `CentOS` (7.9, 8.5) distributions.

WordPress version is installed from the official source:

| Component | Version |
| --------- | ------- |
| WordPress | latest  |

Tested with

| ansible-core | Python |
| ------------ | ------ |
| 2.20.3       | 3.12   |

Requirements

No requirements needed. Just keep in mind that this role does NOT install or configure the web server, PHP or database.

You must have a working environment with:

- Web server (Apache/Nginx)
- PHP (with required modules)
- MySQL/MariaDB database

Role Variables

Default variables are defined in `defaults/main.yml`:

```yaml
wordpress_version: latest
wordpress_install_dir: /var/www/html/wordpress

wordpress_db_name: wordpress
wordpress_db_user: wp_user
wordpress_db_password: wp_pass
wordpress_db_host: localhost

wordpress_table_prefix: wp_

wordpress_owner: www-data
wordpress_group: www-data
```

License

BSD

Author Information

Juan Manuel Payán Barea (Systems Administrator | SysOps | IT Infrastructure) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
