#!/bin/bash
# deploy-k8s-lab.sh

# Despliega las VMs del lab Kubernetes sobre KVM/libvirt a partir de una imagen
# base Ubuntu 24.04. Crea y configura tres nodos (master, worker1, worker2)
# con recursos, IPs y MACs estáticas definidas, e inyecta via cloud-init el
# hostname, /etc/hosts y clave SSH. Al finalizar genera el inventario de Ansible
# y resuelve vars/variables.yml con la IP del master y la versión de Kubernetes
# disponible en el repositorio oficial, listo para lanzar el playbook.

set -e

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
section() {
    echo -e "\n${BOLD}${YELLOW}===========================================${RESET}"
    echo -e "${BOLD}${YELLOW}  $*${RESET}"
    echo -e "${BOLD}${YELLOW}===========================================${RESET}"
}

# Directorio donde se almacenan los discos de las VMs
STORAGE_DIR="/var/lib/libvirt/user-images"

# Imagen base Ubuntu 24.04 (noble) cloud image
BASE_IMAGE=$(find "${STORAGE_DIR}" -name "noble-server-cloudimg-amd64.img" 2>/dev/null | head -1)

# Directorio raíz del playbook de Ansible (relativo a este script)
PLAYBOOK_DIR="$(dirname "$(realpath "$0")")"

# Minor version de Kubernetes objetivo
K8S_MINOR_VERSION="1.32"

# --- Validaciones previas ---
section "Validaciones previas"

if [ ! -d "${STORAGE_DIR}" ]; then
    error "El directorio ${STORAGE_DIR} no existe."
    error "Créalo con los permisos correctos:"
    echo  "        sudo mkdir -p ${STORAGE_DIR}"
    echo  "        sudo chown root:libvirt ${STORAGE_DIR}"
    echo  "        sudo chmod 0775 ${STORAGE_DIR}"
    exit 1
fi

if [ ! -f "${BASE_IMAGE}" ]; then
    error "No se encontró la imagen base requerida: ${BASE_IMAGE}"
    error "Descárgala con:"
    echo  "        wget -P ${STORAGE_DIR} https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    echo  "        sudo mv ${STORAGE_DIR}/noble-server-cloudimg-amd64.img ${BASE_IMAGE}"
    echo  "        sudo chown root:libvirt ${BASE_IMAGE}"
    echo  "        sudo chmod 0664 ${BASE_IMAGE}"
    exit 1
fi

info "Imagen base encontrada: $(basename ${BASE_IMAGE})"

# Red libvirt a la que se conectarán las VMs
NETWORK="default"

# Ruta de la clave SSH para acceso root a las VMs
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# Arrays asociativos con los recursos de cada VM
declare -A RAM
declare -A VCPUS
declare -A DISK
declare -A IPS
declare -A MACS
declare -A HOSTNAMES

RAM[master]=4096
RAM[worker1]=4096
RAM[worker2]=4096

VCPUS[master]=2
VCPUS[worker1]=2
VCPUS[worker2]=2

DISK[master]=30
DISK[worker1]=20
DISK[worker2]=20

IPS[master]="192.168.122.110"
IPS[worker1]="192.168.122.111"
IPS[worker2]="192.168.122.112"

MACS[master]="52:54:00:00:02:01"
MACS[worker1]="52:54:00:00:02:02"
MACS[worker2]="52:54:00:00:02:03"

HOSTNAMES[master]="k8smaster1"
HOSTNAMES[worker1]="k8sworker1"
HOSTNAMES[worker2]="k8sworker2"

# Orden de creación de las VMs
VMS=("master" "worker1" "worker2")

# --- Gestión de clave SSH ---
section "Clave SSH"

if [ -z "${SSH_KEY_PATH}" ]; then
    warn "No se encontró ningún par de claves SSH en ${HOME}/.ssh/. Generando..."
    SSH_KEY_PATH="${HOME}/.ssh/id_rsa"
    ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_KEY_PATH}"
    info "Par de claves generado en ${SSH_KEY_PATH}"
else
    info "Par de claves encontrado: ${SSH_KEY_PATH}. Reutilizando."
fi

# Carga la clave pública en memoria para inyectarla en cloud-init
SSH_PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Copiar la clave pública al directorio public_key/ del playbook
mkdir -p "${PLAYBOOK_DIR}/public_key"
cp "${SSH_KEY_PATH}.pub" "${PLAYBOOK_DIR}/public_key/kubernetesop.pub"
info "Clave pública copiada a ${PLAYBOOK_DIR}/public_key/kubernetesop.pub"

# --- Configuración SSH config ---
section "Configuracion SSH"

SSH_CONFIG="${HOME}/.ssh/config"
K8S_HOSTS="${IPS[master]} ${IPS[worker1]} ${IPS[worker2]}"

if [ ! -f "${SSH_CONFIG}" ]; then
    touch "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"
    info "Fichero ${SSH_CONFIG} creado con permisos 600."
else
    info "Fichero ${SSH_CONFIG} encontrado. Reutilizando."
fi

