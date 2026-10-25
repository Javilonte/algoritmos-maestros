# Plan — Mecánica de batalla: contrato visible, combate honesto y dificultad medible

Que pelear contra un bug sea escribir C++ de verdad: ver el enunciado, entender qué se te pide, recibir un error que enseña y pelear contra un reloj que no te castiga por pensar. Branch: `feature/battle-mechanic`. Delivery: `feature-branch-chain`. Test runner: `godot --headless scenes/qa/<guard>.tscn --quit-after 400` + `./scripts/_qa/run_all_guards.sh`.

## Diagnóstico

Cinco hallazgos, con evidencia. El primero es un bloqueante puro.

### D1 — Dos challenges son imposibles de pasar

`_check_required_feature` (`gdextension/src/validators.cpp:79`) reconoce **cuatro** nombres: `loop`, `conditional`, `call`, `return`. Cualquier otro nombre devuelve `false` → "missing".

Pero dos challenges piden **`"if"`**:

| Challenge | Difficulty | Declara | Estado |
|---|---|---|---|
| `simple_dp` | 4 | `["loop", "return", "if"]` | **imposible** |
| `binary_search` | 3 | `["loop", "return", "if"]` | **imposible** |
| `fibonacci` | 4 | `["conditional", "return"]` | ok |

El análisis AST del validador **es correcto**: detecta el `if` anidado dentro del `for` (`has_descendant_of_type` es recursivo, `gdextension/src/ast_utils.cpp:29`). Lo que falla es sólo la búsqueda del nombre.

Prueba empírica con el código exacto del jugador y el validador real:

```
features declaradas: ["loop", "return", "if"]
--- con las features tal cual ---
  valid: false
  errors: ["Missing required features: if."]
  has_loop: true has_conditional: true has_return: true
  quality: 0.95
--- con 'if' renombrado a 'conditional' ---
  valid: true
  errors: []
  quality: 0.95
```

El código del jugador era **correcto** (quality 0.95) y lo rechazó un nombre mal escrito. Y `simple_dp` es el **primer enemigo del Nivel 01** (el slime): la tutorial es invencible.

### D2 — El enunciado no se muestra nunca

`enemy_data.gd:70` arma `challenge_prompt` en el diccionario del enemigo. **Ninguna UI lo lee** (el único uso de la cadena es esa línea). El editor abre con `challenge.starter_code` (`battle_terminal.gd:79`), cuyo único comentario es `// tu código aquí`.

El jugador pelea contra una tarea invisible. En la captura, el jugador escribió un loop que imprime la paridad de `i` para un challenge que pide **cuántas formas hay de subir n escalones con DP tabulativa**. No era un error del jugador: no tenía el enunciado.

### D3 — El código del jugador nunca se ejecuta

Los 8 runners ignoran el código del jugador y llaman a **su propia solución de referencia**:

```gdscript
static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var n: int = int(test.inputs[0])
	var actual: int = _climb_stairs(n)   # la referencia, no el jugador
```

Y `main_exit_check_runner.gd` devuelve `{"passed": true}` siempre. El "0/5 tests" que muestra la consola es el de la referencia, nunca el del jugador.

Consecuencia: **la única verificación real es el gate de forma del AST**. Escribí cualquier cosa con un bucle, un return y un if, y "ganás". La pelea no evalúa tu algoritmo: evalúa tu sinaxis.

Las fases "linking" y "optimizing" de `code_compiler.gd` son barras de progreso falsas: no hay compilación en ningún lado. El único cliente HTTP del repo postea a `httpbin.org` (`terminal_ui.gd:12`), un placeholder que devuelve 200 para todo.

### D4 — El feedback habla el idioma del validador

"Missing required features: if." le dice al jugador algo que no puede descifrar. Los requisitos (loop, return, if) tampoco se muestran en ningún lado hasta que fallás. Y el detalle por caso **ya existe** en `TestResult.errors` / `failed_test_names` (`test_runner.gd:49`), pero la consola de la batalla sólo muestra el resumen ("4/5 tests"). El jugador nunca ve qué esperaba ni qué obtuvo.

