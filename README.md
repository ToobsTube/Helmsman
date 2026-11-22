# Helmsman

A flight script and autopilot for **Dual Universe** seats, cockpits and remote controllers. It flies the ship by hand the way DU's standard script does, and its autopilot takes you anywhere: across space, round planets, from one planet's surface to another's, and down onto the exact spot.

Helmsman works on its own. It's also the companion to **DU Starmap Navigator**: pick a destination there and Helmsman flies it.

## What it does

- **Space autopilot:** turns, burns, cruises and brakes to a stop. It routes round planets and moons by itself.
- **Surface to surface:** Alt+1 on the ground takes off, flies the trip and lands on the spot. Landings usually end within a few metres of the mark.
- **Trips on the same planet:** flies in the atmosphere at a safe cruise height, or (optionally) in a low orbit for long trips. A ship that can't climb out to space flies the trip in the air instead.
- **Paste to fly:** paste any `::pos{...}` into Lua chat and the ship flies there. Add `|hdg=N` and it parks facing that way.
- **Navigator link:** NAVIGATE in Navigator and the target appears here. With Navigator's AUTO FLY on, route stops chain automatically.
- **Landings onto unknown ground** (map picks): finds the ground on the way down. A telemeter pointing down makes them much faster.
- **Water:** lands onto water by hovering on it, sinks to the seabed on G, holds a depth under water and rises back to the surface under control.
- **Radar:** collision warning on the HUD, and the autopilot stops short of anything in its path.
- **AGG:** anti-grav controls, and autopilot trips that stay at the AGG height instead of landing.
- **Fuel:** every tank read without links, with time left and bars per fuel type.
- **Warp:** warp status on the HUD, and opt-in auto-warp to where the autopilot is going.
- **Altitude hold:** Alt+7 holds your height while you fly by hand (steering and throttle stay yours).
- **Also:** safe cargo mass, rockets for heavy climbs, a Maneuver mode for docking, a fighter-style attitude HUD, and an optional emergency control unit (ECU) script.

## Install

Download the files from the **Releases** page: `Helmsman_v1.0.3.txt`, `Helmsman_v1.0.3.conf` and (optional) `Helmsman_ECU.conf`.

### Option A: paste
1. Link the **core unit** to the seat, cockpit or remote controller. Any slot, any order: the script finds each element by what it is. Optionally also link:
   - the **databank shared with Navigator** (also keeps your settings across new pastes)
   - **one hover or vertical booster** (landings read the distance to the ground)
   - a **telemeter pointing straight down** (sees ~100 m: much faster landings onto unknown ground and water)
   - the **anti-grav generator**, **radar(s)**, the **warp drive**
   - any **manual switch** for cabin automation
2. Open `Helmsman_v1.0.3.txt`, copy everything, then right-click the seat → *Advanced* → *Paste Lua configuration from clipboard*.

### Option B: autoconfigure
1. Copy `Helmsman_v1.0.3.conf` to `...\Dual Universe\Game\data\lua\autoconf\custom\`.
2. Right-click the seat → *Advanced* → *Run custom autoconfigure* → **Helmsman v1.0.3**.
   - **Linked automatically:** core, anti-grav generator, vertical boosters, hovers, telemeter, warp drive.
   - **Link by hand afterwards** (only the ones you use): the databank shared with Navigator, radar(s), manual switch(es). Fuel tanks need no links.

Either way, sit down and check the Lua console:

`[HELM] Helmsman v1.0.3 (build …) | atlas=atlas (N bodies) | databank=Navigator HUD bank | antigrav=OK | ground sensors=1 | telemeter=pointing down | radars=1 | warp=OK`

Then type `help` in Lua chat for the commands.

**Tip:** if pasting says "Lua script has no parameters", stop any other programming board that's running on the ship (Navigator, for example), paste again, then start it back up.

The released files have their comments stripped to keep the paste small (about 195 KB). Your parameters and their descriptions are all still there.

### Emergency control unit (optional)
`Helmsman_ECU.conf` takes over when you leave the seat while flying: it hovers over ground or water, holds its spot under water, stops in space, and lands before the fuel runs out. Copy it to `...\autoconf\custom\`, then right-click the ECU → *Advanced* → *Run custom autoconfigure* → **Helmsman ECU**. Details in the [guide](GUIDE.md#emergency-control-unit-ecu).

## Controls

| Key | Action |
|---|---|
| Alt+1 | Engage / disengage the autopilot (on the ground: take off) |
| Alt+2 | Clear target |
| Alt+3 | Hide / show the HUD |
| Alt+4 | Switch Flight / Maneuver mode |
| Alt+5 | Park hold: stop, then hold position (rotation stays free) |
| Alt+6 | Fighter-style attitude HUD on/off |
| Alt+7 | Altitude hold on/off while hand flying in the atmosphere (back to the last height held) |
| Ctrl+Alt | Brake lock on/off (plain Ctrl is still hold-to-brake) |
| G | Hover / land (gear, hovers and vertical boosters) |
| B | Rockets on/off |
| Alt+G | Anti-grav on/off |
| Brake, throttle, pitch/yaw, stop engines | Disengage the autopilot (you take over) |

While landed with the brake lock on, the movement keys are ignored, so a navigation script that uses the arrow keys can't lift the ship off the pad. G or Alt+1 takes off; Ctrl+Alt releases the lock.

Type `help` in Lua chat for every chat command. Common ones: `::pos{...}` (fly there), `ap` / `ap off`, `clear`, `target`, `speed N` (cruise cap, km/h), `thrust` (engine push in all six directions), `mass`, `fuel`, `radar`, `agg N`, `alt N` (hold N m above sea level), `hdg N`, `hudtheme NAME`, `hud bottom N`, `settings` (what's saved on the databank).

## Roadmap

**Done since v1.0.3** (in testing):
- Air arrival round the far side of a planet: in along the planet's edge at orbital speed, round toward the spot, then glide into the air and fly the rest in the air
- PvP / safe zone row on the HUD, with a warning when you cross the line
- `speed N` is kept after a relog
- Take-off starts lining up 10 m off the ground

**Next:**
- A smoother stop in space over the spot (no turning round at the end)
- A lower stop point over moons and planets without air

**Later:**
- Testing on M-core ships
- Retest ships with engines in every direction

## Full guide

How the autopilot flies each kind of trip, landing and water, every optional feature, all the settings, custom atlases and notes for ship builders: see **[GUIDE.md](GUIDE.md)**.

## Credits

Helmsman is its own code, but several of its ideas come from other DU scripts:

- **SagaHUD by Sagacious:** steering the ship over the destination through the whole descent, tilting the belly toward the target to slide onto it, plane-style banked turns, and starting to slow well before the spot. Sagacious released the SAGA source for others to build on.
- **ArchHUD (Archaegeo and contributors):** the 2:1 safe-mass rule, the rocket on/off governor for climbs (Dodgin's idea), turning seat-linked switches on while seated, starting to slow well before the spot, and the ECU's use of DU's hover hold over ground and water.
- **Novaquark:** DU's standard flight model and Navigator library, which manual flight is built on.
