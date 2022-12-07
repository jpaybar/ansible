# LAMP on Ubuntu 18.04/20.04

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

This playbook will install a LAMP environment (**L**inux, **A**pache, **M**ySQL and **P**HP) on an Ubuntu 18.04/20.04 machine. A virtualhost will be created with the options specified in the `vars/default.yml` variable file. You can find an Apache virtualhost template (jinja2 file) in the files/apache.conf.j2 and two others files (index.html.j2, info.php.j2 ) for testing purposes.

## Settings

- `mysql_root_password`: the password for the MySQL root account.
- `app_user`: a remote non-root user on the Ansible host that will own the application files.
- `http_host`: your domain name.
- `http_conf`: the name of the configuration file that will be created within Apache.
- `http_port`: HTTP port, default is 80.
- `disable_default`: whether or not to disable the default Apache website. When set to true, your new virtualhost should be used as default website. Default is true.

## Running this Playbook

Quickstart guide for those already familiar with Ansible:

### 1. Obtain the playbook

```shell
git clone https://github.com/jpaybar/ansible-playbooks.git
cd ansible-playbooks/LAMP_ubuntu1804_2004
```

### 2. Customize variable file

```shell
nano vars/default.yml
```

```yml
---
mysql_root_password: "mysql_root_password"
app_user: "vagrant"
http_host: "domain_name"
http_conf: "domain_name.conf"
http_port: "80"
disable_default: true
```

### 3. Run the Playbook

```command
ansible-playbook -l [target] -i [inventory file] -u [remote user] playbook.yml
```
