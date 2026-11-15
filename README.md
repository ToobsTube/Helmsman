# Helmsman

A flight script and autopilot for **Dual Universe** seats, cockpits and remote controllers. It flies the ship by hand the way DU's standard script does, and its autopilot takes you anywhere: across space, round planets, from one planet's surface to another's, and down onto the exact spot.

Helmsman works on its own. It's also the companion to **DU Starmap Navigator**: pick a destination there and Helmsman flies it.

## What it does

- **Space autopilot:** turns, burns, cruises and brakes to a stop. It routes round planets and moons by itself.
- **Surface to surface:** Alt+1 on the ground takes off, flies the trip and lands on the spot. Landings usually end within a few metres of the mark.
- **Trips on the same planet:** flies in the atmosphere at a safe cruise height, or (optionally) in a low orbit for long trips.
- **Paste to fly:** paste any `::pos{...}` into Lua chat and the ship flies there. Add `|hdg=N` and it parks facing that way.
- **Navigator link:** NAVIGATE in Navigator and the target appears here. With Navigator's AUTO FLY on, route stops chain automatically.
- **Landings onto unknown ground** (map picks): finds the ground on the way down. A telemeter pointing down makes them much faster.
- **Water:** lands onto water by hovering on it, sinks to the seabed on G, holds a depth under water and rises back to the surface under control.
- **Radar:** collision warning on the HUD, and the autopilot stops short of anything in its path.
- **AGG:** anti-grav controls, and autopilot trips that stay at the AGG height instead of landing.
- **Fuel:** every tank read without links, with time left and bars per fuel type.
- **Warp:** warp status on the HUD, and opt-in auto-warp to where the autopilot is going.
- **Also:** safe cargo mass, rockets for heavy climbs, a Maneuver mode for docking, a fighter-style attitude HUD, and an optional emergency control unit (ECU) script.

## Install

Download the files from the **Releases** page: `Helmsman_v1.0.txt`, `Helmsman_v1.0.conf` and (optional) `Helmsman_ECU.conf`.

### Option A: paste (recommended; use this for DRM ships)
1. Link the **core unit** to the seat, cockpit or remote controller. Any slot, any order: the script finds each element by what it is. Optionally also link:
   - the **databank shared with Navigator** (also keeps your settings across new pastes)
   - **one hover or vertical booster** (landings read the distance to the ground)
   - a **telemeter pointing straight down** (sees ~100 m: much faster landings onto unknown ground and water)
   - the **anti-grav generator**, **radar(s)**, the **warp drive**
   - any **manual switch** for cabin automation
2. Open `Helmsman_v1.0.txt`, copy everything, then right-click the seat → *Advanced* → *Paste Lua configuration from clipboard*.

