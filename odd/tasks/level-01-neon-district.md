# Nivel 01 — Distrito Neón: El Umbral

Crear un nivel completo de platformer con diseño de nivel real: enemigos, saltos, checkpoints y paleta neón, declarado como dato externo por nivel y entrando desde una pantalla de selección de niveles. Branch: `feature/level-01-neon-district`. Delivery: `feature-branch-chain` (work-unit commits sobre la rama, un merge al final; el forecast supera las ~400 líneas). Test runner: `godot --headless scenes/qa/<guard>.tscn --quit-after 400` + `./scripts/_qa/run_all_guards.sh`.

## Specs

### S1

> "planea ahora la creacion de un nivel, es decir un nivel completo de enemigos, saltos, a nivel mas "level design" hazme preguntas para rellenar preferencias"

Un nivel jugable completo, diseñado (no un pasillo con obstacles), con enemigos y saltos. Las decisiones de diseño salen de las respuestas del usuario, no del criterio del implementador.

### S2

> "Dato externo por nivel"

El nivel NO vive en el `.gd` del mundo. Cada nivel es un archivo de datos propio bajo `data/levels/`, y `platformer_world.gd` queda genérico: carga un nivel por id y lo pinta. Agregar un nivel es agregar un archivo, no tocar código.

### S3

> "Medio: 6-8 min"

Nivel de 6-8 minutos de recorrido, ~250-300 tiles de ancho, 8-12 enemigos, 5-6 tramos con ritmo propio.

### S4

> "Patrulla simple"

Los enemigos se mueven: patrullan de un punto a otro y dan la vuelta en el borde. El contacto sigue abriendo la batalla por turnos.

### S5

> "Escalada por algoritmo"

Cada tramo mete el enemigo cuyo challenge es el algoritmo que el jugador viene unlocking. El nivel cierra con un jefe.

### S6

> "Plano de muerte + checkpoints"

Caer al vacío mata. El jugador reaparece en el último checkpoint activado.

### S7

> "Repintar a neón ahora"

El terreno del platformer se repinta a la paleta neón (`CyberStyleBox`) en el mismo trabajo: la UI ya es neón y el terreno marrón con musgo era la última inconsistencia visual del proyecto.

### S8

> "Pantalla de selección de niveles"

El menú deja de abrir un único mundo: hay una pantalla que lista los niveles y el jugador elige.

### S9 — assumptions (not user-stated, flagged as such)

- ASSUMPTION: el combate por turnos y el terminal se reusan sin cambios. Son lo más caro del repo y son agnósticos al género.
- ASSUMPTION: el nivel se declara en un `.gd` de datos (`data/levels/level_01.gd`) y no en un `.tres`. Motivo técnico: el nivel son diccionarios anidados (`x0`/`x1`/`top`), y Godot 4 no edita `Dictionary` en el inspector — un `.tres` obligaría a tipar cada campo en clases Resource para ganar la edición visual, y el costo no paga el beneficio.
- ASSUMPTION: el enemigo declara su id del `EnemyCatalog` y el mundo resuelve nombre, HP y challenge desde el catálogo. Hoy el nivel duplica los nombres a mano y dos no coinciden con el catálogo (`Null Pointer` no existe; `Fantasma Off-by-One` apunta a `linear_search` cuando el catálogo dice `binary_search`).
- ASSUMPTION: el fondo del nivel es un parallax procedural de 2 capas. Sin él, un terreno neón sobre un vacío negro se ve peor que el terreno marrón.

## Level design — the envelope

Los números salen de `platformer_player.gd` (GRAVITY 1800, JUMP_VELOCITY -620, RUN_SPEED 220, JUMP_CUT 0.45), no de la intuición. TILE = 32 px.

| Métrica | Cálculo | Valor | Redondeado |
|---|---|---|---|
| Altura máxima de salto | `v²/(2g)` = 620²/3600 | 106.8 px | **3.34 tiles** |
| Altura de salto mínimo (soltar) | `v²·0.45²/(2g)` | 21.6 px | 0.68 tiles |
| Tiempo en el aire (botón apretado) | `2v/g` | 0.69 s | — |
| Alcance horizontal máximo | `220 · 0.69` | 151 px | **4.7 tiles** |

Invariantes que el nivel respeta y que el guard verifica:

