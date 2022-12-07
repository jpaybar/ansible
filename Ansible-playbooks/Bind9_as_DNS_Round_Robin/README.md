# Bind9 as DNS Round Robin

This playbook installs `Bind9` as a DNS server and configures it to duplicate A pointers (Round Robin). These entries will point to 2 web servers (node1 and node2) with domain name `www.mydomain.com`. The `Apache` web server will display the node we are connected to when we enter our `www` address.

## Settings

- `main.yml`: The main playbook that points to the secondary ones.
- `playbooks/common.yml`: Playbook that installs prerequisites to all nodes.
- `playbooks/dnsservers.yml`: This playbook installs and configures Bind9 as a DNS server, copies the main configuration file, and creates the forward and reverse zone files.
- `playbooks/webservers.yml`: This playbook installs Apache2 as a web server and publishes a web page in which we will see which node we are connected to (Vagrant Machine).
- `playbooks/templates/index.html.j2`: Web page template.
- `playbooks/files/named.conf.local`: Bind9 general configuration file with the local zone.
- `playbooks/files/db.mydomain.com`: Direct zone configuration file.
- `playbooks/files/db.192.168.10`: Reverse zone configuration file.

## Running this Playbook

Quickstart guide for those already familiar with Ansible:

### 1. Obtain the playbook

```shell
git clone https://github.com/jpaybar/ansible-playbooks.git
cd ansible-playbooks/Bind9_as_DNS_Round_Robin
```

### 2. Main playbook file (main.yml)

```bash
nano main.yml
```

```yml
---
- import_playbook: playbooks/common.yml
- import_playbook: playbooks/webservers.yml
- import_playbook: playbooks/dnsservers.yml
```

### 3. Run the Playbook

```command
ansible-playbook -l [target] -i [inventory file] -u [remote user] -k main.yml
```

### 4. Test the Playbook

You can verify that [www.mydomain.com]() is balanced between node1 and node2, repeating the DNS query with dig.

```bash
dig @10.1.1.103 www.mydomain.com
```

We can see it much more clearly through the browser, for which it is necessary to add the IP address of the DNS server as the primary name resolver `192.168.10.50` and we will be able to check how the requests are balanced between the two web servers `node1` and `node2` (we will have to reload the browser, CTRL+F5).