### D5 — La economía castiga el no-saber

| Regla | Valor | Consecuencia |
|---|---|---|
| Daño por fallo | `ENEMY_AUTO_DAMAGE` = 12 | un fallo estructural (no saber la rúbrica) pega igual que un error de algoritmo |
| Vida del jugador | 100 | **8 fallos = muerte** |
| Reloj de turno | `time_limit_ms` = 30000 | corre **mientras escribís**: la batalla es `PROCESS_MODE_ALWAYS`, así que el timer no se congela con el editor abierto |

Sumado: no sabés qué construir, no sabés qué te piden, tenés 30 segundos, y morís en el intento 8. Eso no es "amena": es un muro.

## Parte A — Que la pelea sea legible

### P0 — El vocabulario (bloqueante)

Tres capas, de la más chica a la más durable:

1. **Los datos**: `"if"` → `"conditional"` en `simple_dp.tres` y `binary_search.tres`. Data-only, sin recompilar.
2. **El validador**: que `_check_required_feature` acepte los nombres naturales como alias — `if`/`else`/`switch` → conditional, `for`/`while` → loop — y que un nombre desconocido **sea un error de configuración explícito**, no un "te falta esta feature". Requiere recompilar la extensión (hay toolchain: `gdextension/addons/algorithm-validator/bin/`).
3. **El guard que lo impide volver a pasar**: un guard que, para cada challenge, construye un C++ sintético con las features pedidas y lo pasa por el gate. Si el vocabulario está roto, el guard falla. Si el challenge pide algo imposible, el guard falla.

```gdscript
# por cada challenge: un cuerpo que contenga EXACTAMENTE lo que pide
var code := "int %s(int n) {\n" % hint + "\tint t = 0;\n\tfor (int i = 0; i < n; i++) {\n\t\tif (i %% 2 == 0) { t += i; } else { t -= i; }\n\t}\n\treturn t;\n}"
# → gate.accepts(code) tiene que ser true
```

### P1 — El contrato, arriba del editor

El bloque que le falta al jugador. Todo está en los datos: `prompt`, `function_signature`, `ast_required_features`, `test_cases`.

```
┌ CONTRATO ──────────────────────────────────────────────┐
│ OBJETIVO  Implementa int climbStairs(int n) que retorne  │
│           de cuántas formas puedes subir n escalones...  │
│ FIRMA     int climbStairs(int n)                        │
│ REQUIERE  un bucle · un return · una condición (if/else)│
│ EJEMPLOS  climbStairs(1) → 1    climbStairs(3) → 3      │
└─────────────────────────────────────────────────────────┘
```

Y el **checklist en vivo** mientras escribís: el validador ya devuelve `has_loop` / `has_conditional` / `has_return` / `has_call`, así que un `text_changed` con un debounce de ~0.2s puede pintar:

```
✓ un bucle (for/while)
✓ un return
○ una condición (if/else)      ← lo que falta, y se ve mientras escribís
```

Esto convierte el error opaco en algo que el jugador ve **antes** de submitir. Es el cambio de mayor impacto y no pide tecnología nueva.

### P2 — Errores que enseñan

- Traducir el vocabulario interno: `loop` → "un bucle (for/while)", `conditional` → "una condición (if/else)", `return` → "un return".
- Mostrar el detalle por caso que ya se calcula: `expected 3 ways for n=4, got 0`.
- Si el gate de forma falla, decirlo como lo que es ("tu código todavía no tiene una condición") y no como un veredicto de combate.
- **Dejar de mentir en la consola**: si no hay compilación real, las fases no pueden decir "linking" y "optimizing". O se compila de verdad (P4), o la consola dice lo que pasa ("analizando tu código").

## Parte B — Que la pelea sea amena

### P3 — La economía del combate

Reglas propuestas, todas justificadas con los números de D5:

