#!/bin/bash
# create_rhel_target_vms.sh
#
# Levanta 2 VMs KVM/libvirt (RHEL 8 y RHEL 9 cloud image) como targets
# para el lab de roles Ansible (common, users, hardening, node_exporter).
# Añade las VMs al inventario estático YAML existente sin borrar los grupos
# actuales (proxy, webservers, dbservers, wordpress).
#
# Uso:
#   chmod +x create_rhel_target_vms.sh
#   ./create_rhel_target_vms.sh
#
# Requisitos:
#   - KVM/libvirt instalado y activo (libvirtd en marcha)
#   - virt-install >= 3.0, qemu-img, virsh disponibles
#   - Imágenes base qcow2 de RHEL 8 y RHEL 9 descargadas en BASE_IMAGE_DIR
#   - Suscripción Red Hat activa (Developer Subscription) para registro

set -euo pipefail

# ------------------------------------------------------------------------------
# CARGAR CREDENCIALES — fichero .env en el mismo directorio que el script
# ------------------------------------------------------------------------------

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "[ERROR] No se encuentra el fichero .env"
    echo "        Crea un .env en el mismo directorio que el script con:"
    echo "          export RH_USERNAME=\"tu_usuario@redhat.com\""
    echo "          export RH_PASSWORD=\"tu_password\""
    exit 1
fi

# shellcheck source=.env
source "${ENV_FILE}"

if [[ -z "${RH_USERNAME:-}" || -z "${RH_PASSWORD:-}" ]]; then
    echo "[ERROR] RH_USERNAME o RH_PASSWORD no están definidas en el fichero .env"
    exit 1
fi

# ------------------------------------------------------------------------------
# VARIABLES — ajusta aquí los recursos y rutas antes de ejecutar
# ------------------------------------------------------------------------------

# Nombres de las VMs
VM_NAMES=("rhel8" "rhel9")

# Recursos por VM
VM_CPUS=2
VM_RAM_MB=2048
VM_DISK_GB=10

# Directorio de imágenes base
BASE_IMAGE_DIR="/var/lib/libvirt/user-images"

# Imágenes base RHEL (qcow2)
BASE_IMAGE_RHEL8="rhel-8.10-x86_64-kvm.qcow2"
BASE_IMAGE_RHEL9="rhel-9.7-x86_64-kvm.qcow2"

# Usuario SSH de las imágenes cloud RHEL
SSH_USER="cloud-user"
SSH_KEY="${HOME}/.ssh/id_rsa"
SSH_PUB_KEY="${HOME}/.ssh/id_rsa.pub"

# Red libvirt
LIBVIRT_NETWORK="default"

# Ruta del script — para construir rutas relativas portables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Inventario existente — ruta relativa al script, portable entre usuarios
INVENTORY="${SCRIPT_DIR}/Inventories/kvm/hosts.yml"

# Directorio temporal para ficheros cloud-init
CLOUD_INIT_TMP="/tmp"

# Array asociativo para almacenar IPs asignadas por DHCP
declare -A VM_IPS

