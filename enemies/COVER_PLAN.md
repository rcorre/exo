# Cover system handoff

This records context from the design discussion before cover implementation.
For harness commands, fixture schema, and UI controls, see
[`tests/positioning/README.md`](../tests/positioning/README.md).

## User decisions / requirements

- Enemies should reposition relative to the player to gain a firing angle while
  protecting themselves. Finding a place to hide with no way to engage is not
  sufficient.
- **No manually authored cover slots.** Discover candidates automatically at
  runtime initially. Keep the option of pre-generating them if profiling warrants
  it. Expected regions in test fixtures are assertions, NOT authored cover slots
  or candidate inputs.
- **Use Godot built-ins; no custom plugins for now.** GEQO/godot-eqs can be consulted
  as references, but do not add either as a dependency. Behavior-tree plugins are
  not required either.
- Preserve a lightweight agent feedback loop and human review: given initial
  enemy/player positions, run actual movement, inspect where enemies end up, and
  correct the intended regions. The same algorithm must also drive the top-down
  interactive lab as the player moves.

## What exists, and what does not

- `tests/positioning/` provides real collision, runtime navmesh baking, path
  following, scenario replay, spatial assertions, JSON/SVG reports, and a live lab.
- Its three initial fixtures are **navigation-only positive controls**, not
  cover acceptance tests. They select a standoff destination using the player's
  position and the bearing to the enemy's original spawn. Keep them as controls;
  add separate fixtures with an explicit cover policy.
- No cover selection, exposure tests, reservations, peeking, or cover cache has
  been implemented. The lab actors are simplified physical actors, **not instances
  of the production enemy scene**. Passing the lab does not prove combat works.
- `enemies/enemy.gd` still uses direct chase movement and probabilistic stopping.
  The gameplay test arena has not been given the harness's navigation setup.
  Gameplay integration needs navigation as well as selection/state changes.

## Suggested architecture (not a chosen algorithm)

Separate three responsibilities:

1. **Discovery:** geometric candidate positions, clearance, potential firing/peek
   positions. This part can later be cached lazily or generated offline.
2. **Evaluation:** current threat-relative protection, firing opportunity,
   reachability, range, travel cost, and occupancy.
3. **Execution:** navigate, hold/peek/fire/hide, and reconsider invalid cover.

Runtime-first does not mean rediscover everything every frame. Bound local
searches, filter cheaply before expensive physics/path queries, stagger work,
reuse static candidates, and use a meaningful improvement threshold before
switching positions. Profile discovery, raycasts, and path queries separately:
pre-generating candidates will not eliminate player-dependent evaluation costs.

**The discovery method is still open.** Options discussed:

- Sample obstacle faces/corners; deriving these from box colliders is a practical
  initial approach for the current low-poly geometry, including rotated boxes.
- Sample navmesh boundaries, then validate against real collision geometry. A
  boundary can also be a cliff, bake limit, or region seam—not necessarily cover.
  Navmesh edges are simplified and offset from physical geometry.
- Sample local navigable positions and filter/score them in an EQS-style pipeline.

Prefer a reusable selector under the gameplay system, with a small lab adapter if
needed. Do not make the production algorithm depend on fixture JSON, expected
regions, or a test-only `arena` node layout. The current policy returns only a
`Vector3`; it is fine to extend the integration when cover/peek metadata is needed.
That interface is scaffolding, not a requirement to squeeze everything into one
point.

## Cover semantics and integration traps

- Distinguish **partial cover with a firing opportunity** from **protected cover
  with a nearby reachable peek position**. A useful candidate may be a pair of
  positions, not one point that somehow both sees and cannot be seen.
- Visibility along the same segment is reciprocal. Test protection against
  multiple body points and test firing from the real firing origin separately.
  Validate body clearance along the move to the peek, not just a clear shot ray.
- Closest-navmesh-point projection is not a reachability check. Reject disconnected
  or badly displaced candidates and handle the case where no useful cover exists.