| Regla | Hoy | Propuesta | Por qué |
|---|---|---|---|
| Fallo de forma (falta un if) | 12 dmg | **0 dmg**: es "todavía no está listo", no una respuesta mala | el jugador no debe perder vida por no conocer la rúbrica (que ahora ve, P1) |
| Fallo de algoritmo | 12 dmg | 12 dmg | sí es un error tuyo |
| Reloj | 30 s escribiendo | **se congela con el editor abierto** | el reloj mide la decisión (atacar/huir), no la escritura |
| Intentos | 8 (muerte) | **8-12 según la dificultad del challenge** | un concepto nuevo necesita más intentos que uno ya visto |
| Acierto | 0 cura | **el acierto cura 15** | premia el progreso y perdona un error |

La muerte se mantiene como consecuencia real, pero llega por **errores de algoritmo**, no por no saber las reglas.

### P4 — Que la pelea sea real (decisión)

Mientras el código del jugador no se ejecute, la pelea es un ritual de sinaxis. Hay tres caminos, y la elección cambia el resto del plan:

| Opción | Qué exige | Resultado |
|---|---|---|
| **A. Compilador local** | `clang++` 17 **ya está en la máquina**; sandbox: directorio temporal, timeout, sin red | el código del jugador se compila y se prueba de verdad. Sin clave, sin red, offline. ~1 s por submit |
| **B. Judge0 (sandbox HTTP)** | clave de API + red + latencia | lo mismo, pero el código corre en un servidor |
| **C. Quedarse en el contrato de estructuras** | nada | el juego evalúa "usaste un bucle y una condición". Honesto si el texto lo dice, pero shallow: no verifica tu algoritmo |

**Mi recomendación: A**, con el sandbox local. Es la única que da el juego real sin depender de una clave ni de la red, y la máquina ya tiene el toolchain. El riesgo (código que cuelga o crashea) se cubre con timeout y proceso aparte.

## Parte C — Coherencia con el currículo

### P5 — El contrato ES el skill

El battle tiene que enseñar lo mismo que el árbol de skills:

- El enemigo muestra **qué concepto** practica (el VS badge puede llevar "práctica: Bucles").
- Las features requeridas por el challenge son **exactamente** las del skill que lo habilita. Esto cierra el círculo con T2 del plan de aprendizaje: el remapeo de challenges (el slime con `main_exit_check`, el jefe con `final_gate`) es lo que hace que la pelea sea la clase y no un trivia.
- El checklist muestra el concepto con su nombre de skill ("Bucles — usá un for o un while"), no el token interno.

## Tareas

