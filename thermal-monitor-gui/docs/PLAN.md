# Plan de Trabajo - Thermal Monitor GUI

## 1. Visión del Proyecto

Aplicación GUI minimalista en Rust para monitorear y controlar la gestión térmica del Lenovo IdeaPad, con bajo consumo de recursos y código mínimo.

---

## 2. Análisis de Tecnología

### Selección de Framework GUI

| Framework | RAM | Código | Look Moderno | Linux Nativo |
|-----------|-----|--------|--------------|--------------|
| **egui/eframe** | ~15MB | Mínimo | ✓ | ✓ |
| iced | ~25MB | Medio | ✓ | ✓ |
| gtk4-rs | ~40MB | Alto | ✓ | ✓✓ |
| slint | ~20MB | Medio | ✓✓ | ✓ |

**Decisión: egui/eframe**
- Immediate mode GUI = código mínimo
- ~15MB RAM
- Estilo moderno personalizable
- Excelente para dashboards/monitores
- Bien soportado en Linux

### Dependencias Mínimas

```toml
[dependencies]
eframe = "0.29"          # GUI framework
sysinfo = "0.32"         # Info del sistema (opcional, usaremos sysfs directo)

[dev-dependencies]
```

**Nota**: Leeremos directamente de `/sys/` para minimizar dependencias.

---

## 3. Requerimientos

### Funcionales

| ID | Requerimiento | Prioridad |
|----|---------------|-----------|
| RF01 | Mostrar temperatura CPU en tiempo real | Alta |
| RF02 | Calcular y mostrar temperatura estimada del teclado | Alta |
| RF03 | Mostrar porcentaje de rendimiento actual | Alta |
| RF04 | Mostrar modo actual (COMFORT, OPTIMAL, etc.) | Alta |
| RF05 | Permitir cambiar modo manualmente | Alta |
| RF06 | Mostrar historial de temperatura (gráfico simple) | Media |
| RF07 | Indicador visual de zona térmica (colores) | Media |
| RF08 | Auto-refresh cada 2 segundos | Alta |

### No Funcionales

| ID | Requerimiento | Métrica |
|----|---------------|---------|
| RNF01 | Bajo consumo de RAM | < 20 MB |
| RNF02 | Código mínimo | < 800 líneas |
| RNF03 | Tiempo de inicio | < 1 segundo |
| RNF04 | Compatible con Kubuntu 24 LTS | Wayland/X11 |
| RNF05 | Sin dependencias externas runtime | Solo sysfs |

---

## 4. Historias de Usuario

### HU01 - Ver Estado Térmico
**Como** usuario del laptop
**Quiero** ver la temperatura actual del CPU y teclado estimado
**Para** saber si el equipo está en zona de confort

**Criterios de aceptación:**
- Muestra temperatura CPU en °C
- Muestra temperatura teclado calculada
- Actualización cada 2 segundos
- Color indica zona (verde/amarillo/rojo)

### HU02 - Ver Rendimiento
**Como** usuario
**Quiero** ver el porcentaje de rendimiento actual
**Para** saber cuánta potencia está usando el CPU

**Criterios de aceptación:**
- Muestra % de rendimiento (max_perf_pct)
- Muestra frecuencia actual en GHz
- Muestra modo actual (COMFORT, OPTIMAL, etc.)

### HU03 - Cambiar Modo
**Como** usuario
**Quiero** cambiar el modo de rendimiento manualmente
**Para** aumentar potencia cuando lo necesite (videollamadas)

**Criterios de aceptación:**
- Botones para cada modo (Performance, Comfort, Balanced, Quiet, Auto)
- Confirmación visual del cambio
- Requiere permisos sudo (pkexec)

### HU04 - Historial Visual
**Como** usuario
**Quiero** ver un gráfico simple del historial de temperatura
**Para** entender la tendencia térmica

**Criterios de aceptación:**
- Gráfico de línea últimos 60 puntos (2 min)
- Muestra CPU y teclado estimado

---

## 5. Casos de Uso

