# Plan de Refactor UI — Algoritmos Maestros

> **Estado:** En curso. **Inicio:** 2026-07-05. **Owner:** Javi Lonte.
>
> **Comando rápido:** ver `sección "Quick start"`.

---

## Contexto

El proyecto tiene **dos sistemas visuales en paralelo**:

| Sistema | Estado |
|---|---|
| `D2Theme` + `D2Palette` + `D2StyleBox` + `D2Theme.tres` | Maduro, aplicado globalmente vía `project.godot: theme/custom` |
| Hardcoded en `.tscn` (colores, font_sizes, StyleBoxFlat locales) | Varios archivos ignoran la paleta |

**Resultado:** la `Terminal` del overworld se ve "Godot default"; la de batalla usa un StyleBox local que pisa el theme global; el resto del juego sigue D2. Inconsistencia visual bloquea escalar la estética.

### Inventario de issues (42 identificados durante exploración)

Las 42 issues están categorizadas en:

1. **Bugs / crashes potenciales** (~5) — `@onready` nodo faltante, doble terminación en transitions, etc.
2. **Layout / overlapping** (~5) — HUD no se oculta durante Tutorial, paneles que se pisan en resoluciones bajas.
3. **Posiciones absolutas en vez de anclas** (~4) — hijos de Panel sin `anchor_right/bottom`.
4. **Colores hardcoded fuera de paleta** (~8) — réplicas de `GOLD_TEXT`, `BONE_TEXT`, etc. en archivos `.tscn`.
5. **Capas / layer ordering** (~3) — layers definidos en `_ready` en vez de `.tscn`; sin constante centralizada.
6. **Theme / stylebox** (~4) — 7 sub_resources `code_inner` casi idénticos en `d2_theme.tres`.
7. **Otros** (~10) — code smells, llamadas muertas, scripts huérfanos.

---

## Decisiones adoptadas

| # | Tema | Decisión |
|---|---|---|
| 1 | Composición vs herencia | **Composición**: `BattleTerminal` envuelve a `Terminal` (más flexible para variantes futuras). |
| 2 | Fuente D2 style | **Después**: se implementa en Fase 6. Solo refactor de colores/tamaños en Fases 0-5. |
| 3 | `code_transition` | **Dejar aparte + aplicar Fase 5 (colores)**. Crear `LoadingScreen` reutilizable con `mode="frames"|"typewriter"|"logo"`. NO mezclar con `Terminal` (propósito distinto: interactiva vs narrativa). |
| 4 | Splash duplicado (`splash.tscn` vs `splash_screen.tscn`) | **Mantener ambos, consolidar patrón**: `splash_screen.tscn` 3D voxel queda como `run/main_scene` (marca). `splash.tscn` frames PNG se generaliza como `LoadingScreen` reusable para loadings futuros. |
| 5 | Branch strategy | **Branch aparte** `feature/unified-terminal` para Fase 2 con PR review visual después de cada commit crítico. Merge con `--no-ff` para preservar historia. |
| 6 | Bug HTTPRequest null | **Follow-up** post-Fase 2. No arreglar ahora para mantener scope de Fase 2 contenido. |
| 7 | Squash vs preserve history | **Preservar historia** (`--no-ff` merge). Cada commit es testeable individualmente. |

---

## Fases

### Fase -1 — Baseline validation ✅ **COMPLETADA**

**Objetivo:** confirmar proyecto verde antes de invertir tiempo.

**Hecho:**
- Godot 4.7 detecta el proyecto sin errores.
- `class_name` duplicados: 0 (verificado con `grep | uniq -c`).
- Sin errores de parseo en inicialización: global class names, GDExtensions, autoloads, plugins todos OK.
- 2 bugs latentes confirmados (no arreglados en esta fase):
  - **Bug #1**: `scripts/ui/terminal_ui.gd:7` referencia `$Panel/HTTPRequest` que **no existe** en `scenes/TerminalUI.tscn`. Crash al usar `submit_code()`.
  - **Bug #2**: `scripts/battle/battle.gd:15` apunta a `$BattleArena/MessageLabel` pero el `.tscn` tiene `BattleArena/MessagePanel/MessageLabel`. Crash garantizado en runtime de batalla.

### Fase 0 — Foundation helpers (read-only)

**Objetivo:** extraer convenciones actuales en archivos reutilizables sin romper nada.

