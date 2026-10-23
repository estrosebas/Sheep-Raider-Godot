# Bull runoff with a tether

Implemented in `scripts/actors/original_bull.gd` from native
`src/objects/bull.cpp::Update/SetState/Reset` (`BULL_ST_ESCAPE`).

The native `noReturnBox` property at 0x0c is already exported as
`wildlife.json -> bulls[].no_return_boxes`. Runoff is permitted only when
Ralph is inside it and actively attached to a one-ended elastic. The shared
elastic controller's `protects_from_void` identifies this attachment; owning
an elastic in the inventory or tying it between two trees does not qualify.

When Ralph leaves the movement boxes, the bull keeps charging while this
condition holds. It enters ESCAPE only when its own next step leaves the
movement boxes. Without the condition it returns home as before.

Level05 uses resource 584, Godot bounds X 32.08..42.89, Y -22.08..7.91,
Z -37.17..-22.17, beyond the rim by the solitary elastic tree 71. This is
not an unrestricted ability to lure the bull off any cliff.

ESCAPE plays the native `fall` clip and looping SND_SCOFALL (202). Horizontal
velocity is divided by four and vertical speed becomes 10 m/s downward,
matching the native 250 cm/s charge component multiplied by four. Movement
uses direct translation without collision until leaving the no-return box,
then hides and disables the bull's collisions and audio. Native Reset skips
ESCAPE, so ordinary Ralph respawn does not bring the defeated bull back;
reloading the level creates it again.

Validation: `tools/test_bull_runoff.gd` covers the actual Level05 rim,
attachment and region conditions, original animation/sound/speeds, removal,
and reset behavior. `tools/test_level04_flute_and_bull.gd` exercises ordinary
wake, chase, attack, and stun behavior without runoff.
