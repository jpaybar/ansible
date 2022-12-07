# Docker and containers deployment on Ubuntu 20.04

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

This playbook will install Docker on Ubuntu 20.04 machine behind a proxy and deploy
a number of containers that will be created with the options specified in the `vars/variables.yml` variable file.

## Settings

- `create_containers`: number of containers to create.
- `container_name`: Name for new containers.
- `container_image`: Image for new containers.
- `container_command`: Default command to run on new containers.
- `http_proxy`: Your HTTP proxy.
- `https_proxy`: Your HTTPS proxy.
- `no_proxy`: Proxy exceptions.

## Running this Playbook

### 1. Obtain the playbook

```bash
git clone https://github.com/jpaybar/ansible-playbooks.git
cd ansible-playbooks/DOCKER_ubuntu2004
```

### 2. Project directory tree

```bash
linuxuser@myhost:~/DOCKER_ubuntu2004$ 
.
├── README.md
├── files
│   └── http-proxy.conf.j2
├── inventory_hosts
├── playbook.yml
└── vars
    └── variables.yml
```

### 2. Customize Options

```bash
nano vars/variables.yml
```

```yml
#vars/variables.yml
---
create_containers: 1
default_container_name: alpine    
default_container_image: alpine
default_container_command: top


http_proxy: "http://yourproxy.com:8080"
https_proxy: "http://yourproxy.com:8080"
no_proxy: "localhost,127.0.0.1,10.96.0.0/12,192.168.59.0/24,192.168.39.0/24,192.168.49.0/24"
```

### 3. Jinja template if you are behind an HTTPS proxy server

If you are behind a proxy server, you must configure the docker service in the following way, since it ignores the configuration in `/etc/environment` file.

For more information visit the link below:

[Control Docker with systemd | Docker Documentation](https://docs.docker.com/config/daemon/systemd/#httphttps-proxy)

```bash
nano files/http-proxy.conf.j2
```

```yaml
# files/http-proxy.conf.j2

[Service]
Environment="HTTP_PROXY={{ http_proxy }}"
Environment="HTTPS_PROXY={{ https_proxy }}"
Environment="NO_PROXY={{ no_proxy }}"
```

### 4. Run the Playbook

If you have already made a copy of your `public key` to remote nodes run the following command:

```bash
ansible-playbook -l [target] -i [inventory file] playbook.yml
```

Otherwise you can run this playbook with username and password:

```bash
ansible-playbook -l [target] -i [inventory file] -u [user] -k [ssh password] playbook.yml
```

### 5. Managing created containers

Once you have run the playbook, a container called `alpine1` will be created on remote nodes (`alpine2`, `alpine3`, etc... depending on the value given to the `create_containers` variable).

To see the created container execute the following command:

```bash
sudo docker container ps -a
```

Too start the created container:

```bash
sudo docker start alpine1 [alpine2] [alpin3] [alpineN]
```

If you execute the following command you will enter the container where the `top`command will be executed inside `Alpine`:

```bash
sudo docker attach alpine1
```