- **Hueco ≤ 3 tiles** = cómodo. **4 tiles** = estirón (exige salto completo a velocidad máxima). **5 tiles = imposible** a la misma altura.
- Un hueco de 4 tiles sólo puede aterrizar a la misma altura o más abajo. Un hueco de 4 tiles subiendo 2 niveles es matemáticamente imposible.
- **Subida ≤ 3 tiles** (96 px ≤ 106.8 px). Subir 4 tiles es imposible.
- Sin *step-up*: cualquier desnivel de 1 tile es un salto.

## Level design — layout

Coordenadas en tiles. `x` = columna, `y` = fila de superficie (menor = más alto). 20 filas de alto, plano de muerte bajo la fila 19.

| Acto | x | Nombre | Enseña | Enemigos (challenge) | Beat de salto |
|---|---|---|---|---|---|
| 1 | 0-38 | El Umbral | moverse, saltar, abrir el terminal | Slime Aritmético (`simple_dp`) | huecos de 2-3, una subida de 3 |
| 2 | 38-96 | Escalera Rota | encadenar saltos verticales | Buggo Ciego (`linear_search`) ×2 | subidas de 2-3, plataformas escalonadas |
| 3 | 96-155 | Conducto | alcance y precisión | Fantasma Off-by-One (`binary_search`) ×2 | huecos de 4 (estirón), ruta alta opcional |
| 4 | 155-215 | Azotea | ritmo bajo presión | Ogro del Bucle (`factorial`) ×2, Dragón del Caos (`bubble_sort`) | altura + huecos de 3 mezclados |
| 5 | 215-268 | Núcleo | el jefe | Golem Genérico (`bubble_sort`) ×1, Memory Leak (`hash_map`) JEFE | arena con pilares |

10 encuentros, 5 checkpoints (uno por acto, el primero en el spawn).

### Suelo (`GROUND_SPANS`)

```
{x0:0,   x1:14,  top:15}   spawn, llano
{x0:17,  x1:28,  top:15}   hueco 2
{x0:31,  x1:50,  top:14}   hueco 2, subida 1
{x0:53,  x1:64,  top:12}   hueco 2, subida 2
{x0:67,  x1:78,  top:15}   hueco 2, caída 3
{x0:81,  x1:110, top:13}   hueco 2, subida 2
{x0:115, x1:126, top:13}   HUECO 4 — estirón
{x0:131, x1:142, top:14}   HUECO 4, un nivel más abajo
{x0:145, x1:155, top:14}   hueco 2
{x0:158, x1:166, top:12}   hueco 2, subida 2
{x0:170, x1:178, top:12}   hueco 3
{x0:182, x1:190, top:10}   hueco 3, subida 2
{x0:194, x1:203, top:10}   hueco 3
{x0:206, x1:215, top:12}   hueco 2, caída 2
{x0:218, x1:245, top:12}   arena del jefe, llana
{x0:248, x1:268, top:12}   salida
```

### Plataformas (`FLOATING`)

```
{x0:20, x1:23, y:12}   {x0:25, x1:27, y:13}
{x0:55, x1:58, y:9}    {x0:60, x1:63, y:9}
{x0:69, x1:72, y:12}   {x0:74, x1:77, y:12}
{x0:85, x1:88, y:10}   {x0:91, x1:94, y:10}
{x0:135, x1:137, y:12}
{x0:160, x1:163, y:9}  {x0:174, x1:177, y:9}
{x0:186, x1:189, y:7}  {x0:197, x1:201, y:7}
{x0:225, x1:228, y:9}  {x0:236, x1:239, y:9}
```

Ninguna plataforma está a más de 3 tiles del suelo que tiene debajo: todas se alcanzan con el salto máximo.

### Enemigos (`ENEMY_SPOTS`) y checkpoints

```
{id:"slime_aritm",      y:15, patrol:20-28}
{id:"buggo_ciego",      y:12, patrol:56-64}
{id:"buggo_ciego",      y:13, patrol:82-93}
{id:"fantasma_offbyone", y:13, patrol:100-109}
{id:"fantasma_offbyone", y:14, patrol:133-141}
{id:"ogro_bucle",        y:12, patrol:158-166}
{id:"dragon_caos",       y:10, patrol:182-190}
{id:"ogro_bucle",        y:10, patrol:194-203}
{id:"golem_generico",    y:12, patrol:222-228}
{id:"memory_leak",       y:12, patrol:230-245}   JEFE

CHECKPOINTS: x=4 (spawn), 42, 100, 160, 219
PLAYER_START: (4, 14)
```

El `y` de un enemigo es la fila de la superficie donde apoya los pies. El `y` del spawn es la fila que ocupa el jugador: sus pies quedan en la superficie de la fila siguiente (`14` → superficie `15`).

