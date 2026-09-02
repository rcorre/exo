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

## Player controller

`player/player.gd` is a `CharacterBody3D` with mouse-look (yaw on the body, pitch on the `Head` node, clamped) and WASD movement with asymmetric accel/decel (fast acceleration to top speed, faster deceleration to a stop) via `Vector3.move_toward`. Mouse is captured on start; `Esc` releases it, clicking recaptures. No jump/sprint/crouch yet — extend `_physics_process` when those are needed.
