# Helmsman

A Dual Universe seat flight script with a space autopilot. It is the companion to **DU Starmap Navigator**.

- Normal manual flight (DU's standard flight model: throttle, cruise control, hovers, boosters, gear, anti-grav).
- **Space autopilot**: align, burn, cruise, and brake to a full stop `StopDistance` short of the target. Routes around planets automatically.
- **Surface to surface**: Alt+1 on the ground takes off and climbs out of the atmosphere; a surface destination ends with a straight descent and landing on the spot.
- **Radar**: collision warning on the HUD, and the AP stops short of anything in its path.
- **Paste to fly**: paste any `::pos{...}` (or `Name ::pos{...}`) into Lua chat and the ship flies there.
- **Navigator link**: NAVIGATE in Navigator and the target appears here. With Navigator's AUTO FLY on, the AP engages by itself and route stops chain.
- AR overlay HUD showing target, distance, ETA, speed, braking distance, and AP phase.

> Surface targets: the AP flies to a hold point in space straight above the spot (outside the atmosphere *and* above the highest terrain, which matters for Thades) and stops right on it, not `StopDistance` short. With **AutoLand** on (default) it then **descends straight down the down line**, steering back over the spot all the way down: it tilts its belly toward where it needs to go, by pitch or roll, up to 20° (a falling ship slides toward its low side; the idea is from SagaHUD by Sagacious), and can also turn to face the spot and give the main engines small pushes: gravity does the accelerating, the brakes keep the speed under 85% of the ship's atmospheric burn speed and stop the fast part `DescentHeight` (100 m) above the spot (or above the atlas's highest terrain when the location's altitude is 0, as map picks often are). Below that, if the ship has hovers or vertical boosters, it keeps coming down slowly (when the spot's altitude is unknown, no faster than the normal landing would), still holding over the spot (turning to face it if needed), until the hovers see the ground; then the normal landing sets you down and reports how far from the mark it landed. Brake at any time stops it; Alt+1 above the spot carries on down. AutoLand off: it stops above and waits for G. Picking a body's centre on the map gives the side facing you (no auto-descent: there is no real spot).

## Take-off (Alt+1 on the ground or in atmosphere)

Set a target, then press **Alt+1** (or type `ap` / `go`) while landed or flying in atmosphere:

1. **LIFT**: hovers / vertical boosters lift the ship to hover height, as G does. If they can't get it there (it stops rising below it, or 12 s pass), the take-off stops with a NOT ENOUGH LIFT popup and the ship keeps hovering where it is: a ship that can't reach its hover height can't be trusted to clear rough ground.
2. **LINE UP**: brakes on, the ship turns level toward the destination. The radar collision warning keeps watching during the climb (brake to stop if anything is in the way).
3. **CLIMB**: main engines only. The nose comes up **only as forward speed builds** (level below 29 km/h, full climb angle from 119 km/h) and comes back down if the speed drops, so the ship is never steep and slow. The full angle comes from thrust-to-weight (shallower for heavy ships), up to 45°; if the ship isn't actually climbing it raises the angle step by step to that limit, but only while that doesn't cost forward speed (in thin air a steeper nose just bleeds speed and lift). If it still can't climb, an atmosphere trip cruises at the height it reached ("Can't climb higher — cruising at X m"); a trip to space shows a CAN'T REACH SPACE popup so you can take over. Speed stays under 85% of the burn speed. Turns are flown like a plane (SAGA-style): heading changes round the vertical only, and the bank is twice the angle between the ship's track and the target, up to 45° (faded in from ~140 to ~290 km/h, less if the ship is sinking). A new target well to the side or behind (more than 30° off, over 1 km away) starts a **TURN**: the ship keeps flying speed (brakes only down to what keeps the turn circle inside the distance, never below ~200 km/h), banks fully to one side and lets the nose lead its track by 40° so wings and engines carry it round, holding height with the cruise's own control. If it stops coming round (the target angle doesn't close by 15° within 20 s, or 30 s at the start while it slows to turn speed), or drifts further away than 3 km or half the distance it started the turn at, whichever is more, the AP turns off and the ship lands where it is, with a CAN'T TURN — LANDING popup: a flat turn on the spot would stall a ship that isn't hovering. Alt+1 once down carries on to the target.
4. Once out of the atmosphere (1 km above it), the normal space AP takes over: route around planets, cruise, stop. A surface destination then descends and lands as above.