### Option B: autoconfigure
1. Copy `Helmsman_v1.0.conf` to `...\Dual Universe\Game\data\lua\autoconf\custom\`.
2. Right-click the seat → *Advanced* → *Run custom autoconfigure* → **Helmsman v1.0**.
   - **Linked automatically:** core, anti-grav generator, vertical boosters, hovers, telemeter, warp drive.
   - **Link by hand afterwards** (only the ones you use): the databank shared with Navigator, radar(s), manual switch(es). Fuel tanks need no links.

Either way, sit down and check the Lua console:

`[HELM] Helmsman v1.0.0 (build …) | atlas=atlas (N bodies) | databank=Navigator HUD bank | antigrav=OK | ground sensors=1 | telemeter=pointing down | radars=1 | warp=OK`

Then type `help` in Lua chat for the commands.

**Tip:** if pasting says "Lua script has no parameters", stop any other programming board that's running on the ship (Navigator, for example), paste again, then start it back up.

The released files have their comments stripped to keep the paste small (about 180 KB). Your parameters and their descriptions are all still there.

### Emergency control unit (optional)
`Helmsman_ECU.conf` takes over when you leave the seat while flying. Copy it to `...\autoconf\custom\`, then right-click the ECU → *Advanced* → *Run custom autoconfigure* → **Helmsman ECU**. It links the core, a hover or vertical booster and a telemeter by itself. You can also link the databank you share with Helmsman by hand: the ECU then knows straight away that the telemeter points down.
- **Near a planet:** levels the ship, stops any drift, and hovers at `HoverHeight` over ground or water. From high up it falls no faster than `MaxFall` until the hovers see something. With a telemeter pointing down it can fall faster (up to `MaxFallTele`) and still slow down in time.
- **Under water:** holds that exact spot with the engines.
- **In space:** brakes to a stop.
- **Fuel:** every minute it prints how long the fuel will last. When the tanks feeding the running engines have less than `LandMinutes` left, it lands and switches off.
- When it takes over it prints what it found linked. It never touches the AGG.

## Controls

| Key | Action |
|---|---|
| Alt+1 | Engage / disengage the autopilot (on the ground: take off) |
| Alt+2 | Clear target |
| Alt+3 | Hide / show the HUD |
| Alt+4 | Switch Flight / Maneuver mode |
| Alt+5 | Park hold: stop, then hold position (rotation stays free) |
| Alt+6 | Fighter-style attitude HUD on/off |
| Ctrl+Alt | Brake lock on/off (plain Ctrl is still hold-to-brake) |
| G | Hover / land (gear, hovers and vertical boosters) |
| B | Rockets on/off |
| Alt+G | Anti-grav on/off |
| Brake, throttle, pitch/yaw, stop engines | Disengage the autopilot (you take over) |

While landed with the brake lock on, the movement keys are ignored, so a navigation script that uses the arrow keys can't lift the ship off the pad. G or Alt+1 takes off; Ctrl+Alt releases the lock.

Type `help` in Lua chat for every chat command. Common ones: `::pos{...}` (fly there), `ap` / `ap off`, `clear`, `target`, `speed N` (cruise cap, km/h), `thrust` (engine push in all six directions), `mass`, `fuel`, `radar`, `agg N`, `hdg N`, `hudtheme NAME`, `hud bottom N`, `settings` (what's saved on the databank).

## Flying with the autopilot

### Setting a target
- **Paste** a `::pos{...}` (or `Name ::pos{...}`) into Lua chat. In space the autopilot starts at once (`AutoEngagePaste`); on the ground or in the air it sets the target and waits for Alt+1. Only your own Alt+1 / `ap` / `go` ever starts a take-off.
- **Navigator:** NAVIGATE in Navigator and the target appears here.
- **Map picks** (a spot picked on DU's map) usually have altitude 0, so the ground height is unknown. The autopilot then stops its fast descent above the planet's highest ground and comes down carefully from there until it sees the ground.
- **Parking heading:** add `|hdg=N` after a `::pos{}` (pasted, or from Navigator). N is a compass heading in degrees, 0 = north (toward the planet's pole), 90 = east. A landing turns to face it while still high up and doesn't go below the end of the fast descent until it faces it. An AGG trip, or a landing without the descent, turns in place over the spot first. It gives up after 60 s and says so. Chat: `hdg` shows which way the nose faces; `hdg N`, `hdg here` or `hdg off` set the current target's heading.

### In space
The autopilot turns toward the target, burns, cruises and brakes to a full stop. Targets in space stop `StopDistance` short; spots on a planet or moon stop right over the spot. If a planet or moon is in the way, it adds corner points outside the body's atmosphere plus `PlanetClearance`, and drops them as soon as the straight line is clear.

### Take-off (Alt+1 on the ground or in the air)
1. **LIFT:** hovers / vertical boosters lift the ship to hover height, as G does. If they can't get it there, the take-off stops with a NOT ENOUGH LIFT popup and the ship keeps hovering.
2. **LINE UP:** brakes on, the ship turns level toward the destination.
3. **CLIMB:** main engines. The nose only comes up as forward speed builds, and comes back down if the speed drops, so the ship is never steep and slow. The climb angle comes from thrust-to-weight, up to 45°. Speed stays under 85% of the burn speed. If a heavy ship struggles and has rockets, the autopilot fires them and turns them off again near the burn speed or once it's climbing well. If it still can't climb, a trip in the atmosphere cruises at the height it reached, and a trip to space shows CAN'T REACH SPACE so you can take over.
4. Turns are flown like a plane: heading changes round the vertical only, banking into the turn at speed. A target well to the side or behind starts a banked **TURN** that keeps flying speed. If the ship can't come round, the autopilot lands where it is with a CAN'T TURN popup (a flat turn would stall a ship that isn't hovering).
5. Once out of the atmosphere, the space autopilot takes over.

### Landing on a surface spot
The autopilot flies to a point straight above the spot, outside the atmosphere and the highest terrain, and stops right on it. With **AutoLand** on (default) it then descends straight down:
- **Fast part:** gravity does the accelerating, and engines that face up push the fall to speed high up. The brakes keep the speed under 85% of the burn speed and plan the stop. The fast part ends `DescentHeight` (100 m) above the spot, or above the highest terrain for a map pick.
- **Holding over the spot all the way down:** the ship tilts its belly toward where it needs to go (a falling ship slides toward its low side) by pitch or roll, up to 20°, in air thick enough for it to work. It can also turn to face the spot and give the main engines small pushes.
- **Slow part:** with hovers or vertical boosters, it keeps coming down slowly, still holding over the spot, until the hovers see the ground. With a telemeter pointing down it comes down much faster, slowing as soon as the telemeter sees the ground.
- **Landing:** the normal landing sets you down and reports the touchdown speed and how far from the mark it landed.

Brake at any time stops it; Alt+1 above the spot carries on down. AutoLand off: it stops above and waits for G.

### Trips on the same planet
When the destination is on the planet you're on (or flying over) and that planet has an atmosphere, `PlanetTrips` decides:
- **`atmo` (default):** stays in the air, however far. It climbs as steeply as the ship can manage, flattening as it speeds up, and levels off into **CRUISE** at `AtmoCruiseHeight` (raised over the highest terrain and tallest allowed buildings). Short hops climb less (a 1 km hop goes about 300 m up). It starts slowing well before the spot, eases in, and ends almost stopped right over it, then descends and lands. If down-facing engines lose too much push in thin air to hold the height, it comes down earlier, or lets the ship sink gently rather than holding the brakes.
- **`orbit`:** climbs out and uses the space route, or the orbit hop below.
- **`auto`:** stays in the air up to `AtmoHopMax` km, goes via orbit beyond.

**Orbit hop** (`OrbitHop`, on by default): when it climbs out and the planet is in the way, it flies a low orbit round the planet at just under orbital speed, mostly coasting with the nose level, then stops over the spot and descends. Moons and airless bodies always use the normal route at full speed. Off: the normal corner route.

## Landing, hovering and water

- **G** lifts the ship to `HoverHeight` and lands it again. `GLandsDirect` makes G land in one press while flying. Landings come down as fast as the brakes and hovers can still stop within what they can see (`LandSpeed` 0 = automatic), and set down at `TouchdownSpeed`.
- **Telemeter:** hovers see only about 15 m down. A telemeter mounted pointing straight down sees about 100 m, including through water. Helmsman uses it once a reading shows it pointing down (for example while parked when you sit down), and remembers that on the databank.
- **Landing on water:** hovers see the water surface, but a ship can't settle on it. When a landing touches the water near sea level and keeps sinking, Helmsman switches to hover: the ship floats `HoverHeight` above the water with the brakes held. Press **G** to sink and land on the bottom. A spot saved under water skips the stop and sinks straight to it.
- **Under water:** the hovers are switched off (under water they'd push flat out for the surface). Both Flight and Maneuver mode hold the depth with the engines: Space/C go up and down, let go and it holds. With a telemeter, sinking is fast and slows near the bottom.
- **G under water** rises to the surface under control and stops at `HoverHeight` above the water with the brakes held (C cancels the rise). If the HUD shows HOVER while you're under water, the first G lands (sinks) and the second rises.

## Flight modes

- **Flight** (default): throttle drives the ship forward. Vertical and lateral thrusters only fire while you press their keys. A parked ship makes no thrust at all until you press G.
- **Maneuver:** for docking, parking and slow precise movement. Throttle, strafe and Space/C each ask for a *speed* in that direction, as a fraction of `ManeuverSpeed`, and thrusters facing every direction work together to hit it. With nothing pressed the ship holds still, and holds its height.

The script checks how much thrust the ship has in each of the six directions. That's printed at startup and with `thrust`. In Maneuver mode the HUD shows `F B L R U D`, with any missing direction in red.

## Optional features

- **Fuel (no links needed):** every fuel tank is read through the core. The HUD shows a row per fuel type (ATMO / SPACE / ROCKET) with % and a bar: green above 50%, amber from 20 to 50%, red below 20%. Set the tank owner's talents once with `fueltalents A S R O C` (atmo, space and rocket tank handling, fuel tank optimization, container optimization, each 0-5); they're saved to the databank and are also parameters. A `~` before the % means a tank holds more than those talents allow, so they're set too low. `fuel` lists every tank.
- **Radar (link by hand):** an atmo radar, a space radar, or both. DU's radar widget is shown for whichever works where you are.
- **Collision warning:** a contact on or near your path shows above the HUD: amber `CONTACT ON PATH`, red `COLLISION — BRAKE NOW` when the brakes alone can no longer stop you short of it. It never takes over a ship you're flying yourself.
- **Autopilot obstacle stop (`CollisionStop`):** when the autopilot is flying and a contact is on its path, it stops about 50 m before the warning zone and hands back to you. Fly round it, or press Alt+1 to carry on anyway. If the contact moves off the path, the autopilot continues by itself. It never steers round anything. Docked ships (an AGG elevator, for example) are ignored.
- **Manual switches (link by hand):** a switch linked to the seat turns on when you sit down and off when you get up, for cabin automation (doors, force fields, lights).
- **Anti-grav generator:** Alt+G or `agg on` / `agg off`. `agg 2500` sets the hover height (1,000 m or more), `agg here` sets it to your current altitude, `agg` prints the status. The SYSTEMS panel shows an AGG row: grey off, amber while the lift creeps to a new height, green holding, red when no pulsors are linked. The AGG holds the ship at the **lift point**, so set the height, wait for green, then fly up to it. Helmsman never turns the AGG off by itself; only Alt+G or `agg off` does.
- **AGG trips:** with the AGG on, sending the autopilot to a spot on the planet you're on makes it **stay in the air** at the AGG height over the spot and hold there, instead of landing. If the AGG height clears the planet's highest ground, it flies the whole trip at that height. Arriving from space or another planet with the AGG on, the descent stops at the AGG height over the spot. The chat says which it will do and why.
- **Warp drive:** a WARP line shows the drive's status, destination, distance and warp cells. Jump with DU's warp key as usual. If the autopilot was flying when the warp started, it carries on after the jump (brake during the warp to cancel that).
- **Auto-warp (opt-in, `AutoWarp`):** set the warp destination on the map (scripts can't pick it). When it's where the autopilot is going and the drive reads READY, the autopilot warps by itself, then carries on. The WARP row shows AUTO (green) or why not (amber). Live: `autowarp on/off`.
- **Safe mass:** while landed or stopped, the FLIGHT panel shows `MASS · SAFE`: mass now, the safe mass, and what limits it. Safe mass is half of what the atmo engines, space engines, hovers or brakes could hold against gravity here (2:1), and the lowest counts. Amber within 10%, red when over. `mass` lists all four.
- **Rockets:** B fires and stops them by hand, with a red ROCKETS tag on the HUD. In an autopilot climb that's struggling, the autopilot fires them itself. `rockets test` makes the next climb fire them for up to 15 s.

## Settings (Edit Lua Parameters)

The HUD look (theme, scale, position, opacity), Flight HUD / nav info / AutoLevel, LandSafety and the fuel talents are saved on the databank, so a new paste keeps them: a parameter left at its default uses the saved value. DU's parameter menu always shows the defaults, so type `settings` to see what's actually saved and in use.

| Parameter | Default | Meaning |
|---|---|---|
| CustomAtlas | atlas | Atlas file for your server (see below) |
| MaxCruiseSpeed | 0 | Autopilot speed cap in km/h (0 = ship max) |
| StopDistance | 1000 | Targets in space only: stop this many metres short. Spots on a planet or moon always stop right over the spot |
| PlanetClearance | 10000 | Margin kept outside atmospheres and terrain when routing |
| BrakeSafety | 0.8 | Fraction of brake force planned with (lower = brake earlier) |
| AlignRate | 0.5 | Max autopilot turn rate, rad/s (lower for big ships) |
| AutoEngagePaste | true | In space, pasting a ::pos{} starts the autopilot at once |
| StartMode | 1 | 1 = Flight, 2 = Maneuver when you sit down |
| ManeuverSpeed | 100 | Maneuver mode top speed, km/h |
| HoverHeight | 10 | Hover height (m) after pressing G |
| AutoLand | true | Surface targets: descend and land. Off = stop above and wait for G |
| PlanetTrips | atmo | Same-planet trips: `atmo` = in the air, `orbit` = via space, `auto` = air up to AtmoHopMax |
| AtmoHopMax | 100 | `auto` only: furthest trip (km) that stays in the air |
| AtmoCruiseHeight | 3000 | Cruise altitude (m above sea level) for trips in the air; raised over terrain and buildings |
| OrbitHop | true | Same planet, via space: low orbit instead of the corner route |
| DescentHeight | 100 | Metres above the spot where the fast descent ends (min 30) |
| GLandsDirect | false | On: G while flying lands in one press. Off: G hovers first, G again lands |
| LandSpeed | 0 | Fastest landing descent, km/h. 0 = automatic (as fast as the ship can still stop within what it sees, up to 500 km/h). The sit-down report says what the ship can stop from |
| TouchdownSpeed | 15 | Landing speed (km/h) for the last 2 m |
| CollisionWarn | true | Radar collision warning on the HUD |
| CollisionStop | true | Autopilot stops short of a radar contact on its path |
| AutoWarp | false | Opt-in auto-warp (see above). Live: `autowarp on/off` |
| HudTheme | cyan | cyan, amber, green, red, purple, white, or `#RRGGBB`. Saved: while this is left at `cyan`, the saved colour is used, so a bought ship may show its old owner's colour. `hudtheme NAME` changes it (`hudtheme cyan` for the default) |
| HudOpacity | 0.9 | Panel opacity 0.3-1. `hud opacity N`, saved |
| HudScale / HudShift / HudBottom | 1 / 0 / 7 | Size, sideways nudge (% of screen, positive = right), height from the bottom (% of screen). `hud scale N`, `hud shift N`, `hud bottom N`, saved |
| NavInfo | true | AUTOPILOT panel (target, ETA, brake distance). `navinfo on/off`, saved |
| FlightHud | true | Centre attitude HUD (pitch ladder, flight path marker, target marker). Alt+6, saved |
| FlightHudScale | 0.75 | Size of the centre HUD |
| HideDUWidget | true | Hide DU's own seat panel (the HUD shows the same) |
| HideBuildHelper | true | Hide DU's BUILD HELPER bar while seated |
| BurnProtect | true | Hand flying in atmosphere: engine push fades near the burn speed so you level off just under it. Steering and your throttle are never touched |
| AutoLevel | true | Auto-levelling while hovering/landing or in atmosphere. `autolevel on/off`, saved |
| AtmoTankHandling / SpaceTankHandling / RocketTankHandling | 0 | Fuel tank handling talents (0-5) of the tanks' owner |
| FuelTankOptimization / ContainerOptimization | 0 | Fuel mass talents (0-5) |
| LandSafety | 0.3 | Share of the spare stopping power a landing plans with (lower = gentler). `landsafety N`, saved |
| pitchSpeedFactor / yawSpeedFactor / rollSpeedFactor | 0.8 / 1 / 1.5 | Hand flying: how fast the ship turns with your pitch / yaw / roll keys (0.8 ≈ 46°/s, 1 ≈ 57°/s, 1.5 ≈ 86°/s) |

