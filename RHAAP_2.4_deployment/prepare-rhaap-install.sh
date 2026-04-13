#!/bin/bash
# prepare-rhaap-install.sh
# Prepara el entorno de instalación de RHAAP en el controller:
# verifica SSH, copia bundle e inventario, descomprime y deja listo para ./setup.sh

set -e

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
section() {
    echo -e "\n${BOLD}${YELLOW}===========================================${RESET}"
    echo -e "${BOLD}${YELLOW}  $*${RESET}"
    echo -e "${BOLD}${YELLOW}===========================================${RESET}"
}

# --- Variables locales ---
# Directorio donde reside este script (bundle e inventario en el mismo lugar)
LOCAL_DIR="$(dirname "$(realpath "$0")")"

# Cargar credenciales desde .env 
source "${LOCAL_DIR}/.env"

# Nombre del bundle (ajustar si cambia la versión)
BUNDLE_FILE=$(ls "${LOCAL_DIR}"/ansible-automation-platform-*.tar.gz 2>/dev/null | head -1)

# Fichero de inventario local
INVENTORY_FILE="${LOCAL_DIR}/inventory"

# IP del controller (destino de la copia)
CONTROLLER_IP="192.168.122.101"

# Usuario SSH
SSH_USER="root"

# Clave SSH
SSH_KEY="$HOME/.ssh/id_rsa"

# Directorio de destino en el controller (estándar Red Hat)
REMOTE_DIR="/root"

# Opciones SSH comunes (evita prompts de host desconocido en el lab)
SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# --- Validaciones locales ---
section "Validaciones locales"

if [ -z "${BUNDLE_FILE}" ]; then
    error "No se encontró ningún bundle ansible-automation-platform-*.tar.gz en ${LOCAL_DIR}"
    exit 1
fi
info "Bundle encontrado: $(basename ${BUNDLE_FILE})"

if [ ! -f "${INVENTORY_FILE}" ]; then
    error "No se encontró el fichero de inventario en ${INVENTORY_FILE}"
    exit 1
fi
info "Inventario encontrado: ${INVENTORY_FILE}"

# --- Verificar conectividad SSH al controller ---
section "Verificar conectividad SSH"

info "Verificando conectividad SSH con el controller (${CONTROLLER_IP})..."

# Espera a que la VM arranque y cloud-init finalice completamente
# cloud-init status --wait bloquea hasta recibir "done" o "error"
info "Esperando a que el controller arranque y cloud-init finalice..."
ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "cloud-init status --wait"
ok "cloud-init finalizado correctamente en el controller."

# --- Configurar acceso SSH entre VMs (necesario para el instalador RHAAP) ---
section "Configuracion SSH entre VMs"

info "Generando clave SSH en el controller si no existe..."
ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "[ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4096 -N '' -f /root/.ssh/id_rsa"

info "Recuperando clave publica del controller..."
CONTROLLER_PUBKEY=$(ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "cat /root/.ssh/id_rsa.pub")

info "Distribuyendo clave publica del controller a todas las VMs..."
for host in 192.168.122.101 192.168.122.102 192.168.122.103; do
    ssh ${SSH_OPTS} ${SSH_USER}@${host} "mkdir -p /root/.ssh && echo '${CONTROLLER_PUBKEY}' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
done

info "Populando known_hosts del controller con las 3 VMs..."
ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "ssh-keyscan -H 192.168.122.101 192.168.122.102 192.168.122.103 >> /root/.ssh/known_hosts 2>/dev/null"
ok "Acceso SSH entre VMs configurado correctamente."

# --- Copiar bundle al controller ---
section "Copia del bundle"

info "Copiando bundle al controller... (puede tardar varios minutos)"
scp ${SSH_OPTS} "${BUNDLE_FILE}" ${SSH_USER}@${CONTROLLER_IP}:${REMOTE_DIR}/

# Verificar que la copia se ha realizado correctamente comparando tamaños
LOCAL_SIZE=$(stat -c%s "${BUNDLE_FILE}")
REMOTE_SIZE=$(ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "stat -c%s ${REMOTE_DIR}/$(basename ${BUNDLE_FILE})")

if [ "${LOCAL_SIZE}" != "${REMOTE_SIZE}" ]; then
    error "El tamaño del bundle en el controller (${REMOTE_SIZE}) no coincide con el local (${LOCAL_SIZE}). La copia puede estar corrupta."
    exit 1
fi
ok "Bundle copiado y verificado correctamente."

# --- Copiar inventario al controller ---
section "Copia del inventario"

info "Procesando inventario con credenciales del .env..."
INVENTORY_PROCESSED="/tmp/inventory-processed"
envsubst < "${INVENTORY_FILE}" > "${INVENTORY_PROCESSED}"

info "Copiando inventario al controller..."
scp ${SSH_OPTS} "${INVENTORY_PROCESSED}" ${SSH_USER}@${CONTROLLER_IP}:${REMOTE_DIR}/inventory

# Verificar copia del inventario
if ! ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "[ -f ${REMOTE_DIR}/inventory ]"; then
    error "No se encontró el inventario en el controller tras la copia."
    exit 1
fi
ok "Inventario copiado y verificado correctamente."

# --- Descomprimir bundle en el controller ---
section "Descompresion del bundle"

info "Descomprimiendo bundle en el controller..."
BUNDLE_NAME=$(basename "${BUNDLE_FILE}")

# Descomprime y obtiene el nombre del directorio extraído
INSTALL_DIR=$(ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "
    cd ${REMOTE_DIR} && \
    tar xzf ${BUNDLE_NAME} && \
    ls -td ansible-automation-platform-*/ | head -1
")

if [ -z "${INSTALL_DIR}" ]; then
    error "No se pudo determinar el directorio de instalación tras descomprimir."
    exit 1
fi
ok "Bundle descomprimido en ${REMOTE_DIR}/${INSTALL_DIR}"

info "Eliminando bundle del controller para liberar espacio..."
ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "rm -f ${REMOTE_DIR}/${BUNDLE_NAME}"
ok "Bundle eliminado del controller."

# --- Mover inventario dentro del directorio de instalación ---
section "Colocacion del inventario"

info "Moviendo inventario al directorio de instalación..."
ssh ${SSH_OPTS} ${SSH_USER}@${CONTROLLER_IP} "
    cp ${REMOTE_DIR}/inventory ${REMOTE_DIR}/${INSTALL_DIR}/inventory
"
ok "Inventario colocado en ${REMOTE_DIR}/${INSTALL_DIR}/inventory"

# --- Resumen final ---
section "Entorno de instalacion preparado correctamente"

echo -e ""
echo -e "  Para lanzar la instalacion conectate al controller y ejecuta:"
echo -e ""
echo -e "  ${GREEN}ssh root@${CONTROLLER_IP}${RESET}"
echo -e "  ${GREEN}cd ${REMOTE_DIR}/${INSTALL_DIR}${RESET}"
echo -e "  ${GREEN}./setup.sh${RESET}"
echo -e ""
echo -e "  ${YELLOW}======================================================================${RESET}"