Only your own Alt+1 / `ap` / `go` starts a take-off. Navigator's Auto Fly or a pasted `::pos` while parked just sets the target and says "Alt+1 to take off". Brake stops the take-off at any moment.

### Atmosphere trips (same planet, default)

When the destination is a surface spot on the **same planet** you're on or flying over, and that planet has an atmosphere, the ship stays in the air by default (`PlanetTrips = "atmo"`). It doesn't go to space, however far the spot is:

1. Take-off as above (LIFT, LINE UP, CLIMB).
2. The climb runs at full throttle, as steep as the ship can manage (up to 45°), flattening as it speeds up so it can level off in time, and rounds off smoothly into **CRUISE** at `AtmoCruiseHeight` (3,000 m by default; raised over the highest terrain and tallest allowed buildings, kept under the atmosphere top), heading for the spot, under the burn speed. Short hops climb less: about 30% of the distance (a 1 km hop goes about 300 m up).
3. **Gradual approach**: like SAGA and Arch, it starts slowing well before the spot (about 30% of the brakes, at most 0.8 g), still holding height and heading, and eases in over the last stretch, so it ends almost stopped right over the spot. **SLOWING** (full brakes) is only a backup if it's well over that curve. Down-facing engines (not hovers) hold the height while it's slow, but atmo engines lose push as the air thins, faster than the density itself (measured: about push × density²; DU only reports the sea-level figure). If they can't hold the ship at the cruise height, it comes down before slowing, while still fast, to where they can (never below 350 m over the descent start). If they still turn out too weak, it lets the ship sink rather than holding the brakes on. The `thrust` command shows the up engines' push here and the air density they need.
4. The straight-down descent and landing, as for any surface spot. A short hop that ends lower than where the fast descent would start goes straight to the descent's slow final stretch (belly tilt and position hold over the mark) until the hovers see the ground, the same as long trips.

`PlanetTrips = "orbit"` climbs out instead and uses the space route or orbit hop below. `"auto"` stays in the air up to `AtmoHopMax` km and goes via orbit beyond it.

### Orbit hop (same planet, far side)

When the destination is a surface spot on the **same planet**, the planet is in the way, and that planet **has an atmosphere**, the AP flies a low orbit round it (`ORBIT` phase) instead of the corner route. It stays near the height it starts at (at least 2 km above the atmosphere, at most `PlanetClearance` above it; the hold point above the spot moves to that height too) at just under orbital speed (about 3,700 km/h on Alioth), so it mostly coasts with the nose level along the curve; height is kept by small speed changes, never by pointing at the planet. Near the far side it hands over to the normal stop and auto-descent. This also works when you engage from low orbit near that planet. Moons and airless bodies always use the normal route at full speed: there's no burn speed there, so nothing is limited. `OrbitHop = false` turns it off.

## Build

```
node build.js
```

This produces both install formats from the same source:

- `dist/Helmsman_v0.1.txt`: paste-able Lua configuration
- `dist/Helmsman_v0.1.conf`: custom autoconfigure file

## Install

### Option A: paste (recommended, and the one to use for DRM ships)
1. Link the **core unit** to the seat or remote controller. Optionally also link: the **databank shared with Navigator**, the **anti-grav generator**, **one hover or vertical booster** (lets landings read the distance to the ground), **radar(s)**, the **warp drive**, and any **manual switch** for cabin automation. Any slot, any order works, because the script identifies each element by class at startup.
2. Open `Helmsman_v0.1.txt`, copy everything, then right-click the seat → *Advanced* → *Paste Lua configuration from clipboard*.