if ! grep -q "${IPS[master]}" "${SSH_CONFIG}"; then
    cat >> "${SSH_CONFIG}" <<EOF

# Kubernetes lab - generado por deploy-k8s-lab.sh
Host ${K8S_HOSTS}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    GSSAPIAuthentication no
EOF
    info "Bloque SSH para VMs del lab añadido en ${SSH_CONFIG}."
else
    info "Bloque SSH para VMs del lab ya existe en ${SSH_CONFIG}. Sin cambios."
fi

# --- Generar fichero cloud-init por VM ---
generate_cloud_init() {
    local VM_ROLE=$1
    local VM_HOSTNAME="${HOSTNAMES[$VM_ROLE]}"
    local CLOUD_INIT_FILE="/tmp/k8s-user-data-${VM_ROLE}"

    cat > "${CLOUD_INIT_FILE}" <<EOF
#cloud-config

hostname: ${VM_HOSTNAME}
fqdn: ${VM_HOSTNAME}.lab.local

manage_etc_hosts: false

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: 'ubuntu'
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}

write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1   localhost localhost.localdomain
      ${IPS[master]}  ${HOSTNAMES[master]}.lab.local ${HOSTNAMES[master]}
      ${IPS[worker1]} ${HOSTNAMES[worker1]}.lab.local ${HOSTNAMES[worker1]}
      ${IPS[worker2]} ${HOSTNAMES[worker2]}.lab.local ${HOSTNAMES[worker2]}

runcmd:
  - apt-get update -y
  - apt-get install -y curl wget gnupg
  - systemctl enable --now chrony
  - systemctl restart ssh
EOF

    info "Fichero cloud-init generado en ${CLOUD_INIT_FILE}" >&2
    echo "${CLOUD_INIT_FILE}"
}

# --- Reservar IP estática en dnsmasq para la VM ---
reserve_ip() {
    local VM_ROLE=$1
    local MAC="${MACS[$VM_ROLE]}"
    local IP="${IPS[$VM_ROLE]}"

    virsh net-update default delete ip-dhcp-host \
        "<host mac='${MAC}' ip='${IP}'/>" \
        --live --config &>/dev/null || true

    virsh net-update default add ip-dhcp-host \
        "<host mac='${MAC}' ip='${IP}'/>" \
        --live --config
}

# --- Eliminar VM si ya existe ---
delete_vm_if_exists() {
    local VM_NAME=$1
    if virsh dominfo "$VM_NAME" &>/dev/null; then
        warn "VM '${VM_NAME}' ya existe. Eliminando..."
        virsh destroy "$VM_NAME" &>/dev/null || true
        virsh undefine "$VM_NAME" --remove-all-storage || true
        info "VM '${VM_NAME}' eliminada."
    fi
}

# --- Crear disco COW a partir de la imagen base ---
create_disk() {
    local VM_ROLE=$1
    local VM_NAME="${HOSTNAMES[$VM_ROLE]}"
    info "Creando disco COW para '${VM_NAME}' (${DISK[$VM_ROLE]}G)..."
    qemu-img create -f qcow2 \
        -F qcow2 \
        -b "$BASE_IMAGE" \
        "$STORAGE_DIR/${VM_NAME}.qcow2" \
        "${DISK[$VM_ROLE]}G"
    info "Disco creado: ${STORAGE_DIR}/${VM_NAME}.qcow2"
}

# --- Crear e importar la VM con virt-install ---
create_vm() {
    local VM_ROLE=$1
    local VM_NAME="${HOSTNAMES[$VM_ROLE]}"
    local CLOUD_INIT_FILE=$2
    info "Lanzando virt-install para '${VM_NAME}'..."
    virt-install \
        --name "$VM_NAME" \
        --ram "${RAM[$VM_ROLE]}" \
        --vcpus "${VCPUS[$VM_ROLE]}" \
        --disk path="$STORAGE_DIR/${VM_NAME}.qcow2",format=qcow2 \
        --os-variant ubuntu24.04 \
        --network network="$NETWORK",mac="${MACS[$VM_ROLE]}" \
        --cloud-init user-data="${CLOUD_INIT_FILE}" \
        --import \
        --noautoconsole
    info "VM '${VM_NAME}' creada y arrancando."
}

# --- Bucle principal ---
section "Despliegue de VMs"

for VM in "${VMS[@]}"; do
    VM_NAME="${HOSTNAMES[$VM]}"
    echo -e "\n${BOLD}  >> Procesando: ${VM_NAME}${RESET}"
    delete_vm_if_exists "$VM_NAME"
    rm -f "$STORAGE_DIR/${VM_NAME}.qcow2"
    create_disk "$VM"
    reserve_ip "$VM"
    info "Reserva DHCP registrada - MAC: ${MACS[$VM]}  IP: ${IPS[$VM]}"
    CLOUD_INIT_FILE=$(generate_cloud_init "$VM")
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${IPS[$VM]}" &>/dev/null || true
    create_vm "$VM" "${CLOUD_INIT_FILE}"
done

# --- Esperar a que las VMs estén accesibles por SSH ---
section "Esperando acceso SSH a los nodos"

