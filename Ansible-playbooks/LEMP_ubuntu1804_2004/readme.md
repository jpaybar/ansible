# LEMP on Ubuntu 18.04/20.04

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

This playbook will install a LEMP environment on an Ubuntu 18.04/20.04 machine, 
A virtualhost will be created with the options specified in the `vars/default.yml` variable file. You can find a Nginx virtualhost template (jinja2 file) in the files/nginx.conf.j2 and two others files (index.html.j2, info.php.j2 ) for testing purposes.

## Settings

- `mysql_root_password`: the password for the MySQL root account.
- `http_host`: your domain name.
- `http_conf`: the name of the configuration file that will be created within nginx.
- `http_port`: HTTP port, default is 80.

## Running this Playbook

Quick Steps:

### 1. Obtain the playbook

```shell
git clone https://github.com/jpaybar/ansible-playbooks.git
cd ansible-playbooks/LEMP_ubuntu1804_2004
```

### 2. Customize Options

```shell
nano vars/default.yml
```

```yml
#vars/default.yml
---
mysql_root_password: "mysql_root_password"
http_host: "domain_name"
http_conf: "domain_name.conf"
http_port: "80"
```

### 3. Run the Playbook

```command
ansible-playbook -l [target] -i [inventory file] -u [remote user] playbook.yml
```
