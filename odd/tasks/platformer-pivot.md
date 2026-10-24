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

- T0 — Rebuild the character frame pipeline. S1, S4. Route: inline. Commit `0c17dc1`. The shipped sheets had a baked-in checkerboard (the atlas has no alpha), were cropped through the body (CELL_H 280 vs a ~390 px character) and read a corrupted imported texture. New `scripts/_qa/extract_platformer_frames.py` floods the checker from the border, finds the real row bands by density, cuts on the 328 px stride, crops each frame to its own bbox and bottom-aligns it.
- T1 — Side-view tileset builder. S1, S4. Route: inline. Commit `d6d62e8`. `scripts/platformer/side_tileset_builder.gd`: 32x32 tiles, procedural atlas, physics layer with collision polygons on solid tiles, colours from `D2Palette`.
- T2 — Platformer player controller. S1. Route: inline. Commit `d6d62e8`. `scripts/platformer/platformer_player.gd`: `CharacterBody2D`, gravity, jump, coyote time, jump buffer, variable jump height, run acceleration and friction. Reuses the existing `move_left`/`move_right` actions; adds a new `jump` action in `project.godot`.
- T3 — Platformer world scene + camera. S1. Route: inline. Commit `d6d62e8`. `scenes/platformer/platformer_world.tscn` and `scripts/platformer/platformer_world.gd`: `TileMapLayer` level layout from ground spans and floating platforms, player spawn, `Camera2D` with horizontal lookahead, enemy spawns.
- T4 — Menu routes to the platformer. S1, S2. Route: inline. Commit `d6d62e8`. `WORLD_SCENE_PATH` in `scripts/ui/main_menu.gd` and `scripts/ui/code_transition.gd` points at the new world. The world itself sets the GameManager state to OVERWORLD, following the pattern of every other world.
- T5 — Platformer guard. S1, S2. Route: inline. Commit `d6d62e8`. `scripts/_qa/platformer_guard.gd` + `scenes/qa/platformer_guard.tscn`: 14 assertions covering the TileSet, the painted level, the fall and landing, the jump, the double-jump guard, horizontal movement, the camera and the enemy encounter.

## Open

- T6 — The enemy is a static crow sprite. It has no platformer AI, no patrol and no idle animation. `scenes/overworld/enemy.tscn` was a debug placeholder (a red tinted Sprite2D with no texture); the platformer enemy reuses its battle-trigger script with real crow art.
- T7 — The character art is 3/4 front-facing isometric art reused in a side-scroller. It reads acceptably at 48 px but it is not side-view art. The repo has no side-view character asset: `assets/external/microfantasy/characters/knight_blue.png` turned out to be four vertical colour stripes, not a sprite sheet.
- T8 — The isometric world is retained as legacy. `scenes/iso/iso_demo.tscn` and the iso scripts are untouched.
- T9 — The existing iso character sheets are still cropped and still carry the checkerboard. `resources/personaje_spriteframes.tres` depends on their 344x280 regions, so regenerating them is a separate piece of work with its own frame-geometry change.

## Log

- L1 (2026-10-24) — User: "necesito que hagamos este juego 2d estilo pokemon "dead cells" onda plataformero"
- L1 (2026-10-24) — User, on combat model: "Pokemon: explorar libre, pelear por turnos"
- L1 (2026-10-24) — User, on autonomy: "tienes accesso a todo ire a dormir no te detengas"
- L2 — Evidence: zero 3D in the project; both cameras are `Camera2D`; `scripts/player/player.gd` has no gravity, no jump and no `is_on_floor()`. There is no platformer physics anywhere in the repo.
- L3 — Evidence: every terrain texture is isometric (`tilemap_cyberpunk_floors.png` at 256x128 diamonds, `iso_*_atlas` at 50x56 cube faces, `iso_terrain_atlas` at 350x784). The only side-view sprite in the repo is `assets/external/microfantasy/characters/knight_blue.png` at 96x32 (3 frames of 32x32). `personaje_idle/walk/hurt` are 344x280 frames and need downscale to roughly 48x39 to read as a platformer character.
- L4 — Evidence: `scripts/dungeon/d2_iso_tileset_builder.gd` is the proven pattern for a procedural TileSet (Image.create -> ImageTexture -> TileSetAtlasSource). T1 follows it rather than inventing a new approach.
- L5 — Decision: the battle stays turn-based and terminal-driven (S2). The encounter reuses `EventBus.battle_requested`, which `scripts/overworld/enemy.gd` already emits from a plain `Area2D` body_entered — so a platformer enemy needs no new battle code.
- L6 — Implemented T0-T5 in two work-unit commits on `feature/platformer-pivot`: `0c17dc1 feat(art)` and `d6d62e8 feat(platformer)`. Branch pushed to origin.
- L7 — Evidence: `platformer_guard` 14/14 — the player lands on the floor (y 496.0 -> 496.0, stable), the jump lifts it 110.9 px (about 3.5 tiles), a second jump in mid-air does not lift it again, move_right walks it 98 px, the camera tracks it, and walking into an enemy opens the battle. All 11 guards green; every scene boots except the pre-existing overworld.tscn missing suelo1.png; the real game boots with 0 script errors.
- L8 — RDD assessment on the range fd4b6b3..d6d62e8 returns risk `high` with reason `process_boundary` and `review_due: true`. Native review START was executed and returned the typed `gentle-ai.review-integration.consent/v3` envelope, which is blocking and awaits the user's decision. The candidate is committed and pushed; the review is an additional outside view, not a delivery gate.