### Option B: autoconfigure
1. Copy `Helmsman_v0.1.conf` to `...\Dual Universe\Game\data\lua\autoconf\custom\`
2. Right-click the seat → *Advanced* → *Run custom autoconfigure* → **Helmsman v0.1**.

   **Linked automatically:** core, anti-grav generator, vertical boosters, hovers, warp drive.

   **Link by hand afterwards** (only the ones you use):
   - the **databank shared with Navigator**
   - **radar(s)**, atmo and/or space (collision warning, AP obstacle stop)
   - **manual switch(es)** for cabin automation (on while seated, off when you get up)

   Fuel tanks need no links.

Either way, sit down and check the Lua console:
`[HELM] Helmsman v0.1.0 | atlas=atlas (N bodies) | databank=Navigator HUD bank | antigrav=OK | ground sensors=1 | radars=1 | switches=1 | warp=OK`

(`switches=` only appears when a switch is linked.)

## Optional links: fuel, radar, switches, AGG, warp

- **Fuel (no links needed):** every fuel tank on the construct is read through the core. The HUD shows a row per fuel type (ATMO / SPACE / ROCKET) with litres left, %, and a bar: green above 50%, amber from 20 to 50%, red below 20%. Litres come from each tank's weight; capacity comes from its size and tier, using DU's standard values. Set the tank owner's fuel talents once with `fueltalents A S R O C` (atmo, space and rocket tank handling, fuel tank optimization, container optimization, each 0-5; the old `fueltalents H O C` sets all three handlings to H). The values are saved to the databank and are also parameters. A `~` before the % means a tank holds more than those talents allow, so they're set too low. `fuel` lists every tank, to compare with DU's own refuel-tool readout.
- **Radar (link manually):** link an atmo radar, a space radar, or both, in any slot. DU's own radar widget is shown for whichever one works where you are, switching automatically when you enter or leave atmosphere. The HUD shows the contact count.
- **Collision warning (needs a radar):** a contact on or near your path shows as a strip above the HUD: amber `CONTACT ON PATH` (name, size, distance, seconds to it, how far off you would pass), red `COLLISION — BRAKE NOW` when the brakes alone can no longer stop you short of it. It never takes over a ship you are flying yourself. Contacts the autopilot will stop short of anyway (such as the station you are flying to) are ignored.
- **Autopilot obstacle stop (CollisionStop, on by default):** when the AP is flying and a contact is on its path, it plans a stop about 50 m before the warning zone (phase OBSTACLE, red), holds the brakes and hands back to you with the name and distance. Fly round it, or press Alt+1 to carry on anyway (that contact is then ignored for the trip). If the contact moves off the path while the AP is still well short of it, the AP continues by itself. It never steers round anything. When DU only gives a distance, the contact is assumed to stand still and the result is marked `(est)`. `radar` in Lua chat lists the contacts. Turn off with the CollisionWarn parameter.
- **Manual switches (link manually):** any manual switch linked to the seat or remote turns **on when you sit down and off when you get up**, as in ArchHUD. Ships use it for cabin automation (seat → switch → doors, force fields, lights). It never touches the anti-grav generator.
- **Anti-grav generator (auto-linked by the `.conf`; link it yourself for the paste install):** Alt+G (DU's anti-gravity key) or `agg on` / `agg off` in Lua chat turns it on and off. If another program such as Copilot or Gemini takes Alt+G, rebind the anti-gravity key in DU's controls or use the chat commands. In Lua chat, `agg 2500` sets the hover height (metres, 1,000 or more), `agg here` sets it to your current altitude, and `agg` on its own prints the status. The height is stored on the AGG itself, so it survives getting up, restarts and reinstalls. The SYSTEMS panel shows an AGG row: grey when off, amber while the lift creeps to a new height (with a time estimate), green when holding, red `no pulsors linked` when the generator reports no pulsors (it then lifts nothing, whatever the heights say). A note under it says how far you are above or below the lift. The AGG holds the ship at the **lift point**, not at the height you set: until the row turns green it pulls you toward where the lift is now. So set the height first (on the ground is fine), wait for green, then fly up to it and let go. Helmsman never turns the AGG off: getting up, stopping the seat and the autopilot leave it as it is. Only Alt+G or `agg off` turns it off.
- **AGG trips (autopilot):** with the AGG on (and pulsors linked), sending the AP to a spot on the planet you're on makes it **stay in the air**: the destination becomes the point over the spot at the AGG height (above sea level, as the AGG works), so a Navigator or pasted ground spot works as is. If the AGG height clears the planet's highest ground by 100 m, the AP flies the whole trip at the AGG height and the AGG carries the weight. If not, it cruises at the normal safe height and comes down to the AGG height near the spot. It stops over the spot with the brakes held and the AGG holding; it never lands. A spot saved in the air at the AGG height (within 30 m below to 25 m above it) counts as an AGG trip too: it flies there at that height and holds. A normal trip (landing) is flown instead when the spot is higher than the AGG height, or for a map pick (ground height unknown) when the AGG height is below the highest ground; the chat says why. If it can't bank round toward the target, it stops in the air instead of landing. Trips from space or another planet: when the descent over the spot starts and the AGG is on (same checks), the descent stops at the AGG height over the spot and holds there with the brakes on, instead of landing; the chat says which it will do.
- **Auto-warp (opt-in):** the `AutoWarp` parameter, or `autowarp on` / `off` in chat for this session. With it on, set the warp destination on the map as usual (scripts can't pick it); when it's where the AP is going (same planet/moon, or a point within 10% of the AP's distance) and the drive reads READY, the AP warps by itself during the space part of the trip, then carries on to the spot after the jump (brake to cancel). The HUD's WARP row shows AUTO (green) or why not (amber). Off by default: Helmsman never warps unless asked.
- **Safe mass:** while landed or stopped, the FLIGHT panel's brake-distance row shows `MASS · SAFE` (mass now · safe mass, and what limits it). Safe mass uses ArchHUD's rule of thumb: half of what the atmo engines, space engines, hovers or brakes could hold against gravity here (2:1), and the lowest one counts. Amber within 10%, red when over. Chat: `mass` lists all four and how much room is left.
- **Rockets:** B fires and stops them by hand, as in the stock script; the HUD shows a red ROCKETS tag while they're on, and the sit-down thrust line lists their thrust. During an AP climb, if the climb is struggling (the check behind CAN'T CLIMB), the AP fires them, and turns them off again at 92% of the burn speed, once the ship is climbing well, or when the climb ends. Chat: `rockets` shows their status; `rockets test` makes the next AP climb fire them for up to 15 s.
- **Parking heading:** add `|hdg=N` after a `::pos{}` (pasted, or from Navigator) and the ship parks facing that way: N is a compass heading in degrees, 0 = north (toward the planet's pole, the axis `::pos` latitude uses), 90 = east. A landing holds the heading all the way down, so it has turned while still high up, and doesn't go below the fast descent's end (DescentHeight over the spot) until it faces it. An AGG trip, or a landing without the descent, turns in place over the spot on the brakes before holding or setting down. It gives up after 60 s and says so. Chat: `hdg` shows which way the nose faces; `hdg N`, `hdg here` or `hdg off` set the current target's parking heading.
- **Warp drive (auto-linked by the `.conf`; link it yourself for the paste install):** pick the destination on the in-game map as usual. A single WARP line under the key hints shows the drive's status (READY / cooling down / planet too close / not enough cells / no destination…), the destination and distance, and warp cells needed / aboard (red if not enough). Jump with the game's own warp key (Alt+J) as usual; the script only displays warp info. While DU is warping, the script stops all engine and brake commands so it never fights the jump. If the AP was flying when the warp started, it resumes by itself about a second after you drop out (press brake during the warp to cancel that).

The startup lines report `radars=N`, `warp=OK|none` and `N fuel tanks read`.

## Custom atlas (other servers)

Private and community servers can have different planets. The script uses DU's atlas to convert planet-relative `::pos{}` coordinates and to route around planets, so it needs the right atlas for the server you play on.

1. Put the server's atlas file (a Lua file returning the atlas table) in `Game\data\lua\autoconf\custom\`. `Game\data\lua\` also works.
2. Right-click the seat → *Advanced* → *Edit Lua Parameters* → set **CustomAtlas** to the file name without `.lua` (e.g. `atlas_myserver`).
3. Restart the seat. The console line shows which atlas was loaded and how many bodies it found. If the file can't be found, it warns and falls back to the game's default atlas.

This uses the same parameter name and lookup as Navigator's `CustomAtlas`, so one atlas file serves both. Planets from every star system in the file are used.

## For ship builders (DRM)

Every setting is an **export parameter**, including the atlas. Owners can change them through *Edit Lua Parameters* on a DRM-protected seat, so you never need to remove DRM for a buyer on another server or with different preferences. The paste install finds linked elements by class, so no particular link order is required either.

Chat commands like `speed` and `stopdist` change the setting for the current session only. The parameter value comes back on restart.

## Controls

| Key | Action |
|---|---|
| Alt+1 | Engage / disengage autopilot |
| Alt+2 | Clear target |
| Alt+3 | Toggle HUD |
| Alt+4 | Switch Flight / Maneuver mode |
| Alt+5 | Park hold: stop, then hold position (rotation stays free) |
| Alt+6 | Fighter-style attitude HUD on/off |
| Ctrl+Alt | Brake lock on/off (plain Ctrl is still hold-to-brake) |
| G | Lift off to hover height / land (gear, hovers and vertical boosters) |
| Brake, throttle, pitch/yaw, stop engines | Disengages the AP (you take over) |

Lua chat: `::pos{...}`, `goto ::pos{...}`, `ap`, `ap on`, `ap off`/`stop`, `clear`, `hud`, `speed N` (km/h cap, 0 = max), `stopdist N`, `navinfo on/off`, `brakes` / `brakes reset` (measured braking per speed band; learned and saved per pilot, so someone borrowing the ship starts fresh and doesn't change yours), `ahead N` (test target in empty space N su off the nose), `radar` (contacts and what DU reports about them), `target`, `help`.

## Flight modes

- **Flight** (default): throttle drives the ship forward. Vertical and lateral thrusters only fire while you press their keys. A parked ship makes no thrust at all until you press G.
- **Maneuver**: for docking, parking and slow precise movement. Throttle, strafe and Space/C each ask for a *speed* in that direction, as a fraction of `ManeuverSpeed`. Thrusters facing every direction work together to hit it. With nothing pressed the ship holds still, and the down-facing thrusters (pushing up) carry its weight once you've lifted off with G.

The script checks how much thrust the ship has in each of the 6 directions. That's printed at startup and with the `thrust` command. In Maneuver mode the HUD shows `F B L R U D`, with any missing direction in red, and warns if the up thrust can't carry the ship's weight.

## Settings (Edit Lua Parameters)

The HUD look (theme, scale, position, opacity), Flight HUD / nav info / AutoLevel, LandSafety and the fuel talents are saved on the databank, so a new paste keeps them. A parameter left at its default uses the saved value. DU's parameter menu always shows the script's defaults, so type `settings` in Lua chat to see what is actually saved and in use. Autopilot and flight settings are not saved and come from this list.

| Parameter | Default | Meaning |
|---|---|---|
| CustomAtlas | atlas | Atlas file for your server (see above) |
| MaxCruiseSpeed | 0 | AP speed cap in km/h (0 = ship max) |
| StopDistance | 1000 | Stop this many metres short of the target |
| PlanetClearance | 10000 | Margin kept outside atmosphere/terrain when routing |
| BrakeSafety | 0.8 | Fraction of brake force planned with (lower = brake earlier) |
| AlignRate | 0.5 | Max AP turn rate, rad/s (lower for big ships) |
| AutoEngagePaste | true | Pasting a ::pos{} engages immediately |
| StartMode | 1 | 1 = Flight, 2 = Maneuver when you sit down |
| ManeuverSpeed | 100 | Maneuver mode top speed, km/h |
| HoverHeight | 10 | Hover height (m) after pressing G |
| AutoLand | true | Surface targets: descend straight down from the hold point and land. Off = stop above and wait for G |
| PlanetTrips | atmo | Surface spot on the same atmosphere planet: `atmo` = fly there in the air (any distance), `orbit` = via space / orbit hop, `auto` = air up to AtmoHopMax, orbit beyond |
| AtmoHopMax | 100 | `auto` only: furthest trip (km) that stays in the atmosphere |
| AtmoCruiseHeight | 3000 | Atmosphere trips: cruise altitude (m above sea level), raised over the highest terrain / tallest allowed buildings, kept under the atmosphere top |
| OrbitHop | true | Far side of the same atmosphere planet: low orbit at orbital speed instead of the corner route. Moons always use the normal full-speed route |
| DescentHeight | 100 | AutoLand: metres above the spot where the fast descent ends; below it the ship comes down slowly, still holding over the spot, until the hovers see the ground (min 30) |
| GLandsDirect | false | On: G while flying starts landing in one press. Off: G goes to hover first, then G again lands |
| LandSpeed | 0 | Fastest landing descent, km/h. **0 = automatic**: as fast as the brakes + hovers/boosters can still stop within what they can see (weight and cargo included, brakes as measured on your own stops), up to 500 km/h and never over the burn speed. A number = your own limit. When you sit down (and with `thrust`) a line in chat says what the ship can stop from; it warns if your number is only usable high up, and if the ship can barely hold its own weight. `landsafety N` sets how hard it plans to brake |
| TouchdownSpeed | 15 | Landing speed (km/h) for the last 2 m before touchdown, or the whole landing if no hover/booster is linked. Higher is quicker but lands harder |
| CollisionWarn | true | Radar collision warning on the HUD (warning only) |
| CollisionStop | true | AP stops short of a radar contact on its path and hands back to you. Manual flight is never taken over |
| AutoWarp | false | Opt-in auto-warp: with a warp destination set on the map that is where the AP is going, the AP warps when the drive reads READY, then carries on. Live: `autowarp on/off` |
| HudTheme | cyan | Colour theme: cyan, amber, green, red, purple, white, or `#RRGGBB`. Live: `hudtheme NAME`, saved |
| HudOpacity | 0.9 | Panel opacity 0.3-1. Live: `hud opacity N`, saved |
| HudScale / HudShift / HudBottom | 1 / 0 / 7 | Live: `hud scale N`, `hud shift N`, `hud bottom N`, all saved. Size of the compact bottom HUD (1 = default, 0.8 smaller, 1.3 bigger), sideways nudge (% of screen, negative = left), distance from the bottom (% of screen height) |
| NavInfo | true | AUTOPILOT panel (target, ETA, brake distance). Turn it off if you'd rather watch Navigator's screen; the AP phase then shows as a badge in FLIGHT. Live: `navinfo on/off`, saved |
| FlightHudScale | 0.75 | Size of the fighter-style centre HUD |
| FlightHud | true | Centre attitude HUD: pitch ladder, roll scale, flight path marker, AP target marker, speed / altitude. Alt+6 or `fhud` toggles; saved |
| BurnProtect | true | Hand flying in atmosphere: engine push fades out near the burn speed, so you level off just under it (BURN LIMIT tag); the brakes only act if you go over it, e.g. diving. Steering and your throttle setting are never touched |
| AutoLevel | true | Auto-levelling (only while hovering/landing, or in atmosphere). A LEVEL tag shows whenever it's acting. `autolevel on/off`; saved |
| HideDUWidget | true | Hide DU's own seat panel; the HUD's FLIGHT panel shows throttle / cruise instead |
| HideBuildHelper | true | Hide DU's BUILD HELPER bar at the top of the screen while seated; it comes back when you get up |

