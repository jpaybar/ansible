#!/bin/bash
# setup_target_vms.sh
#
# Levanta 3 VMs KVM/libvirt (Ubuntu cloud image) para el lab de Ansible.
# Genera un inventario estático YAML en el directorio de trabajo actual.
#
# Uso:
#   chmod +x setup_target_vms.sh
#   ./setup_target_vms.sh
#
# Requisitos:
#   - KVM/libvirt instalado y activo (libvirtd en marcha)
#   - virt-install >= 3.0, qemu-img, virsh disponibles
#   - Imagen base qcow2 descargada en BASE_IMAGE_DIR

set -euo pipefail

# ------------------------------------------------------------------------------
# VARIABLES — ajusta aquí los recursos y rutas antes de ejecutar
# ------------------------------------------------------------------------------

# Nombres de las VMs
VM_NAMES=("server1" "server2" "server3")

# Recursos por VM
VM_CPUS=1
VM_RAM_MB=1024
VM_DISK_GB=10

# Imagen base Ubuntu cloud (qcow2)
BASE_IMAGE_DIR="/var/lib/libvirt/user-images"
BASE_IMAGE_NAME="noble-server-cloudimg-amd64.img"   # Ubuntu 24.04
BASE_IMAGE="${BASE_IMAGE_DIR}/${BASE_IMAGE_NAME}"

# Usuario SSH de la imagen cloud Ubuntu
SSH_USER="ubuntu"
SSH_KEY="${HOME}/.ssh/id_rsa"
SSH_PUB_KEY="${HOME}/.ssh/id_rsa.pub"

# Red libvirt
LIBVIRT_NETWORK="default"

# Inventario generado en el directorio de trabajo actual
INVENTORY="${PWD}/hosts.yml"

# Directorio temporal para ficheros cloud-init
CLOUD_INIT_TMP="/tmp"

# Array asociativo para almacenar IPs asignadas por DHCP
declare -A VM_IPS

# ------------------------------------------------------------------------------
# COLORES
# ------------------------------------------------------------------------------

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_CYAN="\033[0;36m"
COLOR_BOLD="\033[1m"

msg_info()    { echo -e "${COLOR_CYAN}${COLOR_BOLD}==> $*${COLOR_RESET}"; }
msg_ok()      { echo -e "${COLOR_GREEN}    [OK]    $*${COLOR_RESET}"; }
msg_warn()    { echo -e "${COLOR_YELLOW}    [WARN]  $*${COLOR_RESET}"; }
msg_error()   { echo -e "${COLOR_RED}    [ERROR] $*${COLOR_RESET}"; }
msg_detail()  { echo -e "    $*"; }
msg_section() { echo -e "${COLOR_BOLD}--- $* ---${COLOR_RESET}"; }

# ------------------------------------------------------------------------------
# FUNCIONES
# ------------------------------------------------------------------------------

check_prerequisites() {
    msg_info "Validando requisitos previos..."

    msg_detail "Buscando imagen base '${BASE_IMAGE_NAME}' en ${BASE_IMAGE_DIR}..."
    BASE_IMAGE=$(find "${BASE_IMAGE_DIR}" -name "${BASE_IMAGE_NAME}" -type f 2>/dev/null | head -1)
    if [[ -z "${BASE_IMAGE}" ]]; then
        echo ""
        msg_error "No se encuentra la imagen base '${BASE_IMAGE_NAME}' en ${BASE_IMAGE_DIR}."
        echo ""
        echo "    Descárgala con:"
        echo "      wget -O ${BASE_IMAGE_DIR}/${BASE_IMAGE_NAME} https://cloud-images.ubuntu.com/noble/current/${BASE_IMAGE_NAME}"
        echo "      sudo chown root:libvirt ${BASE_IMAGE_DIR}/${BASE_IMAGE_NAME}"
        echo "      sudo chmod 0664 ${BASE_IMAGE_DIR}/${BASE_IMAGE_NAME}"
        echo ""
        exit 1
    fi
    msg_ok "Imagen base encontrada: ${BASE_IMAGE}"

    for cmd in virt-install qemu-img virsh ssh-keyscan; do
        if ! command -v "${cmd}" &>/dev/null; then
            msg_error "'${cmd}' no está disponible. Instala el paquete correspondiente."
            exit 1
        fi
    done

    if ! virsh net-info "${LIBVIRT_NETWORK}" &>/dev/null; then
        msg_error "La red libvirt '${LIBVIRT_NETWORK}' no existe o no está activa."
        exit 1
    fi

    msg_ok "Requisitos previos OK."
}