**Entregables:**
- `scripts/ui/ui_layers.gd` — constantes `UILayers.{SPLASH, TUTORIAL, SKILL_TREE, DIALOGUE, TERMINAL_*, PLAYER_HUD}`.
- `scripts/ui/_ui_resolve.gd` — helpers estáticos:
  - `label_color(kind) -> Color` mapea a `D2Palette`.
  - `label_size(kind) -> int` mapea a `UIMetrics`.
  - `bbcode_status(level, text) -> String` para `[OK]/[ERR]/[HINT]/[WARN]` con colores de paleta.
- `scripts/ui/_ui_style.gd` — funciones `apply_d2_*` (panel, button, code_edit, label) reutilizables desde cualquier `_ready`. Centraliza lo que hoy hacen `_apply_local_overrides` ad-hoc en cada script.
- `scripts/ui/_ui_typography.gd` — placeholder para Fase 6 (firma vacía).

**Riesgo:** mínimo. Solo se agregan archivos; no se modifica nada existente.

### Fase 1 — LoadingScreen reusable (en branch aparte)

Solo si se aprueba desvío del flujo principal. Recomendada como branch `feature/loading-screen` independiente.

**Entregables:**
- `scripts/ui/loading_screen.gd` — `class_name LoadingScreen extends CanvasLayer` con `@export`:
  ```gdscript
  @export var mode: String = "frames"  # "frames" | "typewriter" | "logo"
  @export var duration_sec: float = 1.5
  @export var skip_input: bool = true
  @export var mute_buses: PackedStringArray = ["Music"]
  ```
- `scenes/ui/loading_screen_frames.tscn` (reemplaza `splash.tscn`).
- `scenes/ui/loading_screen_typewriter.tscn` (reemplaza `code_transition.tscn`).
- Bug fix: `code_transition.gd` doble terminación (`_process` + `_on_all_lines_done`) → mantener solo tween path.

### Fase 2 — Terminal unificada (rama principal: `feature/unified-terminal`)

**Objetivo:** una sola `Terminal` reutilizable en overworld y battle, parametrizable por composición.

#### Commits del branch (6 commits atómicos, todos testeables)

**Commit 1: Base template (no rompe nada)**
- Crea `scripts/ui/terminal.gd` (`class_name Terminal extends Control`) con properties exportadas, sin funcionalidad todavía.
- Crea `scenes/ui/terminal.tscn` con estructura completa.
- Aplica `apply_d2_*` desde `_ready`.
- Verificación: el juego sigue mostrando la terminal vieja; el nuevo `terminal.tscn` existe pero no se referencia.

**Commit 2: Compositor TerminalUI (overworld) — ⏸ PR review visual**
- Refactor `scripts/ui/terminal_ui.gd` para instanciar `terminal.tscn` con `context="overworld"`.
- Borrar estructura interna hardcoded; delegar.
- Verificación: Terminal se ve con theme D2 aplicado; funcionalmente idéntica.

**Commit 3: Compositor BattleTerminal (batalla) — ⏸ PR review visual**
- Refactor `scripts/battle/battle_terminal.gd` para instanciar `terminal.tscn` con `context="battle"` + AST overlay específico.
- Reemite signals con semántica battle.
- Verificación: funcionalmente idéntica, visualmente simétrica con la terminal de overworld.

**Commit 4: StatusBar + ProgressBar + BBCode formatter**
- Añadir `set_status(text)` y `set_progress(ratio)` a `Terminal`.
- Conectar `EventBus.compiling_started/progress/finished` desde cada compositor.
- BBCode formatter desde `_ui_resolve.gd`.

**Commit 5: Eliminar scenes viejas**
- Borrar `scenes/TerminalUI.tscn` y `scenes/battle/battle_terminal.tscn`.
- Verificar con `grep` que no quedan referencias.

**Commit 6: README + PR a development con `--no-ff`**

### Fase 3 — StatusBar + eventos consolidados

(O incluida en Commit 4 de Fase 2).

### Fase 4 — Capas, eventos y visibilidad

**Objetivo:** eliminar overlapping y flicker entre HUD/Tutorial/Terminal/Dialog.

**Cambios:**
- Mover `layer=` de cada `.tscn` a constante en `UILayers` (declarar en escena).
- `PlayerHUD._update_visibility`: reemplazar polling cada 0.2s por `EventBus.state_changed` (nuevo signal en `GameManager`).
- `PlayerHUD` debe ocultarse también durante `TUTORIAL` y `SKILL_TREE` (no solo `OVERWORLD`).

### Fase 5 — Refactor de colores hardcoded