## How the autopilot flies

Every physics tick it computes a **desired velocity**: toward the target, at the lower of the cruise cap and the fastest speed it can still brake from (`√(2·brake·distance)`). The ship points along *desired − actual velocity* and thrusts once it's within ~3°. One rule covers accelerating, cancelling sideways drift, and cruising. When the ship is faster than it can stop from, it brakes. When it is heading well off course, it brakes while turning.

Before engaging, it checks the straight line against every planet and moon in DU's atlas. If one is in the way, it adds dog-leg waypoints outside the planet's clearance and drops them as soon as the direct line is clear.

## Navigator databank keys

| Key | Written by | Meaning |
|---|---|---|
| `nav_ap_dest` | Navigator | `NAME\|::pos{...}`, optionally `\|hdg=N` on the end (parking heading). Read, then cleared, by Helmsman |
| `nav_print` | Navigator | `NAME\|::pos{...}` from PRINT COORDS. Helmsman prints it to Lua chat (`[NAV] NAME`, then the `::pos{}` on its own line) and clears it. Never used as a destination. Lets a switch-started Navigator PB, which can't print, still show coordinates |
| `autofly` | Navigator | `1` = engage automatically on a new destination |
| `sf_target` | Helmsman | Current target, restored when you sit back down |

## Credits

- **Sagacious (SagaHUD)**: keeping the ship steered over the destination through the whole descent is the idea that makes SAGA land on the spot. Sagacious released the SAGA source for others to build on; Helmsman uses the idea with its own code (nose kept level, no tilting).
