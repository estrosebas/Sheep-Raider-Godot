# Sam's flute encounter and defusable mines

Sources: `sdw-decomp/src/objects/sam.cpp` (`SAM_STT_CIN01`,
`EnterFollowTrajectoryState`) and `src/objects/mine.cpp`
(`DefusableMine::PostLoadInit/Update/DrawPanel/DrawBeatLights`).

Level06 obtains native flute78 from mailbox54; it is not granted on entry.
Mailbox delivery skips exact item identities already in inventory, while allowing
legitimate multiple objects of the same class (such as lettuces). In Sam's initial guard state,
the flute requests CIN2 instead of normal hypnosis. That original12.864s movie
contains Ralph's scripted hit, Sam's earplug prop, cameras, sounds and the three
mines65/69/70. It consumes the flute and ends in Sam's looping41-point patrol
(200 native units/s =2m/s). Staged mines appear at their final CIN positions;
the other eight native mines already operate elsewhere on the map.

`OriginalDefusableMine` is shared, configured by optional `data/mines.json`.
`OriginalSamFluteEncounter` reads an optional encounter descriptor, including
the original patrol and deployment coordinates. No level number is hardcoded.
Checkpoint saves retain encounter phase and each mine's position/safe state;
normal respawn retains Sam's changed behavior and confiscated flute.

## Original codes and controls

Each symbol is `(code >> (2 * beat)) & 3`, read least-significant pair first.
The WAR's length determines whether to read2,3 or4 beats. The source controller
symbols become directions as follows:

| Native index | Native button | Direction | PC |
| --- | --- | --- | --- |
|0|Triangle|Up|W / up arrow|
|1|Circle|Right|D / right arrow|
|2|Square|Left|A / left arrow|
|3|Cross|Down|S / down arrow|

Mobile's existing menu joystick sends the same arrow-key press/release edges.
Return it to neutral between repeated directions. Holding a direction does not
repeat a beat. First observe the pattern, then repeat it with the timing lights.
The panel and beat-light textures come from the native DAV; arrows are adapted.

## Timing and hazards

- Global3s cycle, offset by native phase property. First1.5s dormant; active
  half expands an XZ detection wave to2m (vertical tolerance half the radius).
- Interact within1m, while grounded and the armed mine is dormant.
- Playback symbol starts at+1s, next beat at+1.5s. The last beat waits until
  +3.5s before input starts. Native cue132 loops during that final pause.
- Input target+1s, tolerance±0.25s, checked at+1.5s. Wrong, duplicate, early,
  late or missing input explodes. Beat lights advance in thirds of a second.
- Active detection fuse is0x2aa/4096s. BOOM uses WAR export3/AEXPLOS1, including
  sound99 at time0. Blast affects nearby actors within3m.
- After explosion:20s hidden,5s rearming, then arm in a dormant phase.
- A safely disarmed mine can be picked up, equipped with native LINK and placed
  using the shared original placement animation/probe; placement rearms after5s.

Rebuild: run `tools/extract_mine_mechanics.py DECOMP LEVEL_FOLDER`, import Godot
assets, then `tools/build_mine_assets.gd -- lvl_06`.

Validation: `tools/test_level06_mines.gd` covers original bit codes, native movie
dispatch, consumption/deployment, actual patrol movement, keyboard and mobile
input, successful and failed rhythms, hazard lifecycle and checkpoint restore.
`tools/test_level06_foundation.gd` and `tools/test_level04_flute_and_bull.gd`
cover integration and existing flute behavior.
