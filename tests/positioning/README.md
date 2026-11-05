# Positioning lab

A dependency-free test harness for iterating on tactical positioning. Both the
headless runner and the top-down lab use **the same fixtures, policy, navmesh,
CharacterBody3D actors, and physics steps**. No GUT/gdUnit or other plugins.

An experimental box-based cover selector is exercised by the cover fixtures
(`04` through `09`). It selects standing partial cover or a protected point with a clear side peek; the lab actor only moves to
that point and does not actually peek or fire. The included `navigation_baseline.gd`
is a positive control: it picks a player-relative standoff destination, without
considering protection. The three fixtures test the harness/navigation, not the
existing enemy combat AI. Test actors deliberately omit perception, weapons,
animations, and health; nothing changes the game's main scene or enemy controller.

## Run the tests

From the project root:

```sh
tools/check.sh tests/positioning/run.gd --fixed-fps 60

# One fixture; choose an artifact directory:
tools/check.sh tests/positioning/run.gd --fixed-fps 60 -- \
  --output /tmp/positioning \
  res://tests/positioning/cases/02_detour.json
```

`--fixed-fps 60` advances fixed simulation steps without waiting for wall-clock
seconds. Without it, the same runner works in real time. Cases have bounded
simulation durations; the runner exits nonzero on failure. Continue using
`tools/check.sh`, since Godot can otherwise exit zero despite script errors.

A pass requires **every enemy** to be in one of its accepted destination regions,
stationary horizontally, and on the floor at the deadline. The checker reads
**actual body positions**, not selected destinations. Expected regions are never
used to drive movement. There is also a small positive/negative self-check of the
region matcher.

Each case produces:

- `<case>.json`: pass/fail, actual endpoints, chosen targets, per-enemy checks,
  expected regions, and sampled movement trails.
- `<case>.svg`: a portable overhead diagram of the obstacles, starting positions,
  actual trails/endpoints, chosen targets, and expected regions. Open in a browser.

Default output: `/tmp/exo-positioning`. Existing reports for the same case filename
are overwritten. Treat an interactive report as an observation, not a reproducible
fixture, unless its initial setup has also been saved.

## Interactive lab

```sh
godot res://tests/positioning/lab.tscn

# Open a particular fixture (including an absolute path to a scratch fixture):
godot res://tests/positioning/lab.tscn -- res://tests/positioning/cases/02_detour.json
```

- **WASD**: move the cyan player, with real collision. Enemies replan live.
- **Scenario dropdown**: load another fixture. Unsaved expectation edits block
  switching; save them or use Reset to discard them.
- **Pause / Resume / Step**: pause the simulation or advance exactly one physics
  tick. Editing and camera rendering remain available while paused.
- **Reset**: restart from fixture positions and discard unsaved edits.
- **Enemy dropdown + radius + right-click on the floor**: replace that enemy's
  expected region with a circle at the clicked point. Change the radius *before*
  clicking. Coordinates are snapped to 0.1 meters. This does not command the enemy.
- **Save expectations**: explicitly write these regions back to the selected JSON
  fixture, preserving its original player/enemy starts and scripted player moves.
  This can change a tracked fixture; review its diff before committing.
- **Save setup copy**: write a new fixture under `user://positioning-cases/`, using
  the *current* player/enemy positions as starts and keeping the independently
  authored expectations. Clears scripted player moves and immediately replays the
  saved setup. The absolute path is shown on screen; it can be passed to the runner
  or copied into `cases/` for version control. It does not bless actual endpoints.
- **Export report**: write the current JSON/SVG observation under
  `user://positioning-reports/`; the resolved directory appears on screen.

Green circles are accepted regions. Yellow crosses are the policy's selected
navigation destinations. Orange lines are actual movement trails; hollow orange
circles mark starts. For the experimental cover policy, cyan dots and lines show
valid hide/peek pairs; red dots show rejected hide candidates. Labels identify
enemies and their expected regions.

The lab continues past the fixture deadline to allow exploration. For timed
`player_moves`, Reset replays those events. Expectations are fixed annotations:
if you manually move the player, they do not magically become new correct answers.
Use Save setup copy when turning that exploration into a reproducible case.

## Fixtures

Create a JSON file in `cases/`, or pass a scratch file directly. All positions are
`[x, z]` in meters on a flat floor: **+X right, +Z down** in the overhead view.
The arena is 24 x 20 meters (x = -12..12, z = -10..10), bounded by collision walls.
Keep starts on the floor, clear of walls/obstacles and other actors.

