# Gestión Térmica Automática - Lenovo IdeaPad

**Fecha de implementación:** 2025-12-30
**Equipo:** Lenovo IdeaPad con Intel i5-1235U
**Objetivo:** Maximizar vida útil del equipo manteniendo rendimiento y confort

## Problema a Resolver

El Lenovo IdeaPad con i5-1235U tiende a calentarse significativamente, causando:
- Teclado incómodo para uso prolongado (> 45°C en superficie)
- Degradación acelerada de componentes (> 80°C constante)
- Throttling térmico que reduce rendimiento
- Ruido excesivo del ventilador

## Solución Implementada

Sistema de gestión térmica automática que:
1. Monitorea temperatura cada 30 segundos
2. Ajusta rendimiento dinámicamente según temperatura
3. Prioriza rango óptimo de 50-65°C para máxima vida útil
4. Permite override manual para videollamadas/gaming

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     thermal-manager.timer                    │
│                    (ejecuta cada 30s)                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    thermal-manager.sh                        │
│  - Lee temperatura de x86_pkg_temp y TCPU                   │
│  - Determina nivel de throttling                            │
│  - Ajusta intel_pstate max_perf_pct                         │
│  - Ajusta platform_profile                                  │
│  - Log a /var/log/thermal-manager.log                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         thermald                             │
│  - Capa adicional de protección del kernel                  │
│  - Trip points configurados en thermal-conf.xml             │
│  - Actúa si thermal-manager no puede controlar              │
└─────────────────────────────────────────────────────────────┘
```

## Niveles de Gestión Térmica

| Temperatura | Rendimiento | Turbo | Modo | Descripción |
|-------------|-------------|-------|------|-------------|
| < 45°C | 100% (4.4 GHz) | ON | BOOST | Máximo rendimiento |
| 45-55°C | 90% (4.0 GHz) | ON | OPTIMAL | **Zona ideal para vida útil** |
| 55-65°C | 75% (3.3 GHz) | ON | BALANCED | Balance rendimiento/temperatura |
| 65-75°C | 60% (2.6 GHz) | OFF | WARM | Protección preventiva |
| 75-82°C | 45% (2.0 GHz) | OFF | HOT | Enfriamiento activo |
| > 82°C | 30% (1.3 GHz) | OFF | CRITICAL | Protección máxima |

## Archivos Instalados

| Archivo | Ubicación | Descripción |
|---------|-----------|-------------|
| thermal-manager.sh | /usr/local/bin/ | Script principal de gestión |
| cpu-mode | /usr/local/bin/ | Comando para cambio manual de modos |
| thermal-manager.service | /etc/systemd/system/ | Servicio systemd |
| thermal-manager.timer | /etc/systemd/system/ | Timer (cada 30s) |
| thermal-conf.xml | /etc/thermald/ | Configuración de thermald |

## Uso Diario

### Ver estado actual
```bash
cpu-mode status
```

### Antes de videollamadas (desactiva gestión automática)
```bash
sudo cpu-mode performance
```

### Volver a modo automático (después de videollamada)
```bash
sudo cpu-mode auto
```

### Modo silencioso (mínimo ruido)
```bash
sudo cpu-mode quiet
```

### Ver log en tiempo real
```bash
tail -f /var/log/thermal-manager.log
```

## Comparación con Configuración Anterior

### Antes (solo power-profiles-daemon)
- Sin gestión granular de temperatura
- Saltos bruscos entre perfiles
- Sin protección proactiva
- Teclado frecuentemente caliente

### Después (thermal-manager + thermald)
- 6 niveles de gestión gradual
- Ajuste cada 30 segundos
- Protección desde 55°C
- Teclado confortable (< 40°C superficie)

## Por qué NO usar TLP

1. **Conflicto con intel_pstate active**: TLP asume intel_pstate passive
2. **Redundancia**: power-profiles-daemon ya maneja perfiles básicos
3. **Complejidad**: Agrega otra capa de configuración
4. **Control fino**: thermal-manager usa directamente intel_pstate/max_perf_pct

## Diferencias con Lenovo G400

| Aspecto | Lenovo G400 | Lenovo IdeaPad |
|---------|-------------|----------------|
| CPU | i3-3110M (2.4 GHz) | i5-1235U (4.4 GHz) |
| intel_pstate | passive | **active** |
| Control | scaling_max_freq | **max_perf_pct** |
| Referencia temp | Disco (HDD) | CPU (x86_pkg_temp) |
| Rango óptimo | 40-50°C | 50-65°C |

## Servicios Relacionados

```bash
# Estado del timer
systemctl status thermal-manager.timer

# Logs del servicio
journalctl -u thermal-manager.service -f

# Thermald
systemctl status thermald
```

## Troubleshooting

### La frecuencia no sube aunque está frío
```bash
# Verificar max_perf_pct
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

# Verificar platform_profile
cat /sys/firmware/acpi/platform_profile

# Forzar recálculo
sudo /usr/local/bin/thermal-manager.sh
```

### El timer no está corriendo
```bash
systemctl start thermal-manager.timer
systemctl enable thermal-manager.timer
```

### Volver a configuración original
```bash
sudo systemctl stop thermal-manager.timer
sudo systemctl disable thermal-manager.timer
sudo rm /etc/thermald/thermal-conf.xml
sudo systemctl restart thermald
```

## Referencias

- [Readme de temperaturas](../Readme.md)
- [Intel P-State documentation](https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_pstate.html)
- [Thermald configuration](https://github.com/intel/thermal_daemon)
