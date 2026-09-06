# Exo

First-person extraction shooter. Godot 4.7 (GDScript), Forward+ renderer, Jolt physics. Low-poly 3D art direction — primitive meshes and flat colors are fine, no need for detailed models/textures.

## Running

- Open in editor: `godot -e`
- Run the game: `godot` (launches `run/main_scene` from `project.godot`)
- Headless syntax/scene-load check (useful after editing .tscn/.gd by hand): `godot --headless --quit-after 2`

## Project layout

- `player/` — player character (`player.tscn` + `player.gd`)
- `world/` — levels/test scenes (`test_arena.tscn` is the current main scene)

Group future content the same way: one folder per major system/actor (e.g. `weapons/`, `enemies/`, `ui/`), each holding its scene(s) and script(s) together.

## Conventions

- Indentation: tabs (GDScript/Godot default).
- Script style: typed GDScript (`var x: int`, `-> void`, `:=` for inferred typed locals) and `const` for tunable numeric constants at the top of a script.
- Node references: `@onready var x = $Path` rather than `get_node()` calls scattered through logic.
- Scenes are hand-edited as text (`.tscn`) in this workflow — when editing one by hand, keep `sub_resource`/`ext_resource` ids and `load_steps` count consistent, and validate with the headless check above before considering it done.

## Input

Input actions are defined in `project.godot` under `[input]`, not hardcoded scancodes in scripts. Movement uses `move_forward` / `move_back` / `move_left` / `move_right` (WASD, physical keycodes so layout-independent). Add new actions there (or via Project Settings > Input Map in the editor) rather than reading raw `Input.is_key_pressed`.

## Testing changes

Godot exits 0 on most runtime script errors, so exit code alone does not mean a change works. Use `tools/check.sh`, which also greps output for `SCRIPT ERROR` / `Parse Error` / `ERROR:` and fails if any appear:

```
tools/check.sh tools/smoke_test.gd   # loads every .tscn in the project; run after hand-editing a scene
```

For behavior changes (movement, combat, damage, anything with real physics/state), write a throwaway probe rather than reasoning about the code in the abstract:

```
cp tools/probe_template.gd /tmp/probe_x.gd   # edit /tmp/probe_x.gd, not the template
tools/check.sh /tmp/probe_x.gd
```

A probe boots the real scene via `SceneTree`, steps real `physics_frame`s, and can drive `Input.action_press`/`_fire()` directly — this is not a mock, it's the actual game running headless. Delete the probe when done; it's scratch, not a regression test.

If a probe reports something is broken, include a positive control in the same run — a case set up to obviously succeed (`probe_template.gd` has one: an aimed shot on the enemy). Without it, a wrong assumption in the probe itself (e.g. `look_at`'s `use_model_front` flag) reads as a game bug.

Don't assert on tunable constants (`SPEED`, spread/bloom degrees, damage numbers) — those change during normal iteration and a test on them just taxes every tuning pass. Assert on invariants (spread never exceeds max, health never negative) and discrete state transitions (death, hit registration) instead.

For visual changes (reticle, trails, materials — anything a headless run can't show), render a real frame:

```
tools/screenshot.sh res://world/test_arena.tscn /tmp/shot.png 30
```

This opens an actual window (needs a display, not `--headless`) and saves a PNG — read it back to check the result instead of asking the user to look.

There is no test framework installed yet (no GUT/gdUnit4). Reach for the tools above first; only introduce a real test suite once a specific system (e.g. damage/ammo/objectives) stops changing shape and a bug has bitten twice.

## Player controller

`player/player.gd` is a `CharacterBody3D` with mouse-look (yaw on the body, pitch on the `Head` node, clamped) and WASD movement with asymmetric accel/decel (fast acceleration to top speed, faster deceleration to a stop) via `Vector3.move_toward`. Mouse is captured on start; `Esc` releases it, clicking recaptures. No jump/sprint/crouch yet — extend `_physics_process` when those are needed.
