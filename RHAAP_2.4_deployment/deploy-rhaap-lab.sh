#!/bin/bash
# deploy-rhaap-lab.sh

# Despliega las VMs del lab RHAAP 2.4 sobre KVM/libvirt a partir de una imagen
# base RHEL 9.7. Crea y configura tres nodos (controller, execution, database)
# con recursos, IPs y MACs estáticas definidas, e inyecta via cloud-init el
# hostname, /etc/hosts, clave SSH y configuración base del OS lista para
# lanzar el installer de Red Hat Ansible Automation Platform.

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

# Imagen base RHEL concreta validada para este lab (RHEL 9.7)
BASE_IMAGE="${STORAGE_DIR}/rhel-9.7-x86_64-kvm.qcow2"

# --- Validaciones previas ---
section "Validaciones previas"

# Verificar que el directorio de almacenamiento existe
if [ ! -d "${STORAGE_DIR}" ]; then
    error "El directorio ${STORAGE_DIR} no existe."
    error "Créalo con los permisos correctos:"
    echo  "        sudo mkdir -p ${STORAGE_DIR}"
    echo  "        sudo chown root:libvirt ${STORAGE_DIR}"
    echo  "        sudo chmod 0775 ${STORAGE_DIR}"
    exit 1
fi

# Verificar que existe la imagen base RHEL 9.7 requerida
if [ ! -f "${BASE_IMAGE}" ]; then
    error "No se encontró la imagen base requerida: ${BASE_IMAGE}"
    error "Descárgala desde https://access.redhat.com/downloads"
    echo  "        (Red Hat Enterprise Linux 9.7 KVM Guest Image)"
    echo  "        y colócala en ${STORAGE_DIR} con:"
    echo  "        sudo chown root:libvirt ${BASE_IMAGE}"
    echo  "        sudo chmod 0664 ${BASE_IMAGE}"
    exit 1
fi

info "Imagen base encontrada: $(basename ${BASE_IMAGE})"

# Red libvirt a la que se conectarán las VMs
NETWORK="default"

# Credenciales del portal Red Hat (subscription-manager y registry.redhat.io)
source "$(dirname "$(realpath "$0")")/.env"

# Ruta de la clave SSH para acceso root a las VMs
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# Arrays asociativos con los recursos de cada VM
declare -A RAM
declare -A VCPUS
declare -A DISK
declare -A IPS
declare -A MACS

RAM[controller]=8192
RAM[execution]=4096
RAM[database]=4096

VCPUS[controller]=2
VCPUS[execution]=2
VCPUS[database]=2

DISK[controller]=40
DISK[execution]=20
DISK[database]=20

IPS[controller]="192.168.122.101"
IPS[execution]="192.168.122.102"
IPS[database]="192.168.122.103"

# MACs estáticas asociadas a cada VM para reserva DHCP en dnsmasq
MACS[controller]="52:54:00:00:01:01"
MACS[execution]="52:54:00:00:01:02"
MACS[database]="52:54:00:00:01:03"

# Orden de creación de las VMs
VMS=("controller" "execution" "database")

# --- Gestión de clave SSH ---
section "Clave SSH"

if [ ! -f "${SSH_KEY_PATH}" ]; then
    warn "No se encontró clave SSH en ${SSH_KEY_PATH}. Generando..."
    ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_KEY_PATH}"
    info "Clave SSH generada en ${SSH_KEY_PATH}"
else
    info "Clave SSH encontrada en ${SSH_KEY_PATH}. Reutilizando."
fi

# Carga la clave pública en memoria para inyectarla en cloud-init
SSH_PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")

# --- Configuracion SSH config ---
section "Configuracion SSH"

SSH_CONFIG="${HOME}/.ssh/config"
RHAAP_HOSTS="${IPS[controller]} ${IPS[execution]} ${IPS[database]}"

# Crear ~/.ssh/config si no existe con permisos correctos (600)
if [ ! -f "${SSH_CONFIG}" ]; then
    touch "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"
    info "Fichero ${SSH_CONFIG} creado con permisos 600."
else
    info "Fichero ${SSH_CONFIG} encontrado. Reutilizando."
fi

# Añadir bloque solo si no existe ya (evita duplicados en re-despliegues)
if ! grep -q "${IPS[controller]}" "${SSH_CONFIG}"; then
    cat >> "${SSH_CONFIG}" <<EOF

# RHAAP lab - generado por deploy-rhaap-lab.sh
Host ${RHAAP_HOSTS}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    GSSAPIAuthentication no
EOF
    info "Bloque SSH para VMs del lab añadido en ${SSH_CONFIG}."
else
    info "Bloque SSH para VMs del lab ya existe en ${SSH_CONFIG}. Sin cambios."
fi

# --- Generar fichero cloud-init por VM ---
# Recibe el nombre de la VM y escribe un user-data específico en /tmp
generate_cloud_init() {
    local VM_NAME=$1
    local CLOUD_INIT_FILE="/tmp/rhaap-user-data-${VM_NAME}"

    cat > "${CLOUD_INIT_FILE}" <<EOF
#cloud-config

# Hostname corto y FQDN del nodo
hostname: rhaap-${VM_NAME}
fqdn: rhaap-${VM_NAME}.lab.local

# El /etc/hosts lo gestionamos nosotros en write_files
manage_etc_hosts: false

users:
  - name: root
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}

