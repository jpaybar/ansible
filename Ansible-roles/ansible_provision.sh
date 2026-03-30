#!/bin/bash
# =============================================================
# ansible_provision.sh - Lanzador del playbook Ansible para la
#                        infraestructura OpenStack multi-red
# =============================================================

# Asegurar que ~/.ssh/config tiene las entradas para las redes OpenStack
SSH_CONFIG="$HOME/.ssh/config"

declare -A SSH_HOSTS=(
    ["172.20.0.*"]=""
    ["192.168.1.*"]=""
    ["192.168.2.*"]=""
    ["192.168.3.*"]=""
)

for host in "${!SSH_HOSTS[@]}"; do
    if ! grep -q "Host $host" "$SSH_CONFIG"; then
        echo "" >> "$SSH_CONFIG"
        echo "Host $host" >> "$SSH_CONFIG"
        echo "    StrictHostKeyChecking no" >> "$SSH_CONFIG"
        echo "    UserKnownHostsFile /dev/null" >> "$SSH_CONFIG"
        echo "Entrada SSH agregada para $host"
    fi
done

# Cargamos la clave SSH en el agente del sistema antes de lanzar
# Ansible. Es necesario porque server2 y server3 no tienen IP
# flotante y solo son accesibles saltando desde server1 (bastión).
# Ansible usa agent forwarding para propagar la clave en cada salto,
# por lo que si no está cargada en el agente, la conexión falla.
ssh-add ~/.ssh/id_rsa

# Lanzamos el playbook completo con el inventario dinámico OpenStack
ansible-playbook -i Inventories/openstack.yml Playbooks/site.yml