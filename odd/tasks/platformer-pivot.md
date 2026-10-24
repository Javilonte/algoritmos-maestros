# Platformer pivot — side-scrolling core

Convert the game from an isometric 2.5D world to a 2D side-scrolling platformer with free exploration and turn-based terminal battles on contact. Branch: `feature/platformer-pivot`. Delivery: work-unit commits on this branch. Test runner: `godot --headless scenes/qa/<guard>.tscn --quit-after 250`.

## Specs

### S1
> "necesito que hagamos este juego 2d estilo pokemon "dead cells" onda plataformero"

The playable world is a 2D side-scrolling platformer: gravity, jumping, platforms, and a camera that follows the player horizontally. Isometric diamond projection is retired for the new world.

### S2
> "Pokemon: explorar libre, pelear por turnos"

Exploration is free and uninterrupted. Contact with a monster opens the existing turn-based terminal battle (write code, compile, damage). The platformer layer adds traversal, not real-time combat.

### S3
> "tienes accesso a todo ire a dormir no te detengas"

Autonomous execution is authorised. Decisions are taken from evidence in the repository and documented here; no questions are pending the user.

### S4 — assumptions (not user-stated, flagged as such)

- ASSUMPTION: the existing terminal battle, code compiler, AST validator, challenge set and SkillTree/XP are reused unchanged. They are genre-agnostic and are the most expensive asset in the repo.
- ASSUMPTION: the isometric demo is retained as legacy, not deleted. Deletion is a separate decision the user has not made.
- ASSUMPTION: terrain is generated procedurally, following the existing `D2IsoTilesetBuilder` pattern. No side-view terrain asset exists in the repo — every terrain texture is an isometric diamond or a cube face, and a diamond top-face cannot be converted into a side-view tile.

## Tasks

- T1 — Side-view tileset builder. S1, S4. Route: inline. Produces `scripts/platformer/side_tileset_builder.gd`: 32x32 tiles, procedural atlas, physics layer with collision polygons on solid tiles, colours from `D2Palette`.
- T2 — Platformer player controller. S1. Route: inline. `scripts/platformer/platformer_player.gd`: `CharacterBody2D`, gravity, jump, coyote time, jump buffer, run acceleration and friction. Reuses the existing `move_left`/`move_right` actions; needs a new `jump` action in `project.godot`.
- T3 — Platformer world scene + camera. S1. Route: inline. `scenes/platformer/platformer_world.tscn` and `scripts/platformer/platformer_world.gd`: `TileMapLayer` level layout, player spawn, `Camera2D` with horizontal lookahead, enemy markers for encounters.
- T4 — Menu routes to the platformer. S1, S2. Route: inline. `WORLD_SCENE_PATH` in `scripts/ui/main_menu.gd` and `scripts/ui/code_transition.gd` points at the new world.
- T5 — Platformer guard. S1, S2. Route: inline. `scripts/_qa/platformer_guard.gd` + `scenes/qa/platformer_guard.tscn`: player falls and lands on the floor, jumps when on the floor, does not double-jump without a new press, camera follows, enemy contact opens the battle.

## Log

- L1 (2026-10-24) — User: "necesito que hagamos este juego 2d estilo pokemon "dead cells" onda plataformero"
- L1 (2026-10-24) — User, on combat model: "Pokemon: explorar libre, pelear por turnos"
- L1 (2026-10-24) — User, on autonomy: "tienes accesso a todo ire a dormir no te detengas"
- L2 — Evidence: zero 3D in the project; both cameras are `Camera2D`; `scripts/player/player.gd` has no gravity, no jump and no `is_on_floor()`. There is no platformer physics anywhere in the repo.
- L3 — Evidence: every terrain texture is isometric (`tilemap_cyberpunk_floors.png` at 256x128 diamonds, `iso_*_atlas` at 50x56 cube faces, `iso_terrain_atlas` at 350x784). The only side-view sprite in the repo is `assets/external/microfantasy/characters/knight_blue.png` at 96x32 (3 frames of 32x32). `personaje_idle/walk/hurt` are 344x280 frames and need downscale to roughly 48x39 to read as a platformer character.
- L4 — Evidence: `scripts/dungeon/d2_iso_tileset_builder.gd` is the proven pattern for a procedural TileSet (Image.create -> ImageTexture -> TileSetAtlasSource). T1 follows it rather than inventing a new approach.
- L5 — Decision: the battle stays turn-based and terminal-driven (S2). The encounter reuses `EventBus.battle_requested`, which `scripts/overworld/enemy.gd` already emits from a plain `Area2D` body_entered — so a platformer enemy needs no new battle code.
