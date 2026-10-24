# Main menu redesign — the last screen on the old palette

Bring the main menu onto the same neon system as the combat screens, and fix the layout bugs it inherited. Branch: `feature/platformer-pivot`. Delivery: work-unit commits on this branch. Test runner: `godot --headless scenes/qa/<guard>.tscn --quit-after 250`.

Follows `odd/tasks/battle-ui-redesign.md`, which did the combat family.

## Specs

### S1
> "quedo muy bien antes de subirla vamos a arreglar la pantalla principal"

The combat screens are done and look right. The main menu is the screen the player sees FIRST and it is still the old Diablo II olive-and-gold look, so the game opens on a different design system than the one it spends its time in. It gets the same treatment.

### S2 — assumptions (not user-stated, flagged as such)

- ASSUMPTION: the three-column layout (hero | actions | stats) stays. It is a good structure and the request is about how it looks and how it is built, not about a different menu.
- ASSUMPTION: gameplay is unchanged. The same buttons, the same destinations, the same save state.
- ASSUMPTION: the ambient code scrolling behind the menu stays. It is a good touch; it is currently invisible because the D2 background buries it.

## Diagnosis — measured, not assumed

The hero card was probed at runtime at 1152x648.

### Broken

- **D1 — The hero sprite draws OUTSIDE its card.** `menu_hero_card.gd` parents an `AnimatedSprite2D` inside a `CenterContainer`, exactly like the battle portrait did. Containers arrange Control children only, so the `Node2D` is never moved, and `centered = true` draws it from `-size/2` around the art panel's origin. Measured: the drawn rect is `(162.0, 131.4)` size `92.0x145.2` while the art area is at `(208.0, 204.0)` size `188x254` — the character sticks out 46 px to the left and 72 px above, sitting on top of the card's border.
- **D2 — The sprite scale is a hardcoded `Vector2(0.4, 0.4)`.** The battle portrait had the same disease (a scale derived from a constant that no longer measured anything). A new sheet geometry breaks it silently.
- **D3 — The locked skill dots are invisible.** `_refresh_skills` draws one 12x12 dot per skill, but a locked dot is dark-on-dark, so the panel shows `SKILLS (0/14)` with nothing under it. The fourteen slots are there and you cannot see a single one.
- **D4 — The XP bar shows the widget's own "0%".** The same thing the battle HP bar did. The panel already prints `0 XP` next to it.

### Wrong look

- **D5 — The whole screen is the Diablo II palette.** The background, the header bar, the footer, both cards and every button are `D2StyleBox`/`D2Palette`: olive brown, gold, bone. The combat screens are now neon cyan on near-black, so the game OPENS on a different design system than the one it plays in.
- **D6 — The hero card is a void.** 188x254 of empty dark box with the character floating outside it, and the name, level and subtitle jammed into the bottom 40 px.
- **D7 — The stats panel is a void.** 150 px of content in a 320 px panel: everything crammed at the top, ~200 px of nothing below.
- **D8 — The three columns are unbalanced.** 200 / 260 / 240 wide, different heights, with a hole between the centre column and the stats panel.
- **D9 — The buttons carry emoji.** `⚡`, `▶` and `✦` render in the system emoji font with their own metrics, off-palette.
- **D10 — The "Lv 1" badge is clipped** by its own border: a 48x28 panel whose text barely fits inside.

## The target design

```
┌────────────────────────────────────────────────────────────────┐
│                    ALGORITMOS MAESTROS                        │  ← header 88
│          Domina C++, un algoritmo a la vez_                    │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐   ┌──────────────────────┐  ┌──────────────┐ │
│  │              │   │  INICIO RAPIDO       │  │ [Lv 1]  0 XP │ │
│  │    ART       │   │  Empezar desde cero  │  │ ▓▓░░░░░░░░░░░ │ │
│  │   (floor)    │   ├────────┬─────────────┤  │ ──────────────│ │
│  │              │   │CONTINUAR│NUEVA PARTIDA│  │ SKILLS   0/14 │ │
│  │              │   ├────────┴─────────────┤  │ ●●●●●●●●●●●●●● │ │
│  │              │   │  OPCIONES    SALIR   │  │ ──────────────│ │
│  ├──────────────┤   └──────────────────────┘  │ MACROS      0 │ │
│  │ Player    Lv1│                              │ ──────────────│ │
│  │ Tu viaje...  │                              │ ENEMIES  0/10 │ │
│  └──────────────┘                              │ Sin partida   │ │
│                                                └──────────────┘ │
├────────────────────────────────────────────────────────────────┤
│ ▸ v0.1.0 · dev build                    Algoritmos Maestros    │  ← footer 36
└────────────────────────────────────────────────────────────────┘
```