## Custom atlas (other servers)

Servers can have different planets. Helmsman uses the atlas to turn `::pos{}` coordinates into positions and to route round planets, so it needs the right atlas for your server.

1. Put the server's atlas file in `Game\data\lua\autoconf\custom\` (`Game\data\lua\` also works).
2. Right-click the seat → *Advanced* → *Edit Lua Parameters* → set **CustomAtlas** to the file name without `.lua`.
3. Restart the seat. The console line shows which atlas loaded and how many bodies it has. If the file isn't found, it warns and uses the game's default.

This is the same parameter and lookup as Navigator's `CustomAtlas`, so one atlas file serves both. Helmsman also guards against two kinds of atlas error seen in the wild: it works out each body's gravity from its surface gravity and radius (some custom atlases have wrong `GM` values), and it ignores a highest-ground figure of zero or below (the game's own atlas says −42 m for Alioth Moon 4).

## For ship builders (DRM)

Every setting is an export parameter, including the atlas, so owners can change them through *Edit Lua Parameters* on a DRM-protected seat. The paste install finds linked elements by class, so no link order is needed. Chat commands like `speed` and `stopdist` only change the current session.

## Navigator databank keys

| Key | Written by | Meaning |
|---|---|---|
| `nav_ap_dest` | Navigator | `NAME\|::pos{...}`, optionally `\|hdg=N` on the end. Read, then cleared, by Helmsman |
| `nav_print` | Navigator | `NAME\|::pos{...}` from PRINT COORDS. Helmsman prints it to Lua chat and clears it |
| `autofly` | Navigator | `1` = engage automatically on a new destination |
| `sf_target` | Helmsman | Current target, restored when you sit back down |

## How the autopilot flies

Every physics tick it works out a **desired velocity**: toward the target, at the lower of the cruise cap and the fastest speed it can still brake from (`√(2·brake·distance)`). The ship points along *desired − actual velocity* and thrusts once it's lined up. One rule covers accelerating, cancelling sideways drift and cruising. It measures the ship's real braking on each stop and plans later stops with it.

## Building from source

```
node build.js          # dist/Helmsman_v1.0.txt and .conf, comments stripped
node build.js --full   # the same with all comments, for reading
```

The source is `src/flight.lua`; the ECU is `ecu/Helmsman_ECU.conf`.

## Credits

Helmsman is its own code, but several of its ideas come from other DU scripts:

- **SagaHUD by Sagacious:** steering the ship over the destination through the whole descent, tilting the belly toward the target to slide onto it, plane-style banked turns, and starting to slow well before the spot. Sagacious released the SAGA source for others to build on.
- **ArchHUD (Archaegeo and contributors):** the 2:1 safe-mass rule, the rocket on/off governor for climbs (Dodgin's idea), turning seat-linked switches on while seated, starting to slow well before the spot, and the ECU's use of DU's hover hold over ground and water.
- **Novaquark:** DU's standard flight model and Navigator library, which manual flight is built on.
