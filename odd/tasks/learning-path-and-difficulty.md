# Plan de aprendizaje y ajuste de dificultad

Hacer del juego una progresión de C++ coherente: cada nivel enseña un concepto, cada enemigo es un ejercicio de ese concepto, y la dificultad se ajusta con datos reales de playtest en vez de con intuición. Branch: `feature/learning-path-and-difficulty`. Delivery: `feature-branch-chain`. Test runner: `godot --headless scenes/qa/<guard>.tscn --quit-after 400` + `./scripts/_qa/run_all_guards.sh`.

## Diagnóstico

La curva de aprendizaje **está invertida en los dos extremos** y hay tres mapeos rotos. Los números salen del motor de daño real (`scripts/battle/scoring_engine.gd`) y de `EnemyCatalog`.

### D1 — La curva está invertida

Daño por acierto = `lerp(base, perfect, ratio) · ratio · time_factor · combo · (0.5 + diff/10·1.5) · (0.7 + 0.3·ast_quality)`. Con acierto perfecto (ratio 1, <5 s, AST 1.0) y sin combo:

| Enemigo | Skill | Challenge | diff | HP | dmg/turno | Turnos | Fallos que se aguantan |
|---|---|---|---|---|---|---|---|
| slime_aritm | Nv.1 | **simple_dp** | **4** | 60 | 143 | **1** | 8 |
| buggo_ciego | Nv.2 | linear_search | 2 | 80 | 64 | 2 | 8 |
| ogro_bucle | Nv.2 | factorial | 3 | 100 | 85 | 2 | 8 |
| fantasma_offbyone | Nv.3 | binary_search | 3 | 90 | 95 | 1 | 8 |
| golem_generico | Nv.3 | bubble_sort | 2 | 150 | 64 | 3 | 8 |
| dragon_caos | Nv.4 | bubble_sort | 2 | 220 | 64 | 4 | 8 |
| memory_leak | Nv.4 | hash_map | 3 | 250 | 104 | 3 | 8 |
| hidra_recursiva | Nv.6 | fibonacci | 4 | 180 | 110 | 2 | 8 |
| wyrm_paralelo | Nv.9 | **bubble_sort** | 2 | 260 | 64 | 5 | 8 |
| compilador_divino | Nv.10 | **main_exit_check** | **1** | 500 | 39 | **13** | 8 |

- El **tutorial** (Nv.1) exige el challenge más difícil del juego (programación dinámica, 6 casos de prueba) y mata en **un** turno: se siente trivial aunque el contenido sea el más duro.
- El **jefe final** (Nv.10) usa el challenge más fácil (solo compila, 1 caso de prueba) y necesita **13 turnos**: el jefe más largo con el contenido más vacío.

### D2 — La progresión es evadible

`SkillTree.get_unlocked_enemies()` **sólo se usa para pintar un contador en el menú**. El nivel spawnea los 10 enemigos sin importar si el jugador desbloqueó el skill que los habilita. Consecuencia medida:

- El **Compilador Divino da 1500 XP**: una sola pelea lleva del nivel 1 al **nivel 6 de 10**, con 8 de los 14 skills desbloqueables. El jefe final se puede matar en el primer minuto del juego.
- La rama de punteros (`branch_pointers` → `ptr_if_else` → `ptr_arrays` → `ptr_dynamic`) **no tiene ningún challenge propio**: sus tres enemigos resuelven búsqueda y tablas hash, que son STL.
- `wyrm_paralelo` (concurrencia, Nv.9) pelea con `bubble_sort`. `dragon_caos` (que según su flavor es "std::sort lo calma") pelea con el mismo `bubble_sort` que el golem.
- `simple_dp` —el flagship de recursión + memoización— está atado al primer enemigo del juego.

### D3 — La economía de XP no cierra

- Árbol completo: **5850 XP** en skills. Ascenso a nivel 10: **7464 XP** (curva `100 · 1.5^(n-1)`). Total para llegar al jefe final: **11764 XP**.
- XP de una pasada por los 10 enemigos: **3590**. Falta **8174 XP** → hacen falta **3.3 pasadas completas** por el juego.
- El **primer paso** no cierra: la raíz es gratis, la rama cuesta 100 y pide nivel 2 (100 XP). El único enemigo disponible da **50 XP** → **2_loweres** de slime antes de abrir la primera rama.

### D4 — No hay datos

El juego no mide nada. Lo único que persiste es `user://savegame.json` y `user://settings.json`. No hay forma de saber si un enemigo es difícil porque es difícil o porque el concepto no se enseñó.

