# How to deploy an instance on Openstack and provision it with WordPress using Ansible

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

## Intro:

`Ansible` has a large number of modules, including `Openstack`, which allows us to manage our private `cloud`:
[https://docs.ansible.com/ansible/2.9/modules/list_of_cloud_modules.html#openstack](https://docs.ansible.com/ansible/2.9/modules/list_of_cloud_modules.html#openstack)We also have some `collections` that allow us to do certain operations such as adding a new flavor to our `cloud`. We will use the following:

https://docs.ansible.com/ansible/latest/collections/openstack/cloud/compute_flavor_module.html

In this proof of concept we will create a new `flavor` in our `cloud`, for this we need to `source` our `admin RC file`. The administrator is the only one who can create `flavors`.

Once our custom `flavor` is created, we will create an `instance` with an `Ubuntu 18.04 LTS image` which we will `customize` using `Cloud-config`. In this case, we will make a `source of the RC file of the project`, which in our case will be `Demo`. We will create a new `user` in the system called `jpaybar`, we will assign his shell and name the system, etc...

For this we will use the `os_server` module:

https://docs.ansible.com/ansible/2.9/modules/os_server_module.html#os-server-module

When our `instance` is running, we will register it in the `in-memory inventory`. Obviously, this `instance is newly created` in our cloud so there is `no way to have it` in any kind of `static or dynamic inventory`. For this, the `add_host module` is useful, since it allows us to `temporarily` register an instance in an `inventory in memory` and be able to execute an `ansible playbook` as in this case:

[ansible.builtin.add_host module – Add a host (and alternatively a group) to the ansible-playbook in-memory inventory &mdash; Ansible Documentation](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/add_host_module.html)

Finally, we will run a third `playbook` with which we will provision the instance with `WordPress`.

## Project Folder:

```bash
vagrant@masterVM:~$ tree .
├── ansible.cfg
├── Create_our_own_flavor.yml
├── Deploy_Openstack_Instance_And_Provisioning_WordPress.yml
├── _images
│   └── wordpress_OK.PNG
├── README.md
└── wordpress
    ├── files
    │   ├── apache.conf.j2
    │   └── wp-config.php.j2
    ├── playbook.yml
    └── vars
        └── default.yml
```

## Files:

- `ansible.cfg`:  This file has the custom ansible configuration for this project.
- `Create_our_own_flavor.yml`: This playbook will create a new flavor in our cloud that we will later use to create our instance.

###### **NOTE:**

This playbook also adds a tcp rule to port 80 to enable HTTP access, if you don't have such a rule you can uncomment this section. If this rule does not exist, you will not be able to access the WordPress installation.

- `Deploy_Openstack_Instance_And_Provisioning_WordPress.yml`: This playbook will create the instance and customize it using Cloud-config, also add the instance to the in-memory inventory to later provision it with WordPress.
- `wordpress_OK.PNG`: A photo with the successful installation of WordPress.
- `README.md`: This file.
- `apache.conf.j2`: Apache configuration template.
- `wp-config.php.j2`: WordPress configuration template.
- `playbook.yml`: A yml file containing the playbook for provisioning WordPress. 
- `default.yml`: A yaml file containing all the variables to be used in the WordPress playbook.

## Running this Playbook

Quickstart guide for those already familiar with Ansible:

### 1. Obtain the playbook

```shell
git clone https://github.com/jpaybar/OpenStack.git
cd OpenStack/'Openstack CLI - Task Automation With Scripts'/'Deploy an instance on Openstack and provision it with WordPress using Ansible'
```

### 2. Customize Options

```shell
nano vars/default.yml
```

```yml
---
#System Settings
php_modules: [ 'php-curl', 'php-gd', 'php-mbstring', 'php-xml', 'php-xmlrpc', 'php-soap', 'php-intl', 'php-zip' ]

#MySQL Settings
mysql_root_password: "mysql_root_password"
mysql_db: "wordpress"
mysql_user: "vagrant"
mysql_password: "vagrant"

#HTTP Settings
http_host: "mywordpresswebsite"
http_conf: "mywordpresswebsite.conf"
http_port: "80"
```

### 3. Create custom flavor

The first thing we will do is make a `source of our administration RC file`. In the case of my Openstack cloud it would be:  

```bash
source admin-openrc.sh
```

It will ask us for the password by console.

The next step would be to run the Ansible playbook to create the flavor:

```bash
ansible-playbook Create_our_own_flavor.yml
```

We verify that our custom flavor has been created correctly:

```bash
vagrant@devstack:$ openstack flavor list | grep MY.small
| 1a | MY.small  |  2048 |   10 |         0 |     2 | True      |
```

### 4. Create and provision the instance

The first thing will be to make a source of our project RC file, in this case it will be from the `Demo` project:

```command
source demo-openrc.sh
```

The next step is to run the yml file named `Deploy_Openstack_Instance_And_Provisioning_WordPress.yml` which contains 3 playbooks.

The `first` playbook creates the instance and customizes it with the `userdata:` directive which calls the `cloud-config script`. This yml script creates the user `jpaybar`, assigns it a shell, adds the user's public key to authorized_keys, and finally names the system `wordpress.domain.local`

A very important part is that it adds the created instance to `Ansible's in-memory inventory` using the `add_host` module that will later allow us to run the following playbooks to customize and provision our instance with WordPress.

```yml
- name: Add "Ubuntu_18.04_WordPress" Instance to in-memory Inventory
    add_host: 
      name: wordpress 
      groups: ubuntu
      ansible_ssh_host: "{{ wordpress.server.public_v4 }}"
      ansible_user: jpaybar
      instance_name: "{{ wordpress.server.name }}"
```

#### **NOTE:**

We must create a `public-private key` pair on the host where we have our cloud and copy the content of the public key in the `userdata` directive:

```bash
ssh-keygen
```

Then copy the public key, like this:

```yml
userdata: |
        #cloud-config
        # create additional user
        users:
          - name: jpaybar
            gecos: Juan M. Payan Barea (Ansible User)
            sudo: ALL=(ALL) NOPASSWD:ALL
            shell: /bin/bash
            ssh_authorized_keys:
              - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDmW2InxZ0Wu7LmRIFf92Ot1BzBAaShaRkIYQCRBd7YUBsBUymnvKvkeYIDV1bEZrux839zkS51mUHY1lZASMpaYrcxTTwGsLc24kbDTVIch/U26q1/vXcg8GdZ350zZ7tjYnJ84YQ9AWZzkUSYfnbuTtmlxAO/Nxd4zWeDcJ3yZLIsU8cBhBXm8BVhheoT/Ybkv4U0uX1uO03li6H3sTZrqhTnokpIv70XDClX1aWh28VXkBpxf5lR3gsnn+sc21zBwuoAMvWErOO/TPGXRUBHFjK5eQY1klaONuNkPd35WzC+SBzoyqTGicfRlEo/E/4OGG7WbKR8ZOtmGPQKvbMc5A8tGA7rwIDH7IJ8Cwgo3C9Jt6P9HSaJMO6MZw2RgOtEoArTCkbOtIdwCSPYEo1mxR2bUhjEFzg+nETLubU2jDiE8gTLtycf3lSjGlY2LykCBQDSjnOe6CdcKyomixBW4vQWEbVyb99d+JwHutfTi3MNc+nD3N88CgNR+8v1jkM= vagrant@devstack
```

The `second` playbook adds the google `DNS server 8.8.8.8 to /etc/resolv.conf` and in our case, being behind a corporate network, adds the proxy server of our network to `/etc/environment`. It is important to modify the server with the corresponding data or in case of connecting directly, you can comment on this section of the playbook.

```yml
- name: Add proxy server to /etc/environment
      lineinfile:
        path: /etc/environment
        line: "{{ item.line }}"
      loop:
        - { line: 'export http_proxy="http://your.proxy.here:8080"' }
        - { line: 'export https_proxy="http://your.proxy.here:8080"' }
```

We also specify the private key with which we will connect to the instance:

```yml
vars:
     ansible_ssh_private_key_file: ~/.ssh/jpaybar
```

And we use the `wait_for_connection` module to wait for the instance's SSH server to become available:

```yml
- name: Wait for SSH service to become available
      wait_for_connection:
        delay: 5
        timeout: 300
```

And last but not least, the `third` playbook provisioned the instance and installed `WordPress`. In this case, we actually import the playbook using Ansible's `import_playbook` module.

```yml
- name: Install WordPress on "Ubuntu_18.04_WordPress" Instance 
  import_playbook: wordpress/playbook.yml
```

### 5. Checking the WordPress installation

Once the installation is complete, you will be able to access the initial WordPress setup page:

```http
http://ip
```

![wordpress_OK.PNG](https://github.com/jpaybar/Ansible/blob/main/Ansible-playbooks/Deploy%20an%20instance%20on%20Openstack%20and%20provision%20it%20with%20WordPress%20using%20Ansible/_images/wordpress_OK.PNG)

## Author Information

Juan Manuel Payán Barea    (IT Technician) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
