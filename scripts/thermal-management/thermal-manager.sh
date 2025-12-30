#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Thermal Manager para Lenovo IdeaPad (Intel i5-1235U)
# Versión 2.0 - Optimizado para CONFORT DE TECLADO + Rendimiento
# Objetivo: Teclado a temperatura de dedos (~35°C) con máximo rendimiento
# ═══════════════════════════════════════════════════════════════════════════

PSTATE_STATUS=$(cat /sys/devices/system/cpu/intel_pstate/status 2>/dev/null)

# Obtener temperatura máxima del CPU
get_cpu_temp() {
    local max_temp=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        local ztype=$(cat $(dirname $zone)/type 2>/dev/null)
        if [[ "$ztype" == "x86_pkg_temp" ]] || [[ "$ztype" == "TCPU" ]]; then
            local t=$(cat $zone 2>/dev/null)
            t=$((t / 1000))
            [ $t -gt $max_temp ] && max_temp=$t
        fi
    done
    if [ $max_temp -eq 0 ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            local t=$(cat $zone 2>/dev/null)
            t=$((t / 1000))
            [ $t -gt $max_temp ] && max_temp=$t
        done
    fi
    echo $max_temp
}

CPU_TEMP=$(get_cpu_temp)
[ -z "$CPU_TEMP" ] || [ "$CPU_TEMP" -eq 0 ] && CPU_TEMP=50

# ═══════════════════════════════════════════════════════════════════════════
# NIVELES OPTIMIZADOS PARA CONFORT DE TECLADO
# Meta: Teclado ~35°C (apenas tibio) = CPU máx ~45°C
# Fórmula: T_teclado = 28 + (T_CPU - 28) × 0.45
# ═══════════════════════════════════════════════════════════════════════════

if [ $CPU_TEMP -lt 40 ]; then
    # MUY FRÍO (<40°C) → Teclado ~33°C, boost permitido
    MAX_PERF=85
    MIN_PERF=15
    EPP="balance_performance"
    PLATFORM="balanced"
    TURBO=0
    MODE="COOL"
    COLOR="36"  # Cyan
    KEYBOARD_EST=33

elif [ $CPU_TEMP -lt 45 ]; then
    # FRÍO (40-45°C) → Teclado ~35°C, rendimiento alto
    MAX_PERF=70
    MIN_PERF=15
    EPP="balance_performance"
    PLATFORM="balanced"
    TURBO=0
    MODE="COMFORT"
    COLOR="32"  # Verde
    KEYBOARD_EST=35

elif [ $CPU_TEMP -lt 50 ]; then
    # ÓPTIMO (45-50°C) → Teclado ~37°C, rendimiento bueno
    MAX_PERF=60
    MIN_PERF=10
    EPP="balance_power"
    PLATFORM="balanced"
    TURBO=0
    MODE="OPTIMAL"
    COLOR="32"  # Verde
    KEYBOARD_EST=37

elif [ $CPU_TEMP -lt 55 ]; then
    # TEMPLADO (50-55°C) → Teclado ~39°C, empezar a reducir
    MAX_PERF=50
    MIN_PERF=10
    EPP="balance_power"
    PLATFORM="balanced"
    TURBO=1
    MODE="WARM"
    COLOR="33"  # Amarillo
    KEYBOARD_EST=39

elif [ $CPU_TEMP -lt 60 ]; then
    # CALIENTE (55-60°C) → Teclado ~41°C, reducción activa
    MAX_PERF=40
    MIN_PERF=10
    EPP="power"
    PLATFORM="balanced"
    TURBO=1
    MODE="HOT"
    COLOR="33"  # Amarillo
    KEYBOARD_EST=41

elif [ $CPU_TEMP -lt 70 ]; then
    # MUY CALIENTE (60-70°C) → Teclado ~44°C, enfriamiento agresivo
    MAX_PERF=35
    MIN_PERF=10
    EPP="power"
    PLATFORM="low-power"
    TURBO=1
    MODE="COOLING"
    COLOR="31"  # Rojo
    KEYBOARD_EST=44

else
    # CRÍTICO (>70°C) → Protección máxima
    MAX_PERF=25
    MIN_PERF=10
    EPP="power"
    PLATFORM="low-power"
    TURBO=1
    MODE="CRITICAL"
    COLOR="31"  # Rojo
    KEYBOARD_EST=48
fi

# ═══════════════════════════════════════════════════════════════════════════
# APLICAR CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════

echo "$PLATFORM" > /sys/firmware/acpi/platform_profile 2>/dev/null

if [ "$PSTATE_STATUS" = "active" ]; then
    echo $MAX_PERF > /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null
    echo $MIN_PERF > /sys/devices/system/cpu/intel_pstate/min_perf_pct 2>/dev/null
else
    local max_freq=$((4400000 * MAX_PERF / 100))
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        echo $max_freq > $cpu 2>/dev/null
    done
fi

for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    echo $EPP > $epp 2>/dev/null
done

echo $TURBO > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════

LOG_FILE="/var/log/thermal-manager.log"
TIMESTAMP=$(date '+%H:%M:%S')
MAX_FREQ_MHZ=$((4400 * MAX_PERF / 100))
FREQ_CURRENT=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.1f", $1/1000000}')

# Log a consola
printf "\e[${COLOR}m%s\e[0m | CPU:%2d°C → Teclado:~%d°C | %dMHz (%d%%) | %s\n" \
    "$TIMESTAMP" "$CPU_TEMP" "$KEYBOARD_EST" "$MAX_FREQ_MHZ" "$MAX_PERF" "$MODE"

# Log a archivo
echo "$TIMESTAMP | CPU:${CPU_TEMP}°C | Teclado:~${KEYBOARD_EST}°C | Max:${MAX_FREQ_MHZ}MHz (${MAX_PERF}%) | $MODE" >> $LOG_FILE

# Mantener log pequeño
if [ $(wc -l < $LOG_FILE 2>/dev/null || echo 0) -gt 2000 ]; then
    tail -1000 $LOG_FILE > ${LOG_FILE}.tmp && mv ${LOG_FILE}.tmp $LOG_FILE
fi

echo "comfort-$MODE" > /tmp/cpu-mode.current 2>/dev/null