## Parte A — El plan de aprendizaje

### La espina

`capítulo → concepto → skill → challenge → enemigo`. Cada capítulo abre **una** idea; el enemigo del capítulo es el ejercicio de esa idea. El nivel ES el currículo: su roster es la lección, y el gate lo pone el SkillTree.

| Nivel | Capítulo | Concepto | Skill (Nv) | Challenge | Enemigos | Turnos objetivo |
|---|---|---|---|---|---|---|
| 01 | El Umbral | escribir una función que compile | root_arithmetic (1) | main_exit_check (d1) | slime_aritm | 1 |
| 02 | Bifurcación | if / else, return temprano | ptr_if_else (2) | linear_search (d2) | buggo_ciego | 2 |
| 03 | El Bucle | for / while, acumulador | stl_loops (2) | factorial (d3) | ogro_bucle | 2 |
| 04 | El Índice | arreglos, límites, off-by-one | ptr_arrays (3) | binary_search (d3) | fantasma_offbyone | 2 |
| 05 | La Ordenación | comparator y orden propio; después la biblioteca | stl_functions (3), stl_containers (4) | bubble_sort (d2) → **use_std_sort** (nuevo, d3) | golem_generico, dragon_caos | 2 → 3 |
| 06 | La Memoria | new / delete, nullptr, unordered_map | ptr_dynamic (4) | hash_map (d3) | memory_leak (jefe de capítulo) | 3 |
| 07 | La Recursión | caso base, memoización | recursion (6) | fibonacci (d4) → simple_dp (d4) | hidra_recursiva | 2 → 3 |
| 08 | Los Hilos | template<typename T>, std::thread | templates (7), concurrency (9) | **template_generic** (nuevo, d5) → **thread_join** (nuevo, d6) | wyrm_paralelo | 2 → 3 |
| 09 | El Compilador | todo junto | final_boss (10) | **final_gate** (nuevo, d7) | compilador_divino | 6 |

Los turnos objetivo suben 1 → 2 → 3 → 6: la dificultad crece con el **concepto**, no con el HP.

### Cambios de mapeo

| Enemigo | Challenge actual | Challenge nuevo | Por qué |
|---|---|---|---|
| slime_aritm | simple_dp (d4) | **main_exit_check** (d1) | el tutorial tiene que ser "escribí una función que compile" |
| ogro_bucle | factorial (d3) | factorial (d3) ✓ | queda: iteración es lo que enseña el bucle |
| golem_generico | bubble_sort (d2) | bubble_sort ✓ | queda: escribir tu propio sort |
| dragon_caos | bubble_sort (d2) | **use_std_sort** (nuevo) | su flavor es `std::sort`; después de escribir el tuyo, usás el de la biblioteca |
| hidra_recursiva | fibonacci (d4) | fibonacci ✓ + **simple_dp** | simple_dp es recursión + memo, no aritmética: va acá |
| wyrm_paralelo | bubble_sort (d2) | **thread_join** (nuevo) | concurrencia de verdad |
| compilador_divino | main_exit_check (d1) | **final_gate** (nuevo) | un jefe final de 13 turnos tiene que exigir 13 turnos de contenido |

### Challenges nuevos (4)

| id | diff | Qué exige | AST | Casos |
|---|---|---|---|---|
| use_std_sort | 3 | `std::sort` sobre un `vector<int>` | `loop`, `return` | 5 |
| template_generic | 5 | `template<typename T> T maxOf(vector<T>)` | `template`, `return`, `if` | 5 |
| thread_join | 6 | `std::thread` + `join` que suma en paralelo | `return`, `loop` | 4 |
| final_gate | 7 | una función que use recursión + sort + mapa | todos | 8 |

Cada uno con su `.tres` y su `*_runner.gd`, siguiendo el patrón de los 8 existentes.

### El gate (el fix de D2)

El nivel declara qué skill habilita cada enemigo y **el mundo sólo spawnea enemigos desbloqueados**. El primer enemigo del Nivel 01 es la excepción (la raíz es gratis, así que el slime siempre está disponible). Con el gate, matar al jefe final exige haber desbloqueado sus 4300 XP de skills — el bypass desaparece por construcción, no por balance.

### La economía de XP

