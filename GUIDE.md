# Helmsman guide

The full manual. For what Helmsman does, how to install it and the controls, see the [README](README.md).

## Flying with the autopilot

### Setting a target
- **Paste** a `::pos{...}` (or `Name ::pos{...}`) into Lua chat. In space the autopilot starts at once (`AutoEngagePaste`); on the ground or in the air it sets the target and waits for Alt+1. Only your own Alt+1 / `ap` / `go` ever starts a take-off.
- **Navigator:** NAVIGATE in Navigator and the target appears here.
- **Map picks** (a spot picked on DU's map) usually have altitude 0, so the ground height is unknown. The autopilot then stops its fast descent above the planet's highest ground and comes down carefully from there until it sees the ground.
- **Parking heading:** add `|hdg=N` after a `::pos{}` (pasted, or from Navigator). N is a compass heading in degrees, 0 = north (toward the planet's pole), 90 = east. A landing turns to face it while still high up and doesn't go below the end of the fast descent until it faces it. An AGG trip, or a landing without the descent, turns in place over the spot first. It gives up after 60 s and says so. Chat: `hdg` shows which way the nose faces; `hdg N`, `hdg here` or `hdg off` set the current target's heading.

### In space
The autopilot turns toward the target, burns, cruises and brakes to a full stop. Targets in space stop `StopDistance` short; spots on a planet or moon stop right over the spot. If a planet or moon is in the way, it adds corner points outside the body's atmosphere plus `PlanetClearance`, and drops them as soon as the straight line is clear.

Coming in to a planet, the braking plan counts all the speed gravity will add between the ship and the stop point, so ships with weak brakes start slowing early enough. Climbing up to the stop point, it counts gravity's help instead, so it doesn't stop short.

### Take-off (Alt+1 on the ground or in the air)
1. **LIFT:** hovers / vertical boosters lift the ship to hover height, as G does, with the brakes held. If they can't get it there, the take-off stops with a NOT ENOUGH LIFT popup and the ship keeps hovering. A heavy ship whose hovers reach at least 60% of the hover height (and 4 m) carries on, with a note.
2. **LINE UP:** brakes on, the ship turns level toward the destination. A take-off that starts already hovering also holds the brakes until it faces the right way. With a radar linked, it then checks straight ahead: a construct within about 250 m in front, at about your height, holds the take-off here with a CONSTRUCT AHEAD popup. Fly clear by hand, or press Alt+1 to go anyway.
3. **CLIMB:** main engines. It starts with about 3 s of full throttle against the brakes, so the engines spool up before it sets off. The nose only comes up as forward speed builds, so the ship is never steep and slow. The climb angle comes from the push the engines really give, measured as it climbs (DU's own figure is for thick air), up to `MaxClimbAngle`. **Speed first:** if the ship keeps losing speed in the air, the nose comes down until the speed builds again. At the speed cap with the brakes taking the spare push, the nose goes up instead, so that push goes into height. Speed stays under 85% of the burn speed until the last 2% of air. If a heavy ship struggles and has rockets, the autopilot fires them and turns them off again near the burn speed or once it's climbing well.
4. **Can't climb any higher:** a trip in the atmosphere cruises a little below the height it reached. A trip heading for space to a spot on the **same planet** shows STAYING IN THE AIR and flies the rest as a trip in the air (at `AtmoCruiseHeight`, or lower if that's too high for the ship). A trip to another planet shows CAN'T REACH SPACE so you can take over.
5. Turns are flown like a plane: heading changes round the vertical only, banking into the turn at speed. A target well to the side or behind starts a banked **TURN** that keeps flying speed. If the ship can't come round, the autopilot lands where it is with a CAN'T TURN popup (a flat turn would stall a ship that isn't hovering).
6. Once out of the atmosphere, the space autopilot takes over. If it's already above the air near the spot, it stays at about that height over the spot instead of climbing to the usual stop point outside the atmosphere.

### Landing on a surface spot
The autopilot flies to a point straight above the spot, outside the atmosphere and the highest terrain, and stops right on it. With **AutoLand** on (default) it then descends straight down:
- **Fast part:** gravity does the accelerating, and engines that face up push the fall to speed high up. The brakes keep the speed under 85% of the burn speed and plan the stop. The fast part ends `DescentHeight` (100 m) above the spot, or above the highest terrain for a map pick.
- **Holding over the spot all the way down:** the ship tilts its belly toward where it needs to go (a falling ship slides toward its low side) by pitch or roll, up to 20°, in air thick enough for it to work. It can also turn to face the spot and give the main engines small pushes.
- **Slow part:** with hovers or vertical boosters, it keeps coming down slowly, still holding over the spot, until the hovers see the ground. With a telemeter pointing down it comes down much faster, slowing as soon as the telemeter sees the ground.
- **Landing:** the normal landing sets you down and reports the touchdown speed and how far from the mark it landed.

Brake at any time stops it; Alt+1 above the spot carries on down. AutoLand off: it stops above and waits for G.

**Trip done:** a landing within 300 m of the spot, or a stop at a target in space, clears the target ("Trip done — target cleared"), so sitting down again doesn't bring back a trip you've finished. A saved target you're already at when you sit down is dropped too, and so is a Navigator destination you're already at while landed.

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
- **Under water:** DU's own hover hold is switched off (under water it would push flat out for the surface). Both Flight and Maneuver mode hold the depth with whatever pushes up, engines, hovers or vertical boosters, asking each for just what's needed: Space/C go up and down, let go and it holds. With a telemeter, sinking is fast and slows near the bottom.
- **G under water** rises to the surface under control and stops at `HoverHeight` above the water with the brakes held (C cancels the rise). If the HUD shows HOVER while you're under water, the first G lands (sinks) and the second rises.
- **Alt+1 under water** (take-off to a target): rises to the surface the same way first, then takes off from there. Brake during the rise cancels the take-off.

## Flight modes

- **Flight** (default): throttle drives the ship forward. Vertical and lateral thrusters only fire while you press their keys. A parked ship makes no thrust at all until you press G.
- **Maneuver:** for docking, parking and slow precise movement. Throttle, strafe and Space/C each ask for a *speed* in that direction, as a fraction of `ManeuverSpeed`, and thrusters facing every direction work together to hit it. With nothing pressed the ship holds still, and holds its height.

**Altitude hold** (Flight mode, hand flying in the atmosphere): **Alt+7** holds your height with the nose, while steering, roll and throttle stay yours. Pressing pitch only pauses it: let go and it goes back to the held height, so you can pull through banked turns. The normal burn protection still applies. Alt+7 after turning it off goes back to the last height you held (this time in the seat; nothing is saved). Chat: `alt N` holds N m above sea level (and changes it mid-flight), `alt here` holds the height you're at, `alt` / `alt off` toggle. The FLIGHT panel shows **ALT HOLD N m** while it's on. It turns off when you press Alt+7, engage the autopilot, switch to Maneuver mode, leave the atmosphere or land with G.

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

## Emergency control unit (ECU)
`Helmsman_ECU.conf` takes over when you leave the seat while flying. Copy it to `...\autoconf\custom\`, then right-click the ECU → *Advanced* → *Run custom autoconfigure* → **Helmsman ECU**. It links the core, a hover or vertical booster and a telemeter by itself. You can also link the databank you share with Helmsman by hand: the ECU then knows straight away that the telemeter points down.
- **Near a planet:** levels the ship, stops any drift, and hovers at `HoverHeight` over ground or water. From high up it falls no faster than `MaxFall` until the hovers see something. With a telemeter pointing down it can fall faster (up to `MaxFallTele`) and still slow down in time.
- **Under water:** holds that exact spot with the engines, hovers and boosters.
- **In space:** brakes to a stop.
- **Fuel:** every minute it prints how long the fuel will last. When the tanks feeding the running engines have less than `LandMinutes` left, it lands and switches off.
- When it takes over it prints what it found linked. It never touches the AGG.

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
| MaxClimbAngle | 45 | Steepest take-off climb, degrees (10-60). Weaker ships pick a gentler angle themselves |
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
| `sf_target` | Helmsman | Current target, restored when you sit back down; `none` once a trip is done or the target is cleared |

## How the autopilot flies

Every physics tick it works out a **desired velocity**: toward the target, at the lower of the cruise cap and the fastest speed it can still brake from (`√(2·brake·distance)`). The ship points along *desired − actual velocity* and thrusts once it's lined up. One rule covers accelerating, cancelling sideways drift and cruising. It measures the ship's real braking on each stop and plans later stops with it.

## Building from source

```
node build.js          # dist/Helmsman_v1.0.3.txt and .conf, comments stripped
node build.js --full   # the same with all comments, for reading
```

The source is `src/flight.lua`; the ECU is `ecu/Helmsman_ECU.conf`.