```json
{
  "name": "My positioning case",
  "description": "Explain why this destination is appropriate.",
  "duration_seconds": 8,
  "policy": "res://tests/positioning/navigation_baseline.gd",
  "player": [2, 0],
  "player_moves": [{"at_seconds": 3, "position": [0, 0]}],
  "enemies": [
    {
      "id": "E1",
      "start": [-9, 0],
      "expected": [
        {"center": [-5, 0], "radius": 0.8},
        {"center": [-5, 1], "radius": 0.8}
      ]
    }
  ],
  "obstacles": [
    {"center": [-7, 0], "size": [2, 2.5, 5], "yaw_degrees": 0}
  ]
}
```

- `policy` is optional; defaults to the navigation-only baseline.
- `check_cover: true` asks the cover policy's lab adapter to independently query
  protection, peek movement clearance and firing clearance at the actual endpoint.
  These checks use the same sample heights and physics assumptions as selection.
- `cover_kind` optionally requires `partial` or `side_peek` when `check_cover`
  is enabled. Partial cover checks a blocked torso, exposed head and clear shot.
- `min_enemy_separation` optionally requires every pair of actual enemy endpoints
  to be at least this far apart in XZ.
- Obstacle sizes are `[width, height, depth]`; yaw is in degrees. Boxes become both
  visible geometry and static collision, and feed the runtime navmesh bake.
- `player_moves` is optional: ordered, unique times that teleport the player to
  the specified position. This is useful for deterministic flanking/replan cases;
  interactive movement instead uses actual collision.
- Multiple expected regions mean **any of these is acceptable**, useful for
  symmetric choices. The UI replaces the selected enemy's list with one region;
  edit JSON directly to author alternatives.
- Durations are deadlines, not movement-speed assertions. Use generous margins.
- Expectations describe intended spatial behavior, not tunable spread/damage/etc.

## Adding the real positioning algorithm

Read [`enemies/COVER_PLAN.md`](../../enemies/COVER_PLAN.md) first for the user’s
runtime-first/no-authored-slots/no-plugins decisions, open design choices,
gameplay integration requirements, and navigation pitfalls found while building
this harness.

A policy is a `RefCounted` script with this interface:

```gdscript
func choose_destination(enemy: CharacterBody3D, player: CharacterBody3D, arena: Node3D) -> Vector3:
    # Return a world-space destination. Never read fixture expectations.
    return ...
```

Policies can use the real world through `arena.get_world_3d()`, the navigation map
through `arena.region.get_navigation_map()`, and the actors through `arena.enemies`.
`enemy.start_position` is available for the baseline; real cover logic should use
current positions. Each arena owns one policy instance, allowing future shared
candidate caches/reservations. Selection runs periodically, independently of
frame-by-frame navigation movement.

Put reusable cover selection in the gameplay system (e.g. `enemies/`), and have
both gameplay and this harness call it. Use a small adapter if necessary; do not
create a second test-only implementation of the cover algorithm. Update/add
fixtures with human-authored intended destinations as that algorithm arrives.
Keep the navigation baseline fixtures as positive controls.

Current scope/limitations:

- Flat box-based fixture arenas; no stairs or arbitrary scene import yet.
- No squad avoidance or reservation policy; actors physically collide.
- Closest-navmesh-point projection does not prove reachability. Unreachable/stuck
  actors fail by not arriving; future selection should explicitly filter them.
- Cover checks currently sample two body points and a single standing shot ray;
  they are not a full combat or exposure simulation. The selector assumes a
  flat floor, fixed actor dimensions and static collision layer 1. It has simple
  hide/peek reservations and score hysteresis, but no crouching or peek
  execution. The selector owner must explicitly release reservations on death or
  when an actor stops using cover; freed actors are cleaned up lazily.
- Fixed ticks and a fixed RNG seed reduce noise, but physics/navmesh results are
  not promised bit-identical across engine/platform versions. Use spatial regions.

## Visual checks while developing the harness

```sh
tools/check.sh tools/smoke_test.gd
tools/screenshot.sh res://tests/positioning/lab.tscn /tmp/positioning-lab.png 60
```

Read the PNG back to inspect the actual rendered scene. SVGs are diagnostic
reports, not a replacement for checking the live rendering/UI.
