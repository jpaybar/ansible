jpaybar.Php-fpm
=========

This role installs PHP-Fpm on `Ubuntu` (18.04, 20.04, 22.04), `Debian` (10, 11) and `CentOS` (7.9, 8.5) distributions.

Requirements
------------

No requirements needed. Just keep in mind that `Centos 7.9` requires `python 2` to run the playbook. I added `ansible_python_interpreter: "/usr/bin/python2"` variable to the inventory for it.

Role Variables
--------------

There are 3 variable files (one for each distribution) inside `vars` folder, the `Debian`, `Ubuntu` and `Centos` since the versions are different and configuration files do not have the same path. There are and entry setup inside `defaults` directory.

Dependencies
------------

There are no dependencies.

Run this Playbook
----------------

A quick start:

```bash
git clone https://github.com/jpaybar/Ansible-roles.git
cd Ansible-roles/jpaybar.Php-fpm
```

Once you have cloned the repository, there are 3 directories inside, `Inventories`, `Playbooks` and `Roles`. You may run the Role this way:

```bash
ansible-playbook -i Inventories/php-fpm_role_inventory.yml Playbooks/php-fpm_role_playbook.yml 
```

or this way (user/passwd)

```bash
ansible-playbook -i Inventories/php-fpm_role_inventory.yml Playbooks/php-fpm_role_playbook.yml -u user -k
```

This is the playbook:

```yaml
---
- hosts: all
  become: true
  roles:
    - ../Roles/jpaybar.Php-fpm
```

But you can customize the playbook on your own way, as well as the inventory to your needs.

## Test PHP installation

You may run next command to see PHP version

```bash
php -v
```

and this other to get modules information

```bash
php -m
```

## License

BSD

Author Information
------------------

Juan Manuel Payán Barea    (IT Technician)   [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
