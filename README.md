# Helmsman

A Dual Universe seat flight script with a space autopilot. It is the companion to **DU Starmap Navigator**.

- Normal manual flight (DU's standard flight model: throttle, cruise control, hovers, boosters, gear, anti-grav).
- **Space autopilot**: align, burn, cruise, and brake to a full stop `StopDistance` short of the target. Routes around planets automatically.
- **Paste to fly**: paste any `::pos{...}` (or `Name ::pos{...}`) into Lua chat and the ship flies there.
- **Navigator link**: NAVIGATE in Navigator and the target appears here. With Navigator's AUTO FLY on, the AP engages by itself and route stops chain.
- AR overlay HUD showing target, distance, ETA, speed, braking distance, and AP phase.

> Surface targets: the AP flies to a hold point in space straight above the spot (outside the atmosphere *and* above the highest terrain, which matters for Thades) and stops right on it, not `StopDistance` short. With **AutoLand** on (default) it then **descends straight down the down line**: gravity does the accelerating, the brakes keep the speed under 85% of the ship's atmospheric burn speed and stop the fast part 500 m above the spot (or above the atlas's highest terrain when the location's altitude is 0, as map picks often are). The normal landing then sets you down. Brake at any time stops it; Alt+1 above the spot carries on down. AutoLand off: it stops above and waits for G. Picking a body's centre on the map gives the side facing you (no auto-descent: there is no real spot). Take-off from the ground to space is planned next.

## Build

```
node build.js
```

This produces both install formats from the same source:

- `dist/Helmsman_v0.1.txt`: paste-able Lua configuration
- `dist/Helmsman_v0.1.conf`: custom autoconfigure file

## Install

### Option A: paste (recommended, and the one to use for DRM ships)
1. Link the **core unit** to the seat or remote controller. Optionally also link the **databank shared with Navigator** and the **anti-grav generator**. Any slot, any order works, because the script identifies each element by class at startup.
2. Open `Helmsman_v0.1.txt`, copy everything, then right-click the seat → *Advanced* → *Paste Lua configuration from clipboard*.

### Option B: autoconfigure
1. Copy `Helmsman_v0.1.conf` to `...\Dual Universe\Game\data\lua\autoconf\custom\`
2. Right-click the seat → *Advanced* → *Run custom autoconfigure* → **Helmsman v0.1**. This links the core and anti-grav. Link the Navigator databank yourself afterwards if you use one.

Either way, sit down and check the Lua console:
`[HELM] Helmsman v0.1.0 | atlas=atlas (N bodies) | databank=Navigator HUD bank | antigrav=OK | ground sensors=1`

## Fuel and radar (optional links)

- **Fuel (no links needed):** every fuel tank on the construct is read through the core. The HUD shows a row per fuel type (ATMO / SPACE / ROCKET) with litres left, %, and a bar: green above 50%, amber from 20 to 50%, red below 20%. Litres come from each tank's weight; capacity comes from its size and tier, using DU's standard values. Set the tank owner's fuel talents once with `fueltalents H O C` (handling, fuel tank optimization, container optimization, each 0-5). The values are saved to the databank and are also parameters. A `~` before the % means a tank holds more than those talents allow, so they're set too low. `fuel` lists every tank, to compare with DU's own refuel-tool readout.
- **Radar (link manually):** link an atmo radar, a space radar, or both, in any slot. DU's own radar widget is shown for whichever one works where you are, switching automatically when you enter or leave atmosphere. The HUD shows the contact count.
- **Collision warning (needs a radar):** a contact on or near your path shows as a strip above the HUD: amber `CONTACT ON PATH` (name, size, distance, seconds to it, how far off you would pass), red `COLLISION — BRAKE NOW` when the brakes alone can no longer stop you short of it. It never takes over a ship you are flying yourself. Contacts the autopilot will stop short of anyway (such as the station you are flying to) are ignored.
- **Autopilot obstacle stop (CollisionStop, on by default):** when the AP is flying and a contact is on its path, it plans a stop about 50 m before the warning zone (phase OBSTACLE, red), holds the brakes and hands back to you with the name and distance. Fly round it, or press Alt+1 to carry on anyway (that contact is then ignored for the trip). If the contact moves off the path while the AP is still well short of it, the AP continues by itself. It never steers round anything. When DU only gives a distance, the contact is assumed to stand still and the result is marked `(est)`. `radar` in Lua chat lists the contacts. Turn off with the CollisionWarn parameter.

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

Lua chat: `::pos{...}`, `goto ::pos{...}`, `ap`, `ap on`, `ap off`/`stop`, `clear`, `hud`, `speed N` (km/h cap, 0 = max), `stopdist N`, `navinfo on/off`, `brakes` / `brakes reset` (measured braking per speed band), `ahead N` (test target in empty space N su off the nose), `radar` (contacts and what DU reports about them), `target`, `help`.

## Flight modes

- **Flight** (default): throttle drives the ship forward. Vertical and lateral thrusters only fire while you press their keys. A parked ship makes no thrust at all until you press G.
- **Maneuver**: for docking, parking and slow precise movement. Throttle, strafe and Space/C each ask for a *speed* in that direction, as a fraction of `ManeuverSpeed`. Thrusters facing every direction work together to hit it. With nothing pressed the ship holds still, and the up-facing thrusters carry its weight once you've lifted off with G.

The script checks how much thrust the ship has in each of the 6 directions. That's printed at startup and with the `thrust` command. In Maneuver mode the HUD shows `F B L R U D`, with any missing direction in red, and warns if the up thrust can't carry the ship's weight.

## Settings (Edit Lua Parameters)

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
| HoverHeight | 4 | Hover height (m) after pressing G |
| AutoLand | true | Surface targets: descend straight down from the hold point and land. Off = stop above and wait for G |
| GLandsDirect | false | On: G while flying starts landing in one press. Off: G goes to hover first, then G again lands |
| LandSpeed | 150 | Fastest landing descent, km/h. Reached while the ship is above the highest terrain in the atlas (plus 300 m), or when the hovers/boosters can see far enough to stop. `landsafety N` sets how hard it plans to brake |
| TouchdownSpeed | 15 | Landing speed (km/h) for the last 2 m before touchdown, or the whole landing if no hover/booster is linked. Higher is quicker but lands harder |
| CollisionWarn | true | Radar collision warning on the HUD (warning only) |
| CollisionStop | true | AP stops short of a radar contact on its path and hands back to you. Manual flight is never taken over |
| HudTheme | cyan | Colour theme: cyan, amber, green, red, purple, white, `#RRGGBB`, or custom (AccentR/G/B). Live: `hudtheme NAME`, saved |
| HudOpacity | 0.9 | Panel opacity 0.3-1. Live: `hud opacity N`, saved |
| HudScale / HudShift / HudBottom | 1 / 0 / 7 | Live: `hud scale N`, `hud shift N`, `hud bottom N`, all saved. Size of the compact bottom HUD (1 = default, 0.8 smaller, 1.3 bigger), sideways nudge (% of screen, negative = left), distance from the bottom (% of screen height) |
| NavInfo | true | AUTOPILOT panel (target, ETA, brake distance). Turn it off if you'd rather watch Navigator's screen; the AP phase then shows as a badge in FLIGHT. Live: `navinfo on/off`, saved |
| FlightHudScale | 0.75 | Size of the fighter-style centre HUD |
| FlightHud | true | Centre attitude HUD: pitch ladder, roll scale, flight path marker, AP target marker, speed / altitude. Alt+6 or `fhud` toggles; saved |
| AutoLevel | true | Auto-levelling (only while hovering/landing, or in atmosphere). A LEVEL tag shows whenever it's acting. `autolevel on/off`; saved |
| HideDUWidget | true | Hide DU's own seat panel; the HUD's FLIGHT panel shows throttle / cruise instead |
| AccentR/G/B | 0/200/255 | HUD accent colour |

## How the autopilot flies

Every physics tick it computes a **desired velocity**: toward the target, at the lower of the cruise cap and the fastest speed it can still brake from (`√(2·brake·distance)`). The ship points along *desired − actual velocity* and thrusts once it's within ~3°. One rule covers accelerating, cancelling sideways drift, and cruising. When the ship is faster than it can stop from, it brakes. When it is heading well off course, it brakes while turning.

Before engaging, it checks the straight line against every planet and moon in DU's atlas. If one is in the way, it adds dog-leg waypoints outside the planet's clearance and drops them as soon as the direct line is clear.

## Navigator databank keys

| Key | Written by | Meaning |
|---|---|---|
| `nav_ap_dest` | Navigator | `NAME\|::pos{...}`. Read, then cleared, by Helmsman |
| `autofly` | Navigator | `1` = engage automatically on a new destination |
| `sf_target` | Helmsman | Current target, restored when you sit back down |
