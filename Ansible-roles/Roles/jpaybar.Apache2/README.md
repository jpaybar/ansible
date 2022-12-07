jpaybar.Apache2
=========

This role installs Apache2's latest version on `Ubuntu` (18.04, 20.04, 22.04), `Debian` (10, 11) and `CentOS` (7.9, 8.5) distributions. Sets an apache VirtualHost up on port 80 (Debian and Ubuntu) and redirect it to an `https` connection to port 443. On `Centos` the connection is made https directly. To do this, a self-signed SSL certificate may be created running `self-signed-ssl-cert.py` python script placed on `files` folder (Modify it as best suits you).

Requirements
------------

No requirements needed. Just keep in mind that `Centos 7.9` requires `python 2` to run the playbook. I added `ansible_python_interpreter: "/usr/bin/python2"` variable to the inventory for it.

Role Variables
--------------

There are 3 variable files (one for each distribution) inside `vars` folder, the `Debian` and `Ubuntu` ones are the same, there are changes in `Centos` since the path to the SSL certificate is different and the server installation and corresponding modules have other names. These variables are included on a file called `tasks/variables.yml` and this file is one of the tasks that `tasks/main.yml` runs. Variables for Virtualhost configuration (serverName, documentRoot, etc.) are found in `default/main.yml` file.

Dependencies
------------

There are no dependencies.

Run this Playbook
----------------

A quick start:

```bash
git clone https://github.com/jpaybar/Ansible-roles.git
cd Ansible-roles/jpaybar.Apache2
```

Once you have cloned the repository, there are 3 directories inside, `Inventories`, `Playbooks` and `Roles`. You may run this Role:

```bash
ansible-playbook -i Inventories/apache_role_inventory.yml Playbooks/apache_role_playbook.yml 
```

or this way (user/passwd)

```bash
ansible-playbook -i Inventories/apache_role_inventory.yml Playbooks/apache_role_playbook.yml -u user -k
```

This is the playbook:

```yaml
---
- hosts: all
  become: true
  roles:
    - ../Roles/jpaybar.Apache2
```

But you can customize the playbook on your own way, as well as the inventory to your needs.

License
-------

BSD

Author Information
------------------

Juan Manuel Payán Barea    (IT Technician)    st4rt.fr0m.scr4tch@gmail.com

https://github.com/jpaybar

https://es.linkedin.com/in/juanmanuelpayan