- **La curva de niveles**: `XP_PER_LEVEL_GROWTH` 1.5 → **1.25**. Con 1.25, llegar al jefe final cuesta 6862 XP contra 3590 disponibles: **1.9 pasadas** en vez de 3.3, y el primer paso (raíz → rama) cierra con **una** muerte de slime en vez de dos.
- **La XP por enemigo se escala con el capítulo**: el primer enemigo da 100 (para abrir la rama con una pelea) y el jefe final 1500 se queda.
- **El grinding explícito**: con el gate, repetir un enemigo es la forma de acumular XP antes de la siguiente rama. Eso es sano si es visible; hoy `respawn_time` (25-120 s) lo hace invisible.

### Las dos ramas del SkillTree

El árbol tiene dos ramas (punteros / STL) y un currículo lineal las aplana. **Recomendación**: la espina de los niveles es el camino algorítmico (el de arriba), y las ramas del SkillTree quedan como **variantes por capítulo**: el Nivel 05, 06 y 07 declaran dos rosters y el mundo elige el de la rama que el jugador desbloqueó. Si eso resulta demasiado, la alternativa simple es una espina única y las ramas como desbloqueos opcionales que no cambian el roster — pero entonces la rama de punteros deja de existir como contenido.

## Parte B — Datos reales

### Qué medir

Un log de eventos local, una línea JSON por evento, en `user://plays/<timestamp>.jsonl`.

| Evento | Campos | Para qué |
|---|---|---|
| `level_start` | level_id, intento | saber si hay abandono |
| `checkpoint_reached` | level_id, índice, t_desde_inicio | ritmo del recorrido |
| `player_death` | level_id, x, y, causa (fall\|battle) | dónde se muere |
| `battle_start` | level_id, enemy_id, challenge_id, diff, hp, xp | contexto de la pelea |
| `battle_attempt` | n, elapsed_ms, compile_ok, passed, total, ast_valid, ast_quality, damage, player_hp, combo | curva de aprendizaje |
| `battle_end` | result, turnos, intentos, tiempo | dificultad de la pelea |
| `skill_unlocked` | skill_id, xp, nivel | ritmo de la progresión |
| `level_complete` | level_id, tiempo, muertes, enemigos | balance del nivel |

### Dónde

- **Escritura**: un autoload `PlayLog` con un buffer que escribe JSONL en `user://plays/`. Sin servidor, sin red: el juego es offline y los datos son del jugador.
- **Exportación**: un botón "EXPORTAR DATOS DE JUEGO" en el options que concatena las sesiones en `user://plays_export.jsonl` y muestra la ruta. El jugador decide si lo comparte.
- **Agregación**: `scripts/_qa/play_report.py` (Python, como los `extract_*.py` que ya están) que lee los JSONL y saca las tablas de abajo con un veredicto por métrica.

### Las métricas que deciden

| Métrica | Umbral | Acción si se rompe |
|---|---|---|
| intentos al primer acierto | mediana ≤ 2 en caps. 1-3, ≤ 4 en caps. 7-9 | bajar `difficulty` o `ast_required_features` del challenge |
| primer intento exitoso | ≥ 60 % en el primer enemigo de cada capítulo | el concepto no se enseñó: challenge más chico antes |
| muertes por enemigo | ≤ 35 % | bajar `max_hp` (menos turnos) o el daño del challenge |
| muertes por tramo del nivel | ≤ 25 % del total del nivel | agrandar el hueco o mover el `top` del span |
| turnos para matar | coincide con `ceil(HP / dmg)` ± 1 | el modelo de daño no predice la realidad: recalibrar |
| XP del capítulo vs. XP necesaria | sin déficit al cerrar el capítulo | ajustar `xp_reward` o la curva de niveles |
| tiempo por pelea | ≤ 3 min | el challenge es largo demais: partirlo en dos |
| capítulos completados | ≥ 80 % de los que empiezan | mirar la plataforma, no el código |

### Los knobs

| Knob | Dónde | Efecto | Riesgo |
|---|---|---|---|
| `max_hp` | EnemyCatalog | turnos para matar | bajo |
| `difficulty` | `data/challenges/*.tres` | multiplicador del daño (0.5-2.0) | bajo |
| `base_damage` / `perfect_damage` | `data/challenges/*.tres` | daño por acierto | medio (afecta a todos) |
| `ast_required_features` | `data/challenges/*.tres` | qué exige el código | **alto: es el contenido** |
| `ENEMY_AUTO_DAMAGE` (12) | `scripts/battle/battle.gd` | fallos que se aguantan (100/12 = 8) | medio: global |
| `PLAYER_MAX_HP` (100) | `scripts/autoload/game_manager.gd` | fallos que se aguantan | alto: global |
| geometría (spans, huecos) | `data/levels/*.gd` | dificultad de plataforma | medio |
| `xp_reward` | EnemyCatalog | ritmo de progresión | medio |
| `respawn_time` | EnemyCatalog | si el nivel se repuebla | bajo |
| `XP_PER_LEVEL_BASE/GROWTH` | `scripts/gameplay/skill_tree.gd` | ritmo de progresión | alto: global |

