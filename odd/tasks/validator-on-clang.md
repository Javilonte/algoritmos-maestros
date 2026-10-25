# El gate sobre el AST de clang, sin extension nativa

Sacar la GDExtension de C++ del juego: el gate de forma pasa a leer el AST que produce el `clang++` que el juego YA exige para el sandbox de la pelea. Una sola toolchain, un binario menos, 223 MB de submódulos menos y la clase de bug "el binario quedó viejo" eliminada de raíz.

Branch: `main` (linear, como las unidades anteriores). Delivery: commits por unidad de trabajo. Test runner: `./scripts/_qa/run_all_guards.sh`.

## Por qué

El juego tiene **dos** cadenas de compilación para el mismo trabajo:

- El **sandbox** (`scripts/battle/cpp_sandbox.gd`) compila y corre el código del jugador con `clang++`.
- El **gate de forma** (`scripts/util/ast_validator.gd` → `TreeSitterParser`, una GDExtension en C++ con tree-sitter) parsea el mismo código para ver si tiene bucle, condición, llamada, return y template.

La segunda existe solo porque tree-sitter está en C++. Pero clang ya está ahí, y su AST dice exactamente lo mismo:

| tree-sitter (C++) | clang (JSON) |
|---|---|
| `for_statement` / `while_statement` / `do_statement` | `ForStmt` / `WhileStmt` / `DoStmt` |
| `if_statement` | `IfStmt` |
| `call_expression` | `CallExpr` |
| `return_statement` | `ReturnStmt` |
| `template_declaration` (padre de la función) | `FunctionTemplateDecl` (padre de la función) |

## Specs

- S1 — El validador devuelve **el mismo contrato** que la extensión: `valid`, `function_found`, `function_name`, `return_type_match`, `actual_return_type`, `param_count`, `statement_count`, `has_loop`, `has_conditional`, `has_call`, `has_return`, `has_template`, `required_features_missing`, `errors`, `quality`.
- S2 — El `quality` se computa igual: 0.4 base + 0.2 retorno + 0.1 return + 0.15 bucle + 0.05 condición + 0.05 llamada + 0.05 statements, tope 1.0.
- S3 — `valid` = sin features faltantes + tipo de retorno ok + statements >= mínimo.
- S4 — La validación es **async**: corre clang en un proceso aparte (el gate se dispara en cada pausa al escribir).
- S5 — Si no hay `clang++`, el gate se desactiva con un mensaje claro y la pelea sigue: la corrección la juzgan los **test cases**, no la forma.
- S6 — La extensión desaparece: `addons/algorithm-validator/`, `gdextension/` (con godot-cpp y tree-sitter), el guard de sanity y el binario de Windows que quedó viejo.

## Tareas

- T1 — `scripts/util/cpp_toolchain.gd`: descubrir el compilador y correr un proceso con timeout. Route: inline. **HECHO**.
- T2 — `scripts/util/ast_validator.gd`: el gate sobre el AST de clang. Route: inline. **HECHO**.
- T3 — **Guard diferencial**: el validador nuevo y la extensión tienen que decir lo mismo sobre el mismo código. Es el guard que hace segura la refactorización. Route: inline. **HECHO**: 88/88 (8 samples × 11 campos). Se borró con la extensión: sin ella no hay contra qué comparar.
- T4 — Los consumidores esperan la validación: `code_compiler.gd`, `battle_terminal.gd`, los guards. Route: inline. **HECHO**: `validate()` es una corrutina.
- T5 — Borrar la extensión, los submódulos y el guard de sanity. Route: inline. **HECHO**: `addons/algorithm-validator/`, `gdextension/` (con godot-cpp y tree-sitter), `.gitmodules`, el guard de sanity y el binario de Windows que quedó viejo.

## Log

- L1 (2026-10-25) — User: "c" (de la pregunta "¿Arranco con A (instalar mingw y cruzar el .dll a Windows) o prefieres que ataque directo con C (matar la extensión C++ y quedarnos solo con clang++)?"). Implementa C.
- L2 — Evidence: el dump JSON de clang para el codigo del jugador son 66 KB (34 KB con `-ast-dump-filter=<funcion>`) y GDScript lo parsea en **322 microsegundos**. El dump de texto son 12 KB pero no es estructurado. El JSON gana: el parseo es gratis y el recorrido son 43 microsegundos.
- L3 — Evidence: `CombatAlgorithmEvaluator` (430 de las 1094 lineas de la extension) NO lo usa el juego: solo el guard de sanity. `TreeSitterParser.validate_structure` es el unico contrato vivo (11 claves).
- L4 — Decision: la validacion se hace con `-ast-dump-filter=<nombre de la funcion>`: el dump sale mas chico y, si la funcion no existe, sale vacio — que es justo el caso "function not found".
- L5 — Decision: si la maquina tiene `g++` pero no `clang++`, el gate se desactiva (solo clang entiende `-Xclang`) pero la pelea sigue: los test cases son los que juzgan la correccion.
- L6 — Evidence: el gate con clang COMPIBA el codigo, no solo lo parsea. Sin los headers el AST no sale: tree-sitter no los necesitaba. El gate ahora antepone el MISMO preambulo que el sandbox (`CppToolchain.PREAMBLE`): el gate valida exactamente lo que se compila.
- L7 — Evidence: `-ast-dump-filter` es un filtro por SUBSTRING, no una regex (`^main$` no matchea nada). Con el filtro "main" matchea 40 funciones del SDK de macOS y clang emite un STREAM de objetos JSON, no un documento: `JSON.parse_string` falla con "Extra data". Los objetos son pretty-printed, asi que se recorta por los "{"/"}" de la columna 0 (y un string JSON nunca lleva un newline crudo, asi que el recorte no parte una cadena).
- L8 — Evidence: SIN filtro el dump es de 486 MB (el preambulo instancia toda la STL) y GDScript tarda 5,7 segundos en parsearlo. El filtro no es una optimizacion: es la unica forma viable.
- L9 — Evidence: clang NO envuelve una sentencia de expresion en un nodo (`a = b;` es un CompoundStmt con un BinaryOperator adentro) y tree-sitter si la contaba. Para que los umbrales de `ast_min_statements` significaran lo mismo, el conteo suma las expresiones que son hijas directas de un bloque. Con eso los conteos coinciden EXACTOS con los de tree-sitter.
- L10 — Evidence: clang parte la "llamada" en cuatro kinds: `CallExpr`, `CXXMemberCallExpr`, `CXXOperatorCallExpr` y `CXXConstructExpr` (`std::thread(...)` es una construccion, no una llamada). tree-sitter lo llamaba todo "call_expression".
- L11 — Evidence: el probe del challenge_gate_guard devuelve `int` desde funciones que devuelven `vector<int>`. Con tree-sitter eso no importaba (no mira tipos); con clang es un error de compilacion y el challenge parecia invencible. El probe ahora declara `using __R = <tipo de retorno>` y devuelve esa variable.
- L12 — Verification: W5 — suite 19/19 en verde SIN la extension. `validator_diff_guard` 88/88 contra la extension antes de borrarla. `curriculum_guard` 44/44, `challenge_gate_guard` 12/12, `cpp_sandbox_guard` 14/14, `battle_sandbox_guard` 11/11.