**Objetivo:** eliminar `Color()` literales y `StyleBoxFlat` locales de `.tscn`.

- `battle_terminal.tscn` (si sobrevive Fase 2): eliminar `PanelStyle` sub_resource, usar `D2StyleBox.panel_bronze()` por código.
- `tutorial_overlay.tscn`: 4 colores hardcoded → `D2Palette`.
- `skill_tree_ui.tscn`, `dialogue_ui.tscn`, `options_menu.tscn`, `splash.tscn`, `main_menu.tscn`: auditoría análoga.
- `assets/themes/d2_theme.tres`: consolidar 7 sub_resources `code_inner` casi idénticos en 1.

### Fase 6 — Polish + Fuente D2

**Objetivo:** tipografía consistente + identidad visual real.

- Decidir tipografía: `JetBrainsMono-Regular.ttf` (ya en `assets/fonts/`) o buscar D2-style real.
- `_ui_typography.gd`: aplicar default font al theme root.
- Auditar todos los `font_size` literales → `UIMetrics.*`.
- `macro_bar_ui.gd`: confirmar dónde se monta; si huérfano, integrar al HUD o borrar.

### Fase 7 — Validación final

- `grep -rE 'Color\(|font_size = [0-9]' scenes/` → solo hits dentro de `_ui_*.gd` o `D2Palette`/`D2StyleBox`.
- Pruebas en 1280×720, 1920×1080, 2560×1440 sin overlapping.
- Flujo completo: menu → splash → overworld → terminal → batalla → terminal battle → diálogo → tutorial → skill tree.
- `PlayerHUD` oculto en TODOS los modos no-overworld.

---

## Orden de ejecución y dependencias

```
Fase -1 ✅
    ↓
Fase 0 (helpers, read-only)
    ↓
Fase 2 (branch `feature/unified-terminal`) ──┐
    ↓                                       │
Fase 4 (Layers + events) ── paralelo ───────┤
                                          ↓
                                       Fase 5 (colores) ──┐
                                                          ↓
                                                      Fase 6 (tipografía)
                                                          ↓
                                                      Fase 7 (validación)
```

`Fase 1` (LoadingScreen) se hace en branch aparte si se aprueba.

---

## Riesgos identificados

| Riesgo | Mitigación |
|---|---|
| Baseline con bugs rojos no detectados | **Mitigado**: Fase -1 verde. Pero hay 2 bugs latentes (HTTPRequest null, MessageLabel path) que solo se ven en runtime. |
| `BattleTerminal` class_name colisión durante refactor | **Mitigado**: confirmado 0 duplicados en baseline. |
| Cambio de `D2StyleBox` constants rompe todo | **Bajo**: no se modifica `D2StyleBox.gd`. Solo se referencian los styleboxes existentes. |
| Godot class_name cache desactualizado entre commits | Recargar el editor (`close + open project`) entre tests. |
| `apply_d2_*` aplicación duplicada | Una vez en `_ready` de cada control. Auditar ausencia de `_apply_local_overrides` redundante en refactor. |
| Scenes `.tscn` con referencias rotas al borrar (Commit 5) | `grep` antes del commit. |
| `_ready` race: `@onready` de padres lee antes que hijos | Documentado como caveat en el código. Tests visuales en cada commit. |

---

## Criterios de éxito agregados

Para cerrar el refactor completo:

- [ ] Solo existe una `Terminal` source of truth (`scripts/ui/terminal.gd` + `scenes/ui/terminal.tscn`).
- [ ] `PlayerHUD` oculto en TUTORIAL/SKILL_TREE/TERMINAL/DIALOGUE/PAUSE.
- [ ] `grep Color\( scenes/` solo en `_ui_*.gd`, `D2Palette.gd`, `D2StyleBox.gd`.
- [ ] `grep font_size = ` escenas solo constantes o refs a `UIMetrics`.
- [ ] Sin `sub_resource StyleBoxFlat` ad-hoc en `.tscn` (solo `.tres` centralizado).
- [ ] Sin `set_layer()` en `_ready` (declarado en `.tscn`).
- [ ] Resoluciones probadas: 1280×720, 1920×1080, 2560×1440.
- [ ] 2 bugs latentes (HTTPRequest null + MessageLabel path) resueltos antes del merge final.

---

## Historial de cambios de este doc

| Fecha | Cambio |
|---|---|
| 2026-07-05 | Creación inicial del plan con 7 fases (-1, 0, 1, 2, 3, 4, 5, 6, 7), decisiones sobre composición/fuente/loading/splash. |