for VM in "${VMS[@]}"; do
    IP="${IPS[$VM]}"
    VM_NAME="${HOSTNAMES[$VM]}"
    info "Esperando SSH en ${VM_NAME} (${IP})..."
    RETRIES=30
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
              -i "${SSH_KEY_PATH}" ubuntu@"${IP}" "uptime" &>/dev/null; do
        RETRIES=$((RETRIES - 1))
        if [ $RETRIES -eq 0 ]; then
            error "Timeout esperando SSH en ${VM_NAME} (${IP})"
            exit 1
        fi
        sleep 10
    done
    info "${VM_NAME} accesible por SSH."
done

# --- Consultar versión de Kubernetes disponible ---
section "Consultando versión de Kubernetes ${K8S_MINOR_VERSION} disponible"

# Descarga el índice de paquetes del repo oficial y extrae la versión más reciente
K8S_VERSION=$(curl -sL \
    "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR_VERSION}/deb/Packages" \
    | grep -A1 "^Package: kubelet$" \
    | grep "^Version:" \
    | awk '{print $2}' \
    | sort -V \
    | tail -1)

if [ -z "${K8S_VERSION}" ]; then
    error "No se pudo obtener la versión de Kubernetes desde el repositorio."
    error "Verifica conectividad con pkgs.k8s.io"
    exit 1
fi

info "Versión de Kubernetes disponible: ${K8S_VERSION}"

# --- Generar vars/variables.yml desde el template ---
section "Generando vars/variables.yml"

export CONTROLLER_NODE_IP="${IPS[master]}"
export K8S_VERSION="${K8S_VERSION}"
export K8S_MINOR_VERSION="${K8S_MINOR_VERSION}"

VARS_TEMPLATE="${PLAYBOOK_DIR}/vars/variables.yml.j2"
VARS_OUTPUT="${PLAYBOOK_DIR}/vars/variables.yml"

if [ ! -f "${VARS_TEMPLATE}" ]; then
    error "No se encontró el template ${VARS_TEMPLATE}"
    exit 1
fi

envsubst < "${VARS_TEMPLATE}" > "${VARS_OUTPUT}"
info "Fichero ${VARS_OUTPUT} generado correctamente."
info "  CONTROLLER_NODE_IP = ${CONTROLLER_NODE_IP}"
info "  K8S_VERSION        = ${K8S_VERSION}"
info "  K8S_MINOR_VERSION  = ${K8S_MINOR_VERSION}"

# --- Generar inventario de Ansible ---
section "Generando inventario de Ansible"

INVENTORY_FILE="${PLAYBOOK_DIR}/inventory_hosts.yml"

cat > "${INVENTORY_FILE}" <<EOF
##########################################################################
# Inventario generado automáticamente por deploy-k8s-lab.sh
# No editar manualmente
##########################################################################

all:
  children:
    kubernetes_cluster:
      vars:
        ansible_python_interpreter: "/usr/bin/python3"
        ansible_user: ubuntu
        ansible_ssh_private_key_file: ${SSH_KEY_PATH}
      children:
        controllers:
          hosts:
            ${HOSTNAMES[master]}:
              ansible_host: ${IPS[master]}
        nodes:
          hosts:
            ${HOSTNAMES[worker1]}:
              ansible_host: ${IPS[worker1]}
            ${HOSTNAMES[worker2]}:
              ansible_host: ${IPS[worker2]}
EOF

info "Inventario generado en ${INVENTORY_FILE}"

# --- Resumen final ---
section "Lab desplegado correctamente"

echo -e ""
printf "${BOLD}  %-15s %-25s %-20s %-8s %-6s${RESET}\n" \
    "VM" "FQDN" "IP" "RAM(MB)" "vCPUs"
echo -e "  ${YELLOW}------------------------------------------------------------------------${RESET}"
for VM in "${VMS[@]}"; do
    VM_NAME="${HOSTNAMES[$VM]}"
    printf "  ${GREEN}%-15s${RESET} %-25s ${YELLOW}%-20s${RESET} %-8s %-6s\n" \
        "${VM_NAME}" \
        "${VM_NAME}.lab.local" \
        "${IPS[$VM]}" \
        "${RAM[$VM]}" \
        "${VCPUS[$VM]}"
done

echo -e ""
echo -e "${BOLD}  Kubernetes version : ${GREEN}${K8S_VERSION}${RESET}"
echo -e "${BOLD}  Controller IP      : ${GREEN}${IPS[master]}${RESET}"
echo -e "${BOLD}  Inventario         : ${GREEN}${INVENTORY_FILE}${RESET}"
echo -e "${BOLD}  Variables          : ${GREEN}${VARS_OUTPUT}${RESET}"
echo -e ""
echo -e "${GREEN}  ssh ubuntu@<IP> -i ${SSH_KEY_PATH}${RESET}"
echo -e ""
echo -e "${BOLD}${YELLOW}  Para lanzar el playbook:${RESET}"
echo -e "  ansible-playbook -i ${INVENTORY_FILE} ${PLAYBOOK_DIR}/install_kubernetes.yml"
echo ""