**Lo que no se toca con datos**: el orden de los conceptos. LaDifficulty se ajusta; la progresión pedagogy no es un número, es una decisión.

### El loop

1. **Medir**: se juega con el log activo. Mínimo 5 partidas completas para tener señal (con 10 enemigos y ~40 eventos por nivel, 5 partidas dan ~2000 eventos).
2. **Agregar**: `play_report.py` sobre los JSONL exportados.
3. **Decidir**: una métrica rota → **un** knob. Nunca dos a la vez, o se pierde la causalidad.
4. **Recalcular el objetivo**: si un enemigo se mata en 1 turno pero debería llevar 2, el ajuste es `max_hp`, no `perfect_damage`: subir el HP sube los turnos sin tocar la economía de daño.
5. **Repetir**: el ciclo completo es de horas, no de minutos. Por eso el log tiene que existir ANTES de tocar el balance: sin datos, cualquier ajuste es una carta.

## Tareas

- T1 — Gate de roster por skill desbloqueado. S-D2. Route: inline. Commit W1. HECHO: el mundo sólo spawnea enemigos con su skill desbloqueado; desbloquear un skill mete a su enemigo en el nivel sin reentrar. La raíz se desbloquea sola (cuesta 0): si arrancara bloqueada, el gate dejaría el nivel vacío.
- T2 — Remapeo de challenges. S-D1, S-D2. Route: inline. Los 6 mapeos de la tabla; `simple_dp` y `main_exit_check` salen de donde están.
- T3 — Los 4 challenges nuevos. S-D2. Route: inline. `use_std_sort`, `template_generic`, `thread_join`, `final_gate`, con su `.tres` y su runner, siguiendo el patrón de los 8 existentes.
- T4 — Economía de XP. S-D3. Route: inline. Commit W1 (primera pasada). HECHO a medias: los `xp_reward` del catálogo se re-afinan (350/250/350/350/550/550/1300/2000/2500/1500) para que la cadena fluya, con un simulador de progresión como oráculo. La curva de niveles NO se tocó: el barrido mostró que 1.5 rinde mejor que 1.25 (con la curva más plana el jugador sube de nivel antes y las subidas se comen el XP). Falta calibrar con datos de playtest (T5/T6).
- T5 — `PlayLog` (autoload). S-D4. Route: inline. Buffer de eventos + escritura JSONL en `user://plays/`, con flush en los momentos seguros (nivel, batalla, muerte) y nunca durante un frame de combate.
- T6 — Botón de exportación + `play_report.py`. S-D4. Route: inline. Exporta a `user://plays_export.jsonl`; el script agrega las 8 métricas y marca las que rompen su umbral.
- T7 — Guard del currículo. S-D2. Route: inline. Commit W1 (la parte del gate). HECHO: el guard asserta que el nivel arranca gateado (1 de 10 enemigos), que el jefe final NO está, que desbloquear un skill mete a su enemigo, y que el árbol de skills abre/pausa/reanuda. Falta la parte del remapeo de challenges (T2).
- T8 — Niveles 02 a 09. S-A. Route: inline. Un commit por nivel, con la geometría validada por el guard de T7 antes de commitear.

## Open

- T9 — ¿Las ramas del SkillTree son variantes de capítulo (roster por rama) o se aplanan en una espina única? Es la decisión de diseño más grande del plan y cambia el costo de T8 de 8 niveles a ~13.
- T10 — El `respawn_time` del catálogo (25-120 s) hace que repetir un enemigo por XP sea invisible. ¿Se muestra un contador de "reaparición" o se deja así?
- T11 — El arte del personaje sigue siendo 3/4 isométrico en un side-scroller: el currículo se enseña en el terminal, no en el mundo, así que la línea de fondo del nivel puede seguir siendo el código.
- T12 — ¿El jugador puede volver a un nivel ya superado?hoy no hay selector de capítulo, sólo de nivel, y el roster se filtra por skill: volver atrás es posible, re-jugar es fácil.

## Log

