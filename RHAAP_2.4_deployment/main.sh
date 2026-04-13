#!/bin/bash
# main.sh
# Punto de entrada del lab RHAAP 2.4.
# Ejecuta en orden el despliegue de VMs y la preparación del entorno de instalación.

set -e

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
section() {
    echo -e "\n${BOLD}${YELLOW}===========================================${RESET}"
    echo -e "${BOLD}${YELLOW}  $*${RESET}"
    echo -e "${BOLD}${YELLOW}===========================================${RESET}"
}

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

section "RHAAP 2.4 Lab - Despliegue completo"

section "FASE 1 - Desplegando VMs"
bash "${SCRIPT_DIR}/deploy-rhaap-lab.sh"

# Esperar a que las 3 VMs estén accesibles por SSH antes de continuar
HOSTS=("192.168.122.101" "192.168.122.102" "192.168.122.103")
echo "[INFO] Esperando conectividad SSH en las 3 VMs..."
for host in "${HOSTS[@]}"; do
    echo -n "[INFO]  Esperando $host ..."
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
              -o BatchMode=yes "root@${host}" true 2>/dev/null; do
        echo -n "."
        sleep 10
    done
    echo " OK"
done

section "FASE 2 - Preparando entorno de instalacion"
bash "${SCRIPT_DIR}/prepare-rhaap-install.sh"

section "Lab listo"

echo -e ""
echo -e "  Conectate al controller y lanza el installer:"
echo -e ""
echo -e "  ${GREEN}ssh root@192.168.122.101${RESET}"
echo -e "  ${GREEN}cd /root/ansible-automation-platform-*${RESET}"
echo -e "  ${GREEN}./setup.sh${RESET}"
echo -e ""