### CU01 - Monitorear Temperatura
```
Actor: Usuario
Precondición: Aplicación iniciada
Flujo:
1. Sistema lee temperatura de /sys/class/thermal/
2. Sistema calcula T_teclado = T_amb + (T_cpu - T_amb) × 0.45
3. Sistema muestra valores en UI
4. Sistema repite cada 2 segundos
Postcondición: Usuario ve temperaturas actualizadas
```

### CU02 - Cambiar Modo de Rendimiento
```
Actor: Usuario
Precondición: Aplicación iniciada
Flujo:
1. Usuario hace clic en botón de modo (ej: "Performance")
2. Sistema ejecuta: pkexec /usr/local/bin/cpu-mode performance
3. Sistema muestra confirmación
4. Sistema actualiza vista con nuevo estado
Postcondición: Modo cambiado exitosamente
Flujo alternativo:
3a. Si falla pkexec, mostrar error
```

### CU03 - Ver Historial
```
Actor: Usuario
Precondición: Aplicación corriendo > 4 segundos
Flujo:
1. Sistema almacena últimos 60 valores de temperatura
2. Sistema renderiza gráfico de línea
3. Usuario ve tendencia
Postcondición: Gráfico visible con historial
```

---

## 6. Arquitectura

### Patrón: Model-View-Update (MVU) / Immediate Mode

```
┌─────────────────────────────────────────────────────────────┐
│                      thermal-monitor                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Model     │  │   View      │  │   System Reader     │  │
│  │             │  │   (egui)    │  │                     │  │
│  │ - cpu_temp  │◄─┤ - render()  │  │ - read_cpu_temp()   │  │
│  │ - kbd_temp  │  │ - buttons   │  │ - read_perf_pct()   │  │
│  │ - perf_pct  │  │ - graph     │  │ - read_mode()       │  │
│  │ - mode      │  │             │  │ - set_mode()        │  │
│  │ - history[] │  └─────────────┘  └─────────────────────┘  │
│  └─────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
```

### Módulos

```
src/
├── main.rs          # Entry point, setup eframe
├── app.rs           # ThermalApp struct, impl eframe::App
├── system.rs        # Lectura de sysfs, cálculos físicos
└── widgets.rs       # Componentes UI reutilizables (opcional)
```

---

## 7. Diagrama de Clases (ver DIAGRAMS.puml)

---

## 8. Plan de Implementación

### Fase 1: Core (2 horas)
- [ ] Setup proyecto Cargo
- [ ] Implementar lectura de sysfs (system.rs)
- [ ] Tests unitarios para system.rs
- [ ] Modelo de datos básico

### Fase 2: UI Básica (2 horas)
- [ ] Ventana principal con egui
- [ ] Display de temperaturas
- [ ] Display de rendimiento
- [ ] Indicadores de color

### Fase 3: Interactividad (1 hora)
- [ ] Botones de cambio de modo
- [ ] Integración con pkexec
- [ ] Feedback visual

### Fase 4: Historial (1 hora)
- [ ] Buffer circular para historial
- [ ] Gráfico de línea simple
- [ ] Leyenda

### Fase 5: Polish (30 min)
- [ ] Estilos visuales
- [ ] Icono de aplicación
- [ ] .desktop file para Kubuntu

---

## 9. Estructura de Archivos Final

```
thermal-monitor-gui/
├── Cargo.toml
├── Cargo.lock
├── src/
│   ├── main.rs
│   ├── app.rs
│   └── system.rs
├── tests/
│   └── system_tests.rs
├── docs/
│   ├── PLAN.md
│   └── DIAGRAMS.puml
├── assets/
│   └── icon.png
└── thermal-monitor.desktop
```

---

## 10. Métricas de Éxito

| Métrica | Objetivo | Medición |
|---------|----------|----------|
| Líneas de código | < 800 | `tokei src/` |
| RAM en uso | < 20 MB | `ps aux \| grep thermal` |
| Tiempo inicio | < 1s | Medición manual |
| Cobertura tests | > 80% system.rs | `cargo tarpaulin` |
