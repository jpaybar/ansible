# TOMCAT 10 on Ubuntu 18.04/20.04

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

This playbook will install an Apache Tomcat environment on an Ubuntu 18.04/20.04 machine,  a free and open-source implementation of the Jakarta Servlet, Jakarta Expression Language, and WebSocket technologies.
A Tomcat server will be created with the options specified in the `vars/default.yml` variable file. You will find three templates (jinja2 file) in the files/ playbook configuration folder. A tomcat.service.j2 for running the service on an Ubuntu machine and the two others (context.xml.j2, tomcat-users.xml.j2) are Tomcat configuration files.

## Settings

- `java_home`: environment variable for Java Development Kit (JDK).
- `tomcat_username`: user for Tomcat Web Management Interface.
- `tomcat_password`: password for Tomcat Web Management Interface.
- `tomcat_roles`: manager-gui,admin-gui for this configuration.
- `http_port`: HTTP port, default is 8080 for Tomcat server.

## Running this Playbook

Quick Steps:

### 1. Obtain the playbook

```shell
git clone https://github.com/jpaybar/ansible-playbooks.git
cd ansible-playbooks/TOMCAT_ubuntu1004_2004
```

### 2. Customize Options

```shell
nano vars/default.yml
```

```yml
#vars/default.yml
---
java_home: "/usr/lib/jvm/java-1.11.0-openjdk-amd64"
http_port: "8080"
tomcat_username: "admin"
tomcat_password: "admin"
tomcat_roles: "manager-gui,admin-gui"
```

### 3. Run the Playbook

```command
ansible-playbook -l [target] -i [inventory file] -u [remote user] playbook.yml
```