check_ssh_key() {
    echo ""
    msg_info "Comprobando clave SSH..."

    if [[ -f "${SSH_PUB_KEY}" ]]; then
        msg_ok "Clave SSH encontrada: ${SSH_PUB_KEY}"
    else
        msg_warn "Clave SSH no encontrada. Generando ${SSH_KEY} (RSA 4096)..."
        ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_KEY}"
        msg_ok "Clave generada: ${SSH_PUB_KEY}"
    fi
}

generate_cloud_init() {
    local vm="$1"
    local public_key
    public_key=$(cat "${SSH_PUB_KEY}")

    local cloud_init_file="${CLOUD_INIT_TMP}/cloud-init-${vm}.yml"

    cat > "${cloud_init_file}" << EOF
#cloud-config
hostname: ${vm}
fqdn: ${vm}.lab.local
manage_etc_hosts: true

users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${public_key}

ssh_pwauth: false

package_update: false
package_upgrade: false
EOF

    echo "${cloud_init_file}"
}

delete_vm() {
    local vm="$1"

    if virsh dominfo "${vm}" &>/dev/null; then
        msg_detail "Eliminando VM existente: ${vm}"

        if virsh domstate "${vm}" | grep -q "running"; then
            virsh destroy "${vm}" &>/dev/null || true
        fi

        virsh undefine "${vm}" --remove-all-storage &>/dev/null || true
        msg_ok "${vm} eliminada."
    else
        msg_detail "${vm} no existe, nada que eliminar."
    fi

    # Limpiar known_hosts para evitar conflictos de fingerprint
    ssh-keygen -R "${vm}" 2>/dev/null || true
}

create_disk() {
    local vm="$1"
    local disk_path="${BASE_IMAGE_DIR}/${vm}.qcow2"

    echo -e "    Creando disco COW: ${disk_path}" >&2
    qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMAGE}" "${disk_path}" "${VM_DISK_GB}G" >&2

    echo "${disk_path}"
}

create_vm() {
    local vm="$1"
    local disk_path="$2"
    local cloud_init_file="$3"

    msg_detail "Lanzando ${vm}..."
    virt-install \
        --name "${vm}" \
        --memory "${VM_RAM_MB}" \
        --vcpus "${VM_CPUS}" \
        --disk "${disk_path}",format=qcow2 \
        --os-variant ubuntu24.04 \
        --network network="${LIBVIRT_NETWORK}" \
        --cloud-init user-data="${cloud_init_file}" \
        --import \
        --noautoconsole \
        --wait 0

    msg_ok "${vm} creada y arrancando."
}

wait_for_ip() {
    local vm="$1"

    echo -ne "${COLOR_CYAN}    Esperando IP de ${vm}...${COLOR_RESET}"
    local ip=""
    local attempts=0
    local max_attempts=30

    while [[ -z "${ip}" && ${attempts} -lt ${max_attempts} ]]; do
        sleep 5
        ip=$(virsh domifaddr "${vm}" 2>/dev/null \
            | grep -oP '(\d{1,3}\.){3}\d{1,3}' \
            | head -1 || true)
        attempts=$((attempts + 1))
        echo -n "."
    done

    if [[ -z "${ip}" ]]; then
        echo ""
        msg_error "${vm} no obtuvo IP tras $((max_attempts * 5)) segundos."
        exit 1
    fi

    VM_IPS["${vm}"]="${ip}"
    echo -e " ${COLOR_GREEN}${ip}${COLOR_RESET}"
}

wait_for_ssh() {
    local vm="$1"
    local ip="${VM_IPS[${vm}]}"

    echo -ne "    ${vm} (${ip})..."
    until ssh -o ConnectTimeout=5 \
              -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              -o BatchMode=yes \
              -i "${SSH_KEY}" \
              "${SSH_USER}@${ip}" true 2>/dev/null; do
        sleep 5
        echo -n "."
    done
    echo -e " ${COLOR_GREEN}OK${COLOR_RESET}"
}