- L1 (2026-10-25) — User: "que podemos planear para ajustar la dificultad con datos reales, que sea incremental en el sentido de que tenga coherencia el ir 'aprendiendo' lo mas basico de c++ e irlo incrementando propon un plan completo de aprendizaje conforme los niveles y enemigos"
- L2 — Evidence: la curva de daño sale de `scoring_engine.gd`; con acierto perfecto, el slime (tutorial, Nv.1) se mata en 1 turno con `simple_dp` (dificultad 4) y el jefe final (Nv.10) necesita 13 turnos con `main_exit_check` (dificultad 1). La curva está invertida en los dos extremos.
- L3 — Evidence: `SkillTree.get_unlocked_enemies()` sólo se usa en `menu_stats_panel.gd` para pintar un contador. El nivel spawnea los 10 enemigos sin filtro: una pelea contra el Compilador Divino da 1500 XP y lleva del nivel 1 al 6 de 10.
- L4 — Evidence: la rama de punteros del SkillTree no tiene challenge propio (sus tres enemigos resuelven búsqueda y hash), `wyrm_paralelo` pelea con `bubble_sort` y `dragon_caos` pelea con el mismo challenge que el golem.
- L5 — Evidence: la economía de XP no cierra. Árbol 5850 + ascenso a Nv.10 7464 = 11764 XP contra 3590 disponibles (3.3 pasadas), y el primer paso (raíz gratis → rama de 100) pide 2_loweres del único enemigo inicial.
- L6 — Decision: el plan tiene dos mitades encadenadas. La Parte A define el currículo (qué se enseña en qué orden y qué challenge lo evalúa); la Parte B define cómo se mide para ajustar la dificultad con datos y no con intuición. El log tiene que existir ANTES del primer ajuste de balance.
- L7 — Decision: la curva de niveles baja a 1.25 y el primer enemigo da 100 XP, para que la primera rama se abra en una pelea y no en dos.
- L8 — Decision: los turnos objetivo (1 → 2 → 3 → 6) escalan con el concepto, no con el HP: la dificultad se sube con el contenido, y el HP se usa para calibrar el ritmo una vez que el contenido está.
- L9 — Decision: el gate de roster se implementa, no se documenta. Es lo que convierte el árbol de skills en un currículo real en vez de un contador decorativo.
- L10 — Verification: los números de D1-D3 se calcularon con el modelo de daño real (`ScoringEngine.calculate_damage`) y con la curva de XP real (`XP_PER_LEVEL_BASE/GROWTH`), no a ojo.
- L11 (2026-10-25) — User: "vamos por el gate". Implementa T1 (el gate) + la primera pasada de T4 (la economía de XP), porque el gate sin números es un nivel vacío.
- L12 — Evidence: el gate tenía una dependencia dura que nadie había visto. `SkillTree.get_unlocked_enemies()` sólo se usaba en el menú; la pantalla del árbol la instanciaba `scripts/overworld.gd`, que está HUÉRFANO (ninguna escena lo usa). O sea: la pantalla de skills era inalcanzable en el juego. Con el gate, eso era un deadlock: sin árbol no se desbloqueaba nada y sin desbloqueos no spawneaba ningún enemigo.
- L13 — Evidence: el InputMap mapeaba `toggle_skill_tree` a F6 y F2, ninguna tecla que un jugador vaya a buscar. Se agregó el backtick (physical 96). El guard lo asserta: abre, pausa el mundo y cerrar reanuda.
- L14 — Evidence: la raíz del árbol ahora se desbloquea sola. Cuesta 0 y es el conocimiento inicial; si arrancara bloqueada, el gate dejaría el nivel sin enemigos y el jugador sin saber por qué.
- L15 — Decision: la XP por enemigo se afinó con un SIMULADOR de progresión (no a ojo): el simulador juega el árbol como lo juega un jugador —desbloquea lo más barato que abre un enemigo, pelea, sube de nivel— y cuenta las peleas. Con los valores del catálogo: 54 peleas y el slime 13 veces. Con los afinados: 17 peleas y el slime 5.
- L16 — Decision: la curva de niveles NO se toca. El barrido (growth 1.5/1.25/1.15 × cuatro valores del primer enemigo) dio 16-19 peleas con 1.5 y 20-27 con 1.25: una curva más plana hace que el jugador suba de nivel antes y las subidas se comen el XP que los skills necesitan. El número que hay que mover es el XP por enemigo, no la curva.
- L17 — Evidence: el gate es correcto y el nivel no se vacía: el guard mide 1 de 10 enemigos al arrancar (el slime, con la raíz desbloqueada) y el jefe final no aparece hasta desbloquear su skill.
- L18 — Verification: W1 — `level_01_guard` 116/116, suite 15/15, capturas reales del nivel gateado y del árbol de skills.
