# Battle UI redesign — fix the broken layout, rebuild the look

Diagnose and rebuild the combat screen. Branch: `feature/platformer-pivot`. Delivery: work units on this branch. Test runner: `godot --headless scenes/qa/<guard>.tscn --quit-after 250`.

## Specs

### S1
> "organiza y planes [Image 1] que esta mal en estas interfaces y dales un better look"

The combat screen must be diagnosed against what the code actually renders, not against what the scene file appears to declare, and then rebuilt so the player reads it at a glance. "Organize and plan" is the diagnosis plus a written plan; "dales un better look" authorises the implementation of that plan.

### S2 — assumptions (not user-stated, flagged as such)

- ASSUMPTION: the combat screen keeps its current metaphor — two framed portraits facing each other across a VS badge. The request is about how the screen is built and looks, not about replacing the duel presentation.
- ASSUMPTION: gameplay is unchanged. No mechanic, no timing, no damage rule moves. This is a presentation change.
- ASSUMPTION: the only screen in scope is the one in the screenshot (`scenes/battle/battle.tscn`). The battle terminal and the GameOver screen are a separate pass.

## Diagnosis — measured, not assumed

All numbers below come from a runtime probe of the live scene at 1152x648, not from reading the `.tscn`.

### Broken (functional defects)

- **D1 — The character sprite draws OUTSIDE its portrait frame.** `battle_portrait.gd` parents an `AnimatedSprite2D` (a `Node2D`) inside a `CenterContainer`. Containers arrange **Control** children only, so the sprite is never moved: it stays at the art area's origin. With `centered = true` it draws from `-size/2` to `+size/2` around that origin. Measured: enemy drawn rect `(228.7, -8.4)` → `(315.3, 142.4)` and player `(608.2, -8.4)` → `(703.8, 142.4)`, against art areas at `(272, 67)` and `(656, 67)`. The art hangs 8.4 px above the top of the screen and 48 px to the left of its own frame, covering the name label and the border.
- **D2 — The sprite scale is derived from a constant that no longer exists.** `_fit_scale()` divides by `SIGIL_SIZE = (160, 180)`, while the real art area is 224x223. Both sprites come out exactly 150.88 px tall — scaled to a phantom 180 px box.
- **D3 — The battle background is 92% opaque, so the overworld bleeds through.** `CyberStyleBox.DEEP` has alpha 0.92. The screenshot shows the overworld's grey tiles, a dashed map edge and a character sprite behind the combat screen.
- **D4 — The HP bar does not align with the card.** The row is `[HP tag][bar]`, so the tag eats 24 px and the bar starts inside the frame: enemy bar `x 292..496` against a frame at `x 264..504`.
- **D5 — The HP bar shows the widget's own "100%"** instead of a health readout, and both sides are the identical D2 red, so the player's HP and the enemy's HP are indistinguishable.
- **D6 — The macro bar is on the wrong layer.** `MacroBar` lives in `battle.tscn` (CanvasLayer 9); the code editor it feeds lives in `battle_terminal.tscn` (CanvasLayer 11) behind an opaque panel. The macro buttons are visible only where they cannot be used and hidden where they can.

### Wrong look (composition)

- **D7 — ~46% of the width is dead.** The duel occupies `x 264..888` of 1152; 264 px of void on each side.
- **D8 — The turn timer floats in the top-right corner** as a bare "21" and a 6 px bar, 250 px from anything, unlabelled.
- **D9 — Palette split-brain.** The screen mixes the neon palette with the Diablo II palette: the VS badge text is gold `(0.95, 0.82, 0.45)`, the message is `D2Palette.BONE_TEXT` (beige), the HP tag is `D2Palette.MUTED_TEXT` (brown-grey), the HP fill is a D2 red.
- **D10 — Magenta carries two meanings.** It is the enemy accent in the portraits and the "Run" button.
- **D11 — The button glyphs are emoji** (`⚔`, `🏃`). They render at the system emoji font with their own metrics, misaligned against the label and off-palette.
- **D12 — A frame inside a frame.** The card border and the art border are the same 2 px accent line around a 224x223 empty hole.
- **D13 — The header splits.** The name is centred inside a 195 px label while `Lv 1` is pinned to the far right — a 100 px gap and no grouping.

