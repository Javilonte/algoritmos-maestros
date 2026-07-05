# Algoritmos Maestros

A Godot 4.6 game where the player writes C++ code in an in-game terminal to defeat "algorithm monsters". The code is sent to a backend (mock: httpbin.org) for evaluation.

> **Status:** early prototype. Player can move around the overworld; opening the terminal lets you write C++ code, submit it, and receive a (currently local) validation result.

## Requirements

- Godot 4.6 (Forward Plus renderer)
- Desktop platform only (Windows / macOS / Linux)

## Running

1. Open the project in Godot 4.6.
2. Press F5 (or `Project → Run`).
3. Use **WASD** or **arrow keys** to move the player.
4. Press **`** (backtick) to open the terminal.
5. Write C++ code in the editor, click **Compile && Run**.

Default passing snippet:

```cpp
int main() {
    return 0;
}
```

## Controls

| Action | Keys |
|---|---|
| Move | `W` `A` `S` `D` / Arrow keys |
| Open / close terminal | `` ` `` (backtick) |
| Interact | `E` |

## Project structure

```
project.godot
project.godot             # main project config + autoloads + input map
player/                   # Player scene + sprite
scenes/                   # overworld + battle + UI scenes
scripts/
  autoload/               # EventBus, GameManager (autoloaded singletons)
  player/                 # player.gd
  ui/                     # terminal_ui.gd
  overworld.gd            # root script of the overworld scene
assets/                   # textures, audio (future)
```

## Architecture notes

- **Autoloads**: `EventBus` carries global signals, `GameManager` owns the FSM (`BOOT → OVERWORLD ↔ TERMINAL → BATTLE`).
- **Player movement** is driven by `CharacterBody2D.move_and_slide()` inside `_physics_process`.
- **Terminal validation** is currently a regex check (`int main() { return 0; }`); it lives behind a `_evaluate_challenge(challenge_id, code, response)` dispatch so future challenges can be plugged in.
- **Backend**: the script POSTs JSON to `BACKEND_URL` (default: `https://httpbin.org/post` mock). Replace it with a real endpoint when one is available. Validation is currently *local* (regex) — the backend response is logged but not authoritative.

## Known issues / TODO

- Player texture is 5.6 MB and rendered at `scale = 0.1`. A lower-resolution source is recommended.
- Ground has no collision body; the player can walk "over" it freely.
- No `interact` handler yet (door / monster trigger not implemented).
- Backend integration is a stub — only the request is sent, no real C++ compilation.

## License

MIT — see `LICENSE`.