- T1 — Vocabulario de features. S-D1. Route: inline. Data-only: `"if"` → `"conditional"` en los 2 challenges. Cierra el bloqueante del tutorial.
- T2 — Guard "todo challenge es ganable". S-D1. Route: inline. Construye el C++ sintético por challenge y lo pasa por el gate real. Falla si un challenge es imposible o pide una feature desconocida.
- T3 — Alias en el validador C++. S-D1. Route: inline. `_check_required_feature` acepta los nombres naturales y **rechaza en voz alta** un nombre desconocido. Recompila la extensión.
- T4 — El contrato en el editor. S-D2. Route: inline. Bloque OBJETIVO/FIRMA/REQUIERE/EJEMPLOS en `battle_terminal.tscn`, alimentado por los datos que ya existen.
- T5 — Checklist en vivo. S-D2. Route: inline. `text_changed` con debounce → re-validar el AST → pintar los ticks. Reusa el validador, no lógica nueva.
- T6 — Errores en el idioma del jugador. S-D4. Route: inline. Traducción feature → texto humano + el detalle por caso que `TestResult` ya trae.
- T7 — Economia del combate. S-D5. Route: inline. Reloj congelado con el editor, 0 dmg por forma incompleta, daño por error de algoritmo, intentos según dificultad, cura al acertar.
- T8 — Consola honesta. S-D3, S-D4. Route: inline. **HECHO (W3)**: las fases dicen lo que pasa porque ahora compilan de verdad: lexing → parsing AST → compiling → running tests.
- T9 — Ejecutar el código del jugador. S-D3. Route: inline. **HECHO (W3)**: `scripts/battle/cpp_sandbox.gd` compila el código del jugador con clang++ (c17) en un temporal bajo `user://sandbox`, arma un harness que llama a SU función una vez por caso de prueba, lo corre con timeout de 5 s y compara los resultados con los `test_cases`. `code_compiler.gd` ahora usa el sandbox: forma → compilación real → tests reales. Las fases "linking"/"optimizing" (que eran barras falsas) desaparecieron.
- T13 — **HECHO (W3)**: el detalle por caso llega a la consola ("n=3: expected 3, got -2") y el error de forma se dice en el idioma del jugador ("Te falta: un bucle (for/while), una condición (if/else)").
- T10 — El concepto en la pelea. S-P5. Route: inline. El enemigo y el checklist nombran el skill que la pelea practica.
- T11 — **HECHO (W1, commit `1cce870`)**: el vocabulario del gate. Los dos challenges que pedian `"if"` piden ahora `"conditional"`, el nombre que el gate conoce, y un guard nuevo (`challenge_gate_guard`) prueba que TODO challenge es ganable: arma un C++ con las estructuras que cada challenge declara y lo pasa por el gate real. Un challenge imposible falla el guard por nombre.
- T12 — **HECHO (W2, commit `8de477d`)**: el contrato y el checklist en vivo. El editor muestra objetivo, firma, requisitos con tick y dos casos resueltos; todo estaba en los datos del challenge y nada lo leia. Los ticks usan el `has_loop`/`has_conditional`/`has_return`/`has_call` que el validador ya calculaba y se descartaban.

## Open

- T11 — **La decisión P4**: compilador local (A), Judge0 (B) o contrato de estructuras (C). Es la que define si las tareas T7-T9 tienen sentido: sin ejecución real, el daño y la muerte giran sobre la sinaxis, y la "dificultad" sigue siendo un número inventado.
- T12 — ¿El reloj congelado con el editor abierto, o un reloj generoso (90 s) que siga corriendo? Congelar es más amable; correr es más tenso. Recomiendo congelar y que el reloj mida la decisión.
- T13 — ¿El gate de forma sigue siendo un requisito **obligatorio** para hacer daño, o pasa a ser **informativo** (un consejo de estilo: "podrías usar un bucle")? Si el algoritmo se ejecuta de verdad (P4-A), la obligatoriedad de la forma penaliza a quien resuelve el problema de otra forma. Recomiendo: obligatoria mientras no haya ejecución real, informativa cuando la haya.

## Log