## The target design

Three bands, one palette, nothing floating.

```
  ┌ status band ────────────────────────── TURN ┐
  │ COMBO                            [ 21 ▓▓▓░ ] │
  └──────────────────────────────────────────────┘
   ┌──────────── card ────────────┐  (VS)  ┌────────── card ─────────┐
   │ NAME                    Lv 1 │        │ NAME              Lv 1 │
   │ ┌───────────────────────────┐ │        │ ┌─────────────────────┐ │
   │ │           ART             │ │        │ │         ART         │ │
   │ └───────────────────────────┘ │        │ └─────────────────────┘ │
   │ HP                      30/30 │        │ HP                  42/50 │
   │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │        │ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░ │
   └───────────────────────────────┘        └─────────────────────────┘
   ┌──────────── message (720) ────────────────────────────┐
   │              Your turn — choose an action.            │
   └────────────────────────────────────────────────────────┘
              [ ATTACK ]          [ RUN ]
```

- **S3** The art of each portrait draws fully inside its art area, scaled from that area's real size, bottom-anchored so the feet sit on a baseline.
- **S4** The combat background is opaque. The world behind does not bleed through.
- **S5** The HP bar spans the full card width and shows `current/max` as text next to it, with a green → amber → red fill ramp. The "HP" tag moves to its own line above the bar so the bar aligns with the card edges.
- **S6** The turn timer lives in a framed chip labelled `TURN` in the status band. No bare number in a corner.
- **S7** Every colour on the screen comes from `CyberStyleBox`. No `D2Palette` reference remains in the battle screen.
- **S8** Magenta means enemy. "Run" uses the amber caution accent; "Attack" uses cyan.
- **S9** The action buttons carry no emoji. Uppercase text only.
- **S10** The art area is a plain dark backdrop with a floor line — not a second border inside the card border.
- **S11** The macro bar lives in the terminal, where the code editor it feeds actually is.

## Tasks

- T1 — Extend `CyberStyleBox`. S7, S4, S8. Route: inline. Commit `ui` work unit. New helpers: `backdrop()` (opaque), `card()`, `art_backdrop()`, `chip()`, `hp_color()`, plus the text/amber/green/red palette constants. `frame()` was deleted: the portrait was its only caller and it is now `card()` + `art_backdrop()`.
- T2 — Rebuild `BattlePortrait`. S3, S5, S10. Route: inline. Commit `ui` work unit. Dropped the `CenterContainer`; the sprite now hangs off the art panel and is laid out by hand against its `resized`. Scale comes from the real rect. New header row and a separate HP meta row.
- T3 — `HPBar` ramp and a `percent_text` export. S5. Route: inline. Commit `ui` work unit. `show_percentage` is already a `ProgressBar` property, so the export had to take another name.
- T4 — Recompose `battle.tscn`. S6, S9, S11. Route: inline. Commit `ui` work unit. Status band with the timer chip, 380x340 cards, opaque backdrop, 720-wide message panel, bottom action band, macro bar removed. The D2 gold sub-resources are gone from the `.tscn`: the look lives in one place.
- T5 — Rewire `battle.gd`. S6, S7, S8, S9. Route: inline. Commit `ui` work unit. New timer paths, new button accents, new text colours, the combo label emptied instead of hidden.
- T6 — Move the macro bar into `battle_terminal.tscn`. S11. Route: inline. Commit `ui` work unit.
- T7 — `battle_layout_guard`. S3, S4, S5, S6, S9. Route: inline. Commit `ui` work unit. 16 assertions: the art rect encloses the sprite's drawn rect, the art area is inside the card, the HP bar spans the card, the HP reads `cur/max`, the backdrop is opaque, the timer is inside its chip and right-aligned, and no button label carries an emoji.
- T8 — Fix the crow sheet's checkerboard. Route: inline. Commit `art` work unit. See L7.
- T9 — Fix the platformer enemy's hardcoded atlas region. Route: inline. Commit `art` work unit. See L8.

