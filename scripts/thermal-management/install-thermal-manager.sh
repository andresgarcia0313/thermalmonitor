#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Instalador de Thermal Manager para Lenovo IdeaPad
# Ejecutar: sudo ./install-thermal-manager.sh
# ═══════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} Este script debe ejecutarse como root"
    echo "Uso: sudo $0"
    exit 1
fi

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   THERMAL MANAGER - Lenovo IdeaPad (i5-1235U)             ║${NC}"
echo -e "${CYAN}║   Gestión térmica automática para vida útil + confort     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}[1/7]${NC} Instalando script thermal-manager.sh..."
cp "$SCRIPT_DIR/thermal-manager.sh" /usr/local/bin/
chmod +x /usr/local/bin/thermal-manager.sh
echo -e "${GREEN}✓${NC} Script instalado"

echo -e "${YELLOW}[2/7]${NC} Instalando cpu-mode..."
cp "$SCRIPT_DIR/cpu-mode" /usr/local/bin/
chmod +x /usr/local/bin/cpu-mode
echo -e "${GREEN}✓${NC} cpu-mode instalado"

echo -e "${YELLOW}[3/7]${NC} Configurando thermald..."
cp "$SCRIPT_DIR/../docs/configuraciones/thermal-conf.xml" /etc/thermald/thermal-conf.xml 2>/dev/null || \
cp "$SCRIPT_DIR/../../docs/configuraciones/thermal-conf.xml" /etc/thermald/thermal-conf.xml
systemctl restart thermald
echo -e "${GREEN}✓${NC} Thermald configurado"

echo -e "${YELLOW}[4/7]${NC} Instalando servicios systemd..."
cp "$SCRIPT_DIR/../docs/configuraciones/systemd-services/thermal-manager.service" /etc/systemd/system/ 2>/dev/null || \
cp "$SCRIPT_DIR/../../docs/configuraciones/systemd-services/thermal-manager.service" /etc/systemd/system/
cp "$SCRIPT_DIR/../docs/configuraciones/systemd-services/thermal-manager.timer" /etc/systemd/system/ 2>/dev/null || \
cp "$SCRIPT_DIR/../../docs/configuraciones/systemd-services/thermal-manager.timer" /etc/systemd/system/
systemctl daemon-reload
echo -e "${GREEN}✓${NC} Servicios instalados"

echo -e "${YELLOW}[5/7]${NC} Deshabilitando powertop auto-tune (conflicto)..."
systemctl disable powertop-autotune.service 2>/dev/null || true
systemctl stop powertop-autotune.service 2>/dev/null || true
echo -e "${GREEN}✓${NC} Powertop deshabilitado"

echo -e "${YELLOW}[6/7]${NC} Habilitando thermal-manager..."
systemctl enable thermal-manager.timer
systemctl start thermal-manager.timer
echo -e "${GREEN}✓${NC} Timer habilitado"

echo -e "${YELLOW}[7/7]${NC} Ejecutando primera vez..."
/usr/local/bin/thermal-manager.sh
echo -e "${GREEN}✓${NC} Primera ejecución completada"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                  INSTALACIÓN COMPLETADA                    ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "TABLA DE COMPORTAMIENTO:"
echo "────────────────────────────────────────────────────────────"
echo "Temperatura │ Rendimiento │ Turbo │ Modo"
echo "────────────────────────────────────────────────────────────"
echo "  < 45°C    │ 100% (4.4GHz) │  ON  │ BOOST"
echo " 45-55°C    │  90% (4.0GHz) │  ON  │ OPTIMAL (vida útil máx)"
echo " 55-65°C    │  75% (3.3GHz) │  ON  │ BALANCED"
echo " 65-75°C    │  60% (2.6GHz) │ OFF  │ WARM (protección)"
echo " 75-82°C    │  45% (2.0GHz) │ OFF  │ HOT (enfriamiento)"
echo "  > 82°C    │  30% (1.3GHz) │ OFF  │ CRITICAL"
echo "────────────────────────────────────────────────────────────"
echo ""
echo "Comandos útiles:"
echo "  Ver estado:     cpu-mode status"
echo "  Videollamadas:  sudo cpu-mode performance"
echo "  Modo auto:      sudo cpu-mode auto"
echo "  Ver log:        tail -f /var/log/thermal-manager.log"
echo ""