- Avoid stacking enemies at a single point. Reservations and release on invalid
  selection/death are possible solutions; local navigation avoidance alone does
  not solve tactical occupancy.
- Keep a valid choice stable, but reconsider when flanked, blocked, or unable to
  engage. Avoid oscillation between nearly equivalent candidates.
- Gameplay currently treats loss of sight as a reason to chase. Entering cover
  must not immediately cancel the cover behavior. Track a last-known threat
  position rather than granting omniscient tracking through walls. The lab passes
  a live threat directly to isolate positioning; it does not test perception.
- Enemy sight and firing currently use different hardcoded heights (`_can_see_player`
  and `_fire`). Consult actual code when defining sample points; do not assume the
  existing sight ray also establishes firing clearance.
- The enemy scene has an unused crouch animation, but animation alone does not
  change collision or shot origins. Side peeks and standing partial cover are a
  reasonable first slice; real crouching needs physical stance support. Some old
  comments in `AGENTS.md`/`enemy.gd` about the player lacking crouch are stale—read
  `player/player.gd` before sharing stance logic.

## Harness pitfalls already encountered

- **Navmesh bake completion is not navigation-map synchronization.** Checking only
  `map_get_iteration_id() > 0` produced intermittent failures, especially when
  replacing fixtures. `arena.gd` waits until a closest-point query identifies
  **this region's RID** as its owner. Preserve that readiness check.
- Baked walkable surfaces can sit above the physical floor due to voxelization.
  This caused agents to oscillate at the first path point despite valid paths.
  The flat lab derives each agent's `path_height_offset` from the synchronized
  navmesh; arrival/expected regions use XZ distance. Do not blindly generalize
  this fixed floor offset to stairs or multi-level gameplay.
- Lab actors use collision **layer 2**, static geometry uses **layer 1**; actor
  collision masks include both. Physics tests must deliberately choose masks and
  exclusions. These are lab conventions, not guaranteed production conventions.
- The actor projects the policy result onto the navmesh before moving/reporting
  it. Debug raw versus projected candidates if a destination changes unexpectedly.
  Selection must still establish clearance/reachability; projection can hide an
  invalid raw point.
- A single policy instance is shared by all enemies in one arena. Reset replaces
  that instance, making it a suitable owner for per-scenario caches/reservations.
- `arena.stepped` fires after actors move. Use it for post-physics observations;
  `SceneTree.physics_frame` fires before node physics processing.
- Test UI events with `Viewport.push_input(event, true)` when using viewport-local
  coordinates. The lab uses the mouse event's position for ray projection.
- JSON numbers round-trip as floats; compare geometric values approximately,
  rather than expecting exact equality of nested int/float arrays.
- Accelerated runs occasionally emitted a Jolt job-system exhaustion warning on
  this machine. The three cases passed repeatedly after the navigation readiness
  fix. Recheck without `--fixed-fps` if investigating timing; do not dismiss script
  errors or assertion failures as that warning.

## Suggested first implementation slice

1. Add a shared runtime selector and debug candidate/score visualization, keeping
   the baseline policy and fixtures unchanged.
2. Add small explicit cover fixtures: low partial cover, a tall obstacle with
   reachable edge shots, rotated cover, an unreachable candidate, player flanking,
   and competing enemies. Allow alternative acceptable regions for symmetric
   solutions; explain the tactical intent in each fixture description.
3. Exercise the selector in both headless and live lab modes. Add protection and
   firing-clearance checks alongside region assertions when those semantics exist.
   Do not generate expected destinations from the selector or simply bless output.
4. Integrate the same selector into production navigation/combat, then probe the
   actual enemy scene for sight-loss, shot clearance, stance, and reaction/death
   interactions. Lab movement alone cannot validate those.

This is a proposed sequence, not approval of a particular scoring formula,
search algorithm, crouch implementation, or squad planner.