## Open

- T10 — Every enemy is drawn with the crow sheet. `battle.gd` sets the enemy's *name* from `enemy_data` but never its `sprite_frames`, so "Slime Aritmetico" is rendered as the hooded archer that the crow files actually contain. Fixing it needs per-enemy art, which the repository does not have.
- T11 — The extractor's `ROWS` table is wrong for the walk row. The source atlas holds eight characters in that row at irregular offsets (bands starting at 364, 631, 882, 1168, 1416, 1671, 1941, 2209), not seven on a 320 stride, so the first walk frame is a sliver. Pre-existing at `HEAD`, and `crow_walk` is not played by any scene.
- T12 — The battle terminal keeps its own green console theme and its `Submit Attack` / `Back` buttons still use Godot's default grey theme. A separate pass.
- T13 — The GameOver screen was not reviewed in this pass.

## Log

- L1 (2026-10-24) — User: "organiza y planes [Image 1] que esta mal en estas interfaces y dales un better look" (screenshot: the combat screen with the characters hanging out of their frames).
- L2 — Evidence: runtime probe at 1152x648. The sprite's global position equals the art area's top-left origin `(272, 67)` / `(656, 67)` and `centered = true` draws it from `-size/2`, so both characters land at `y = -8.4` — above the top of the screen. A `CenterContainer` never moves a `Node2D` child, which is the root cause; the `CenterContainer` also has a 0x0 minimum size because its only child is a `Node2D`.
- L3 — Evidence: `_fit_scale()` divides by `SIGIL_SIZE (160, 180)` while the art area measures 224x223. Both sprites land on exactly 150.88 px tall.
- L4 — Decision: the sprite is positioned manually against the art panel's `resized` signal rather than wrapped in a container. A `Node2D` inside a `Control` needs an explicit position, and `resized` is the one signal that fires when the container has settled.
- L5 — Decision: the HP bar moves to its own full-width row under a `HP` / `current-over-max` meta row. That is the only way the bar can align with the card edges while still carrying a label.
- L6 — Decision: the macro bar moves to the terminal. Deleting it would drop a feature; leaving it puts a dead control on the screen this pass is cleaning up.
- L7 — Evidence: the enemy portrait showed opaque grey slabs around the art. The cause was in `extract_crow_frames.py`, not in the UI: `CHANNEL_TOL = 14` sat one notch below the checker's channel spread of 16, so the blue-tinted checker squares were never background and came out as opaque islands in the same connected component as the character. Raising the tolerance to 18 was the obvious fix and it was WRONG — the character's browns have the same spread of 16, so the first idle frame lost its hood. The discriminator that works is HUE: every checker square in that atlas is blue-tinted (blue >= red) and every warm brown of the character has red > blue. The background candidate is now "unsaturated AND blue-tinted". After the change every idle frame is a complete character with a consistent bounding box, and no frame fills its cell with background any more.
- L8 — Evidence: `scenes/platformer/platformer_enemy.tscn` picked the atlas region by hand (`Rect2(0, 0, 320, 320)`), which was already stale against the old 182x317 cell. The enemy now takes its texture from the `SpriteFrames` resource at runtime, so a regenerated sheet can never leave the crop behind.
- L9 — Evidence: `godot --headless --import` is mandatory between regenerating a sheet and rebuilding the `.tres`. Godot serves PNGs through its import cache and a headless run does not re-import a changed source on its own: the first attempt rebuilt the `.tres` from the OLD sheet size and wrote the old cell regions back.
- L10 — Verification: all 12 guards green (11 before, `battle_layout_guard` added). `battle_layout_guard` 16/16. The screen was captured twice — once from the isolated scene and once from a real battle opened in the platformer world by walking into the enemy — and both read clean.

