jpaybar.Mysql
=========

This role installs MySQL's latest version on `Ubuntu` (18.04, 20.04, 22.04), `Debian` (10, 11) and `CentOS` (7.9, 8.5) distributions.

Requirements
------------

No requirements needed. Just keep in mind that `Centos 7.9` requires `python 2` to run the playbook. I added `ansible_python_interpreter: "/usr/bin/python2"` variable to the inventory for it.

Role Variables
--------------

There are 3 variable files (one for each distribution) inside `vars` folder, and some others for every version. The main.yml file variable is under `defaults` folder.

Dependencies
------------

There are no dependencies.

Run this Playbook
----------------

A quick start:

```bash
git clone https://github.com/jpaybar/Ansible-roles.git
cd Ansible-roles/jpaybar.Mysql
```

Once you have cloned the repository, there are 3 directories inside, `Inventories`, `Playbooks` and `Roles`. You may run the Role this way:

```bash
ansible-playbook -i Inventories/mysql_role_inventory.yml Playbooks/mysql_role_playbook.yml 
```

or this way (user/passwd)

```bash
ansible-playbook -i Inventories/mysql_role_inventory.yml Playbooks/mysql_role_playbook.yml -u user -k password
```

This is the playbook:

```yaml
---
- hosts: all
  become: true
  roles:
    - ../Roles/jpaybar.Mysql
```

But you can customize the playbook on your own way, as well as the inventory to your needs.

License
-------

BSD

Author Information
------------------

Juan Manuel Payán Barea    (IT Technician) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