## Tasks

- T1 — Nivel como dato externo. S2. Route: inline. Commit W1. `data/levels/level_01.gd` con los const arrays; `scripts/gameplay/level_registry.gd` indexa los niveles; `platformer_world.gd` deja de tener el nivel hardcodeado y lo carga por id vía el registro. El mundo conserva `GROUND_SPANS`/`FLOATING`/`ENEMY_SPOTS` como API pública para no romper el guard actual.
- T2 — Geometría del Nivel 01. S3, S5. Route: inline. Commit W1. Los spans, plataformas, enemigos y checkpoints de las tablas de arriba. Cada enemigo declara su id de `EnemyCatalog`; el mundo resuelve nombre/HP/challenge del catálogo.
- T3 — Patrulla de enemigos. S4. Route: inline. Commit W2. El enemigo camina entre dos x y da la vuelta en el borde. El `Area2D` de batalla sigue igual; el enemigo no se teletransporta, camina.
- T4 — Plano de muerte y checkpoints. S6. Route: inline. Commit W2. Caer bajo la fila 19 mata y reaparece en el último checkpoint, con fade. El checkpoint se marca visualmente (pilar neón) y se activa al pisarlo.
- T5 — Terreno neón. S7. Route: inline. Commit W3. `side_tileset_builder.gd` pasa de tierra/musgo a la paleta `CyberStyleBox`: cuerpo azul-acero, borde de superficie cyan, ladrillo magenta de advertencia, cristal cyan. La geometría de colisión no cambia (32x32, polígono completo) — sólo los colores.
- T6 — Fondo parallax. S9. Route: inline. Commit W3. Dos capas de skyline procedural (sin assets) con parallax lento. Sin esto el terreno neón flota en un vacío negro.
- T7 — Selección de niveles. S8. Route: inline. Commit W4. `scenes/ui/level_select.tscn` + `scripts/ui/level_select.gd` listando los niveles con nombre, nº de enemigos y estado bloqueado/desbloqueado; el menú abre esa pantalla; `GameManager` transporta el id del nivel elegido al mundo.
- T8 — Guard del nivel. S3. Route: inline. Commit W1 (geometría) + W2 (comportamiento). `scripts/_qa/level_01_guard.gd` + `scenes/qa/level_01_guard.tscn`: asserts sobre la geometría (ningún hueco > 4 tiles, ninguna subida > 3, todo enemigo sobre suelo, todo challenge existe en el registro, todo checkpoint alcanzable, spawn sobre suelo) y sobre el comportamiento (patrulla patrulla, checkpoint resucita, caída mata). La geometría del nivel pasa a ser código verificable.

## Open

- T9 — El enemigo defeated tiene `respawn_time` (25-120 s según el catálogo). Si el jugador muere y vuelve a un checkpoint, los enemigos ya derrotados pueden reaparecer. No está resuelto: puede ser desirable (el nivel se re-popula) o no (el jugador pierde su progreso).
- T10 — El tiempo total lo domina el combate, no el platforming. 10 batallas de terminal × 1-3 min de código = 15-30 min para un jugador nuevo, contra los 6-8 min de S3. S3 se interpretó como tiempo de recorrido; el tiempo de sesión real será mayor y hay que decidir si se recorta el roster o se acepta.
- T11 — El arte del personaje sigue siendo 3/4 isométrico dentro de un side-scroller (T7 del doc del pivot). El nivel lo expone más que el actual porque hay más pantalla en cuadro.
- T12 — `platformer_world.gd` sigue siendo un único mundo. Con la pantalla de selección, el mundo debería volverse genérico de verdad (una escena, N niveles) — T1 lo deja a medio camino si el registry no resuelve la escena.
- T13 — El `d2_theme.tres` global sigue manejando options menu, skill tree y dialogue (pendiente de la doc del menú).

## Log