configure_ssh_config() {
    echo ""
    msg_info "Configurando ~/.ssh/config..."

    local ssh_config="${HOME}/.ssh/config"

    if [[ ! -f "${ssh_config}" ]]; then
        touch "${ssh_config}"
        chmod 600 "${ssh_config}"
    fi

    if ! grep -q "# ansible-lab" "${ssh_config}"; then
        cat >> "${ssh_config}" << 'EOF'

# ansible-lab
Host 192.168.122.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    IdentityFile ~/.ssh/id_rsa
EOF
        msg_ok "Bloque SSH añadido a ${ssh_config}."
    else
        msg_warn "Bloque SSH ya presente en ${ssh_config}, no se duplica."
    fi
}

update_known_hosts() {
    echo ""
    msg_info "Actualizando ~/.ssh/known_hosts..."

    for vm in "${VM_NAMES[@]}"; do
        local ip="${VM_IPS[${vm}]}"

        # Limpiar entradas anteriores por IP y por nombre
        ssh-keygen -R "${ip}" 2>/dev/null || true
        ssh-keygen -R "${vm}" 2>/dev/null || true

        # Obtener fingerprint por IP
        local key
        key=$(ssh-keyscan -t ed25519 "${ip}" 2>/dev/null)

        if [[ -n "${key}" ]]; then
            # Entrada por IP (la original)
            echo "${key}" >> "${HOME}/.ssh/known_hosts"
            # Entrada por nombre (misma clave, sustituye IP por hostname)
            echo "${key}" | sed "s/^${ip}/${vm}/" >> "${HOME}/.ssh/known_hosts"
            msg_ok "Fingerprint de ${vm} (${ip}) añadido por IP y por nombre."
        else
            msg_warn "No se pudo obtener fingerprint de ${vm} (${ip})."
        fi
    done
}

update_etc_hosts() {
    echo ""
    msg_info "Actualizando /etc/hosts..."

    for vm in "${VM_NAMES[@]}"; do
        local ip="${VM_IPS[${vm}]}"
        sudo sed -i "/${vm}/d" /etc/hosts
        echo "${ip} ${vm}" | sudo tee -a /etc/hosts > /dev/null
        msg_ok "${ip} ${vm}"
    done
}

generate_inventory() {
    echo ""
    msg_info "Generando inventario Ansible: ${INVENTORY}"

    cat > "${INVENTORY}" << EOF
all:
  vars:
    ansible_python_interpreter: "/usr/bin/python3"
### Para Rhaap el inventario no debe tener ni usuario ni credenciales ya que las configuramos desde el propio aap    
#   ansible_user: ${SSH_USER}
#   ansible_ssh_private_key_file: ${SSH_KEY}

  children:
    proxy:
      hosts:
        server1:
          ansible_host: ${VM_IPS[server1]}
    webservers:
      hosts:
        server2:
          ansible_host: ${VM_IPS[server2]}
    dbservers:
      hosts:
        server3:
          ansible_host: ${VM_IPS[server3]}
    wordpress:
      hosts:
        server2:
          ansible_host: ${VM_IPS[server2]}
EOF
    msg_ok "Inventario generado."
}

print_summary() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  Lab listo${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-10s %s${COLOR_RESET}\n" "VM" "IP"
    printf "  %-10s %s\n" "----------" "---------------"
    for vm in "${VM_NAMES[@]}"; do
        printf "  ${COLOR_GREEN}%-10s %s${COLOR_RESET}\n" "${vm}" "${VM_IPS[${vm}]}"
    done
    echo ""
    echo -e "  Inventario : ${COLOR_CYAN}${INVENTORY}${COLOR_RESET}"
    echo -e "  Usuario SSH: ${COLOR_CYAN}${SSH_USER}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------

check_prerequisites
check_ssh_key
configure_ssh_config

echo ""
msg_info "Eliminando VMs existentes..."
for vm in "${VM_NAMES[@]}"; do
    delete_vm "${vm}"
done

echo ""
msg_info "Creando VMs..."
for vm in "${VM_NAMES[@]}"; do
    echo ""
    msg_section "${vm}"
    disk_path=$(create_disk "${vm}")
    cloud_init_file=$(generate_cloud_init "${vm}")
    create_vm "${vm}" "${disk_path}" "${cloud_init_file}"
done

echo ""
msg_info "Esperando IPs por DHCP..."
for vm in "${VM_NAMES[@]}"; do
    wait_for_ip "${vm}"
done

echo ""
msg_info "Esperando SSH en cada VM..."
for vm in "${VM_NAMES[@]}"; do
    wait_for_ssh "${vm}"
done

update_known_hosts
update_etc_hosts
generate_inventory
print_summary