# Intérprete Python para RHEL 8 — se detecta en bootstrap_python()
PYTHON_INTERPRETER_RHEL8="/bin/python3.9"

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

    # Comprobar imagen RHEL 8
    msg_detail "Buscando imagen RHEL 8 '${BASE_IMAGE_RHEL8}' en ${BASE_IMAGE_DIR}..."
    if [[ ! -f "${BASE_IMAGE_DIR}/${BASE_IMAGE_RHEL8}" ]]; then
        echo ""
        msg_error "No se encuentra la imagen RHEL 8 '${BASE_IMAGE_RHEL8}' en ${BASE_IMAGE_DIR}."
        echo ""
        echo "    Descárgala desde:"
        echo "      https://access.redhat.com/downloads → Red Hat Enterprise Linux 8 → KVM Guest Image"
        echo ""
        exit 1
    fi
    msg_ok "Imagen RHEL 8 encontrada: ${BASE_IMAGE_DIR}/${BASE_IMAGE_RHEL8}"

    # Comprobar imagen RHEL 9
    msg_detail "Buscando imagen RHEL 9 '${BASE_IMAGE_RHEL9}' en ${BASE_IMAGE_DIR}..."
    if [[ ! -f "${BASE_IMAGE_DIR}/${BASE_IMAGE_RHEL9}" ]]; then
        echo ""
        msg_error "No se encuentra la imagen RHEL 9 '${BASE_IMAGE_RHEL9}' en ${BASE_IMAGE_DIR}."
        echo ""
        echo "    Descárgala desde:"
        echo "      https://access.redhat.com/downloads → Red Hat Enterprise Linux 9 → KVM Guest Image"
        echo ""
        exit 1
    fi
    msg_ok "Imagen RHEL 9 encontrada: ${BASE_IMAGE_DIR}/${BASE_IMAGE_RHEL9}"

    # Comprobar comandos necesarios
    for cmd in virt-install qemu-img virsh ssh-keyscan; do
        if ! command -v "${cmd}" &>/dev/null; then
            msg_error "'${cmd}' no está disponible. Instala el paquete correspondiente."
            exit 1
        fi
    done

    # Comprobar red libvirt
    if ! virsh net-info "${LIBVIRT_NETWORK}" &>/dev/null; then
        msg_error "La red libvirt '${LIBVIRT_NETWORK}' no existe o no está activa."
        exit 1
    fi

    # Comprobar que el inventario existe
    if [[ ! -f "${INVENTORY}" ]]; then
        msg_error "No se encuentra el inventario: ${INVENTORY}"
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

    # El mismo user-data es válido para RHEL 8 y RHEL 9
    # cloud-init es agnóstico de la versión de RHEL
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

# No actualizamos paquetes en el arranque inicial
# Los roles Ansible se encargarán de la configuración
package_update: false
package_upgrade: false

# Registro automático en Red Hat al primer arranque
runcmd:
  - subscription-manager register --username=${RH_USERNAME} --password=${RH_PASSWORD} --auto-attach
EOF

    echo "${cloud_init_file}"
}

get_base_image() {
    local vm="$1"
    if [[ "${vm}" == "rhel8" ]]; then
        echo "${BASE_IMAGE_DIR}/${BASE_IMAGE_RHEL8}"
    else
        echo "${BASE_IMAGE_DIR}/${BASE_IMAGE_RHEL9}"
    fi
}

get_os_variant() {
    local vm="$1"
    if [[ "${vm}" == "rhel8" ]]; then
        echo "rhel8-unknown"
    else
        echo "rhel9-unknown"
    fi
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
    local base_image
    base_image=$(get_base_image "${vm}")
    local disk_path="${BASE_IMAGE_DIR}/${vm}.qcow2"

    echo -e "    Creando disco COW desde $(basename "${base_image}"): ${disk_path}" >&2
    qemu-img create -f qcow2 -F qcow2 -b "${base_image}" "${disk_path}" "${VM_DISK_GB}G" >&2

    echo "${disk_path}"
}