- L1 (2026-10-25) — User: "planea ahora la creacion de un nivel, es decir un nivel completo de enemigos, saltos, a nivel mas "level design" hazme preguntas para rellenar preferencias"
- L2 — User, preferencias (respuestas a las 7 preguntas): "Dato externo por nivel" / "Medio: 6-8 min" / "Patrulla simple" / "Escalada por algoritmo" / "Plano de muerte + checkpoints" / "Repintar a neón ahora" / "Pantalla de selección de niveles".
- L3 — Evidence: la física del jugador sale de `platformer_player.gd` (GRAVITY 1800, JUMP_VELOCITY -620, RUN_SPEED 220, JUMP_CUT 0.45). Altura máxima 106.8 px = 3.34 tiles; alcance 151 px = 4.7 tiles. De ahí salen los invariantes del nivel, no del gusto: hueco ≤ 3 cómodo, ≤ 4 estirón, 5 imposible; subida ≤ 3.
- L4 — Evidence: el nivel actual declara sus datos en `const` arrays dentro de `platformer_world.gd` — el nivel vive en código y no escala a un nivel diseñado a mano.
- L5 — Evidence: el `EnemyCatalog` tiene 10 enemigos y 8 challenges reales, pero el nivel actual duplica los nombres a mano y dos no coinciden (`Null Pointer` no está en el catálogo; `Fantasma Off-by-One` apunta a `linear_search` en el nivel y a `binary_search` en el catálogo). El nivel nuevo declara ids del catálogo y deja que el mundo resuelva el resto.
- L6 — Evidence: `enemy.gd` ya tiene `defeat()` y `respawn()` con `respawn_time`. Los enemigos derrotados vuelven a aparecer solos; el nivel no lo resuelve todavía (T9).
- L7 — Decision: el nivel se declara en un `.gd` de datos y no en un `.tres`. Los datos son diccionarios anidados y Godot 4 no edita `Dictionary` en el inspector; un `.tres` obligaría a tipar cada campo en clases Resource sin ganar nada que el editor no dé.
- L8 — Decision: la geometría del nivel se verifica con un guard (T8). Un nivel a mano es justo el caso donde un error de un tile lo hace incompletable, y la aritmética del envelope lo detecta.
- L9 — Decision: S3 se lee como tiempo de recorrido. El tiempo de sesión real lo domina el terminal (T10).
- L10 — Delivery: `feature-branch-chain`. El forecast (~1000 líneas con el guard) supera las ~400 líneas de un slice, así que la rama lleva varios work-unit commits y un solo merge.
- L11 — Evidence: la geometría se validó con aritmética antes de escribirla, contra el envelope real del jugador. 16 spans, 15 plataformas, 10 enemigos, 268 tiles (8576 px) de ancho. Resultado: 0 fallas — ningún hueco supera 4 tiles, ninguna subida supera 3, ninguna plataforma queda a más de 3 tiles del suelo, todo enemigo y todo checkpoint apoya sobre suelo. El primer pase tenía 3 errores (dos patrols cruzaban un hueco, el spawn usaba la regla de fila del enemigo en vez de la del jugador) y el checker los marcó antes de que llegaran al código.
- L12 — Evidence: el nivel actual usa huecos de 3 tiles en sus 5 tramos, con saltos de ±3 filas. El nivel nuevo mantiene 2-3 tiles en los actos 1-2 y sube a 4 (estirón) sólo en el acto 3, que es donde el acto se llama "Conducto".
- L13 — Decision: no hay plataforma en el medio del hueco de 4 tiles. Una piedra de paso ahí convertiría el estirón en un salto trivial y el acto perdería su función.
- L14 (2026-10-25) — User: "su dale" (autoriza la implementación).
- L15 — Evidence: el guard nuevo calcula el envelope leyendo las constantes de `platformer_player.gd` con `get_script_constant_map()`, no una copia. Si alguien retoca la física del salto, el guard recalcula el límite y avisa qué del nivel quedó invalidado. Su propia matemática tenía un error (la velocidad de salto es negativa y el tiempo en el aire salía negativo) y lo detectó al correr: el guard se auto-declaraba incapaz de saltar un hueco.
- L16 — Evidence: `enemy.gd` (scripts/overworld) lo usa también `battle_retry_guard`, así que la patrulla NO se agrega ahí: va en un subclase del enemigo del platformer. El `Enemy` compartido sigue siendo sólo el disparador de la batalla.
- L17 — Decision: el `Dragon del Caos` del catálogo apunta a `linear_search`, pero su propio flavor dice "Desordena vectores; std::sort lo calma" — o sea, `bubble_sort`. Como el nivel escala por algoritmo, repetir `linear_search` rompía la curva: entra la `Hidra Recursiva` (`fibonacci`) en su lugar. El Dragón queda para un nivel posterior, junto al jefe final.
- L18 — Verification: W1 — `level_01_guard` 101/101 en verde, suite completa 14/14. Captura real del mundo: el nivel pinta, el spawn cae sobre el suelo y el hueco inicial se ve. También se vio al jugador caer al vacío por caminar sin saltar: sin plano de muerte (T4) no hay red, y por ahora ese hueco sin red es el precio de T4.