write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1   localhost localhost.localdomain
      ${IPS[${VMS[0]}]} rhaap-${VMS[0]}.lab.local rhaap-${VMS[0]}
      ${IPS[${VMS[1]}]} rhaap-${VMS[1]}.lab.local rhaap-${VMS[1]}
      ${IPS[${VMS[2]}]} rhaap-${VMS[2]}.lab.local rhaap-${VMS[2]}

runcmd:
  # 1. Registrar el nodo en Red Hat Subscription Manager y adjuntar suscripción
  - subscription-manager register --username=${RH_USERNAME} --password=${RH_PASSWORD} --auto-attach
  # 2. Actualizar el sistema tras el registro antes de instalar RHAAP
  - dnf update -y
  # 3. Forzar SELinux en modo enforcing (requerido por el installer de RHAAP)
  - setenforce 1
  - sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
  # 4. Habilitar firewalld (el installer de RHAAP lo necesita activo)
  - systemctl enable --now firewalld
  # 5. Habilitar sincronización horaria (crítico en entornos multi-nodo)
  - systemctl enable --now chronyd
  # 6. Reinicia sshd para que aplique la configuración del agente
  - systemctl restart sshd
EOF

    info "Fichero cloud-init generado en ${CLOUD_INIT_FILE}" >&2
    # Devuelve la ruta del fichero generado para usarla en create_vm
    echo "${CLOUD_INIT_FILE}"
}

# --- Reservar IP estática en dnsmasq para la VM ---
# Asocia la MAC a la IP en la red libvirt antes de arrancar la VM
# Elimina la reserva previa si existe para garantizar re-despliegues limpios
reserve_ip() {
    local VM_NAME=$1
    local MAC="${MACS[$VM_NAME]}"
    local IP="${IPS[$VM_NAME]}"

    virsh net-update default delete ip-dhcp-host \
        "<host mac='${MAC}' ip='${IP}'/>" \
        --live --config &>/dev/null || true

    virsh net-update default add ip-dhcp-host \
        "<host mac='${MAC}' ip='${IP}'/>" \
        --live --config
}

# --- Eliminar VM si ya existe ---
# Destruye y elimina la VM junto con su almacenamiento
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
# qemu-img crea un disco incremental (copy-on-write) que no modifica la imagen base
create_disk() {
    local VM_NAME=$1
    info "Creando disco COW para '${VM_NAME}' (${DISK[$VM_NAME]}G)..."
    qemu-img create -f qcow2 \
        -F qcow2 \
        -b "$BASE_IMAGE" \
        "$STORAGE_DIR/${VM_NAME}.qcow2" \
        "${DISK[$VM_NAME]}G"
    info "Disco creado: ${STORAGE_DIR}/${VM_NAME}.qcow2"
}

# --- Crear e importar la VM con virt-install ---
# Usa el disco ya creado y aplica el cloud-init específico de esta VM
create_vm() {
    local VM_NAME=$1
    local CLOUD_INIT_FILE=$2
    info "Lanzando virt-install para '${VM_NAME}'..."
    virt-install \
        --name "$VM_NAME" \
        --ram "${RAM[$VM_NAME]}" \
        --vcpus "${VCPUS[$VM_NAME]}" \
        --disk path="$STORAGE_DIR/${VM_NAME}.qcow2",format=qcow2 \
        --os-variant rhel9.0 \
        --network network="$NETWORK",mac="${MACS[$VM_NAME]}" \
        --cloud-init user-data="${CLOUD_INIT_FILE}" \
        --import \
        --noautoconsole
    info "VM '${VM_NAME}' creada y arrancando."
}

# --- Bucle principal ---
section "Despliegue de VMs"

for VM in "${VMS[@]}"; do
    echo -e "\n${BOLD}  >> Procesando: rhaap-${VM}${RESET}"
    delete_vm_if_exists "$VM"
    rm -f "$STORAGE_DIR/${VM}.qcow2"
    create_disk "$VM"
    reserve_ip "$VM"
    info "Reserva DHCP registrada - MAC: ${MACS[$VM]}  IP: ${IPS[$VM]}"
    CLOUD_INIT_FILE=$(generate_cloud_init "$VM")
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${IPS[$VM]}" &>/dev/null || true
    create_vm "$VM" "${CLOUD_INIT_FILE}"
done

# --- Resumen final ---
section "Lab desplegado correctamente"

echo -e ""
printf "${BOLD}  %-20s %-22s %-20s %-8s %-6s${RESET}\n" \
    "VM" "FQDN" "IP" "RAM(MB)" "vCPUs"
echo -e "  ${YELLOW}------------------------------------------------------------------------${RESET}"
for VM in "${VMS[@]}"; do
    printf "  ${GREEN}%-20s${RESET} %-22s ${YELLOW}%-20s${RESET} %-8s %-6s\n" \
        "rhaap-${VM}" \
        "rhaap-${VM}.lab.local" \
        "${IPS[$VM]}" \
        "${RAM[$VM]}" \
        "${VCPUS[$VM]}"
done
echo -e ""
echo -e "${GREEN}  ssh root@<IP> -i ${SSH_KEY_PATH}${RESET}"
echo ""