- L1 (2026-10-25) — User: "antes que tocar algo me gustaria que revises la mecanica de pelea porque si me pide un loop no me deja tirar un loop ya teniendo un if, analiza que esta حفiendo y hay que planear una jugabilidad amena y coherente esto es prioridad"
- L2 — Evidence: `_check_required_feature` (validators.cpp:79) sólo conoce `loop`, `conditional`, `call`, `return`. Dos challenges piden `"if"` → **imposibles**. Probado con el validador real y el código del jugador: `valid: false`, `errors: ["Missing required features: if."]`, pero `has_loop/has_conditional/has_return` en true y quality 0.95 — el AST estaba bien, el nombre mal. Con `"conditional"`: `valid: true`.
- L3 — Evidence: `challenge_prompt` se arma en `enemy_data.gd:70` y ninguna UI lo lee. El editor abre con `starter_code` ("// tu código aquí"). El jugador no sabe qué construir: por eso escribió un loop de paridad para un challenge de DP.
- L4 — Evidence: los 8 runners llaman a su solución de referencia (`_player_code` sin usar) y `main_exit_check` devuelve `passed: true` siempre. El código del jugador no se compila ni se ejecuta en ningún lado; las fases "linking"/"optimizing" son barras falsas. La única verificación real es la forma del AST.
- L5 — Evidence: `ENEMY_AUTO_DAMAGE` 12 contra 100 de vida = 8 fallos = muerte; `time_limit_ms` 30000 con la batalla en `PROCESS_MODE_ALWAYS` → el reloj corre mientras se escribe.
- L6 — Decision: dos fases. "Que sea legible" (P0-P2: vocabulario, contrato, checklist, errores) no pide tecnología nueva y ataca el motivo real del reclamo. "Que sea real" (P4) depende de una decisión del usuario y cambia el resto.
- L7 — Decision: el checklist en vivo reutiliza lo que el validador ya devuelve (`has_loop`, `has_conditional`, `has_return`, `has_call`): no es una feature nueva, es mostrar lo que ya se calcula y se guardaba.
- L8 — Decision: el guard de "todo challenge es ganable" construye un C++ sintético con las features pedidas y lo pasa por el gate real. Es la invariante que impide que la clase D1 vuelva, y no depende de que haya ejecución real.
- L9 — Decision: recomendar el compilador local (A) para P4: `clang++` 17 ya está en la máquina, no hay clave de Judge0 en el entorno y el juego es offline. Riesgo cubierto con timeout y proceso aparte.
- L10 — Verification: el bug se reprodujo con el validador real (no con una lectura del código) y el plan del guard T2 sale directamente de esa reproducción.
- L11 — Evidence (W1): reproducido el bug con el validador real y el código del jugador: `valid: false`, `errors: ["Missing required features: if."]`, pero `has_loop/has_conditional/has_return` en true y quality 0.95 — el AST estaba bien, el nombre mal. Con `"conditional"`: `valid: true`. El guard nuevo falla con `FAIL: 'simple_dp' is UNWINNABLE` si se reintroduce el bug (probado).
- L12 — Evidence (W2): `text_changed` dispara 35 veces al tipear 35 caracteres (las lambdas de GDScript capturan por valor: un contador en lambda miente, y por ahi el primer test dio falso negativo). El debounce corre con el arbol pausado porque el BattleTerminal es PROCESS_MODE_ALWAYS. El gate sólo mira DENTRO del cuerpo de la funcion: un `for` escrito fuera de la funcion deja el tick en ○, que es lo correcto.
- L13 — Decision: el checklist se refresca tambien en el submit. El debounce puede no haber disparado todavia y el contrato que ve el jugador tiene que ser el del codigo que va a hacer falta.
- L14 (2026-10-25) — User: "sandbox local". T9 entra: el codigo del jugador se compila con clang++ (que ya estaba en la maquina) y se corre en un sandbox local con timeout.
- L15 — Evidence (W3): el sandbox compila y corre de verdad. La solucion DP correcta del jugador pasa 6/6 y el enemigo pierde HP (80 -> 0). La solucion con la estructura correcta y el algoritmo equivocado falla con el detalle real: "n=0: expected 1, got 0", "n=3: expected 3, got -2", "n=10: expected 89, got 5". El codigo roto devuelve el error de clang con la linea y el cursor. Un loop infinito se corta a los 5 s.
- L16 — Decision: el codigo del jugador va SIEMPRE a un archivo y el comando lo arma el juego: no hay inyeccion posible. El shell solo redirige la salida del compilador a un archivo. El binario corre con los permisos del usuario: es su codigo, escrito por el, y el riesgo real (un loop infinito) esta cubierto con el timeout y el proceso aparte.
- L17 — Evidence (W3): dos guards nuevos. `cpp_sandbox_guard` (11 asserts: compila, pasa, falla, el error es real, no filtra la ruta del sandbox, el main del jugador compila) y `battle_sandbox_guard` (11 asserts end-to-end: la pelea arranca con el evento, el editor abre con el challenge del enemigo, la solucion correcta gana y el enemigo pierde HP, la wrong no le hace dano). Los dos se SALTAN si la maquina no tiene compilador.
- L18 — Evidence (W3): el timeout tiene que medirse con el reloj y no contando frames: en headless el bucle corre a cientos de fps y un timeout contado por frames duraba milisegundos. Y el runner de guards paso de 400 a 2500 frames porque el guard de batalla espera las fases REALES de la pelea.
