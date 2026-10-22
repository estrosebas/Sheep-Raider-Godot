# Level05: spring launch toward the clock

## Original rules

`sdw-decomp/src/objects/elastic.cpp`, `ApplyTension`, `SetupLaunch`, and
`MSG_MODIFY_MOVE / ELASTIC_ST_STRUNG` define a shared controller. The level
provides the dimensions: item86 has LONGUEUR_MAX1000, DISTANCE_PROJECTION3200,
HAUTEUR_PROJECTION1200, VITESSE_PROJECTION1000. In this port those are10m,
32m,12m and10m/s. Launch distance and height are multiplied by tension.
The horizontal direction points opposite the stretch vector, not toward the
camera. Turbo uses repeated taps (`Wolf::RunTapCheck`), not a held button.

Native automatic release counts1000ms above tension0xe00/4096 (87.5%).
It can also launch immediately when the rider becomes airborne at partial
tension. Thus reaching maximum extension does not immediately release a
grounded rider: there is still time to run/adjust the shot.

## Port adaptation

A real-terrain test reproduced the reported short shot: loss of floor contact
at16.4% tension produced a5.248m trajectory with1.968m peak height. The first
test then verified the upper bank only. That was insufficient: landing on that
bank does not prove access to the clock's entrance.

Level05 now opts into the existing full-charge safeguard used in Level03:
`full_charge_threshold=0.98`, `minimum_launch_charge=1.0`, and
`automatic_launch_hold=1.0`, in `data/port_balance.json`. Near-full tension
snaps to100% to account for centimetre quantization. Partial airborne contact
cannot release a weak shot, and the grounded countdown starts at full charge.
This charge gate is a port adaptation; it is not claimed to be a native rule.
The one-anchor yo-yo, maximum length, speed and peak height remain unchanged.

### Entrance correction

The access window is above and to the left of the clock when viewed from the
starting trees. Its lip is at approximately(1.7,7.76,-21.15)m. Aiming directly
at clock61 leads to a wall/upper bank, not the window. Even aiming at the
window, the32m port arc contacts the wall around(2.03,2.18,-20.35), well below
the lip. A real CharacterBody sweep compared distances32/36/40m and heights
4/8/12m against the imported collision, with no collision disabled.

`launch_profiles` now gives Ralph a40m projection only between trees62/67.
It preserves the12m peak and10m/s projection speed. The shot lands at about
(1.67,7.76,-21.17), can advance into the window, descend to the actual chamber
floor atY=-3.99, and walk to interaction range of the clock. This is an explicit
port balance adjustment for this entrance, not a value extracted from the
original item record. Other tree combinations and slingshot cargo still use
the native32m projection. There is no homing or automatic angle correction.

## Verification

`tools/test_elastic_level05_clock.gd` checks the partial airborne regression,
native defaults, full charge, one-second grounded aiming window, the actual
entry lip, descent to the chamber and `clock.can_interact(actor)`. It also checks
that other anchors and cargo retain the native range. The test isolates save
files and progress in memory and never changes the user's saved progress.

`tools/inspect_level05_clock_access.gd` reproduces the collision sweep and
renders `validation/level05_elastic_clock_entry.png` with the access window
marked. It is a diagnostic tool, not an in-game HUD or shortcut.

Verified: Level05 entrance/descent/clock interaction range,0failures;
Level03 full-charge catapult, sheep slingshot and native gap regression,
0failures. Logs: `validation/elastic_level05_clock.log` and
`validation/elastic_level03_balance_clock_regression.log`.