- **S3** The character art draws fully inside the hero card, scaled from that area's real size, standing on a floor line.
- **S4** The menu shares `CyberStyleBox` with the combat screens. No `D2StyleBox` and no `D2Palette` left in the menu.
- **S5** The hero card and the stats panel fill their column: no 200 px voids.
- **S6** The stats panel is a list of labelled rows — label left, value right — with a visible dot for every skill slot, locked or not.
- **S7** The XP bar shows the XP, not the widget's percentage.
- **S8** The action buttons carry no emoji. Uppercase text.
- **S9** The three columns are balanced and the gaps between them are even.
- **S10** The ambient code is visible again over the dark background.

## Tasks

- T1 — `SpriteInFrame` helper. S3. Route: inline. Commit `menu` work unit. `scripts/ui/sprite_in_frame.gd` holds the "put a Node2D sprite inside a Control art area" math ONCE. The battle portrait and the hero card both need it, and a third copy of that arithmetic is how the bug came back.
- T2 — Rebuild `MenuHeroCard`. S3, S4, S5. Route: inline. Commit `menu` work unit. The sprite hangs off the art panel and is positioned by hand against its `resized`; the card uses `CyberStyleBox.card()` and an `art_backdrop()` with a floor line.
- T3 — Rebuild `MenuStatsPanel`. S4, S5, S6, S7. Route: inline. Commit `menu` work unit. Rows of label + value, visible locked dots, the XP bar without its percentage.
- T4 — Restyle `MenuActionButton`. S4, S8. Route: inline. Commit `menu` work unit. The four variants map to the shared palette: primary cyan, neutral steel, subtle dim, danger red.
- T5 — Recompose `main_menu.tscn` and `main_menu.gd`. S4, S9, S10. Route: inline. Commit `menu` work unit. Header 88, body fills, footer 36, balanced columns, dark background, ambient code visible.
- T6 — Extend `main_menu_layout_guard`. S3, S4, S7, S8. Route: inline. Commit `menu` work unit. 37 assertions, up from 21.

## Open

- T7 — The global `d2_theme.tres` still drives the options menu, the skill tree and the dialogue. Only the combat family and the main menu have moved to the neon palette.
- T8 — The splash screen was not reviewed in this pass.
- T9 — The ENEMIES row shows a count but not WHICH enemies are unlocked. The SkillTree knows the ids (`slime_aritm`) but they are raw identifiers, not the display names the battle screen uses.

## Log

- L1 (2026-10-24) — User: "quedo muy bien antes de subirla vamos a arreglar la pantalla principal" (screenshot: the main menu with the character hanging out of its card).
- L2 — Evidence: runtime probe. The hero sprite's global position equals the art panel's top-left origin `(208, 204)` and `centered = true` draws it from `-size/2`, so the drawn rect lands at `(162.0, 131.4)`. Same root cause as the battle portrait, same fix.
- L3 — Decision: the fix becomes a shared helper instead of a second copy of the arithmetic. `SpriteInFrame.fit()` owns the scale-from-real-rect and the floor anchoring, and both the battle portrait and the hero card call it.
- L4 — Decision: the stats panel becomes a list of rows rather than a stack of labels. A panel whose content is 150 px tall inside a 320 px frame reads as broken; rows that spread over the frame read as a stat panel.
- L5 — Decision: the hero card and the stats panel FILL the body height instead of being centred boxes. The character is the first thing the player should see, and a 320 px card with a 254 px hole is not a showcase.
- L6 — Evidence: a Button is NOT a Container, so its children are not laid out. The menu buttons' VBox sat at `(0, 0)` with its minimum size and the text started flush against the border — the "I" of INICIO RÁPIDO was under the frame. The VBox is now anchored to the button's full rect, with its margins read from the stylebox so the palette stays the single source.
- L7 — Evidence: the ambient code had `z_index = -1`, which put it BEHIND the background panel — a sibling earlier in the tree. It had never been visible. The tree order already puts it behind the menu.
- L8 — Evidence: clearing a row with `queue_free()` does not empty it. The free is deferred to the end of the frame, so the new dots were added while the old ones were still children and the row accumulated fourteen plus fourteen. The guard caught it. The children are now removed from the tree before the free is queued.
- L9 — Evidence: the headless viewport measures 64x64 by default, so the guard was asserting the layout against the minimum sizes instead of the real ones. It now measures at 1152x648.
- L10 — Verification: 13/13 guards green, `main_menu_layout_guard` 37/37, and the game boots with no script errors.