create_vm() {
    local vm="$1"
    local disk_path="$2"
    local cloud_init_file="$3"
    local os_variant
    os_variant=$(get_os_variant "${vm}")

    msg_detail "Lanzando ${vm} (${os_variant})..."
    virt-install \
        --name "${vm}" \
        --memory "${VM_RAM_MB}" \
        --vcpus "${VM_CPUS}" \
        --disk "${disk_path}",format=qcow2 \
        --os-variant "${os_variant}" \
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

        ssh-keygen -R "${ip}" 2>/dev/null || true
        ssh-keygen -R "${vm}" 2>/dev/null || true

        local key
        key=$(ssh-keyscan -t ed25519 "${ip}" 2>/dev/null)

        if [[ -n "${key}" ]]; then
            echo "${key}" >> "${HOME}/.ssh/known_hosts"
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

bootstrap_python() {
    echo ""
    msg_info "Bootstrap Python en VMs RHEL..."

    for vm in "${VM_NAMES[@]}"; do
        local ip="${VM_IPS[${vm}]}"

        # Detectar versión mayor de RHEL via raw (no necesita Python)
        local rhel_version
        rhel_version=$(ssh -o StrictHostKeyChecking=no \
                           -o UserKnownHostsFile=/dev/null \
                           -o BatchMode=yes \
                           -i "${SSH_KEY}" \
                           "${SSH_USER}@${ip}" \
                           "rpm -q --queryformat '%{VERSION}' redhat-release 2>/dev/null | cut -d. -f1" 2>/dev/null)

        msg_detail "${vm} → RHEL ${rhel_version} detectado"

        if [[ "${rhel_version}" == "8" ]]; then
            # RHEL 8 trae Python 3.6 por defecto — necesita Python 3.9
            msg_detail "Instalando python39 en ${vm}..."
            ssh -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o BatchMode=yes \
                -i "${SSH_KEY}" \
                "${SSH_USER}@${ip}" \
                "sudo dnf install -y python39 python3-libselinux &>/dev/null" 2>/dev/null
            msg_ok "${vm} → python39 instalado, intérprete: ${PYTHON_INTERPRETER_RHEL8}"
        else
            # RHEL 9 trae Python 3.9+ por defecto
            msg_ok "${vm} → Python 3.9+ disponible en /usr/bin/python3"
        fi
    done
}

update_inventory() {
    echo ""
    msg_info "Actualizando inventario Ansible: ${INVENTORY}"

    # Eliminar bloque rhel anterior si existe para evitar duplicados
    if grep -q "# rhel-lab" "${INVENTORY}"; then
        msg_warn "Bloque 'rhel' ya existe en el inventario, eliminando para regenerar..."
        # Borrar desde el marcador hasta el final del fichero
        sed -i '/# rhel-lab/,$d' "${INVENTORY}"
    fi

    # Añadir grupo rhel al final del inventario existente
    cat >> "${INVENTORY}" << EOF

    # rhel-lab
    rhel:
      vars:
        ansible_user: ${SSH_USER}
        ansible_ssh_private_key_file: ${SSH_KEY}
      hosts:
        rhel8:
          ansible_host: ${VM_IPS[rhel8]}
          ansible_python_interpreter: ${PYTHON_INTERPRETER_RHEL8}
        rhel9:
          ansible_host: ${VM_IPS[rhel9]}
          ansible_python_interpreter: /usr/bin/python3
EOF

    msg_ok "Grupo 'rhel' añadido al inventario."
}

print_summary() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  Lab RHEL listo${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-10s %-20s %s${COLOR_RESET}\n" "VM" "IP" "OS"
    printf "  %-10s %-20s %s\n" "----------" "---------------" "-------"
    printf "  ${COLOR_GREEN}%-10s %-20s %s${COLOR_RESET}\n" "rhel8" "${VM_IPS[rhel8]}" "RHEL 8"
    printf "  ${COLOR_GREEN}%-10s %-20s %s${COLOR_RESET}\n" "rhel9" "${VM_IPS[rhel9]}" "RHEL 9"
    echo ""
    echo -e "  Inventario : ${COLOR_CYAN}${INVENTORY}${COLOR_RESET}"
    echo -e "  Usuario SSH: ${COLOR_CYAN}${SSH_USER}${COLOR_RESET}"
    echo -e "  Grupo Ansible: ${COLOR_CYAN}rhel${COLOR_RESET}"
    echo ""
    echo -e "  Registro Red Hat: ${COLOR_CYAN}automático vía cloud-init (subscription-manager)${COLOR_RESET}"
    echo -e "  Verifica en: ${COLOR_CYAN}https://access.redhat.com/management/systems${COLOR_RESET}"
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
msg_info "Eliminando VMs RHEL existentes..."
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
bootstrap_python
update_inventory
print_summary
