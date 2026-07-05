## Constantes de CanvasLayer layer para cada subsistema UI.
## Usar como único punto de referencia para evitar solapamientos visuales.
##
## Convención de numbering:
##   0-9      : HUD base del juego (siempre visible durante gameplay)
##   10-19    : Overlays de gameplay (terminal, combate)
##   20-29    : Modales de interacción directa (diálogos)
##   50-99    : Pantallas completas (skill tree, options)
##   150-199  : Tutoriales / hints
##   200+     : Splash screens (top-most)

const SPLASH := 200
const TUTORIAL := 150
const SKILL_TREE := 50
const OPTIONS := 50
const DIALOGUE := 30
const TERMINAL_OVERWORLD := 20
const TERMINAL_BATTLE := 21
const PLAYER_HUD := 10
