--[[@
slot=unit
event=onStart
]]
-- ════════════════════════════════════════════════════════════════════
--  HELMSMAN  —  seat flight script + space autopilot
--  Companion to DU Starmap Navigator.
--
--  Fly to a location:
--    • Paste a ::pos{...} into Lua chat (optionally "Name ::pos{...}")
--    • Or NAVIGATE in Navigator — it writes nav_ap_dest on the shared
--      databank, which this script picks up. If Navigator's AUTO FLY is
--      on, the AP engages by itself and route stops chain automatically.
--
--  Keys:  Alt+1 engage/disengage AP   Alt+2 clear target   Alt+3 HUD
--  Chat:  type "help" in Lua chat for the full command list.
--
--  Links: core unit (required), plus optional databank shared with
--  Navigator and optional anti-grav — in ANY slot, any order. Elements
--  are identified by class at startup. Engines need no links.
--
--  Every setting below is an export parameter, so on a DRM-protected
--  seat owners can still change them via "Edit Lua Parameters".
-- ════════════════════════════════════════════════════════════════════
VERSION = "1.0.3"
BUILD   = "dev"   -- stamped by build.js (date-time), shown on the HUD so you can tell which paste is running

-- ── Server ────────────────────────────────────────────────────────
CustomAtlas = "atlas"  --export: Atlas file for your server. "atlas" = game default. Put custom files in Game/data/lua/autoconf/custom/ (or Game/data/lua/) and enter the file name without .lua

-- ── Autopilot ─────────────────────────────────────────────────────
MaxCruiseSpeed  = 0      --export: AP cruise speed cap in km/h. 0 = use the ship's max speed.
StopDistance    = 1000   --export: Targets in space only: how far short (m) the AP stops. Spots on a planet or moon always stop right over the spot
PlanetClearance = 10000  --export: Extra margin (m) kept outside atmospheres/surfaces when routing around planets.
BrakeSafety     = 0.8    --export: Fraction of max brake force the AP plans with. Lower = starts braking earlier.
AlignRate       = 0.5    --export: Max AP turn rate in rad/s. Lower it if a big ship overshoots when aligning.
AutoEngagePaste = true   --export: Engage the AP immediately when you paste a ::pos{} into Lua chat.
-- ── HUD ───────────────────────────────────────────────────────────
HudTheme  = "cyan" --export: HUD colour theme: cyan, amber, green, red, purple, white, or a hex colour like "#FF8800". Saved on the databank: left at "cyan", the saved colour is used (a bought ship may show its old owner's). Change it in chat: hudtheme NAME (hudtheme cyan for the default)
HudOpacity = 0.9  --export: HUD panel opacity 0.3-1 (live: hud opacity N)
HudScale  = 1     --export: Size of the bottom HUD (1 = compact default, 1.3 = bigger, 0.8 = smaller; live: hud scale N)
HudShift  = 0     --export: Move the HUD bar sideways, % of screen width (negative = left, positive = right; live: hud shift N)
HudBottom = 7     --export: HUD bar distance from the bottom of the screen, % of screen height (live: hud bottom N)
NavInfo   = true  --export: AUTOPILOT panel (target, ETA, brake distance). Off = hide it, e.g. when Navigator's screen already shows those. Live: navinfo on/off, saved
FlightHud = true  --export: Fighter-style attitude HUD in the centre of the screen: pitch ladder, roll, flight path marker, target marker (Alt+6 toggles; saved)
FlightHudScale = 0.75 --export: Size of the fighter-style HUD (1 = large, 0.75 = default)
HideDUWidget = true --export: Hide DU's own seat panel (throttle, cruise/travel) — the HUD shows the same info
HideBuildHelper = true --export: Hide DU's BUILD HELPER bar at the top of the screen while seated (comes back when you get up)
CollisionWarn = true --export: Radar collision warning: a contact on or near your path shows on the HUD (red = too close to stop with brakes). Never flies the ship you're flying. Needs a linked radar
AutoWarp      = false --export: Opt-in auto-warp. On: with a warp destination set on the map (scripts can't pick it) that is where the AP is going, the AP warps by itself when the drive reads READY, then carries on to the spot. Off = Helmsman never warps. Live: autowarp on/off
CollisionStop = true --export: When the AUTOPILOT is flying toward a radar contact on its path, it stops short of it and hands back to you (Alt+1 carries on anyway). Manual flight is never taken over
-- ── Flight feel (DU default values) ───────────────────────────────
AutoLevel        = true  --export: Auto-level roll in atmosphere when you're not rolling
BurnProtect      = true  --export: Hand flying in atmosphere: engine push fades out near the burn speed so you level off just under it (BURN LIMIT tag); brakes only if you go over it (e.g. diving). Off while climbing out through the last 2% of the air. Steering and your throttle setting are never touched
HoverHeight      = 10    --export: Hover height in metres when you press G to lift off (hover engines / vertical boosters)
AutoLand         = true  --export: Surface targets: after stopping above the spot, the AP descends straight down (through the atmosphere, under the burn speed) and lands. Off = it stops above and waits for G
PlanetTrips      = "atmo" --export: Surface spot on the SAME planet (with an atmosphere) while you're on it or in its air: "atmo" = take off and fly there inside the atmosphere (any distance), "orbit" = climb out and use the space route / orbit hop, "auto" = atmo up to AtmoHopMax, orbit beyond
AtmoHopMax       = 100   --export: PlanetTrips "auto": furthest trip in km that stays in the atmosphere
AtmoCruiseHeight = 3000  --export: Atmosphere trips: cruising altitude in metres above sea level. Raised automatically above the highest terrain / tallest allowed buildings, kept under the atmosphere top
OrbitHop         = true  --export: Surface spot on the far side of the SAME planet with an atmosphere: fly a low orbit round the planet (orbital speed, mostly coasting) instead of the corner route. Moons and airless bodies always use the normal route at full speed
DescentHeight    = 100   --export: AutoLand: the fast descent stops this many metres above the spot (when its altitude is known); below that it comes down slowly, still holding over the spot, until the hovers see the ground, then the normal landing does the rest. Lower = quicker (min 30)
GLandsDirect     = false --export: G while flying lands in one press. Off = G goes to hover first, then G again lands
StartMode        = 1     --export: Mode when you sit down. 1 = Flight, 2 = Maneuver (Alt+4 switches)
LandSpeed        = 0     --export: Fastest landing descent in km/h. 0 = automatic: as fast as the ship's brakes + hovers can still stop within what they can see (weight and cargo included), up to 500 km/h and never over the burn speed. A number = your own limit (the sit-down report says if the ship can't really stop from it). Without hovers/boosters, TouchdownSpeed below the highest terrain
TouchdownSpeed   = 15    --export: Landing speed in km/h for the last 2 m before touchdown (and the whole landing if no hover/booster is linked). Higher = quicker but harder touchdown
AtmoTankHandling     = 0   --export: Atmospheric fuel tank handling talent (0-5) of the tanks' owner: bigger tanks. Or "fueltalents A S R O C" in Lua chat; saved to the databank.
SpaceTankHandling    = 0   --export: Space fuel tank handling talent (0-5)
RocketTankHandling   = 0   --export: Rocket fuel tank handling talent (0-5)
FuelTankOptimization = 0   --export: Fuel tank optimization talent level (0-5): lighter fuel
ContainerOptimization = 0  --export: Container optimization talent level (0-5): lighter fuel
LandSafety       = 0.3   --export: Share of the ship's spare stopping power a landing plans with. Lower = starts slowing higher, gentler (0.1-1). Tune live with "landsafety N" in Lua chat; saved to the databank.
ManeuverSpeed    = 100   --export: Maneuver mode top speed in km/h (throttle / strafe / up-down are a fraction of this)
pitchSpeedFactor = 0.8   --export: Hand flying: how fast the nose pitches with your pitch keys (0.8 ≈ 46°/s). Lower = gentler, higher = snappier
yawSpeedFactor   = 1     --export: Hand flying: how fast the ship yaws with your yaw keys (1 ≈ 57°/s)
rollSpeedFactor  = 1.5   --export: Hand flying: how fast the ship rolls with your roll keys (1.5 ≈ 86°/s). Also used for your roll input while the AP flies
-- Fixed (were parameters; trimmed 2026-11-14 - the code is built around
-- these values, and nobody changed them):
brakeSpeedFactor = 3
brakeFlatFactor  = 1
torqueFactor     = 2
autoRollFactor   = 2
MaxClimbAngle    = 45     --export: Steepest nose angle (degrees, 10-60) the AP climbs at when taking off to space. It picks a gentler angle itself for weaker ships; lower this for heavy ships that need speed more than height (e.g. 20)
AtmoClimbAngle   = 45     -- steepest climb on atmosphere trips (flattens with speed)
FuelTierStep     = 1.5    -- tank capacity step per tier (verified)

-- ── Local helpers (captured as upvalues by the global functions) ──
local EPS, SU = 1e-6, 200000
local mabs, msqrt, mmin, mmax = math.abs, math.sqrt, math.min, math.max
local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
local function V(t) if not t then return nil end return vec3(t.x or t[1], t.y or t[2], t.z or t[3]) end
local function norm(v) local l = v:len() if l < EPS then return vec3(), 0 end return v / l, l end
local function now() return system.getArkTime() end
local function esc(s) return (tostring(s or "")):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;") end

-- ── Core state ────────────────────────────────────────────────────
pitchInput, rollInput, yawInput, brakeInput, upInput, strafeInput = 0, 0, 0, 0, 0, 0
Mode   = 1    -- 1 = Flight, 2 = Maneuver (set from StartMode at the end of onStart)
Thrust = nil  -- per-direction thrust survey, see SurveyThrust()
ParkBrake  = false
HudOn      = true
StatusMsg, StatusUntil = "", 0
MaxSpeedMS, MaxBrakeN, MaxThrustN = 30000/3.6, 0, 0

AP = { active=false, phase="OFF", target=nil, name="", posStr="", note=nil,
       legs=nil, leg=1, accel=0, brake=0, angVel=vec3(), alignErr=0,
       remaining=0, vAlong=0, vDes=0, total=0 }

-- ── Element detection ─────────────────────────────────────────────
-- Works for both installs: the .conf names slots (core/navdb/antigrav),
-- the pasted JSON leaves them generic (slot1..slotN; some seats have more than 10 link slots, e.g. a radar in slot 15). Either way, ask
-- each linked element what class it really is instead of trusting the
-- slot. Literal tokens only — _ENV["slot"..i] fails in DU's sandbox.
local function classOf(e)
  if type(e) ~= "table" then return "" end
  local ok, c = pcall(function() return e.getClass() end)
  if not ok or not c then ok, c = pcall(function() return e.getElementClass() end) end
  return (ok and c) and tostring(c):lower() or ""
end
local foundCore, foundAgg, banks = nil, nil, {}
GroundEngines = {}   -- linked vertical boosters / hovers: used only to read ground distance
Radars        = {}   -- linked radars (atmo and/or space)
WarpDrive     = nil  -- linked warp drive (destination is chosen on the in-game map)
Switches      = {}   -- linked manual switches: ON while seated, OFF on leaving (like ArchHUD)
Telemeters    = {}   -- linked telemeters: a DOWN-facing one sees the ground ~100 m off
-- (Fuel tanks need no links — every tank is read through the core.)
-- The same element can appear under two names (e.g. .conf name + slotN).
local seen = {}
local function addOnce(list, e, item)
  if seen[e] then return end
  seen[e] = true
  list[#list+1] = item or e
end
for _, e in pairs({core, navdb, navdb_1, navdb_2, antigrav, antigrav_1,
                   vBooster, vBooster_1, vBooster_2, vBooster_3, vBooster_4,
                   hover, hover_1, hover_2, hover_3, hover_4,
                   radar, radar_1, radar_2, warpdrive, warpdrive_1, switch, switch_1, switch_2,
                   telemeter, telemeter_1, telemeter_2,
                   slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9, slot10,
                   slot11, slot12, slot13, slot14, slot15, slot16, slot17, slot18, slot19, slot20,
                   slot21, slot22, slot23, slot24, slot25}) do
  local c = classOf(e)
  if c:find("core") then foundCore = foundCore or e
  elseif c:find("antigravity") then foundAgg = foundAgg or e
  elseif c:find("radar") then addOnce(Radars, e)
  elseif c:find("warpdrive") then WarpDrive = WarpDrive or e
  elseif c:find("verticalbooster") or c:find("hovercraft") or c:find("hover") then addOnce(GroundEngines, e)
  elseif c:find("databank") then addOnce(banks, e)
  elseif c:find("manualswitch") then addOnce(Switches, e)
  elseif c:find("telemeter") then addOnce(Telemeters, e)
  end
end
-- Seat-linked manual switches go ON when you sit down and OFF when you get
-- up (ArchHUD does the same). Ships use it for cabin automation: Carl's
-- Hammer Crest has seat -> switch -> board for doors, force fields and
-- lights; the seat's own script used to flip that switch.
for _, sw in ipairs(Switches) do pcall(sw.activate) end
-- Which databank is which? Navigator's ship PB has TWO banks and writes
-- "autofly" to both, so that key proves nothing. Use keys that only
-- exist on one of them (key-list membership — the nav_*_dest keys stay
-- listed even after being cleared to ""):
--   "hud"  = Navigator's navdatabank (shared with Arch/Saga) — correct
--   "main" = Navigator's own data bank — wrong one to link here
--   "mine" = only this script's sf_target, "blank"/"other" otherwise
local function keySet(d)
  local ok, list = pcall(function() return d.getKeyList() end)
  local s = {}
  if ok and type(list) == "table" then for _, k in pairs(list) do s[k] = true end end
  return s
end
function BankKind(d)
  local s = keySet(d)
  if s.nav_ap_dest or s.nav_print or s.nav_arch_dest or s.nav_saga_dest or s.SavedLocations or s.SagaConf or s.SagaRoutes then return "hud" end
  if s.personal_wps or s.personal_routes then return "main" end
  if s.sf_target then return "mine" end
  return next(s) and "other" or "blank"
end
local rank = { hud = 1, mine = 2, blank = 3, other = 4, main = 5 }
NavDB = nil
for _, b in ipairs(banks) do
  if not NavDB or rank[BankKind(b)] < rank[BankKind(NavDB)] then NavDB = b end
end
NavKind = NavDB and BankKind(NavDB) or nil

-- ── Settings that survive re-pasting the script ───────────────────
-- Pasting a new build resets export parameters to their code defaults.
-- So (same rule as Navigator's HudX/HudY): if the parameter is still at
-- its default, use the value saved on the databank; if someone changed
-- the parameter, that wins and is saved.
function DbGetNum(key)
  if not NavDB then return nil end
  local ok, v = pcall(NavDB.getStringValue, key)
  return ok and tonumber(v) or nil
end
function DbSetNum(key, v)
  if NavDB then pcall(NavDB.setStringValue, key, tostring(v)) end
end
local function persisted(key, exportVal, default)
  if exportVal ~= default then DbSetNum(key, exportVal) return exportVal end
  return DbGetNum(key) or exportVal
end
-- Per-PILOT values (Carl: lending the ship shouldn't need a "brakes
-- reset"): the learned brake factor depends on whoever sits in the seat
-- (their brake talents), so it's saved under the player's id. The ship's
-- owner keeps what was saved before this (the old shared key). Fuel
-- talents stay per SHIP: they're the talents of whoever placed the tanks.
PilotId = nil
do
  local ok, id = pcall(player.getId)
  id = ok and tonumber(id) or nil
  if id and id > 0 then PilotId = math.floor(id) end
end
function PK(key) return PilotId and (key.."_p"..PilotId) or key end
local function pilotIsOwner()
  local ok, o = pcall(construct.getOwner)
  return ok and type(o) == "table" and not o.isOrganization and tonumber(o.id) == PilotId
end
function DbGetPilot(key)
  local v = DbGetNum(PK(key))
  if v == nil and PilotId and pilotIsOwner() then v = DbGetNum(key) end
  return v
end
LandSafety = clamp(persisted("sf_landsafety", LandSafety, 0.3), 0.1, 1)
local function persistedBool(key, v, default)
  if v ~= default then DbSetNum(key, v and 1 or 0) return v end
  local n = DbGetNum(key)
  if n == nil then return v end
  return n == 1
end
AutoLevel = persistedBool("sf_autolevel", AutoLevel, true)
FlightHud = persistedBool("sf_fhud", FlightHud, true)
NavInfo = persistedBool("sf_navinfo", NavInfo == true or NavInfo == 1, true)
HudOpacity = clamp(persisted("sf_hud_opacity", HudOpacity, 0.9), 0.3, 1)
HudScale   = clamp(persisted("sf_hud_scale", HudScale, 1), 0.5, 2)
HudShift   = persisted("sf_hud_shift", HudShift, 0)
HudBottom  = clamp(persisted("sf_hud_bottom", HudBottom, 7), 0, 80)
BrakeK = clamp(DbGetPilot("sf_brake_k3") or 1, 0.3, 1)   -- learned, see BrakeMeasure
BrakeSeenAtmo, BrakeSeenSpace = nil, nil

-- ── Colour themes ─────────────────────────────────────────────────
-- a = accent (borders, titles, fighter HUD), bg = panel background.
local THEMES = {
  cyan   = { a = {0, 200, 255},   bg = {6, 12, 20} },
  amber  = { a = {255, 176, 0},   bg = {16, 11, 4} },
  green  = { a = {60, 230, 120},  bg = {4, 15, 9} },
  red    = { a = {255, 85, 85},   bg = {18, 6, 6} },
  purple = { a = {180, 125, 255}, bg = {11, 8, 20} },
  white  = { a = {225, 232, 240}, bg = {10, 12, 16} },
}
ThemeAcc, ThemeBg, ThemeName = THEMES.cyan.a, THEMES.cyan.bg, "cyan"
function ApplyTheme(spec)
  local s = tostring(spec or ""):lower():match("^%s*(.-)%s*$")
  if THEMES[s] then
    ThemeAcc, ThemeBg, ThemeName = THEMES[s].a, THEMES[s].bg, s
    return true
  end
  local hex = s:match("^#?(%x%x%x%x%x%x)$")
  local a
  if hex then
    a = { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
    ThemeName = "#"..hex:upper()
  else
    return false
  end
  -- Background: a very dark tint of the accent.
  ThemeAcc, ThemeBg = a, { math.floor(4 + a[1] * 0.05), math.floor(6 + a[2] * 0.05), math.floor(10 + a[3] * 0.05) }
  return true
end
do  -- same saving rule as the numbers: export at default → use the saved one
  local want = HudTheme
  if tostring(HudTheme):lower() ~= "cyan" then
    if NavDB then pcall(NavDB.setStringValue, "sf_theme", tostring(HudTheme)) end
  elseif NavDB then
    local ok, v = pcall(NavDB.getStringValue, "sf_theme")
    if ok and v and v ~= "" then want = v end
  end
  if not ApplyTheme(want) then ApplyTheme("cyan") end
end
-- Handling is a separate talent per fuel type. Atmo keeps the old key
-- (sf_ft_handling); space / rocket start from it until set themselves.
do
  local oldH = DbGetNum("sf_ft_handling") or 0
  local function per(key, exportVal)
    if exportVal ~= 0 then DbSetNum(key, exportVal) return exportVal end
    return DbGetNum(key) or oldH
  end
  TankH = {
    atmo   = clamp(math.floor(persisted("sf_ft_handling", AtmoTankHandling, 0)), 0, 5),
    space  = clamp(math.floor(per("sf_ft_handling_s", SpaceTankHandling)), 0, 5),
    rocket = clamp(math.floor(per("sf_ft_handling_r", RocketTankHandling)), 0, 5),
  }
end
function TalentsText()
  return string.format("handling atmo %d · space %d · rocket %d · fuel tank opt %d · container opt %d",
    TankH.atmo, TankH.space, TankH.rocket, FuelTankOptimization, ContainerOptimization)
end
FuelTankOptimization  = clamp(math.floor(persisted("sf_ft_fuelopt", FuelTankOptimization, 0)), 0, 5)
ContainerOptimization = clamp(math.floor(persisted("sf_ft_contopt", ContainerOptimization, 0)), 0, 5)
core, antigrav = foundCore, foundAgg
if not core then
  system.print("[HELM] ERROR: no core unit linked — link the core to this seat and restart")
  error("Helmsman: core unit not linked")
end

Nav = Navigator.new(system, core, unit)
Nav.axisCommandManager:setupCustomTargetSpeedRanges(axisCommandId.longitudinal, {1000, 5000, 10000, 20000, 30000})
-- ── Hover / landing state (hover engines + vertical boosters) ─────
--   landed  : gear down, ground engines get exactly zero. Always.
--   hover   : gear up, DU's ground stabilization holds HoverHeight.
--   landing : OUR controller (not DU's) lowers the ship at a steady
--             LandRate on the ground engines; when the gear touches and
--             the ship stops, → landed.
-- DU's ground stabilization is ONLY active in "hover". Any other state
-- turns it off — with it on, even at a 0 m target, DU itself keeps the
-- ground engines holding the ship up (the "stuck settling" bug).
-- Nothing here switches the ground engines on/off by fall speed; that
-- on/off flicker is what makes ships bounce.
HoverState = "landed"
HoverOn    = false   -- true while ground engines are in use (hover or landing)
LandRate   = math.max(math.min(tonumber(TouchdownSpeed) or 15, 30), 1) / 3.6   -- m/s final descent (TouchdownSpeed km/h)
LandAcc    = vec3()  -- ground-engine command while landing (set in HoverTick)
local landStart, landSettle = 0, nil
LandPhase = "stop"   -- while landing: "stop" first, then "descend"
Nav.axisCommandManager:setTargetGroundAltitude(0)
Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()

-- OnGround: we believe the ship is sitting on something (parked at
-- startup, or a landing finished). Any real movement clears it.
OnGround = false
-- Landing gear: the command is queued and sent from the HUD timer, not
-- from wherever SetHover was called. When the AP's descent started the
-- landing from inside the physics update (onFlush) the gear never came
-- out (Carl, first auto-descent); from the G key it always did.
GearWant, GearErrShown = nil, false
function SetGear(down) GearWant = down end
function ApplyGear()
  if GearWant == nil then return end
  local f = GearWant and unit.deployLandingGears or unit.retractLandingGears
  GearWant = nil
  local ok, err = pcall(f)
  if not ok and not GearErrShown then
    GearErrShown = true
    system.print('[HELM] landing gear command failed: '..tostring(err))
  end
end

function SetHover(on, forceLand)
  local acm = Nav.axisCommandManager
  if on then
    HoverState, HoverOn = "hover", true
    SetGear(false)
    acm:setTargetGroundAltitude(HoverHeight)
    acm:activateGroundEngineAltitudeStabilization(HoverHeight)
    ParkBrake = false
  elseif HoverState == "hover" or forceLand then
    HoverState, HoverOn = "landing", true
    SetGear(true)
    acm:deactivateGroundEngineAltitudeStabilization()
    -- Phase 1 "stop": nothing may keep pushing the ship while it stops.
    acm:resetCommand(axisCommandId.longitudinal)
    acm:resetCommand(axisCommandId.lateral)
    acm:resetCommand(axisCommandId.vertical)
    LandPhase = "stop"
    landStart, landSettle = now(), nil
    LandingReport(true)   -- warns only if the ship can barely hold itself up
  else
    HoverState, HoverOn = "landed", false
    SetGear(true)
    acm:deactivateGroundEngineAltitudeStabilization()
    LandAcc = vec3()
  end
end

-- What the ground engines (hovers + vertical boosters) get this frame.
function GroundCmd(hoverAcc)
  if HoverState == "hover" then return hoverAcc end
  if HoverState == "landing" then return LandAcc end
  return vec3()
end

-- Diagnostic: every engine on the construct grouped by name + its tags,
-- read from the core (no links needed). Tags decide which engines a
-- setEngineForceCommand('ground' / 'thrust analog vertical' ...) reaches.
function PrintEngineTags()
  local ok, ids = pcall(core.getElementIdList)
  if not ok or type(ids) ~= "table" then system.print("[HELM] can't read element list from core") return end
  local groups, order = {}, {}
  for _, id in ipairs(ids) do
    local okT, tg = pcall(core.getEngineTagsById, id)
    -- comes back as a JSON-ish '[["a","b"]]' string; non-engines give '[]'
    tg = (okT and type(tg) == "string") and tg:gsub('[%[%]"]', ''):gsub(',', ', ') or ""
    if tg:find("%a") then
      local _, nm = pcall(core.getElementDisplayNameById, id)
      local key = tostring(nm or "?").."  ["..tg.."]"
      if not groups[key] then groups[key] = 0; order[#order+1] = key end
      groups[key] = groups[key] + 1
    end
  end
  system.print("[HELM] Engines ("..#order.." kinds):")
  for _, k in ipairs(order) do system.print(string.format("  %dx %s", groups[k], k)) end
end

-- Re-arm stabilization after Space/C only if we're hovering.
function RestoreGroundStab()
  -- (under water: never — the hovers read 0 there and DU's hold drives
  -- them flat out for the surface: "let go of C and it shoots up", Carl)
  if UnderwaterNow or UwRise then return end
  if HoverState == "hover" then
    Nav.axisCommandManager:activateGroundEngineAltitudeStabilization(Nav:getTargetGroundAltitude())
  end
end

-- Called every flush while landing. Commands the ground engines for a
-- steady LandRate descent (they can only push up, so this just meters
-- how much of gravity they cancel). Touchdown = ship stopped for 0.7 s.
-- Ground distance from linked vertical boosters / hovers (closest one).
-- -1 = none linked or nothing in range. GroundRangeSeen learns how far
-- they can actually see, starting from a cautious guess.
-- The learned range is saved on the databank so the first landing after
-- sitting down is already fast.
GroundDist, GroundRangeSeen = -1, mmax(15, DbGetNum("sf_ground_range") or 0)
-- What the hovers read while the ship SITS on the ground (they're mounted
-- above its lowest point). Learned when parked (startup, each landing) so
-- "2 m to go" really means 2 m above touching (Carl: TouchdownSpeed 5, no
-- gear, still bounced a little). Not saved: re-learned every sit-down.
GroundRest = nil
local savedRange = GroundRangeSeen
function ReadGroundDist()
  local best = -1
  for _, e in ipairs(GroundEngines) do
    local ok, d = pcall(function() return e.getDistance() end)
    if ok and type(d) == "number" and d >= 0 and (best < 0 or d < best) then best = d end
  end
  if best > GroundRangeSeen then GroundRangeSeen = best end
  if GroundRangeSeen > savedRange + 1 then   -- don't write every frame
    savedRange = GroundRangeSeen
    DbSetNum("sf_ground_range", string.format("%.1f", GroundRangeSeen))
  end
  GroundDist = best
  return best
end

-- Telemeter pointing DOWN: sees the ground ~100 m off (hovers ~15 m), so
-- a landing onto unknown ground (map picks) can come down much faster.
-- Which way a telemeter points isn't known from its link, so one only
-- counts once a hit lands straight below the ship (parked at sit-down,
-- or any later reading). Returns: ground distance (-1 = nothing seen),
-- and how far it can see (0 = no down telemeter).
TeleRest = 3          -- what it reads while the ship sits on the ground (learned)
function TeleDown()
  if #Telemeters == 0 then return -1, 0 end
  local g = vec3(core.getWorldGravity())
  if g:len() < 0.1 then return -1, 0 end
  local dn = g / g:len()
  local pos = vec3(construct.getWorldPosition())
  local best, range = -1, 0
  for _, t in ipairs(Telemeters) do
    if t.helmDown == nil then
      local okI, id = pcall(t.getLocalId)
      t.helmDown = (okI and id and DbGetNum("sf_tdown_"..tostring(id)) == 1) or false
    end
    local ok, r = pcall(t.raycast)
    local okM, m = pcall(t.getMaxDistance)
    m = (okM and tonumber(m)) or 100
    if ok and type(r) == "table" and r.hit and r.point then
      local p = vec3(r.point.x or r.point[1], r.point.y or r.point[2], r.point.z or r.point[3])
      -- From the TELEMETER, not the ship's centre: on a big ship it sits
      -- metres to the side, so a hit 3 m below it is nowhere near
      -- "straight below the centre" (Carl's Rouen V2: never counted).
      local o = pos
      if not t.helmOff then
        local okI, id = pcall(t.getLocalId)
        local okP, lp = false, nil
        if okI and id then okP, lp = pcall(core.getElementPositionById, id) end
        if okP and type(lp) == "table" then
          t.helmOff = vec3(lp[1] or lp.x or 0, lp[2] or lp.y or 0, lp[3] or lp.z or 0)
        else
          t.helmOff = vec3()
        end
      end
      local L = t.helmOff
      o = pos + vec3(construct.getWorldOrientationRight()) * L.x
              + vec3(construct.getWorldOrientationForward()) * L.y
              + vec3(construct.getWorldOrientationUp()) * L.z
      local v = p - o
      if v:len() > 0.5 and (v / v:len()):dot(dn) > 0.95 and not t.helmDown then
        t.helmDown = true
        -- remembered on the databank: a paste over deep water (nothing in
        -- range to prove it) still knows it points down (Carl, 1115-1116)
        local okI, id = pcall(t.getLocalId)
        if okI and id then DbSetNum("sf_tdown_"..tostring(id), 1) end
      end
      if t.helmDown then
        local d = tonumber(r.distance) or v:len()
        if best < 0 or d < best then best = d end
      end
    end
    if t.helmDown then range = mmax(range, m) end
  end
  return best, range
end
-- How far down we can be sure the way is clear: hovers' range, or the
-- down telemeter's reading / range (minus what it reads when landed + 2 m).
function SightDown()
  local tD, tR = TeleDown()
  if tR <= 0 then return nil end
  if tD >= 0 then return mmax(tD - TeleRest - 2, 0) end
  return mmax(tR - TeleRest - 2, 0)
end

-- Descent speed for this frame (m/s).
--   No ground engine linked : LandRate all the way (we can't see the ground).
--   Linked, out of range    : as fast as we could still stop inside the
--                             range the engines can see, capped at LandSpeed.
--   Linked, ground in sight : the speed we can stop from in half the
--                             remaining distance, never below LandRate.
-- "Stop" = brakes + ground engines, minus gravity (from SurveyThrust).
LandVSet = LandRate
-- Height above the nearest body's HIGHEST terrain (atlas), minus a margin
-- for buildings/constructs standing on the peaks. The ground can't be
-- closer than this, so high up the landing can run at full LandSpeed
-- (Carl: the moon descent from 10 km was capped at 197 km/h because the
-- hovers only see ~20-30 m). nil = no atlas body near.
local TerrainMargin = 300
function ClearAboveTerrain()
  local pos = vec3(construct.getWorldPosition())
  local best, bd
  for _, B in ipairs(Bodies or {}) do
    local d = (pos - B.c):len() - B.r
    if not bd or d < bd then best, bd = B, d end
  end
  if not best then return nil end
  return (pos - best.c):len() - best.top - TerrainMargin
end

-- Spare stopping power for a landing: brakes (as MEASURED on this ship's
-- stops, BrakeK) + ground engines − gravity, per kg of CURRENT mass
-- (cargo makes it land slower automatically).
function LandSpare(glen, mass)
  local push = MaxBrakeN * 0.8 * clamp(BrakeK or 1, 0.3, 1) + ((Thrust and Thrust.G) or 0)
  return push / mmax(mass, 1) - glen
end
-- LandSpeed 0 = automatic: the stopping maths below sets the speed, up to
-- 500 km/h (a G press at 3 km diving at 1,100 km/h would be physically
-- fine but frightening) and never over the burn speed in atmosphere.
function LandCap()
  if (tonumber(LandSpeed) or 0) > 0 then return mmax(LandSpeed, 5) / 3.6 end
  local cap = 500 / 3.6
  if (unit.getAtmosphereDensity() or 0) > 0.0001 then cap = mmin(cap, BurnCap()) end
  return cap
end

-- Fastest speed we can stop from within D metres when the push arrives
-- only ~1 s after it's asked for (hovers / boosters spool up): v*L +
-- v²/2a = D. Without the delay the maths said "stop in 13 m from 100
-- km/h" and Carl's ship touched down at 28 km/h and bounced (build 2225).
local LAND_LAG = 1.0
function VStopIn(a, D)
  D = mmax(D, 0)
  return -a * LAND_LAG + msqrt((a * LAND_LAG) ^ 2 + 2 * a * D)
end
-- ── Water: hover on the surface ──
-- Hovers / boosters DO see the water surface, and read 0 under it — so a
-- landing on the sea "touched" and then kept sinking at touchdown speed
-- to the seabed, waiting for a stop that never came (Alioth, 1115-0717:
-- "LANDING 0 m" at -207 m, landed at -408 m). DU's own hover mode holds a
-- height above water fine (ArchHUD hovers there the same way). So: at the
-- touch, near sea level, still sinking for 1.5 s → it's water → hover.
-- G from there sinks and lands on the bottom (Carl's choice). A beach at
-- sea level stops the ship, so it lands as normal.
WaterHold, WaterSink = nil, nil
local waterT
function WaterCheck(vDown)
  if WaterSink or GroundDist < 0 or GroundDist > (GroundRest or 0) + 0.5 or vDown < 0.3 then
    waterT = nil
    return false
  end
  local pos = vec3(construct.getWorldPosition())
  local B = NearestBody(pos)
  -- (only AT the surface: deep under water a G landing tripped this too —
  -- "hovering on the water, brakes held" at −282 m, and the next G sank it)
  local hSea = B and (pos - B.c):len() - B.r or 0
  if not B or (B.atm or 0) <= 0 or hSea > 20 or hSea < -5 then waterT = nil return false end
  -- Landing on a spot saved UNDER water (below sea level, and we're over
  -- it): that's where you want to be — no stop at the surface (Carl).
  if AP.surfB == B and AP.spotR and AP.spotR < B.r - 2 and AP.target then
    local dl = norm(AP.target - B.c)
    local rel = pos - B.c
    if (rel - dl * rel:dot(dl)):len() < 300 then
      if not WaterSink then WaterSink = true; Msg("Spot is under water — sinking to it") end
      waterT = nil
      return false
    end
  end
  waterT = waterT or now()
  if now() - waterT < 1.5 then return false end
  waterT = nil
  SetHover(true)
  WaterHold = true
  -- Brakes held too, so it doesn't drift off the spot (Carl). Any
  -- movement key or Ctrl+Alt lets them go; G sinks.
  ParkBrake = true
  Msg(string.format("Water — hovering %.0f m above it, brakes held. G: sink and land on the bottom", HoverHeight))
  return true
end

-- Landing report (sit-down) / warning (each landing). Carl: let the
-- pilot pick a speed, but say if the ship can't really stop from it.
function LandingReport(warnOnly)
  local glen = vec3(core.getWorldGravity()):len()
  if glen < 0.5 then return end
  RefreshShipStats()
  if not Thrust then SurveyThrust() end
  local spare = LandSpare(glen, construct.getMass())
  if spare < 1.5 then
    system.print(string.format("[HELM] !! Landing: brakes + hovers can barely hold this ship here (%.1f m/s² spare) — landings will be very slow. Land by hand with care, or lighten the cargo", mmax(spare, 0)))
    return
  end
  if warnOnly then return end
  local ls = tonumber(LandSpeed) or 0
  if #GroundEngines == 0 then
    system.print("[HELM] Landing: no hovers / vertical boosters — fast only above the highest terrain, then "..
      string.format("%.0f km/h", TouchdownSpeed).." to touchdown")
    return
  end
  local R = mmax(GroundRangeSeen, 15)
  local vNear = VStopIn(spare * LandSafety, R) * 3.6
  local msg = string.format("[HELM] Landing: this ship can stop from %.0f km/h within its hover range (%.0f m)", vNear, R)
  if ls <= 0 then
    msg = msg..string.format(" · LandSpeed auto (up to %.0f km/h high above the terrain)", LandCap() * 3.6)
  elseif ls > vNear * 1.05 then
    msg = msg..string.format(" · your LandSpeed %.0f km/h is only used high above the terrain", ls)
  end
  system.print(msg)
end

local function landSpeedFor(d, glen, mass)
  -- Spare stopping power (LandSpare), scaled by LandSafety.
  local aPlan = mmax(LandSpare(glen, mass) * LandSafety, 0.3)
  local vMax = LandCap()
  local clear = ClearAboveTerrain()
  if #GroundEngines == 0 then
    -- Can't see the ground: fast only while above the highest terrain.
    if clear and clear > 0 then return clamp(VStopIn(aPlan, clear), LandRate, vMax) end
    return LandRate
  end
  if d < 0 then
    -- Ground not in sensor range: it's at least the sensor range away,
    -- and at least our height above the highest terrain.
    -- (a down telemeter sees further: its reading or range counts too)
    local gMin = mmax(GroundRangeSeen, clear or 0, SightDown() or 0)
    return clamp(VStopIn(aPlan, gMin), LandRate, vMax)
  end
  return clamp(VStopIn(aPlan, d - (GroundRest or 0) - 2), LandRate, vMax)
end
-- Touchdown report: fastest fall in the last metre, and any bounce.
local landPeak, landBounce, landTouched = 0, 0, false

LandBrake = 0
function HoverTick(vel)
  LandBrake = 0
  if HoverState ~= "landing" then return end
  local g = vec3(core.getWorldGravity())
  local glen = g:len()
  local function done()
    ReadGroundDist()
    if GroundDist >= 0 and GroundDist < 6 then GroundRest = GroundDist end
    local tD = TeleDown()
    if tD >= 0 and tD < 15 then TeleRest = tD end
    SetHover(false)
    ParkBrake, OnGround = true, true
    WaterSink, WaterHold = nil, nil
    -- how far from the AP's spot, if we were landing on one
    local offTxt = ""
    local S = AP.surfB
    if S and AP.target and not AP.active then
      local pos = vec3(construct.getWorldPosition())
      local dnL = norm(AP.target - S.c)
      local rel = pos - S.c
      local off = (rel - dnL * rel:dot(dnL)):len()
      if rel:dot(dnL) > 0 and off < 300 then offTxt = string.format(", %.1f m from %s", off, AP.name or "the mark") end
    end
    if landTouched then
      Msg(string.format("Landed at %.0f km/h%s%s — engines off, brakes held", landPeak * 3.6,
        landBounce > 0.3 and string.format(" (bounced %.1f m/s)", landBounce) or "", offTxt))
    else
      Msg("Landed — engines off, brakes held")
    end
    if offTxt ~= "" then TripDone() end        -- landed on the AP's spot
  end
  if glen < 0.3 then done() return end          -- no gravity: nothing to set down on
  local wv = g / glen
  local vDown = vel:dot(wv)
  local hSpeed = (vel - wv * vDown):len()       -- sideways speed
  ReadGroundDist()

  -- Phase 1: STOP. Full brakes, ground engines hold height (vertical
  -- speed target 0). Move on once essentially still, or after 8 s so a
  -- ship that can't fully stop (e.g. falling out of booster range) never
  -- gets stuck here.
  if LandPhase == "stop" then
    LandVSet = 0
    LandAcc = wv * ((0 - vDown) * 2.0) - g
    LandBrake = 1
    if (hSpeed < 0.5 and mabs(vDown) < 0.5) or now() - landStart > 8 then
      LandPhase, landStart, landSettle = "descend", now(), nil
      landPeak, landBounce, landTouched = 0, 0, false
    end
    return
  end

  -- Phase 2: DESCEND.
  -- Under water the hovers read 0 ("touching" all the way down), so it
  -- sank at touchdown speed. A down telemeter sees the seabed through the
  -- water (Carl, 1115-1033: 98.6 m → 2.2 m, sank at up to 97 km/h, eased
  -- to 9) — use its distance; no hit keeps it slow (safe either way).
  local gD = GroundDist
  do
    local pos = vec3(construct.getWorldPosition())
    local Bw = NearestBody(pos)
    local depth = Bw and (Bw.atm or 0) > 0 and (Bw.r - (pos - Bw.c):len()) or -1
    if depth > 3 then
      local tD, tR = TeleDown()
      if tD >= 0 then gD = mmax(tD - TeleRest, 0) + (GroundRest or 0)
      elseif tR > 0 then
        -- nothing within its range: the seabed is at least that far down
        -- (Carl: it crept at 8 km/h until the telemeter saw the bottom)
        gD = mmax(tR - TeleRest, 0) + (GroundRest or 0)
      end
    end
  end
  -- Last metre above touching (by gD: under water the hovers' 0 counted
  -- the whole sink — "landed at 111 km/h" after easing to 9): remember the fastest fall, then any
  -- upward kick after it (a bounce).
  if gD >= 0 and gD < (GroundRest or 0) + 1 then
    landTouched = true
    landPeak = mmax(landPeak, vDown)
    if landPeak > 0.3 then landBounce = mmax(landBounce, -vDown) end
  end
  local vSet = landSpeedFor(gD, glen, construct.getMass())
  if WaterCheck(vDown) then return end            -- touched water: hover on it
  LandVSet = vSet
  LandAcc = wv * ((vSet - vDown) * 2.0) - g
  -- Brakes help when falling faster than wanted (they work at any height,
  -- the ground engines only once the ground is in range) and kill any
  -- sideways drift over 1 m/s.
  LandBrake = mmax(clamp((vDown - vSet - 0.5) / 3, 0, 1),
                   hSpeed > 0.5 and clamp(hSpeed / 3, 0.1, 1) or 0)   -- (was >1 m/s: drifted off the mark)
  if now() - landStart < 1 then return end      -- let the descent start first
  -- Touchdown: we are ASKING to descend, our own brakes are off, the
  -- pilot isn't braking — and the ship still won't move. Only the ground
  -- can do that. (Brakes alone can hold a ship mid-air, so any braking
  -- resets the timer.)
  local braking = brakeInput > 0 or ParkBrake or LandBrake > 0
  if not braking and mabs(vDown) < 0.2 and vel:len() < 0.5 then
    landSettle = landSettle or now()
  else
    landSettle = nil
  end
  if landSettle and now() - landSettle > 0.7 then done() end
end

-- ── Atlas (per-server) ────────────────────────────────────────────
-- Same lookup as Navigator: autoconf/custom/<name> first, then <name>
-- straight from data/lua, then the game's own atlas as a fallback.
AtlasName = nil
do
  local want = tostring(CustomAtlas or ""):gsub("\\", "/"):gsub("%.lua$", ""):match("^%s*(.-)%s*$")
  local tries = {}
  if want ~= "" and want ~= "atlas" then tries = { "autoconf/custom/"..want, want } end
  tries[#tries+1] = "atlas"
  for _, n in ipairs(tries) do
    local ok, res = pcall(require, n)
    if ok and type(res) == "table" then Atlas, AtlasName = res, n break end
  end
  if want ~= "" and want ~= "atlas" and AtlasName == "atlas" then
    system.print("[HELM] WARNING: custom atlas '"..want.."' not found — using the game default")
  end
end

-- ── Formatting ────────────────────────────────────────────────────
function FormatDist(m)
  if not m then return "---" end
  if m >= 0.5*SU then return string.format("%.2f su", m/SU)
  elseif m >= 1000 then return string.format("%.1f km", m/1000)
  else return string.format("%.0f m", m) end
end
function FormatTime(s)
  if not s or s ~= s or s < 0 or s == math.huge then return "---" end
  if s >= 3600 then return string.format("%dh %02dm", math.floor(s/3600), math.floor((s%3600)/60)) end
  return string.format("%dm %02ds", math.floor(s/60), math.floor(s%60))
end
function Msg(text)
  StatusMsg, StatusUntil = text, now() + 8
  system.print("[HELM] "..text)
end
-- Big centre-screen popup for things a pilot glancing away must notice
-- (Carl: people let the AP fly and watch from the corner of their eye).
-- Radar warnings pop up by themselves (see the HUD); this is for events.
Alert = nil
function ShowAlert(title, text, col, secs)
  Alert = { title = title, text = text, col = col or "#ffc24b", untilT = now() + (secs or 8) }
end

-- ── Fuel (every tank, no links, no lookup table) ──────────────────
-- Confirmed against Carl's tanks in game (2026-11-07):
--   litres   = (current mass − empty mass) ÷ (density × mass talents)
--   capacity = base for the size × 1.5 per tier above basic × handling
-- The core gives every tank's current mass and item; the item gives its
-- empty mass, size and tier. Only the owner's fuel talents are unknown —
-- those are parameters ("fueltalents A S R O C"), saved to the databank.
local FUEL_DENSITY = { atmo = 4, space = 6, rocket = 0.8 }     -- kg per litre, no talents
local FUEL_BASE = {                                             -- litres at basic tier
  atmo   = { xs = 100, s = 400, m = 1600, l = 12800, xl = 25600, xxl = 51200 },
  space  = { xs = 100, s = 400, m = 1600, l = 12800, xl = 25600, xxl = 51200 },
  rocket = { xs = 400, s = 800, m = 6400, l = 50000, xl = 100000, xxl = 200000 },
}
local HANDLING_STEP = { atmo = 0.2, space = 0.2, rocket = 0.1 } -- capacity bonus per handling level

FuelTankList = {}   -- { id, kind, name, cap0 (basic-tier litres incl. tier), dry (kg) }
function ScanFuelTanks()
  FuelTankList = {}
  local okL, ids = pcall(core.getElementIdList)
  if not okL or type(ids) ~= "table" then return end
  for _, id in ipairs(ids) do
    local _, nm = pcall(core.getElementDisplayNameById, id)
    nm = tostring(nm or "")
    local lo = nm:lower()
    if lo:find("fuel tank") then
      local kind = lo:find("rocket") and "rocket" or lo:find("space") and "space" or lo:find("atmo") and "atmo"
      local okI, itemId = pcall(core.getElementItemIdById, id)
      local okG, item = pcall(system.getItem, okI and itemId or 0)
      if kind and okG and type(item) == "table" then
        local size = tostring(item.size or ""):lower()
        local base = FUEL_BASE[kind][size]
        local tier = tonumber(item.tier) or 1
        if base then
          FuelTankList[#FuelTankList+1] = {
            id = id, kind = kind, size = size, tier = tier,
            name = tostring(item.displayNameWithSize or nm),
            -- "Optimised" tanks hold more: Carl's Rare Optimised Atmo XS
            -- (tier 4) shows 583 L base = 100 × 1.5³ × 1.2³, i.e. an
            -- extra 20% per tier above basic (it read "~100%" without this).
            cap0 = base * (FuelTierStep ^ (tier - 1))
                 * ((lo:find("optimi") or tostring(item.displayNameWithSize or ""):lower():find("optimi")) and 1.2 ^ (tier - 1) or 1),
            dry = tonumber(item.unitMass) or 0,
          }
        end
      end
    end
  end
end

-- Per tank: litres, capacity. "over" = more fuel than the talents allow,
-- i.e. the talent parameters are set lower than the owner's real ones.
function TankFuel(t)
  local okM, mass = pcall(core.getElementMassById, t.id)
  local kg = (okM and tonumber(mass) or t.dry) - t.dry
  local massFactor = mmax(1 - 0.05 * (FuelTankOptimization + ContainerOptimization), 0.3)
  local litres = mmax(kg, 0) / (FUEL_DENSITY[t.kind] * massFactor)
  local cap = t.cap0 * (1 + HANDLING_STEP[t.kind] * (TankH[t.kind] or 0))
  local over = litres > cap * 1.02
  return litres, mmax(cap, litres), over
end

-- Burn rate per tank (litres/s), smoothed, keyed by element id so a
-- rescan keeps it. Tanks feed particular engines, so each tank drains at
-- its own pace — the tank that runs dry first is what matters, not the
-- ship total.
local tankRate, tankLast = {}, {}
local function updateRate(id, v)
  local t, last = now(), tankLast[id]
  tankLast[id] = { v = v, t = t }
  if not last or t - last.t < 0.2 then return end
  local r = (last.v - v) / (t - last.t)
  if r < -0.5 then tankRate[id] = 0 return end          -- refuelling: start over
  tankRate[id] = (tankRate[id] or mmax(r, 0)) * 0.85 + mmax(r, 0) * 0.15
end
function TankTimeLeft(id, v)
  local r = tankRate[id] or 0
  if r < 0.02 then return nil end                       -- not really burning
  return v / r
end

Fuel = {}   -- kind → { n, over, tanks = { {pct, v, m, tte} }, lowPct, soonest }
function ReadFuel()
  local sums = {}
  for _, t in ipairs(FuelTankList) do
    local v, m, over = TankFuel(t)
    updateRate(t.id, v)
    local s = sums[t.kind] or { n = 0, over = false, tanks = {}, lowPct = 1, soonest = nil }
    local pct = clamp(v / m, 0, 1)
    local tte = TankTimeLeft(t.id, v)
    s.n, s.over = s.n + 1, s.over or over
    s.tanks[#s.tanks+1] = { pct = pct, v = v, m = m, tte = tte, size = t.size, tier = t.tier }
    if pct < s.lowPct then s.lowPct = pct end
    if tte and (not s.soonest or tte < s.soonest) then s.soonest = tte end
    sums[t.kind] = s
  end
  -- Biggest tanks first, so the HUD bars read left → right by size.
  for _, s in pairs(sums) do table.sort(s.tanks, function(a, b) return a.m > b.m end) end
  Fuel = sums
end

-- "fuelinfo": every tank with litres / capacity / %, to compare with what
-- DU shows when you hover a tank with the refuel tool.
function PrintFuelInfo()
  ScanFuelTanks()
  ReadFuel()
  system.print(string.format("[HELM] %d fuel tanks · talents: %s", #FuelTankList, TalentsText()))
  for _, t in ipairs(FuelTankList) do
    local v, m, over = TankFuel(t)
    local tte = TankTimeLeft(t.id, v)
    system.print(string.format("  %-44s %7.0f / %-7.0f L  %3d%%%s%s", t.name, v, m,
      math.floor(v / m * 100 + 0.5),
      tte and ("  · empty in "..FormatTime(tte)) or "",
      over and "  ← fuel above capacity: talents set too low?" or ""))
  end
  if #FuelTankList == 0 then system.print("[HELM] no fuel tanks found on this construct") end
end

-- ── Radar (linked radars only) ────────────────────────────────────
-- Shows DU's own radar widget for whichever linked radar works where you
-- are (atmo radars only work in atmosphere, space radars only in space)
-- and hides the other. getOperationalState() == 1 means operational.
ActiveRadar, RadarContacts = nil, 0
local shownRadar = nil
function UpdateRadar()
  if #Radars == 0 then return end
  local pick
  for _, r in ipairs(Radars) do
    local ok, s = pcall(function() return r.getOperationalState() end)
    if ok and s == 1 then pick = r break end
  end
  ActiveRadar = pick
  local show = pick or Radars[1]   -- nothing works here: still show one (it says why)
  if show ~= shownRadar then
    for _, r in ipairs(Radars) do
      if r == show then pcall(function() r.showWidget() end) else pcall(function() r.hideWidget() end) end
    end
    shownRadar = show
  end
  RadarContacts = 0
  if pick then
    local ok, ids = pcall(function() return pick.getConstructIds() end)
    if ok and type(ids) == "table" then RadarContacts = #ids end
  end
  UpdateThreats()
end

-- ── Collision warning (radar contacts on our path) ───────────────────
-- Warning only: nothing here touches the controls. Twice a second, for
-- each contact:
--   • if DU gives its world position (identified contacts), use it and
--     its change since last time → relative velocity → closest approach;
--   • otherwise only the distance is known. Treat the contact as standing
--     still: how fast the distance shrinks vs our own speed gives the
--     angle off our path (closing = v·cosθ) → how far off we'd pass it
--     and when. Fine for stations/parked ships; a moving ship is a guess
--     (marked "est").
-- A threat = passes closer than its size + 150 m, within 60 s (or within
-- 3× our braking distance). DANGER = the brakes alone can't stop us short
-- of it any more.
Threat = nil
local radarSeen = {}
-- Rough hull radius from the core class (half the build-zone edge). The
-- full edge was far too big: flying between station elements, every L
-- core counted as "hit" 115-130 m out (Carl's station run).
local CORE_R = { XS = 8, S = 16, M = 32, L = 64, XL = 128 }
local warnedIds = {}
-- "Home" contacts: whatever we sat on / hovered in while (nearly) still,
-- e.g. the pad we take off from (Carl: Pad1 [L] 82 m "TOO CLOSE TO STOP"
-- on every lift-off). Ignored until we're well clear of its zone.
local homeIds = {}
ShipBelow = nil                 -- dynamic construct under us while landing (HUD)
local belowWarned = {}
local function rcall(r, f, ...)
  if not r[f] then return nil end
  local ok, v = pcall(r[f], ...)
  if ok then return v end
  return nil
end
-- Contact at the destination of a surface trip (the pad we land on):
-- within its size + 100 m of the line straight down to the spot. AP.target
-- is the hold point high above, so it can't be used for this (bug: the
-- pad at the spot was never ignored).
function AtDest(wp, Rp)
  local B = AP.surfB
  if not (AP.active and B and AP.target) then return false end
  local dn = norm(AP.target - B.c)
  local rel = wp - B.c
  return rel:dot(dn) > 0 and (rel - dn * rel:dot(dn)):len() < Rp + 100
end
-- Take-off: a construct in front of the ship, close, at about our height
-- (Carl, 1121: the take-off flew into his base as it set off forward —
-- the AP obstacle stop is off during take-offs, and the old pad check
-- warned on every pad field). Needs the contact's world position (own
-- and identified constructs); returns name, distance or nil.
function TakeoffBlocker(pos, h, upW)
  local r = ActiveRadar
  if not r then return nil end
  local ids = rcall(r, "getConstructIds")
  if type(ids) ~= "table" then return nil end
  local docked = {}
  local okD, dl = pcall(construct.getDockedConstructs)
  if okD and type(dl) == "table" then for _, did in ipairs(dl) do docked[did] = true end end
  local okP, par = pcall(construct.getParent)
  if okP and par and par ~= 0 then docked[par] = true end
  local best, bestD
  for i, id in ipairs(ids) do
    if i > 60 then break end
    local d = not docked[id] and rcall(r, "getConstructDistance", id)
    if type(d) == "number" and d < 400 then
      local wp = rcall(r, "getConstructWorldPos", id)
      if type(wp) == "table" and wp[1] and (wp[1] ~= 0 or wp[2] ~= 0 or wp[3] ~= 0) then
        local rel = vec3(wp[1], wp[2], wp[3]) - pos
        local Rp = (CORE_R[rcall(r, "getConstructCoreSize", id) or ""] or 64) + 15
        local vert = rel:dot(upW)
        local hz = rel - upW * vert
        local ahead = hz:dot(h)
        local side = (hz - h * ahead):len()
        -- in front (not behind us), within ~250 m plus its size, its
        -- rough size across our path, and not well below us
        if ahead > 0 and ahead < 250 + Rp and side < Rp + 10 and vert > -Rp
           and (not bestD or d < bestD) then
          best, bestD = rcall(r, "getConstructName", id) or "a construct", d
        end
      end
    end
  end
  return best, bestD
end

function UpdateThreats()
  Threat, ShipBelow = nil, nil
  local r = ActiveRadar
  if not (CollisionWarn and r) then radarSeen = {} return end
  local ids = rcall(r, "getConstructIds")
  if type(ids) ~= "table" then return end
  local C = construct
  local pos, vel = vec3(C.getWorldPosition()), vec3(C.getWorldVelocity())
  local v = vel:len()
  local t = now()
  local brakeD = BrakeDist(v, BrakeAccel(C.getMass()) / BrakeSafety)
  local seen, stopBest = {}, nil
  -- Local "up" near a planet (for the climbing-over check below).
  local Bn = NearestBody(pos)
  local upW = Bn and ((pos - Bn.c):len() < Bn.r * 1.5) and norm(pos - Bn.c) or nil
  -- How much higher the climb can still take us: an atmosphere trip
  -- levels off at its cruise height, so don't count on more than that.
  local T = AP.active and AP.takeoff
  local capGain = (T and T.cruiseR and T.B) and mmax(T.cruiseR - (pos - T.B.c):len(), 0) or nil
  -- Going (mostly) straight down near a planet = landing.
  local vDownNow = upW and -vel:dot(upW) or 0
  local landingNow = upW and vDownNow > 1 and (vel + upW * vDownNow):len() < vDownNow * 1.5 + 5
  local below = nil
  -- Climbing toward a contact that we'll be above (its whole zone) by the
  -- time we get there: not on our path, even though the straight line
  -- along our velocity goes through it. Live: if the climb stops, the
  -- warning comes back on the next check.
  local function climbsOver(rel, Rp)
    if not upW then return false end
    local vUp = vel:dot(upW)
    if vUp < 1 then return false end
    local vert = rel:dot(upW)
    local horiz = rel - upW * vert
    local hd = horiz:len()
    if hd <= Rp then return false end
    local vh = (vel - upW * vUp):dot(horiz / hd)
    if vh < 1 then return false end
    local gain = vUp * (hd - Rp) / vh * 0.7      -- cautious: climbs can ease off
    if capGain then gain = mmin(gain, capGain) end
    return gain - vert > Rp + 10
  end
  -- Ships docked to us (and the one we're docked to) travel with us:
  -- never a threat (Carl, 1114: the carrier's docked AGG elevator was
  -- reported as a ship below).
  local docked = {}
  local okD, dl = pcall(C.getDockedConstructs)
  if okD and type(dl) == "table" then for _, did in ipairs(dl) do docked[did] = true end end
  local okP, par = pcall(C.getParent)
  if okP and par and par ~= 0 then docked[par] = true end
  for i, id in ipairs(ids) do
    if i > 60 then break end                    -- CPU budget
    local d = not docked[id] and rcall(r, "getConstructDistance", id)
    if type(d) == "number" then
      -- Rp = physical size (its core class + ~15 m for us).
      local Rp = (CORE_R[rcall(r, "getConstructCoreSize", id) or ""] or 64) + 15
      if v < 5 and d < Rp + 30 then homeIds[id] = true
      elseif homeIds[id] and d > Rp + 300 then homeIds[id] = nil end
      local prev = radarSeen[id]
      local e = { d = d, t = t }
      local wp = rcall(r, "getConstructWorldPos", id)
      if type(wp) == "table" and wp[1] and (wp[1] ~= 0 or wp[2] ~= 0 or wp[3] ~= 0) then
        e.wp = vec3(wp[1], wp[2], wp[3])
        e.rel = e.wp - pos
      end
      local dt = prev and (t - prev.t) or 0
      -- No lag from our own acceleration: the contact's OWN velocity comes
      -- from its world positions (≈ 0 for stations), and our velocity is
      -- the current one. (Bug: relative velocity measured over 0.5 s,
      -- smoothed, lagged behind a hard-accelerating ship; mixed with the
      -- current speed it put the AP stop point BEHIND the station part.)
      local miss, tCA, alongCA, est
      if dt > 0.2 then
        if e.wp and prev.wp then
          local cv = (e.wp - prev.wp) / dt
          e.cv = prev.cv and (prev.cv * 0.5 + cv * 0.5) or cv
          local vr = e.cv - vel                       -- its motion relative to us
          local vr2 = vr:dot(vr)
          if vr2 > 1 then
            tCA = -e.rel:dot(vr) / vr2
            miss = (e.rel + vr * mmax(tCA, 0)):len()
            alongCA = tCA * msqrt(vr2)
          end
        else
          -- Distance only: compare the closing speed with our own speed
          -- over the SAME interval (both lag equally), assume it's still.
          local c = (prev.d - d) / dt               -- closing speed, m/s
          local sv = (prev.pos and (pos - prev.pos):len() / dt) or v
          e.c = prev.c and (prev.c * 0.5 + c * 0.5) or c
          e.sv = prev.sv and (prev.sv * 0.5 + sv * 0.5) or sv
          if v > 1 and e.sv > 1 then
            local cs = clamp(e.c / e.sv, -1, 1)
            if cs > 0 then
              alongCA = d * cs
              tCA = alongCA / v
              miss = d * msqrt(1 - cs * cs)
            end
          end
          est = true
        end
      end
      e.pos = pos
      seen[id] = e
      -- Ship below while landing (Carl: SAGA said so; warning only).
      -- Dynamic constructs only — the pad/base you land on is static.
      if landingNow and d < 1000 and rcall(r, "getConstructKind", id) == 5 then
        local off, depth
        if e.wp then
          local vert = e.rel:dot(upW)
          if vert < 0 then depth, off = -vert, (e.rel - upW * vert):len() end
        elseif miss and alongCA and alongCA > 0 then
          depth, off = alongCA, miss                 -- distance only: estimate
        end
        if depth and off < Rp + 30 and (not below or depth < below.depth) then
          below = { id = id, depth = depth, off = off, est = not e.wp,
                    name = rcall(r, "getConstructName", id) or "a ship",
                    size = rcall(r, "getConstructCoreSize", id) or "?" }
        end
      end
      -- Not on our path at all: the construct we started from, the one at
      -- the destination spot (surface trips: the pad we're landing on),
      -- or one we're climbing over.
      local skip = homeIds[id]
        or (e.wp and AtDest(e.wp, Rp))
        or (e.wp and climbsOver(e.rel, Rp))
        -- Static construct on a planet (pad, base): count its zone as
        -- LOW — full width, but only half as high above the core. We pass
        -- above that at the closest point: no warning. (Carl, take-off
        -- over his pad field: "Pad1 [L] 81 m ahead · passes ~76 m off —
        -- TOO CLOSE TO STOP", ~60 m above a flat pad.)
        or (upW and e.wp and e.cv and tCA and tCA > 0
            and -(e.rel + (e.cv - vel) * tCA):dot(upW) > (Rp - 15) * 0.5 + 15
            and rcall(r, "getConstructKind", id) == 4)
        -- Distance-only contact (unidentified ship) at or past the landing
        -- spot of a surface trip: e.g. a ship parked by the pad, seen 2.4 km
        -- "ahead" during the descent (Carl, 1111-2103).
        or (not e.wp and alongCA and AP.active and AP.spot
            and alongCA > (AP.spot - pos):len() - Rp - 100)
      if v > 20 and tCA and tCA > 0 and miss and alongCA and not skip then
        -- R adds a warning margin to Rp that grows with speed (3 s of
        -- travel, 30-150 m), so slow flying round a station doesn't flag
        -- every element (Carl, small ship at 150 km/h: everything within
        -- ~280 m warned).
        local R = Rp + clamp(v * 3, 30, 150)
        -- Static constructs (pads, bases) can't move into our path: a
        -- fixed 30 m margin. (Carl, descent: a neighbouring pad 226 m off
        -- the down line warned "CONTACT ON PATH" through the 150 m margin.)
        if rcall(r, "getConstructKind", id) == 4 then R = Rp + 30 end
        local along = d - R
        -- The AP will stop before reaching it (e.g. the station you're
        -- flying to, stopping StopDistance short): nothing to warn about.
        local apStopsFirst = AP.active and AP.remaining and (AP.remaining + 50) < (alongCA - R)
        -- Already alongside and passing clear of its physical size: no
        -- warning (Carl's log: lots of "1 s · passes ~250 m off").
        local passingClear = miss >= Rp and tCA < 3
        -- Already inside its rough size (flying among a station's own
        -- parts): a core position can't tell where its hull is, so the
        -- radar has nothing useful to say — stay quiet.
        if d < Rp then passingClear = true end
        if miss < R and (tCA < 60 or along < brakeD * 3) and not apStopsFirst and not passingClear then
          -- RED only when we'd actually hit it (inside its physical size)
          -- and the brakes can't stop us before reaching it. Was: inside
          -- the warning margin → "BRAKE NOW" 200 m out with 8 m braking.
          local entry = alongCA - msqrt(mmax(Rp * Rp - miss * miss, 0))
          local danger = miss < Rp and entry < brakeD * 1.3 + 10
          -- Nearest stop point over ALL contacts on the path, not just the
          -- one shown: around a station several parts are on the path and
          -- the shown one switches (bug: the AP took that as "path clear").
          local entryR = alongCA - msqrt(mmax(R * R - miss * miss, 0))
          if id ~= AP.ignoreObs and (not stopBest or entryR < stopBest.entryR) then
            stopBest = { id = id, entryR = entryR, dist = d,
                         name = rcall(r, "getConstructName", id) or ("contact "..tostring(id)) }
          end
          if not Threat or tCA < Threat.t then
            Threat = { id = id, name = rcall(r, "getConstructName", id) or ("contact "..tostring(id)),
                       size = rcall(r, "getConstructCoreSize", id) or "?",
                       dist = d, t = tCA, miss = miss, est = est, danger = danger,
                       entryR = entryR }
          end
        end
      end
    end
  end
  radarSeen = seen
  ShipBelow = below
  if below and not belowWarned[below.id] then
    belowWarned[below.id] = true
    system.print(string.format("[HELM] Ship below you: %s [%s] · %s down · ~%s off your line%s",
      below.name, below.size, FormatDist(below.depth), FormatDist(below.off), below.est and " (est)" or ""))
  end
  -- AP flying into it: stop short (CollisionStop). Only while the AP is
  -- in control — manual flight is never taken over (Carl: players hate
  -- scripts grabbing the ship). Stop point = 50 m before the warning zone.
  -- (Not during a take-off / atmosphere trip or the descent: those don't
  -- use the stop point, so it only printed a false "stopping short".)
  if stopBest and AP.active and CollisionStop and not AP.takeoff and not AP.descent then
    local dir = vel / v
    local along = mmax(stopBest.entryR - 50, 0)
    local o = AP.obs
    if not o or along < (o.pt - pos):dot(o.dir) then
      -- First obstacle, or a nearer one: (re)plan the stop in front of it.
      AP.obs = { id = stopBest.id, name = stopBest.name, dist = stopBest.dist, start = pos, dir = dir,
                 pt = pos + dir * along, seen = t }
      if not o then
        Msg(string.format("%s on the AP path (%s ahead) — stopping short", stopBest.name, FormatDist(stopBest.dist)))
      end
    else
      o.seen = t                                 -- something is still on the path
    end
  end
  -- Chat: only the red ones, once per contact (amber stays on the HUD).
  if Threat and Threat.danger and not warnedIds[Threat.id] then
    warnedIds[Threat.id] = true
    system.print(string.format("[HELM] !! Contact on your path: %s [%s] %s ahead · %.0f s · passes ~%s off%s",
      Threat.name, Threat.size, FormatDist(Threat.dist), Threat.t, FormatDist(Threat.miss),
      Threat.danger and " — TOO CLOSE TO STOP" or ""))
  end
end

-- "radar" chat command: what DU's radar tells us about each contact, so we
-- know what the warning can rely on (position or distance only).
function PrintRadar()
  local r = ActiveRadar
  if not r then system.print("[HELM] No working radar here"..(#Radars == 0 and " (none linked)" or "")) return end
  local ids = rcall(r, "getConstructIds") or {}
  system.print(string.format("[HELM] Radar: %d contacts%s", #ids, #ids > 15 and " (first 15)" or ""))
  for i, id in ipairs(ids) do
    if i > 15 then break end
    local wp = rcall(r, "getConstructWorldPos", id)
    local hasPos = type(wp) == "table" and wp[1] and (wp[1] ~= 0 or wp[2] ~= 0 or wp[3] ~= 0)
    local e = radarSeen[id]
    system.print(string.format("[HELM]  %s [%s] kind %s · %s · %s%s%s",
      tostring(rcall(r, "getConstructName", id) or id), tostring(rcall(r, "getConstructCoreSize", id) or "?"),
      tostring(rcall(r, "getConstructKind", id) or "?"),
      FormatDist(rcall(r, "getConstructDistance", id) or 0),
      hasPos and "position OK" or "distance only",
      (function() local x = rcall(r, "isConstructIdentified", id) return (x == true or x == 1) and " · identified" or "" end)(),
      (e and e.c) and string.format(" · closing %.0f m/s", e.c) or ""))
  end
  if Threat then
    system.print(string.format("[HELM] Threat: %s · %.0f s · passes ~%s off%s", Threat.name, Threat.t,
      FormatDist(Threat.miss), Threat.danger and " · TOO CLOSE TO STOP" or ""))
  end
end

-- ── Warp drive ────────────────────────────────────────────────────
-- The destination is picked on the in-game map (Lua can't set it). We
-- show what the drive reports and start the jump on the warp key.
-- getStatus() codes (15 = ready, confirmed by Arch's emergency warp):
local WARP_TEXT = {
  [1] = "no warp drive", [2] = "drive broken", [3] = "WARPING", [4] = "parent warping",
  [5] = "not anchored", [6] = "cooling down", [7] = "PvP cooldown", [8] = "docked ship moving",
  [9] = "no warp cell container", [10] = "planet too close", [11] = "no destination — set it on the map",
  [12] = "destination too close", [13] = "destination too far", [14] = "not enough warp cells",
  [15] = "READY",
}
Warp = { status = nil, text = "", dest = nil, dist = nil, cells = nil, need = nil }
function ReadWarp()
  if not WarpDrive then return end
  local okS, st = pcall(function() return WarpDrive.getStatus() end)
  Warp.status = okS and tonumber(st) or nil
  Warp.text = Warp.status and (WARP_TEXT[Warp.status] or ("status "..Warp.status)) or "?"
  Warp.dest, Warp.dist = nil, nil
  local okW, raw = pcall(function() return WarpDrive.getWidgetData() end)
  if okW and type(raw) == "string" and json then
    local okJ, d = pcall(json.decode, raw)
    if okJ and type(d) == "table" then
      if d.destination and d.destination ~= "Unknown" and d.destination ~= "" then Warp.dest = tostring(d.destination) end
      Warp.dist = tonumber(d.distance)
    end
  end
  local okA, have = pcall(function() return WarpDrive.getAvailableWarpCells() end)
  local okR, need = pcall(function() return WarpDrive.getRequiredWarpCells() end)
  Warp.cells = okA and tonumber(have) or nil
  Warp.need  = okR and tonumber(need) or nil
end
function IsWarping() return Warp.status == 3 or Warp.status == 4 end

-- ── Auto-warp (opt-in: "autowarp on", for this session) ─────────────
-- Carl's rule stands — Helmsman never warps unless asked. With it on, and
-- a warp destination set on the map (scripts can't choose it) that is
-- where the AP is going, the AP warps as soon as the drive says READY,
-- and after the jump carries on to the spot (the existing warp resume).
-- Does the map's warp destination match the AP's destination? By name
-- (the planet / moon the AP is going to), or by distance within 10% for
-- anything else (warp beacons).
function WarpMatches()
  if not (Warp.dest and AP.target) then return false end
  local pos = vec3(construct.getWorldPosition())
  local B = AP.surfB or NearestBody(AP.target)
  if B and (AP.target - B.c):len() < B.r * 5 then
    local wn, bn = Warp.dest:lower(), B.name:lower()
    -- exact name only: "Alioth" is part of "Alioth Moon 4" and "Alioth
    -- Prime", so a part match would warp to the wrong body
    if wn == bn then return true end
  end
  if Warp.dist and Warp.dist > 0 then
    local d = (AP.target - pos):len()
    if mabs(Warp.dist - d) < d * 0.1 then return true end
  end
  return false
end
function AutoWarpTick()
  if not (AutoWarp and WarpDrive and AP.active and AP.target) then return end
  if AP.takeoff or AP.descent or AP.orbit or AP.parkTurn then return end
  if AP.phase == "BRAKING" or AP.phase == "STOPPING" or AP.phase == "OBSTACLE" then return end
  if Warp.status ~= 15 or not WarpMatches() then return end
  if now() - (AutoWarpT or 0) < 10 then return end
  AutoWarpT = now()
  local ok = pcall(function() WarpDrive.initiate() end)
  Msg(ok and ("Auto-warp → "..(Warp.dest or AP.name).." (the AP carries on after the jump — brake to cancel)")
         or "Auto-warp: the warp drive wouldn't start — warp by hand")
end

-- (Warp is started by the game itself on its warp key, Alt+J; the
-- script only shows the drive's state.)

-- ── Planets (from DU's built-in atlas) ────────────────────────────
-- hard = the shell the AP must never enter: atmosphere top, or for
-- airless moons the highest terrain. Every star system in the atlas is
-- included — custom servers don't always put everything in system 0.
Bodies = {}
if Atlas then
  for sysId, sys in pairs(Atlas) do
    if type(sys) == "table" then
      for id, b in pairs(sys) do
        local r = type(b) == "table" and tonumber(b.radius) or 0
        if r > 0 and type(b.center) == "table" then
          local n = b.name; if type(n) == "table" then n = n[1] end
          -- (atlasNC spells it "atmosphericRadius": read as 0, every planet
          -- there looked airless — no air trips, no orbit hop, no burn caps,
          -- routes skimming the ground top. Carl, 1117. Thickness as a last
          -- resort.)
          local atm  = tonumber(b.atmosphereRadius) or tonumber(b.atmosphericRadius) or 0
          if atm <= 0 and (tonumber(b.atmosphereThickness) or 0) > 0 then atm = r + tonumber(b.atmosphereThickness) end
          -- (a NEGATIVE highest ground is an atlas error — the game's own
          -- atlas says -42 m for Alioth Moon 4, so spots on its surface
          -- weren't "on" the moon and every route was "blocked by Alioth
          -- Moon 4" (Carl, 1115-0746). Then use the 5% guess.)
          local sMax = tonumber(b.surfaceMaxAltitude)
          -- (0 too: the custom "Prime" moons in atlasCG1 all say 0)
          if not sMax or sMax <= 0 then sMax = r * 0.05 end
          local surf = r + sMax
          -- Surface gravity × radius² first: the custom "... Prime" bodies
          -- in atlasCG1 carry GM figures 2-60% of the real pull (Thades
          -- Prime 0.07×: the orbit hop crawled at ~330 km/h "orbital"
          -- speed, 1115-0629), while their gravity matches what DU reads.
          local gv = tonumber(b.gravity) or 0
          local gm = (gv > 0 and gv * r * r) or tonumber(b.GM) or 0
          Bodies[#Bodies+1] = { id=id, name=tostring(n or ("body "..tostring(id))), c=V(b.center), r=r, hard=mmax(atm, surf), top=surf, atm=atm, gm=gm,
                                    stat=tonumber(b.maxStaticAltitude), sys=sysId }
        end
      end
    end
  end
end

-- ── ::pos{} parsing ───────────────────────────────────────────────
function ParsePos(s)
  local inner = s and s:match("::pos(%b{})")
  if not inner then return nil, "no ::pos{} found" end
  local n = {}
  for part in inner:sub(2, -2):gmatch("[^,]+") do n[#n+1] = tonumber((part:gsub("%s", ""))) end
  if #n ~= 5 then return nil, "malformed ::pos{}" end
  for i = 1, 5 do if not n[i] then return nil, "malformed ::pos{}" end end
  local sys, body = math.floor(n[1]), math.floor(n[2])
  if body == 0 then return vec3(n[3], n[4], n[5]) end
  local B = Atlas and Atlas[sys] and Atlas[sys][body]
  if not B then return nil, "unknown planet id "..body.." (atlas not loaded?)" end
  local lat, lon = math.rad(n[3]), math.rad(n[4])
  local r, cl = (tonumber(B.radius) or 0) + n[5], math.cos(lat)
  return V(B.center) + vec3(cl*math.cos(lon), cl*math.sin(lon), math.sin(lat)) * r
end

-- ── Route planning around planets ─────────────────────────────────
local function segHit(a, b, c, R)
  local d = b - a
  local dd = d:dot(d)
  local t = dd > EPS and clamp((c - a):dot(d) / dd, 0, 1) or 0
  local p = a + d * t
  return (p - c):len() < R, p, t
end
-- Normal margin is hard+PlanetClearance. If either end of the segment
-- already sits inside that band (leaving low orbit, or a target that
-- holds just above a planet) only the hard shell is enforced, otherwise
-- every such trip would be "blocked" by the planet it starts next to.
local function obstacleR(B, a, b)
  local R = B.hard + PlanetClearance
  -- (+1 km: the hold point over a surface spot sits EXACTLY at hard +
  -- PlanetClearance, so a rounding hair outside counted it as "not near",
  -- the full band then hit the segment's own end, every corner did the
  -- same, and it gave up: "Path blocked by Alioth Moon 4" — Carl, 1115-0742)
  if (a - B.c):len() < R + 1000 or (b - B.c):len() < R + 1000 then R = B.hard + 500 end
  return R
end
local function firstBlock(a, b)
  local best, bt, bp, bR
  for _, B in ipairs(Bodies) do
    local R = obstacleR(B, a, b)
    local hit, p, t = segHit(a, b, B.c, R)
    if hit and (not bt or t < bt) then best, bt, bp, bR = B, t, p, R end
  end
  return best, bp, bR
end
local function plan(a, b, depth)
  local B, p, R = firstBlock(a, b)
  if not B then return { b } end
  if depth >= 4 then return nil, "Path blocked by "..B.name.." — fly clear of it and try again" end
  local n = norm(p - B.c)
  if n:len() < EPS then
    n = norm((b - a):cross(vec3(0, 0, 1)))
    if n:len() < EPS then n = norm((b - a):cross(vec3(1, 0, 0))) end
  end
  local wp = B.c + n * (R * 1.25)
  local L, e1 = plan(a, wp, depth + 1); if not L then return nil, e1 end
  local Rt, e2 = plan(wp, b, depth + 1); if not Rt then return nil, e2 end
  for _, q in ipairs(Rt) do L[#L+1] = q end
  return L
end
function SegmentClear(a, b) return firstBlock(a, b) == nil end
function InsideBody(p)
  for _, B in ipairs(Bodies) do if (p - B.c):len() < B.hard then return B end end
  return nil
end

-- ── Ship capability (refreshed twice a second) ────────────────────
function RefreshShipStats()
  local ok, v = pcall(construct.getMaxSpeed)
  if ok and v and v > 0 then MaxSpeedMS = v end
  ok, v = pcall(construct.getMaxBrake)
  if ok and v and v > 0 then
    MaxBrakeN = v   -- keep last good value
    -- Remember what DU reports in each environment (for the `brakes` command).
    if (unit.getAtmosphereDensity() or 0) > 0.0001 then BrakeSeenAtmo = v else BrakeSeenSpace = v end
  end
  ok, v = pcall(construct.getMaxThrustAlongAxis, "thrust analog longitudinal", construct.getOrientationForward())
  if ok and type(v) == "table" then
    local inAtmo = (unit.getAtmosphereDensity() or 0) > 0.0001
    MaxThrustN = (inAtmo and v[1]) or (v[3] and v[3] > 0 and v[3]) or v[1] or 0
  end
end
-- ── Engine survey: how hard can we push in each of the 6 directions? ──
-- getMaxThrustAlongAxis returns {atmo +, atmo -, space +, space -} for a
-- construct-local axis. "Up" = engines that push the ship upward.
local function fmtN(n)
  if n >= 1e6 then return string.format("%.1f MN", n/1e6) end
  if n >= 1 then return string.format("%.0f kN", n/1000) end
  return "none"
end
function SurveyThrust()
  local atmo = (unit.getAtmosphereDensity() or 0) > 0.0001
  local function along(tags, axis)
    local ok, t = pcall(construct.getMaxThrustAlongAxis, tags, axis)
    if not ok or type(t) ~= "table" then return 0, 0 end
    return mabs(t[atmo and 1 or 3] or 0), mabs(t[atmo and 2 or 4] or 0)
  end
  local T = { atmo = atmo }
  -- Engines only: stabilizers and wings are tagged "thrust analog" too,
  -- and DU reports part of their lift as push (Carl's hovercraft: "Back
  -- 10-22 kN · Left 38 kN" with no such engines — tilted stabilizers; the
  -- approach then planned with back engines it didn't have). Front/back:
  -- the "longitudinal" tag, which only engines carry (the main-thrust
  -- reading has always used it). Sides / up-down: engines tagged per axis
  -- and "fueled" — hovers and vertical boosters included. (A "fueled"
  -- query with a fallback to all tags fell back now and then.)
  T.F, T.B = along('thrust analog longitudinal', construct.getOrientationForward())
  T.R, T.L = along('thrust analog lateral fueled', construct.getOrientationRight())
  T.U, T.D = along('thrust analog vertical fueled', construct.getOrientationUp())
  T.G = along('ground', construct.getOrientationUp())
  T.K = along('rocket_engine', construct.getOrientationForward())   -- rockets (on/off boost, B)
  T.weight = construct.getMass() * vec3(core.getWorldGravity()):len()
  Thrust = T
  return T
end
-- Down-facing engines' real push here, hovers / vertical boosters left out
-- (they only reach ~15-45 m down). DU reports the full sea-level figure at
-- any height (Carl, 1113: 'Up' the same at 1.6 km and on the ground), but
-- atmo engines lose push as the air thins — faster than the density
-- itself. Measured (Carl, 1113): 10.9 MN of up engines held a 3.9 MN ship
-- only down at 64% density (push x density said 36%); 8.1 MN on 4.0 MN
-- sank steadily at 51%. Push x density² fits both. Newtons.
function UpEngN(T)
  T = T or Thrust
  if not T then return 0 end
  local n = mmax((T.U or 0) - (T.G or 0), 0)
  if T.atmo then n = n * clamp(unit.getAtmosphereDensity() or 0, 0, 1) ^ 2 end
  return n
end
-- Safe mass, ArchHUD's rule of thumb: half of what each set of engines /
-- the brakes could hold against gravity here (2:1). The lowest one is the
-- limit. Shown on the FLIGHT panel while landed / parked; "mass" lists all.
local function fmtT(kg)
  if kg >= 1e6 then return string.format("%.1f kt", kg / 1e6) end
  return string.format("%.0f t", kg / 1000)
end
function SafeMass()
  local C = construct
  local pos = vec3(C.getWorldPosition())
  local g = vec3(core.getWorldGravity()):len()
  -- (AGG on: the reading drops toward 0 — use the planet's real pull)
  local B = NearestBody(pos)
  if B and B.gm and (pos - B.c):len() < B.hard + 1000 then g = mmax(g, B.gm / (pos - B.c):len() ^ 2) end
  if g < 0.1 then g = 9.80665 end
  local function ax(tags, dir)
    local ok, t = pcall(C.getMaxThrustAlongAxis, tags, dir)
    if ok and type(t) == "table" then return mabs(t[1] or 0), mabs(t[3] or 0) end
    return 0, 0
  end
  local fA, fS = ax('thrust analog longitudinal', C.getOrientationForward())
  local hA = ax('ground', C.getOrientationUp())
  local list = {
    { "atmo engines", 0.5 * fA / g }, { "space engines", 0.5 * fS / g },
    { "hovers", 0.5 * hA / g }, { "brakes", 0.5 * (MaxBrakeN or 0) / g } }
  local low
  for _, e in ipairs(list) do if e[2] > 0 and (not low or e[2] < low[2]) then low = e end end
  return low, list, C.getMass()
end

-- Rockets: on/off only, through DU's booster toggle (B does the same).
RocketOn, RocketByAP, RocketTest = false, false, nil
function SetRockets(on, msg)
  if on == RocketOn then return end
  Nav:toggleBoosters()
  RocketOn, RocketByAP = on, on
  if msg then Msg(msg) end
end

function PrintThrust()
  local T = SurveyThrust()
  -- "Up" = real up engines only. Hovers / vertical boosters only push
  -- within ~15 m of the ground, and counting them in "Up" hid that a ship
  -- had no up engines at all (the carrier read "Up 895.8 MN", all hovers).
  local upFull = mmax((T.U or 0) - (T.G or 0), 0)
  local hov = (T.G or 0) > 0 and (" (+ "..fmtN(T.G).." hover/VBoost, ground range only)") or ""
  system.print("[HELM] Thrust ("..(T.atmo and "atmo" or "space").."):  Fwd "..fmtN(T.F).." · Back "..fmtN(T.B)..
    " · Left "..fmtN(T.L).." · Right "..fmtN(T.R).." · Up "..fmtN(upFull)..hov.." · Down "..fmtN(T.D)..
    ((T.K or 0) > 0 and (" · Rockets "..fmtN(T.K)) or ""))
  system.print("[HELM] Weight here "..fmtN(T.weight))
  if T.atmo and upFull > 0 and T.weight > 0 then
    local need = T.weight / upFull
    system.print(string.format("[HELM] Up engines (no hovers) %s at sea level, ~%s here · %s",
      fmtN(upFull), fmtN(UpEngN(T)),
      need > 1 and "can't hold the ship up on their own anywhere"
        or string.format("hold the ship up where the air is over ~%.0f%% (now %.0f%%)", msqrt(need) * 100,
          (unit.getAtmosphereDensity() or 0) * 100)))
  end
end
-- Warnings that matter for Maneuver mode; returns nil when all is well.
function ManeuverWarning()
  local T = Thrust or SurveyThrust()
  local miss = {}
  for _, k in ipairs({ {"F","fwd"}, {"B","back"}, {"L","left"}, {"R","right"}, {"U","up"}, {"D","down"} }) do
    if T[k[1]] < 1 then miss[#miss+1] = k[2] end
  end
  -- (hovers don't count: they only hold within their range of the ground)
  if T.weight > 1 and UpEngN(T) < T.weight then
    return "Up engines "..fmtN(UpEngN(T)).." here < weight "..fmtN(T.weight)..
      " — can't hold height away from the ground"..(T.atmo and " (they get weaker as the air thins)" or "")
  end
  if #miss > 0 then return "No thrust: "..table.concat(miss, ", ") end
  return nil
end

-- ── Altitude hold (Flight mode, hand flying in the atmosphere) ──
-- altM: metres above sea level; nil = the height we're at now.
AltHold, AltHoldOn, AltHoldLast = nil, false, nil
function AltHoldSet(altM, here)
  if here then AltHoldLast = nil end
  if AP.active then Msg("The autopilot is flying — altitude hold is for hand flying") return end
  if Mode ~= 1 then Msg("Altitude hold is for Flight mode (Maneuver mode holds its own height)") return end
  if OnGround or HoverState == "landed" then Msg("Altitude hold is for flying — take off first") return end
  local pos = vec3(construct.getWorldPosition())
  local B = NearestBody(pos)
  if not B or (unit.getAtmosphereDensity() or 0) <= 0.0001 then Msg("Altitude hold works in the atmosphere only") return end
  -- (no altitude given: the last height held this time in the seat, on
  -- this planet — Carl: after a turn flown by hand, Alt+7 brings it back to
  -- the height you were flying instead of wherever the turn left you.
  -- Kept in memory only: it's gone when you leave the seat, nothing saved.)
  local R = altM and (B.r + altM) or (AltHoldLast and AltHoldLast.B == B and AltHoldLast.R) or (pos - B.c):len()
  local keep = AltHold and AltHold.B == B and AltHold.trim
  AltHold = { B = B, R = R, trim = keep or nil }
  AltHoldLast = { B = B, R = R }
  local note = ""
  if R < (B.top or B.r) + 200 then note = " — careful: below "..B.name.."'s highest ground ("..string.format("%.0f m", (B.top or B.r) - B.r)..")" end
  Msg(string.format("Altitude hold ON: %.0f m%s (Alt+7 off · \"alt N\" changes it · steering and throttle are yours)", R - B.r, note))
end
function AltHoldOff(why)
  if not AltHold then return end
  AltHold, AltHoldOn = nil, false
  Msg("Altitude hold off"..(why and (" — "..why) or ""))
end

function SetMode(m)
  Mode = (m == 2) and 2 or 1
  if Mode == 2 then AltHoldOff("Maneuver mode") end
  ManHoldPos = nil
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)   -- never inherit a throttle
  if Mode == 2 then
    local w = ManeuverWarning()
    Msg("MANEUVER mode"..(w and ("  —  "..w) or "  —  all directions OK")..
        (HoverOn and "" or "  ·  G to lift off"))
  else
    Msg("FLIGHT mode")
  end
end

function CruiseCap()
  local cap = MaxSpeedMS * 0.99
  if MaxCruiseSpeed and MaxCruiseSpeed > 0 then cap = mmin(cap, MaxCruiseSpeed / 3.6) end
  return cap
end
-- BrakeK: how much of DU's reported brake force the ship REALLY gets,
-- measured while the AP brakes (1 = exactly as reported). Learned on the
-- databank, so later stops plan with the real number from the start.
function BrakeAccel(mass) return mmax(MaxBrakeN / mmax(mass, 1) * BrakeSafety * BrakeK, 0.1) end

-- Plain stopping kinematics (a0 = brake deceleration). Servers differ
-- in top speed (Carl's ship: 49 500 km/h), so no speed-of-light model is
-- assumed: instead the brakes are MEASURED per speed band (below) and the
-- AP plans with the weakest band seen, whatever the server does.
function BrakeDist(v, a0) return v * v / (2 * mmax(a0, 0.01)) end
function BrakeVmax(d, a0) return msqrt(2 * mmax(a0, 0.01) * mmax(d, 0)) end

-- Called every AP tick while braking: speed actually lost vs what DU's
-- brake force (± gravity) says should be lost, kept per 5 000 km/h band
-- so we can see whether brakes get weaker at high speed.
local BAND = 5000 / 3.6
function BrakeMeasure(vel, speed, mass)
  local t = system.getArkTime()
  local bk = AP.bk
  -- Engines running (KILL DRIFT at a corner brakes AND thrusts while the
  -- nose swings round) also change the speed, which read as "weak brakes"
  -- (66% at the moon corner). Measure only on pure braking, starting 1 s
  -- after the engines were last asked for anything (they spool down).
  if bk and ((AP.accel or 0) > 0.05 or AP.phase == "KILL DRIFT") then bk.engT = t end
  if bk and AP.brake == 1 and bk.lastT and speed > 30 and bk.lastSpeed > 30
     and t - (bk.engT or -1e9) > 1 then
    local dt = t - bk.lastT
    if dt > 0 and dt < 0.5 then
      local g = vec3(core.getWorldGravity())
      local raw = MaxBrakeN / mmax(mass, 1)
      local expect = raw - g:dot(vel / speed)
      -- Only while the brake command is saturated: at low speed DU's
      -- command (brakeSpeedFactor·v + flat) asks for less than full brake
      -- on purpose, which would read as "weak brakes".
      local full = brakeSpeedFactor * speed + brakeFlatFactor >= raw * 1.2
      if expect > 0.1 and full then
        bk.raw = raw
        local i = math.floor(speed / BAND)
        local b = bk.bands[i]
        if not b then b = { dv = 0, exp = 0, time = 0 }; bk.bands[i] = b end
        b.dv, b.exp, b.time = b.dv + (bk.lastSpeed - speed), b.exp + expect * dt, b.time + dt
        bk.time = bk.time + dt
        -- Weakest band with at least 1 s of data = what we plan with.
        local worst
        for _, x in pairs(bk.bands) do
          if x.time >= 1 then
            local r = x.dv / x.exp
            if not worst or r < worst then worst = r end
          end
        end
        if worst then
          bk.ratio = worst
          BrakeK = clamp(worst, 0.3, 1)   -- use it straight away
        end
      end
    end
  end
  if bk then bk.lastT, bk.lastSpeed = t, speed end
end
-- Per-band lines for the stop report / brakes command.
function BrakeBandLines()
  local bk, out = AP.bk, {}
  if not (bk and bk.bands) then return out end
  local keys = {}
  for i in pairs(bk.bands) do keys[#keys+1] = i end
  table.sort(keys, function(x, y) return x > y end)
  for _, i in ipairs(keys) do
    local b = bk.bands[i]
    if b.time >= 0.3 then
      out[#out+1] = string.format("%5d-%d km/h: %3.0f%%  (%.0f m/s² measured, %.1f s)",
        i * 5000, (i + 1) * 5000, b.dv / b.exp * 100, b.dv / b.time, b.time)
    end
  end
  return out
end

-- Save what was learned (only after a real braking run).
function BrakeLearnSave()
  local bk = AP.bk
  if bk and bk.ratio and bk.time >= 3 then
    BrakeK = clamp(bk.ratio, 0.3, 1)
    DbSetNum(PK("sf_brake_k3"), string.format("%.3f", BrakeK))
  end
end

-- Time to cover d metres from along-track speed v0, accelerating at aa,
-- capped at vmax, and braking at ab to a stop.
function CalcETA(d, v0, vmax, aa, ab)
  if d <= 0 then return 0 end
  v0, aa = mmax(v0, 0), mmax(aa, 0.01)
  if v0*v0 / (2*ab) >= d then return 2*d / mmax(v0, 0.1) end
  local vp = msqrt((2*d + v0*v0/aa) / (1/aa + 1/ab))
  if vp > vmax then
    local da = mmax(0, vmax*vmax - v0*v0) / (2*aa)
    local db = vmax*vmax / (2*ab)
    return mmax(0, vmax - v0)/aa + mmax(0, d - da - db)/vmax + vmax/ab
  end
  return (vp - v0)/aa + vp/ab
end

-- ── Target handling ───────────────────────────────────────────────
function SaveTarget()
  if not NavDB then return end
  -- No target = "none", not "": after "Trip done — target cleared" the old
  -- target still came back on sit-down (Carl, 1120), so a write of "" over
  -- a value doesn't seem to stick. "none" has no ::pos, so nothing loads.
  pcall(NavDB.setStringValue, "sf_target", AP.target and (AP.name.."|"..AP.posStr..
    (AP.hdg and string.format("|hdg=%.1f", AP.hdg) or "")) or "none")
end

-- Surface targets become a hold point straight ABOVE the spot. Stopping
-- StopDistance short of that left the ship ~1 km to the side of the spot
-- (Carl: the down line should hit the centre of the destination), so for
-- those the AP stops ON the hold point.
function StopDist() return AP.surface and 0 or StopDistance end
-- Arrival window. Distance can't go below 0, so with a stop distance of 0
-- "remaining <= 0" was never met after the slightest overshoot and the AP
-- hunted back and forth round the point (Carl, moon spot). Surface targets
-- count as arrived within 25 m; the brakes then stop the ship there.
function ArriveTol() return AP.surface and 25 or 0 end

-- Parking heading on a destination: "...::pos{...}|hdg=135" (compass
-- degrees: 0 = north = toward the planet's pole (+Z, the axis ::pos
-- latitude uses), 90 = east). Navigator adds it to nav_ap_dest.
function ParseHdg(s)
  local h = s and tonumber(s:match("hdg%s*=%s*(%-?[%d%.]+)"))
  return h and (h % 360) or nil
end

-- Level direction for compass heading hdg at "up" upW (nil near a pole).
function HeadingVec(hdg, upW)
  local Z = vec3(0, 0, 1)
  local n = Z - upW * Z:dot(upW)
  if n:len() < 0.05 then return nil end
  n = n / n:len()
  local e = n:cross(upW)                     -- east (toward +longitude)
  local a = math.rad(hdg)
  return n * math.cos(a) + e * math.sin(a)
end

-- Compass heading (0-360) of the ship's nose, nil near a pole / nose up.
function HeadingOf(fwd, upW)
  local Z = vec3(0, 0, 1)
  local n = Z - upW * Z:dot(upW)
  local f = fwd - upW * fwd:dot(upW)
  if n:len() < 0.05 or f:len() < 0.05 then return nil end
  n, f = n / n:len(), f / f:len()
  local e = n:cross(upW)
  return math.deg(math.atan(f:dot(e), f:dot(n))) % 360
end

-- The construct's centre of mass in world coordinates (nil if DU won't say).
function ComWorld()
  local C = construct
  local ok, m = pcall(C.getWorldCenterOfMass)
  if ok and type(m) == "table" and (m[1] or m.x) then return V(m) end
  ok, m = pcall(C.getCenterOfMass)                 -- local: x right, y forward, z up
  if ok and type(m) == "table" and (m[1] or m.x) then
    m = V(m)
    return vec3(C.getWorldPosition()) + vec3(C.getWorldOrientationRight()) * m.x
         + vec3(C.getWorldOrientationForward()) * m.y + vec3(C.getWorldOrientationUp()) * m.z
  end
  return nil
end

function SetTarget(name, posStr, hdg)
  local descentR
  local aggPlan
  local p, err = ParsePos(posStr)
  if not p then Msg("Bad location: "..err) return false end
  local note
  local spot, trustedR, mapPick = nil, nil, nil
  local B = InsideBody(p)
  -- (a spot a little above the atlas' highest ground is still ON that
  -- body — atlas heights aren't always right)
  if not B then
    for _, Bb in ipairs(Bodies) do
      if (p - Bb.c):len() < Bb.top + 5000 then B = Bb break end
    end
  end
  if B then
    -- The AP flies to a hold point above the spot (then descends if AutoLand).
    local up = norm(p - B.c)
    note = "stops above "..B.name
    -- The DU map often gives the body's CENTRE when you pick a planet or
    -- moon. "Above the centre" has no direction, so use the side facing
    -- the ship (closest, and no trip round the body).
    if (p - B.c):len() < B.r * 0.05 or up:len() < EPS then
      local sp = vec3(construct.getWorldPosition())
      up = norm(sp - B.c)
      if up:len() < EPS then up = vec3(0, 0, 1) end
      note = "centre of "..B.name.." picked — stops above the side facing you"
    end
    -- Fast descent ends DescentHeight (100 m) above the spot when its altitude can be
    -- trusted (saved/pasted from the ground: above sea level). Altitude 0
    -- or less is typical of map picks, so then only down to the atlas
    -- highest terrain + 300 m; the landing's sensors do the rest.
    local spotR = (p - B.c):len()
    if note:find("centre of", 1, true) then
      descentR = nil                                  -- no real spot: no auto-descent
    elseif spotR > B.r + 1 then
      descentR = spotR + mmax(tonumber(DescentHeight) or 100, 30)
      trustedR = spotR
    else
      descentR = B.top + 300
      mapPick = B
    end
    -- Say what will actually happen (Carl: "stops in space" showed even
    -- for a spot saved on the ground, which lands on it).
    if descentR and AutoLand then
      note = mapPick and ("map pick — lands on "..B.name..", finds the ground on the way down")
                      or ("lands on the spot on "..B.name)
    elseif descentR then
      note = "stops above the spot on "..B.name.." (AutoLand off — G to land)"
    end
    spot = p
    p = B.c + up * (B.hard + PlanetClearance)
    -- AGG on: stay in the air at the AGG's height over the spot.
    aggPlan = AggTripPlan(B, trustedR, mapPick ~= nil)
    if aggPlan then note = AggTripNote(aggPlan, trustedR) end
  end
  local wasActive = AP.active
  if wasActive then APDisengage(nil) end
  AP.spotR = trustedR               -- spot height we can trust (nil = unknown)
  AP.mapPick = mapPick ~= nil
  AP.agg = nil                      -- AGG trip plan: decided at engage (the AGG may be switched meanwhile)
  name = (name and name:match("^%s*(.-)%s*$")) or ""
  AP.target, AP.posStr, AP.note = p, posStr:match("::pos%b{}"), note
  AP.surface, AP.surfB, AP.descentR, AP.descent = B ~= nil, B, descentR, false
  AP.spot = spot                    -- the surface spot itself (AP.target is the point above it)
  AP.hdg = B and hdg or nil         -- parking heading (surface spots only)
  AP.parkTurn = nil
  AP.name = name ~= "" and name or "Pasted location"
  AP.legs, AP.leg = nil, 1
  AP.lastObsId, AP.obs = nil, nil   -- new target: an old "carry on anyway" doesn't carry over
  system.setWaypoint(AP.posStr)
  SaveTarget()
  Msg("Target: "..AP.name..(note and ("  ("..note..")") or "")..
      (AP.hdg and string.format(" · parks facing %.0f°", AP.hdg) or ""))
  -- Map picks have no ground height (altitude 0): say what that means
  -- (Carl: "tell the pilot what is going on with a map pick").
  -- (not on an AGG trip: there's no descent — Carl, 1114 carrier test)
  if mapPick and AutoLand and not aggPlan then
    system.print(string.format("[HELM] Map pick: no ground height for this spot, so the fast descent stops %s up (300 m over %s's highest terrain); %s",
      FormatDist(mapPick.top + 300 - mapPick.r), mapPick.name,
      #GroundEngines > 0 and "below that it comes down slowly, steering onto the spot, until the hovers see the ground"
                          or "then the normal landing comes down slowly (no hovers/boosters to see the ground)"))
  end
  -- Never leave the ship coasting: a new target mid-flight re-plans and
  -- keeps flying (if that fails, brakes go on).
  -- (true: the pilot already had the AP on, e.g. a new Navigator stop
  -- arriving mid-climb must not stop the take-off.)
  if wasActive and not APEngage(true) then ParkBrake = true end
  return true
end

function ClearTarget(msg)
  if AP.active then APDisengage(nil) end
  AP.warpResume = nil
  AP.target, AP.name, AP.posStr, AP.note, AP.legs = nil, "", "", nil, nil
  -- setWaypoint("") makes DU print "Invalid destination:"; clear properly if the API allows
  if system.clearWaypoint then pcall(system.clearWaypoint, false) end
  SaveTarget()
  Msg(msg or "Target cleared")
end

-- Trip finished at the spot: clear the target, so sitting down later
-- doesn't put the old (already reached) point back over a new map
-- waypoint (Carl, 1119). Not after an early stop (brake, take-over,
-- obstacle): then Alt+1 still carries on.
function TripDone()
  if AP.target and not AP.active then ClearTarget("Trip done — target cleared") end
end

-- ── Autopilot engage / disengage ──────────────────────────────────
-- allowTakeoff: only the pilot's own Alt+1 / "ap" / "go" may start a
-- take-off from a planet. Navigator's Auto Fly, a pasted ::pos and the
-- warp resume never lift a parked ship off by themselves.
function APEngage(allowTakeoff)
  if not AP.target then Msg("No target — paste a ::pos{...} into Lua chat") return false end
  AltHoldOff("autopilot engaged")
  AP.descent, AP.takeoff, AP.orbit, AP.parkTurn = false, nil, nil, nil
  local pos = vec3(construct.getWorldPosition())
  -- AGG trip? Only from inside the same planet's atmosphere (a trip from
  -- space or another planet arrives the normal way).
  AP.agg, AP.aggDescent = nil, nil
  if AP.surfB then
    local B = AP.surfB
    if NearestBody(pos) == B and (pos - B.c):len() < (B.atm or 0) then
      local why
      AP.agg, why = AggTripPlan(B, AP.spotR, AP.mapPick)
      if AP.agg then AP.note = AggTripNote(AP.agg, AP.spotR)
      elseif why then Msg("AGG on, but a normal trip: "..why) end
    end
  end
  -- Already above the surface spot (e.g. braked during the descent, Alt+1
  -- again): carry on down instead of refusing for being in atmosphere.
  if CanDescend() then StartDescent() return true end
  -- Already in orbit round the target's planet: keep going round (orbit
  -- hop) or take the space route — never the take-off, which treats the
  -- thin top of the air as "on the planet" and heads down to the cruise
  -- height (Carl: in orbit 0.6 su from the spot, Alt+1 started back down).
  local orbiting = OrbitNow(pos)
  if not orbiting and ((unit.getAtmosphereDensity() or 0) > 0.0001 or InsideBody(pos)) then
    if not allowTakeoff then Msg("Target set — Alt+1 to take off") return false end
    -- Under water: rise to the surface under control first, then take off
    -- from hover height there (LIFT waits for the hovers to reach hover
    -- height, and under water they read 0 — Carl: AP from the seabed).
    do
      local Bs = NearestBody(pos)
      if Bs and (Bs.atm or 0) > 0 and (pos - Bs.c):len() - Bs.r < -3 then
        if ParkHold then ParkRelease(nil) end
        ParkBrake, WaterHold = false, nil
        SetHover(true)
        Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()
        UwRise, UwStabOff, TakeoffAfterRise = true, true, true
        Msg("Under water — rising to the surface first, then taking off to "..AP.name.." (brake to stop)")
        return true
      end
    end
    return StartTakeoff()
  end
  RefreshShipStats()
  if MaxBrakeN <= 0 then Msg("No brakes detected — the AP needs brakes to stop") return false end
  if (AP.target - pos):len() <= StopDist() + 50 then Msg("Already at "..AP.name) return false end
  if StartOrbitHop(pos, orbiting) then return true end
  -- Above the air but under the hold point over a spot on this planet:
  -- stop at our own height instead (same rule as the orbit hop), when the
  -- straight line there is clear. Carl, 1118: the ECU held the ship at
  -- ~8 km near the spot, Alt+1 climbed straight up to 16 km to come back
  -- down — fuel wasted.
  do
    local B = AP.surfB
    if B and AP.descentR and not AP.agg and NearestBody(pos) == B then
      local R0 = (AP.target - B.c):len()
      local dist = (pos - B.c):len()
      -- (no "air top + 2 km" floor: we're already above the air here, and
      -- that floor still climbed Carl from 7.6 to 8.4 km — build 2004)
      local Rlow = mmax(dist, AP.descentR + 500)
      -- (straight line blocked — on a longer trip it dips into the air /
      -- curve of the planet: Carl, 1120, 56 km from 6.1 km up still went
      -- to the 16 km hold point. Then the lowest point over the spot, in
      -- 500 m steps, that the straight line clears.)
      local Rtry = Rlow
      while Rtry < R0 - 50 do
        local low = B.c + norm(AP.target - B.c) * Rtry
        if SegmentClear(pos, low) then
          AP.target = low
          Msg(string.format("%s (%s) over %s — no climb to the hold point",
            Rtry == Rlow and "Staying at this height" or "Heading for a lower point", FormatDist(Rtry - B.r), AP.name))
          break
        end
        Rtry = Rtry + 500
      end
    end
  end
  local legs, err = plan(pos, AP.target, 0)
  if not legs then Msg(err) return false end
  AP.legs, AP.leg = legs, 1
  AP.bk = { time = 0, bands = {} }
  AP.minRemaining, AP.approachDir, AP.aimOff, AP.latFix, AP.maxPast = nil, nil, vec3(), false, nil
  AP.kdOn = false
  -- Alt+1 right after an obstacle stop = "carry on anyway": ignore that
  -- one contact for this trip.
  AP.obs, AP.ignoreObs = nil, AP.lastObsId
  AP.lastObsId = nil
  local total, prev = 0, pos
  for _, q in ipairs(legs) do total = total + (q - prev):len(); prev = q end
  AP.total = total
  if ParkHold then ParkHold = nil end   -- AP takes over from a park hold
  AP.active, AP.phase = true, "ALIGN"
  ParkBrake = false
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  Msg("AP engaged → "..AP.name.."  "..FormatDist(total)..
      (#legs > 1 and ("  (routing around "..(#legs-1).." planet"..(#legs > 2 and "s" or "")..")") or ""))
  return true
end

function APDisengage(reason)
  if not AP.active then return end
  BrakeLearnSave()
  AP.active, AP.phase, AP.accel, AP.brake, AP.angVel = false, "OFF", 0, 0, vec3()
  AP.descent, AP.takeoff, AP.orbit, AP.parkTurn = false, nil, nil, nil
  if RocketByAP then SetRockets(false) end
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  if reason then Msg("AP off — "..reason) end
end

function APArrive()
  local d = (AP.target - vec3(construct.getWorldPosition())):len()
  local kBefore = BrakeK
  BrakeLearnSave()
  local bk = AP.bk
  if bk then
    -- Stop report: lets Carl see whether DU's brake number matched reality.
    local closest = (AP.minRemaining or (d - StopDist())) + StopDist()
    local over = mmax(0, StopDist() - closest)
    system.print(string.format("[HELM] Stop report: aimed to stop %s out · closest %s · stopped %s out%s",
      FormatDist(StopDist()), FormatDist(closest), FormatDist(d),
      over > 1 and (" · overshot by "..FormatDist(over)) or " · no overshoot"))
    if AP.approachDir then
      -- Split the miss: along the approach line vs off to the side.
      local off = AP.target - vec3(construct.getWorldPosition())
      local along = off:dot(AP.approachDir)
      local side = (off - AP.approachDir * along):len()
      local mp = AP.maxPast or 0
      system.print(string.format("[HELM]   approach line: furthest %s · off to the side at the end: %s",
        mp > 1 and (FormatDist(mp).." past the stop point") or "never passed the stop point", FormatDist(side)))
    end
    if AP.surfB then
      -- Surface spot: what matters is how far off the down line we are.
      local dn = norm(AP.target - AP.surfB.c)
      local off = vec3(construct.getWorldPosition()) - AP.target
      local h = (off - dn * off:dot(dn)):len()
      system.print(string.format("[HELM]   off the down line: %s · %s %s the hold point",
        FormatDist(h), FormatDist(mabs(off:dot(dn))), off:dot(dn) >= 0 and "above" or "below"))
    end
    if bk.ratio then
      system.print(string.format("[HELM]   brakes vs DU's %.0f m/s², by speed (%.0f s of braking):", bk.raw or 0, bk.time))
      for _, l in ipairs(BrakeBandLines()) do system.print("[HELM]     "..l) end
      system.print(string.format("[HELM]   brake factor %.2f → %.2f%s", kBefore, BrakeK,
        NavDB and " (saved)" or " (no databank — resets on restart)"))
    else
      system.print("[HELM]   not enough braking to measure (needs 3 s above 30 m/s)")
    end
  end
  AP.active, AP.accel, AP.brake, AP.angVel = false, 0, 0, vec3()
  AP.phase = "ARRIVED"
  ParkBrake = true
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  Msg("Arrived: "..AP.name.."  ("..FormatDist(d).." out, brakes held)")
end

-- Roll toward wings-level about the nose (wv = world down). atan2 so a
-- ship that is upside down rolls over promptly; asin read ~0 there and
-- it only slowly tipped over (Carl: "it is staying upside down").
-- Nothing when the nose points nearly straight up/down (roll undefined).
function RollLevelAV(fwd, right, up, wv)
  if mabs(fwd:dot(wv)) > 0.9 then return vec3() end
  local err = math.atan(right:dot(wv), -up:dot(wv))   -- + = right wing low
  return fwd * RollRate(err, fwd)
end

-- Turn-rate softening for ships that answer the controls late. A heavy
-- ship keeps turning after it's told to stop and swings past the wanted
-- angle (Carl, 1114: the L-core carrier lining up turned flat past the
-- heading twice before it settled). Each time it swings through the
-- wanted angle while still turning fast, that axis's gain drops 30%
-- (down to 35%) for the rest of the session — ships that settle cleanly
-- never trigger it. axis: world axis it turns about (to read its rate).
SoftK = { roll = 1, yaw = 1 }
local softPrev = {}
function SoftGain(key, err, axis, label)
  local tN = now()
  local p = softPrev[key]
  -- (a real swing through, not the wanted angle jumping across)
  if p and tN - p.t < 0.5 and (err > 0) ~= (p.e > 0) and mabs(err - p.e) < 0.1
     and tN - (p.cut or 0) > 1.5 and SoftK[key] > 0.36 then
    local w = mabs(vec3(construct.getWorldAngularVelocity()):dot(axis))
    if w > 0.05 then
      SoftK[key] = mmax(SoftK[key] * 0.7, 0.35)
      p.cut = tN
      system.print(string.format("[HELM] %s swung past the mark — softening the AP's %s to %d%% for this ship",
        label, key, math.floor(SoftK[key] * 100 + 0.5)))
    end
  end
  softPrev[key] = { e = err, t = tN, cut = p and p.cut }
  return SoftK[key]
end

-- Roll rate wanted for a roll error (rad, + = right wing lower than wanted).
function RollRate(err, fwd)
  local k = SoftGain("roll", err, fwd, "Roll")
  return -clamp(err * 1.5 * k, -0.5 * k, 0.5 * k)
end

-- Yaw rate (about upW) wanted for a heading error (rad, + = turn left).
-- Also never faster than it can stop from in the angle left: the yaw
-- acceleration is learned as the ship spins up (heavy ships spin up
-- slowly, so slow down early — the carrier's first line-up overshot
-- before the softening above had anything to go on).
local yawPrevW, yawPrevT
function YawRate(err, upW, gain, cap)
  local k = SoftGain("yaw", err, upW, "Turn")
  local w = vec3(construct.getWorldAngularVelocity()):dot(upW)
  local tN = now()
  if yawPrevT and tN - yawPrevT > 0.02 and tN - yawPrevT < 0.5 and mabs(w) > mabs(yawPrevW) then
    local a = mabs(w - yawPrevW) / (tN - yawPrevT)
    if a < 3 then YawAcc = mmax(YawAcc or 0, a) end
  end
  yawPrevW, yawPrevT = w, tN
  local r = clamp(err * gain * k, -cap * k, cap * k)
  if YawAcc and YawAcc > 0.002 then
    local vs = msqrt(YawAcc * mabs(err))           -- stops in the angle left at half that acceleration
    r = clamp(r, -vs, vs)
  end
  return r
end

-- ── Descent: hold point above a surface spot → straight down → landing ──
-- Carl: players like to be in the atmosphere before the landing starts
-- (it's quicker). After the stop above the spot the AP falls straight down
-- the down line: gravity does the accelerating, brakes hold the speed to
-- the lower of (a) what it can still stop from before AP.descentR,
-- (b) 85% of the ship's atmospheric burn speed (only on bodies with an
-- atmosphere), (c) the `speed` cap. No engine thrust, nose kept level.
-- At AP.descentR, or as soon as the hovers/boosters see the ground, the
-- normal landing (the one G starts) takes over.
-- Share of DU's friction burn speed the AP and BurnProtect use (Carl,
-- 2026-11-13: tried 90% and got a little burn, so it's back to 85%: the
-- margin is needed for banked turns).
BURN_FRAC = 0.85
function BurnCap()
  local ok, v = pcall(construct.getFrictionBurnSpeed)
  if ok and type(v) == "number" and v > 10 then return v * BURN_FRAC end
  return 250                                   -- ~900 km/h if DU won't say
end
-- Leaving the atmosphere: under 2% air the speed cap only slows the way
-- out while the atmo engines fade and the space engines warm up (Carl:
-- burn protection has to stop at 1-2% air). Only while CLIMBING — coming
-- down into the air the cap still applies.
BURN_OFF_AIR = 0.02
function ThinAirClimb()
  if (unit.getAtmosphereDensity() or 0) >= BURN_OFF_AIR then return false end
  local pos = vec3(construct.getWorldPosition())
  local B = NearestBody(pos)
  if not B then return true end
  return vec3(construct.getWorldVelocity()):dot((norm(pos - B.c))) > 0
end

-- low: also when already BELOW the descent start (an atmosphere short hop
-- arriving at hop height) — with hovers/boosters the descent's slow final
-- stretch (belly tilt, position hold) brings it down onto the mark instead
-- of the plain landing (Carl: short hops had no tilt). Only the atmo trip's
-- arrival passes it: Alt+1 on a parked ship must never "descend".
function CanDescend(sideTol, low)
  if AP.agg then return false end   -- AGG trip: stays up at the AGG height
  if not (AutoLand and AP.target and AP.surfB and AP.descentR) then return false end
  if low and #GroundEngines > 0 then
    local B = AP.surfB
    local up = norm(AP.target - B.c)
    local rel = vec3(construct.getWorldPosition()) - B.c
    if rel:dot(up) > 0 and (rel - up * rel:dot(up)):len() < (sideTol or 200)
       and rel:len() <= AP.descentR + 20 then return true end
  end
  local pos = vec3(construct.getWorldPosition())
  local B = AP.surfB
  local up = norm(AP.target - B.c)
  local rel = pos - B.c
  local side = (rel - up * rel:dot(up)):len()           -- off the down line
  local r = rel:len()
  -- On the down line (within 200 m), above where the descent ends, and
  -- no higher than the hold point (+2 km slack).
  return rel:dot(up) > 0 and side < (sideTol or 200) and r > AP.descentR + 20
     and r < (AP.target - B.c):len() + 2000
end

function StartDescent()
  AP.active, AP.descent, AP.phase = true, true, "DESCENT"
  AP.accel, AP.brake, AP.angVel, AP.descentHold, AP.vAccel = 0, 0, vec3(), nil, 0
  ParkBrake = false
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  local B = AP.surfB
  local r0 = (vec3(construct.getWorldPosition()) - B.c):len()
  -- Arriving from space / another planet with the AGG on: the descent
  -- stops at the AGG height over the spot and holds there, no landing
  -- (decided here, at the start of the descent — the AGG may have been
  -- switched during the trip). Same rules as an AGG trip on the planet.
  AP.aggDescent = nil
  if not AP.agg then
    local ag, why = AggTripPlan(B, AP.spotR, AP.mapPick)
    if ag and r0 > ag.R + 50 then
      AP.agg, AP.aggDescent = ag, true
      local note = ""
      if ag.base and mabs(ag.base - ag.alt) > 20 then
        note = string.format(" (the AGG's lift is still at %.0f m, creeping toward %.0f m)", ag.base, ag.alt)
      end
      Msg(string.format("AGG on — descending to the AGG height over %s: stops at %.0f m (%s down) and holds, no landing%s — brake to stop",
        AP.name, ag.alt, FormatDist(r0 - ag.R), note))
      return
    elseif why then
      Msg("AGG on, but landing: "..why)
    end
  end
  local h = r0 - AP.descentR
  -- How far off the down line it starts (Carl: a short hop reached hover
  -- height 12 m off the mark and crept the rest — say so in chat).
  local rel = vec3(construct.getWorldPosition()) - B.c
  local dl = norm(AP.target - B.c)
  local offTxt = string.format(", %.0f m off the mark", (rel - dl * rel:dot(dl)):len())
  if h > 5 then
    Msg("Descending to "..AP.name.." ("..FormatDist(h).." down"..offTxt..") — brake to stop")
  else
    -- (short hop: already below the fast part — straight to the slow,
    -- steered final stretch)
    Msg("Coming down onto "..AP.name..offTxt..", holding over the mark — brake to stop")
  end
end

function APDescentStep(pos, vel, fwd, up, mass)
  local B = AP.surfB
  local g = vec3(core.getWorldGravity())
  local glen = g:len()
  local rel = pos - B.c
  local dn = norm(B.c - pos)                     -- straight down
  -- AGG arrival: the descent ends AT the AGG height and holds there.
  local aggD = AP.aggDescent and AP.agg
  local goal = rel:len() - (aggD and AP.agg.R or AP.descentR)   -- metres of fast descent left
  local vDown = vel:dot(dn)
  local hSpeed = (vel - dn * vDown):len()
  -- Braking while falling: brakes minus gravity. (AGG on: the gravity
  -- reading drops near the lift height — plan with the planet's real pull
  -- from the atlas, or it would come in too fast for the AGG height.)
  local gB = glen
  if aggD and B.gm then gB = mmax(glen, B.gm / (rel:len() ^ 2)) end
  local ab = mmax(BrakeAccel(mass) - gB, 0.3)
  local vmax = BrakeVmax(mmax(goal, 0), ab)
  if (B.atm or 0) > 0 then vmax = mmin(vmax, BurnCap()) end
  vmax = mmin(vmax, CruiseCap())
  -- AGG arrival: there's no slow final stretch to soak up an overshoot —
  -- the stop itself has to be AT the AGG height (Carl, 1114-1855: fell a
  -- bit past it). Atmospheric brakes fade at low speed and lag, so the
  -- fast part plans to stop 40 m above it with 80% of the brakes, then the
  -- last 40 m close in proportion (10 m/s at 40 m, 1 m/s at 4 m).
  if aggD then
    -- Atmospheric brakes fade below ~100 m/s (in proportion to speed), so
    -- with full brakes the fall settles at a FLOOR speed where they only
    -- match gravity (Carl: full brakes by hand never got under ~50 km/h
    -- until the AGG started helping). Brakes alone can't stop at the AGG
    -- height — the AGG makes the catch. So: arrive as slowly as the brakes
    -- allow. Plan the slowing with the fade (a(v) = A·min(1, v/100) − g),
    -- reach the floor speed 80 m above the AGG height, then full brakes
    -- the rest of the way down into the AGG.
    local DA = AP.descentHold or {}
    AP.descentHold = DA
    local A = mmax(BrakeAccel(mass), 0.5) * 0.8          -- full-speed braking, 20% spare
    local tN = now()
    -- Learn the real figure while the brakes are full on, high enough that
    -- the AGG isn't helping yet: A = (fall slowing + g) / fade.
    -- (over 0.25 s windows: frames are ~16 ms apart, and the old 50 ms
    -- minimum meant it never measured at all — 1114-2016 "DU's figure")
    if (DA.pB or 0) >= 0.95 and vDown > 5 and goal > 150 then
      if not DA.mT then
        DA.mT, DA.mV = tN, vDown
      elseif tN - DA.mT >= 0.25 then
        local an = (DA.mV - vDown) / (tN - DA.mT)
        local vAvg = (DA.mV + vDown) / 2
        local Am = (an + gB) / mmax(mmin(1, vAvg / 100), 0.05)
        if Am > 0 and Am < 500 then DA.Am = DA.Am and (DA.Am * 0.7 + Am * 0.3) or Am end
        DA.mT, DA.mV = tN, vDown
      end
    else
      DA.mT = nil
    end
    DA.pB = AP.brake or 0
    -- Measured only ever makes the plan MORE careful. Trusting a higher
    -- measured figure (3x DU's on the Hammer Crest) relaxed the plan 150 m
    -- up and it came into the last stretch at 407 km/h (1114-2052).
    if DA.Am then A = mmin(A, DA.Am * 0.6) end
    DA.A = A
    local vF = 100 * gB / mmax(A, 0.1)                   -- floor speed: brakes = gravity
    local vEnd = mmax(vF * 1.15, 3)
    DA.vF = vF
    if goal <= 100 and not DA.v100 then DA.v100 = vDown end
    if goal <= 0 and not DA.v0 then DA.v0 = vDown end
    -- Distance to slow from v to vEnd with fading brakes (numeric).
    local function slowDist(v)
      if v <= vEnd then return 0 end
      local n, d = 16, 0
      local dv = (v - vEnd) / n
      for i = 0, n - 1 do
        local vm = vEnd + (i + 0.5) * dv
        local a = A * mmin(1, vm / 100) - gB
        if a <= 0.05 then return 1e9 end
        d = d + vm * dv / a
      end
      return d
    end
    -- (Carl's way by hand: full brakes from well above, the fall settles
    -- at the floor speed, the AGG catches it. The last 200 m is full brakes,
    -- so the real — stronger — brakes get it down to their real floor.)
    local room = goal - 200
    if room <= 0 then
      vmax = 0                                           -- last 200 m: full brakes into the AGG
    else
      local lo, hi = vEnd, mmax(vmax, vEnd)
      if slowDist(hi) > room then
        for _ = 1, 12 do
          local mid = (lo + hi) / 2
          if slowDist(mid) > room then hi = mid else lo = mid end
        end
        vmax = lo
      end
    end
  end
  -- Short drops: near the bottom, hold the fall until we're over the spot
  -- (a 1 km hop has only ~50 m of drop; the creep across hadn't finished).
  local offNow = (rel - norm(AP.target - B.c) * rel:dot(norm(AP.target - B.c))):len()
  -- Final stretch (Carl: "get it closer to the mark — SAGA did a great job
  -- of that"): with a spot height we can trust and hovers/boosters to see
  -- the ground, the position hold doesn't stop at DescentHeight — it goes
  -- on, slowly, until the ground is in sensor range. The plain landing
  -- below it has no position hold (drifted ~11 m in 100 m, build 2231).
  local final = #GroundEngines > 0 and goal <= 5 and not aggD
  if final then
    local gR = mmax(GroundRangeSeen or 15, 10)
    if AP.spotR then
      local dF = rel:len() - (AP.spotR + gR * 0.7)
      vmax = clamp(VStopIn(ab * 0.5, dF), LandRate, mmin(LandCap(), 30))
    else
      -- Spot height unknown (map pick, altitude 0 — Carl: "tilt stuff even
      -- though it isn't a trusted altitude?"): the ground could be anywhere
      -- below, so no faster than the plain landing would come down here
      -- (it can stop within what the hovers see), but still steering.
      local aPlan = mmax(LandSpare(glen, mass) * LandSafety, 0.3)
      -- (a down telemeter sees ~100 m: as fast as it can stop within that)
      vmax = clamp(VStopIn(aPlan, mmax(gR, SightDown() or 0)), LandRate, LandCap())
      local DH = AP.descentHold or {}
      AP.descentHold = DH
      if not DH.mapMsg then
        DH.mapMsg = true
        local _, tR = TeleDown()
        Msg(string.format("Map pick: ground height unknown — coming down at ≤ %.0f km/h until the hovers see the ground%s", vmax * 3.6,
          tR > 0 and string.format(" (down telemeter sees %.0f m)", tR)
                 or (#Telemeters > 0 and " (telemeter linked, but not seen pointing down yet)" or "")))
      end
    end
    if offNow > 4 then vmax = 0 elseif offNow > 2 then vmax = mmin(vmax, 1.5) end
  else
    if offNow > 3 and goal < 150 then vmax = mmin(vmax, 2) end
    -- Still well off the line: fall no faster than the creep across can
    -- keep up with (~3 m/s), so it's over the spot before it's down low.
    if offNow > 5 then vmax = mmin(vmax, mmax(goal / (offNow / 3), 3)) end
    if offNow > 4 and goal < 15 then vmax = 0 end          -- not over it yet: hold, don't hand over
  end
  -- Parking heading: held all the way down (so it's done turning high
  -- up, clear of buildings — Carl), and nothing below DescentHeight until
  -- it faces it. Gives up after 60 s rather than hang there.
  local D0 = AP.descentHold or {}
  AP.descentHold = D0
  local hv = AP.hdg and HeadingVec(AP.hdg, -dn)
  local yawH = 0
  if hv then
    local flH = fwd + dn * fwd:dot(dn)
    if flH:len() > 0.05 then
      flH = flH / flH:len()
      yawH = math.atan(flH:cross(hv):dot(-dn), flH:dot(hv))
    end
  end
  local hdgOk = not hv or mabs(yawH) < math.rad(3)
  if hv and not hdgOk and goal <= 5 then
    D0.hdgT0 = D0.hdgT0 or now()
    vmax = 0
    if not D0.hdgMsg then D0.hdgMsg = true; Msg(string.format("Turning to face %.0f° before going lower", AP.hdg)) end
    if now() - D0.hdgT0 > 60 then
      Msg(string.format("Couldn't finish turning to %.0f° (%.0f° off) — landing as it is", AP.hdg, math.deg(mabs(yawH))))
      AP.hdg, hv, hdgOk = nil, nil, true
    end
  end
  local brake = 0
  -- Only as much brake as the fall needs: full brakes to hold height also
  -- killed the sideways creep to the spot (0.3 m/s, landed 30 m off — sim).
  if vDown > vmax + 1 then brake = (vmax > 30) and 1 or clamp((vDown - vmax) / 4, 0.1, 1) end
  -- (AGG arrival: catch the sink sooner and firmer near the bottom — weak
  -- low-speed brakes nudged at 10% let it slide past the height)
  if aggD and vDown > vmax + 0.3 then brake = mmax(brake, clamp((vDown - vmax) / 1.5, 0.2, 1)) end
  -- Position hold over the spot, all the way down. The idea of steering
  -- for the spot through the whole drop comes from SagaHUD by Sagacious
  -- (Carl: "SAGA would practically hold the line in the middle of the
  -- destination"); SAGA tilts the ship for it. Ours keeps Carl's rules:
  -- the nose stays LEVEL, the ship only yaws to face where it has to go
  -- and gives the main engines small pushes (level nose = push along the
  -- ground); brakes take anything faster than wanted, in any direction.
  local spotDir = norm(AP.target - B.c)
  local off = rel - spotDir * rel:dot(spotDir)        -- sideways from the down line
  local offLen = off:len()
  local vH = vel - dn * vDown
  local aH = 2                                        -- gentle sideways push, ~0.2 g
  local vHdes = vec3()
  if offLen > 1.5 then
    -- Slow creep that can still stop with real brake/engine lag (~1-2 s):
    -- it slid past the spot and turned round when lag was in the sim.
    -- (0.25/s, was 0.1/s: 12 m took ~15 s at the end of a short hop —
    -- Carl, 1115-0913. The lag-aware (offLen − 1)/2.5 still rules close in.)
    vHdes = off * (-mmax(mmin(offLen * 0.25, (offLen - 1) / 2.5, 4), 0) / offLen)
  end
  -- Gentle brakes: nothing for small overshoots, then gradually more
  -- (Carl: braking hard made it turn round a lot to push back).
  -- Dead zone with hysteresis: steer when more than 5 m off, stop once
  -- within 2 m (hovering ~3 m off flipped the facing back and forth — sim).
  local D = AP.descentHold or {}
  AP.descentHold = D
  -- (final stretch: tighter, it's slow by then)
  if offLen > (final and 2.5 or 5) then D.steer = true elseif offLen < (final and 1 or 2) then D.steer = false end
  local excess = vH - vHdes
  -- Brakes act on the WHOLE velocity: braking a 0.5 m/s slide while
  -- falling 22 m/s mostly brakes the fall, and the drop crawled down from
  -- 12 km at 80 km/h with the brakes at 12% (Carl, 1114-1951). So slide
  -- braking only once the fall is slow, or the slide is a real share of
  -- the motion; above that the belly tilt does the steering.
  -- "Slow" = the fall we WANT is slow (near the bottom), not the fall we
  -- happen to have: a descent starts from a stop, so "vDown < 8" braked a
  -- 0.7 m/s slide, which held the fall under 8 m/s, which kept it braking
  -- — 9 km down at 25 km/h, brakes 37% (Carl, 1120 on Haven). And a slide
  -- only counts as a real share of the motion from 2 m/s.
  local sideBrake = vmax < 8 or vH:len() > mmax(vDown * 0.3, 2)
  if not sideBrake then
    -- (no slide braking while falling fast)
  elseif not D.steer then
    -- Over the spot: stop any leftover slide (coasting past at ~2.5 m/s
    -- made it turn right round to come back — sim).
    if vH:len() > 0.3 then brake = mmax(brake, clamp(vH:len() / 2, 0.1, 1)) end
  elseif excess:len() > 0.4 and excess:dot(vH) > 0 then
    brake = mmax(brake, clamp((excess:len() - 0.2) / 3, 0, 1))
  end
  local e = vHdes - vH
  AP.remaining, AP.vAlong, AP.vDes = goal, vDown, vmax
  -- Nose level (pitch + roll to the horizon); yaw toward the push needed.
  -- (AGG on: the gravity reading can point anywhere — planet centre)
  local wv = (glen > 0.01 and not AggIsOn()) and g / glen or dn
  local upW = -wv
  local pitchAng = math.asin(clamp(fwd:dot(wv), -1, 1))
  local right = vec3(construct.getWorldOrientationRight())
  AP.angVel = right * clamp(pitchAng * 1.5, -0.5, 0.5) + RollLevelAV(fwd, right, up, wv)
  -- Belly tilt toward where we need to go: SagaHUD (by Sagacious) points
  -- the belly at the target while braking down onto it, and Carl hand
  -- flies it the same way, by pitch OR roll ("target left: roll right and
  -- brake to go left") — a ship falling with its belly tilted slides
  -- toward its low side. Tilt follows the sideways-speed error (3° per
  -- m/s), up to 20° high up and 8° in the slow final stretch (SAGA levels
  -- out near the bottom too). Any direction: no turning needed for it.
  -- Safety: if it ever drifts 25 m further off than where tilting began,
  -- the tilt isn't working on this ship — level nose for the rest.
  -- Only in air thick enough for the tilt to push the ship sideways (Carl:
  -- it needs ~10%): above that, level nose, and no judging the tilt —
  -- the drift up there switched it off for the whole descent (1114-2016).
  local airOk = (unit.getAtmosphereDensity() or 0) >= 0.1
  if not airOk then D.tiltOff0 = nil end
  if D.steer and not D.noTilt and airOk then
    D.tiltOff0 = mmin(D.tiltOff0 or offLen, offLen)
    if offLen > D.tiltOff0 + 25 then
      D.noTilt = true
      Msg("Belly tilt isn't bringing it closer — flying the rest nose-level")
    end
  end
  if D.steer and not D.noTilt and airOk and e:len() > 0.3 and vDown > 1 then
    -- Less tilt close to the mark (3° + 0.3° per metre off, so ~6° at
    -- 10 m, the full 20° only from ~57 m), and half as much while the
    -- brakes are on: braking makes a small tilt move the line a lot
    -- (Carl, 1119: "it tilts a lot as it uses the brake when it is fairly
    -- close").
    -- (was 3° + 0.3°/m: better, "still tilted a little much" — 1119-2321)
    local tMax = mmin(final and 8 or 20, 2 + offLen * 0.2)
    if brake > 0.2 then tMax = tMax * 0.5 end
    local tilt = clamp((e:len() - 0.3) * math.rad(3), 0, math.rad(tMax))
    local tdir = e / e:len()
    local uDes = upW * math.cos(tilt) - tdir * math.sin(tilt)   -- belly (−up) leans toward tdir
    local av = up:cross(uDes) * 1.5
    local L = av:len()
    if L > 0.4 then av = av * (0.4 / L) end
    AP.angVel = av
  end
  -- Face the SPOT (that direction only flips once, when we pass over it),
  -- not the push needed (that flipped every time the brakes caught an
  -- overshoot, so the ship kept turning round — Carl). Push only along
  -- the nose, only when slower than wanted.
  local accel = 0
  if D.steer then
    local fl = norm(fwd - upW * fwd:dot(upW))
    local th = norm(-off)
    local yawErr = math.atan(fl:cross(th):dot(upW), fl:dot(th))
    -- Line up on the spot FIRST (turn when > 15° off, until within 3°),
    -- then push only when nearly straight on (< 8°). Pushing while 25° off
    -- made it drift sideways, and close to the spot that sideways offset
    -- became a big angle -> more turns (Carl's "twitch", ~180° of turning
    -- in total; reproduced in the sim with lag). No new turn in the last
    -- 8 m: a small leftover is accepted rather than turned for.
    -- (final stretch: turning allowed down to 2.5 m off — it's barely
    -- moving sideways by then, so the bearing to the spot holds still; the
    -- 8 m rule left it sinking 5 m off with the spot beside it — sim)
    -- (parking heading set: no turning to face the spot — the belly tilt
    -- and brakes move it across; only if the tilt doesn't work does it
    -- turn for the spot, and faces the heading again once over it)
    if hv and not D.noTilt then D.turning = false
    elseif mabs(yawErr) > math.rad(15) and offLen > (final and 2.5 or 8) then D.turning = true
    elseif mabs(yawErr) < math.rad(3) then D.turning = false end
    if D.turning then AP.angVel = AP.angVel + upW * YawRate(yawErr, upW, 0.6, 0.15) end
    -- small pushes only, and none once nearly at the wanted speed (the
    -- engines keep pushing for a moment after being told to stop)
    if mabs(yawErr) < math.rad(8) then
      if final then
        -- The brakes holding the sink also brake the creep (they act on
        -- the whole velocity): add back their sideways share, firmer gain
        -- (0.08 m/s² vs the brakes' ~0.06 left it stuck 4-5 m off — sim).
        local sp = vel:len()
        local bH = brake * (brakeSpeedFactor * sp + brakeFlatFactor) * mmax(vH:dot(fl), 0) / mmax(sp, 0.1)
        accel = clamp((e:dot(fl) - 0.1) * 1.0 + bH, 0, 1.5)
      else
        accel = clamp((e:dot(fl) - 0.3) * 0.5, 0, 1)
      end
    end
  end
  if hv and not (D.steer and D.noTilt) then
    AP.angVel = AP.angVel + (-dn) * YawRate(yawH, -dn, 0.6, 0.15)
  end
  -- Down push (Carl: "add up facing engines to help descend"): high up the
  -- fall starts slow and only gravity speeds it up. Engines facing up push
  -- the ship down, so use them until the fall is near the speed the plan
  -- allows (8 m/s short of it — engines keep pushing a moment after being
  -- told to stop), never while braking, never in the slow final stretch.
  -- The braking plan and burn cap set vmax as before, so stopping is
  -- unchanged. Ships without such engines just fall as they did.
  local vAcc = 0
  if brake == 0 and not final and vmax > 20 and goal > 300 and (Thrust and (Thrust.D or 0) > 0) then
    vAcc = -clamp((vmax - 8 - vDown) * 0.5, 0, 10)
    if vAcc < -0.5 and not D0.pushMsg then
      D0.pushMsg = true
      Msg("Up-facing engines pushing the fall to speed")
    end
  end
  AP.vAccel = vAcc
  AP.brake, AP.accel, AP.phase = brake, accel, "DESCENT"
  AP.alignErr = math.deg(mabs(pitchAng))
  -- Hand over to the landing: fast part done (and slowed), or the ground
  -- engines can already see the ground (spot higher than we thought).
  local seesGround = #GroundEngines > 0 and ReadGroundDist() >= 0
  local handOver
  if aggD then
    -- At the AGG height, over the spot, facing the heading: hold there.
    D0.minGoal = mmin(D0.minGoal or goal, goal)
    -- (or the AGG has caught it a little above the height — its lift may
    -- not be exactly there — and holds it still for 3 s)
    if goal <= 80 and mabs(vDown) < 0.5 then D0.stillT = D0.stillT or now() else D0.stillT = nil end
    local held = D0.stillT and now() - D0.stillT > 3
    if (goal <= 5 and mabs(vDown) < 1 or held) and offNow <= 4 and hdgOk then
      local low = D0.minGoal
      AP.descent = false
      AggArrive()
      system.print(string.format("[HELM] AGG stop: %s · %s 100 m above, %s at the height · full-brake floor ~%.0f km/h (brakes %.0f m/s²%s)",
        low < -0.5 and string.format("dipped %.0f m below the AGG height", -low) or "no dip below the AGG height",
        D0.v100 and string.format("%.0f km/h", D0.v100 * 3.6) or "?",
        D0.v0 and string.format("%.0f km/h", D0.v0 * 3.6) or "?",
        (D0.vF or 0) * 3.6, D0.A or 0, D0.Am and ", measured" or ", DU's figure"))
    end
    return
  end
  if final then
    -- over the spot (or the ground is close anyway), or far below the
    -- spot height we were given (it was wrong): the landing takes over
    handOver = (seesGround and (offNow <= 2.5 or GroundDist < 6)) or (AP.spotR and rel:len() < AP.spotR - 30)
    -- Sat down already (Thades map pick, 1115-0636: on its gear 3 m off
    -- the mark, hover reading 6+ m, so it held there in DESCENT): seeing
    -- the ground and not moving for 3 s → the landing takes over.
    if seesGround and vel:len() < 0.5 then
      D0.restT = D0.restT or now()
      if now() - D0.restT > 3 then handOver = true end
    else
      D0.restT = nil
    end
  else
    handOver = (goal <= 5 and vDown < 5 and offNow <= 4) or seesGround
  end
  if handOver and hdgOk then
    local name = AP.name
    APDisengage(nil)
    SetHover(false, true)
    Msg(string.format("Descent done — landing on %s (%.1f m off the mark%s)", name, offNow,
      AP.hdg and string.format(", facing %.0f°", AP.hdg) or ""))
  end
end

-- ── Take-off: ground / atmosphere → space ────────────────────────────
-- Alt+1 while landed or in atmosphere (Carl's choices):
--   LIFT     hovers/boosters lift to hover height (as G does)
--   LINE UP  brakes on, turn level toward the destination
--   CLIMB    main engines; the nose may only come up as forward speed
--            builds (0° below 8 m/s → full climb angle at 33 m/s), and
--            comes back down if speed drops — never steep and slow (Carl:
--            SAGA tipped too far without forward movement). Full climb
--            angle from thrust/weight (15° at 1:1, +30° per extra 1),
--            capped by MaxClimbAngle. Speed kept under 85% burn speed.
--   then, out of the atmosphere (and above the highest terrain), the
--   normal space AP takes over: route, cruise, stop.
-- "Down" for levelling and the trip's up/down. NOT core.getWorldGravity():
-- with an AGG holding the ship that reads ~0 and can point anywhere (Carl,
-- 1114-1049: Hammer Crest AGG trip cruised upside down at 1192 m). The
-- direction to the nearest planet's centre (atlas — nothing the AGG can
-- touch) within 2 su of it, else DU's world vertical.
function DownDir(pos, B)
  B = B or NearestBody(pos)
  if B and (pos - B.c):len() - B.r < 2 * SU then return norm(B.c - pos) end
  local ok, v = pcall(core.getWorldVertical)
  v = ok and v and vec3(v) or vec3()
  if v:len() > 0.5 then return v / v:len() end
  return nil
end

function NearestBody(pos)
  local best, bd
  for _, B in ipairs(Bodies or {}) do
    local d = (pos - B.c):len() - B.r
    if not bd or d < bd then best, bd = B, d end
  end
  return best
end

function StartTakeoff()
  RefreshShipStats()
  SurveyThrust()
  local pos = vec3(construct.getWorldPosition())
  local vel = vec3(construct.getWorldVelocity())
  if MaxThrustN <= 0 then Msg("No forward engines that work here — can't take off") return false end
  local landed = HoverState == "landed"
  if landed and #GroundEngines == 0 then
    Msg("Take-off needs hovers or vertical boosters to lift off — lift off by hand, then Alt+1")
    return false
  end
  local phase = "CLIMB"
  if landed then phase = "LIFT"
  elseif vel:len() < 30 and #GroundEngines > 0 and ReadGroundDist() >= 0 then phase = "LINE UP" end
  AP.takeoff = { phase = phase, t0 = now(), B = NearestBody(pos) }
  local T = AP.takeoff
  T.startR = T.B and (pos - T.B.c):len()
  if AP.agg then
    -- AGG trip: cruise at the AGG height (the AGG carries the weight all
    -- the way) when that clears the planet's highest ground; otherwise
    -- the normal safe cruise height, coming down to it near the spot.
    T.atmo, T.agg = true, AP.agg
    T.cruiseR = AP.agg.cruise and AP.agg.R or AtmoCruiseR(T.B)
  else
    local want, whyOut = AtmoHopWanted(pos, T.B)
    T.whyOut = whyOut
    if want then
    -- Short hops don't go up to the full cruise height: at most ~30% of
    -- the trip in height gain (1 km hop → ~300 m up), at least 150 m over
    -- the start and the spot. (Climbing to 3 km on a 1 km hop flew past
    -- the spot mid-climb and swung back and forth round it — sim.)
    local B = T.B
    local a, b = norm(pos - B.c), norm(AP.target - B.c)
    local arc = math.atan(a:cross(b):len(), a:dot(b)) * B.r
    local rS = (pos - B.c):len()
    local floorR = mmax(rS, AP.descentR - mmax(tonumber(DescentHeight) or 100, 30)) + 150
    T.atmo = true
    T.cruiseR = mmax(mmin(AtmoCruiseR(B), rS + 0.3 * arc), mmin(floorR, AtmoCruiseR(B)))
    end
  end
  AP.legs, AP.leg, AP.total, AP.obs, AP.descent = nil, 1, 0, nil, false
  AP.active, AP.phase, AP.accel, AP.brake, AP.angVel = true, phase, 0, 0, vec3()
  ParkBrake = false
  if ParkHold then ParkHold = nil end
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  if landed then SetHover(true) end
  if T.agg then
    Msg(string.format("AGG trip → %s: %s, stops over the spot at the AGG height (%.0f m) — brake to stop",
      AP.name, T.agg.cruise and "flying at the AGG height"
        or string.format("cruising at %.0f m (AGG height is below %s's highest ground), down to it near the end", T.cruiseR - T.B.r, T.B.name),
      T.agg.alt))
    if T.agg.base and mabs(T.agg.base - T.agg.alt) > 20 then
      Msg(string.format("Note: the AGG lift is still at %.0f m, creeping to %.0f m", T.agg.base, T.agg.alt))
    end
  else
  Msg("Take-off → "..AP.name..
      (T.atmo and string.format(" (in the atmosphere, cruising at %.0f m)", T.cruiseR - T.B.r)
        or (T.whyOut and (" (via space: "..T.whyOut..")")) or "")..
      " — brake to stop")
  end
  return true
end

-- ── Atmosphere hop: surface spot on the same planet, staying in the air ──
-- Carl: going to space for a short hop wastes fuel, and nobody should be
-- forced to space for the far side either → PlanetTrips (default "atmo").
-- The take-off climbs to the cruise height instead of leaving, CRUISE
-- holds height and heading under the burn speed, SLOWING brakes (nose
-- level) so we stop over the spot, then the normal descent / landing.
-- Flare curve: the climb (or sink) rate allowed with dh metres still to
-- go, like a braking curve — eases to 0 at the cruise height (≈4 m/s² of
-- vertical slowing far out, a 6 s settle in the last few dozen metres).
function LevelOffVUp(dh)
  if dh <= 0 then return 0 end
  return mmin(msqrt(2 * 4 * dh), dh / 6)
end

function AtmoHopWanted(pos, B)
  local S = AP.surfB
  if not (S and B and S == B and (B.atm or 0) > 0 and AP.descentR) then
    local why
    if S and B and S ~= B then why = string.format("the spot is on %s (system %s, id %s), not %s (system %s, id %s) we're on",
      S.name, tostring(S.sys), tostring(S.id), B.name, tostring(B.sys), tostring(B.id))
    elseif B and (B.atm or 0) <= 0 then why = B.name.." has no atmosphere in the atlas"
    elseif S and not AP.descentR then why = "no landing spot (planet centre picked)" end
    return false, why
  end
  local mode = tostring(PlanetTrips or "atmo"):lower()
  -- (second value: why it goes via space, for the take-off message —
  -- Carl, a 20 km trip went out to space and nothing said why)
  if mode == "orbit" then return false, "PlanetTrips is \"orbit\"" end
  if mode == "auto" then
    local a, b = norm(pos - B.c), norm(AP.target - B.c)
    local arc = math.atan(a:cross(b):len(), a:dot(b)) * B.r
    local mx = (tonumber(AtmoHopMax) or 100) * 1000
    if arc <= mx then return true end
    return false, string.format("%s over the ground, AtmoHopMax is %s", FormatDist(arc), FormatDist(mx))
  end
  return true
end

-- Cruise radius: AtmoCruiseHeight, but at least 500 m over the highest
-- terrain, 300 m over the tallest allowed building and 400 m over the
-- end of the descent; never closer than 500 m to the atmosphere top.
function AtmoCruiseR(B)
  local alt = mmax(tonumber(AtmoCruiseHeight) or 3000, (B.top - B.r) + 500, (B.stat or 0) + 300)
  if AP.descentR then alt = mmax(alt, AP.descentR - B.r + 400) end
  alt = mmin(alt, (B.atm - B.r) - 500)
  return B.r + alt
end

function APTakeoffStep(pos, vel, fwd, up, mass)
  local T = AP.takeoff
  local B = T.B
  local g = vec3(core.getWorldGravity())
  local glen = g:len()
  local wv = DownDir(pos, B) or -up
  local upW = -wv
  local right = vec3(construct.getWorldOrientationRight())
  local speed = vel:len()
  local inAtmo = (unit.getAtmosphereDensity() or 0) > 0.0001
  AP.remaining, AP.vAlong, AP.vDes = (AP.target - pos):len(), vel:dot(fwd), 0

  -- Out: no atmosphere, and 1 km clear of the atmosphere top / highest
  -- terrain (the route planner treats anything within 500 m of that
  -- shell as "blocked by the planet") → normal space AP.
  local clear = not B or (pos - B.c):len() > B.hard + 1000
  if not T.atmo and not inAtmo and clear and not InsideBody(pos) then
    local name = AP.name
    APDisengage(nil)
    Msg("Out of the atmosphere — on to "..name)
    if not APEngage(true) then ParkBrake = true end
    return
  end

  -- Parking heading with a turn in place at the end (AGG hold, or a
  -- landing without the descent): a ship turns about its centre of mass,
  -- so its position (what the spot was saved with) swings round that —
  -- the carrier ended 64 m off the spot after turning (Carl, 1114-1403).
  -- So the trip brings the CENTRE OF MASS to where it will be once the
  -- ship faces the heading with its position on the spot; the turn then
  -- leaves the position on the spot.
  local refPos, aimDir = pos, nil
  T.comOff = nil
  if AP.hdg and AP.spot and B and AP.surfB == B and (T.agg or not AutoLand or #GroundEngines == 0) then
    local M = ComWorld()
    if M then
      local upS = norm(AP.spot - B.c)
      local hv = HeadingVec(AP.hdg, upS)
      if hv then
        local d = M - pos
        local Mf = AP.spot + hv:cross(upS) * d:dot(right) + hv * d:dot(fwd) + upS * d:dot(up)
        refPos, aimDir = M, norm(Mf - B.c)
        T.comOff = (d - upW * d:dot(upW)):len()
      end
    end
  end

  -- Level heading toward the destination (keep ours if it's straight up).
  local fl = fwd - upW * fwd:dot(upW)
  fl = fl:len() > 0.05 and norm(fl) or norm(up - upW * up:dot(upW))
  local dT = norm(AP.target - pos)
  -- (only for a spot on the planet we're leaving: for one on ANOTHER
  -- planet that point is a planet-sized distance off to the side, and the
  -- take-off headed 90° away from the destination — Carl, 1114-1951,
  -- both ways between Alioth and Alioth Prime)
  if AP.surfB and AP.surfB == B then
    -- Surface spot: steer for the spot at our own height, not the hold
    -- point 10+ km above it — from 1 km away that's nearly straight up,
    -- its level part fell under the 0.1 cut-off and the take-off kept
    -- its old heading (flew the wrong way on a 1 km hop — sim).
    local S = AP.surfB
    local aD = aimDir or norm(AP.target - S.c)
    dT = norm(S.c + aD * (refPos - S.c):len() - refPos)
  end
  local h = dT - upW * dT:dot(upW)
  h = h:len() > 0.01 and norm(h) or fl

  local twr = MaxThrustN / mmax(mass * glen, 1)
  local climbMax = math.rad(clamp(15 + (twr - 1) * 30, 10, clamp(tonumber(MaxClimbAngle) or 45, 10, 60)))
  local capRad = math.rad(clamp(tonumber(MaxClimbAngle) or 45, 10, 60))
  local accel, brake, pitch, heading = 0, 0, 0, h
  local vAcc = 0   -- down-facing engines, pushing up (slow end of an atmosphere trip)

  -- Atmosphere hop: distance over the ground to the spot, stop over it.
  local s, r, vUp, vH, vF, ab
  if T.atmo and (T.phase == "CLIMB" or T.phase == "CRUISE" or T.phase == "SLOWING") then
    local dn = aimDir or norm(AP.target - B.c)
    local rp
    rp, r = norm(refPos - B.c)
    s = math.atan(rp:cross(dn):len(), rp:dot(dn)) * r
    vUp = vel:dot(upW)
    vH = vel - upW * vUp
    vF = vH:dot(h)
    local vSide = (vH - h * vF):len()
    ab = BrakeAccel(mass)
    AP.remaining, AP.vAlong = s, vF
    -- Gradual approach (Carl: "slow down sooner... braking in sections
    -- like SAGA / Arch; watch the red line creep onto the destination"):
    -- the speed follows a gentle curve — ~30% of the brakes (at most
    -- 0.8 g) far out, then closing the last stretch over ~6 s — while the
    -- cruise keeps holding height and heading. It ends nearly stopped
    -- right over the spot, so the descent has nothing to turn for. (A late
    -- full-brake stop slid past the spot with real brake lag and the
    -- descent turned ~170° to come back.)
    -- Below ~100 m/s atmospheric brakes get weaker in proportion to speed
    -- (ArchHUD plans with brake x speed/100), so the last stretch closes
    -- in PROPORTION to the distance (v = k*d, like SAGA's "half the
    -- distance in km/h"), not a constant-brake curve that the brakes then
    -- can't follow at low speed (Carl: "still stomped on the brakes at the
    -- end"). Above 100 m/s: ~30% of the brakes, at most 0.8 g.
    -- No up engines (hovers / VBoosts don't count): a slow ship can't hold
    -- its height, so keep wing speed longer and brake later and harder,
    -- SAGA-style (Carl, build 0701: 121 km/h, 500 m out, sinking → brakes
    -- 100%: "not waiting long enough to hold the brakes").
    -- (at the air density HERE: DU's figure is the sea-level one)
    local upNoG = UpEngN() / mmax(mass, 1)
    -- AGG holding the weight (on, and we're near its lift height): the ship
    -- holds its height like one with strong up engines.
    local aggLiftR = T.agg and T.agg.R
    if T.agg then
      local sA = AggRead()
      if sA and sA.base then aggLiftR = B.r + sA.base end
    end
    T.aggHold = T.agg and AggIsOn() and mabs(r - aggLiftR) < 300 or false
    local late = upNoG < glen * 0.9 and not T.aggHold
    -- (late: hold speed closer in — build 0712 still crawled at 84 km/h,
    -- 76 m out, brakes 8% then 100% at the descent: "gets too slow before")
    local aG = late and clamp(ab * 0.8, 1, 30) or clamp(ab * 0.3, 1, 8)
    local vL = late and 50 or 100            -- proportional tail below this
    local k = late and mmin(aG / vL, ab * 0.6 / 100, 1 / 3) or mmin(aG / 100, 1 / 7)
    local d = mmax(s - 3, 0)
    local d100 = vL / k
    local vB = d <= d100 and k * d or msqrt(vL * vL + 2 * aG * (d - d100))
    if not late then
      -- Ships that hold their height: the gentle curve, but a firm tail
      -- (d/4: 25 m/s at 100 m, 2.5 m/s at 10 m). The old tail matched the
      -- curve at 100 m/s with k = aG/100, so weak brakes (aG ~1.5) made it
      -- a crawl from ~6 km out — 54 km/h at 1 km (Carl, 1113-2355: "crept
      -- forward fairly slow" with down-facing engines that hold it up).
      vB = mmin(d / 4, msqrt(2 * aG * d))
    end
    if late then
      -- No up engines: steady 60% of the brakes right down to 10 m/s, then
      -- the last ~30 m in proportion (3 s). The "brakes fade below 100 m/s"
      -- tail (ArchHUD's rule) made a brakes-only ship crawl the last 450 m
      -- while sinking 25 m/s (Carl: "it is slowing down too soon"). Our
      -- brake command already asks for full force at low speed.
      local aT, vS = ab * 0.6, 10
      local dS = vS * 3
      vB = d <= dS and d / 3 or msqrt(vS * vS + 2 * aT * (d - dS))
    end
    -- Back-facing engines (retro) don't fade at low speed like the brakes:
    -- with them the last stretch closes at a steady half of their push
    -- instead of the slow brakes-only tail (Carl, alt with low brake
    -- talents: crept 10 km/h the last ~600 m, sank to hover height 26 m
    -- short of the spot — no good next to a platform edge).
    local aR = ((Thrust and Thrust.atmo and Thrust.B) or 0) / mmax(mass, 1)
    local vBrk = vB
    if aR > 0.5 then vB = mmax(vB, msqrt(aR * d)) end
    T.vB, T.aG, T.aR = vB, aG, aR
    -- Hand over to the descent once close and slow (it holds the ship up
    -- with the brakes and creeps the last metres with the spot ahead). In
    -- the sim a ship that couldn't hold its height slowly fell onto the
    -- ground while still creeping in the air.
    local canDesc = CanDescend(nil, true)
    -- (no faster than the approach curve allows there, or it slides past)
    -- (60 m out only with 300+ m of drop to creep across in: holding
    -- height on brakes at the bottom of a short drop also stopped the
    -- creep — it landed 30 m off in the sim. Short drops get over the
    -- spot in the air first.)
    local longDrop = AP.descentR and r - AP.descentR > 300
    -- (|vF|: sliding PAST the spot at 30 m/s counted as "slow" — sim with slow-spooling engines)
    -- (brakes-only speed here: the descent stops with the brakes alone)
    -- (25 m, was 60: the descent's sideways creep is slow, and from 50 m
    -- short a 418 m drop ended at hover height still short, then moved
    -- across low — Carl, 1114-2129, Market 7)
    if (canDesc and longDrop and s <= 25 and mabs(vF) < vBrk + 1 and vSide < 3) or (s <= 8 and vH:len() < 1.5) then
      -- Over the spot: straight down (fast descent if we're high enough),
      -- else the normal landing.
      local name = AP.name
      if T.agg then
        ParkTurnThen(AggArrive)
      elseif canDesc then
        AP.takeoff = nil
        StartDescent()             -- (the descent turns to the parking heading itself)
      else
        ParkTurnThen(function()
          APDisengage(nil)
          SetHover(false, true)
          Msg("Over "..name.." — landing")
        end)
      end
      return
    end
    -- Full brakes only for the unusual: way over the curve, sliding
    -- sideways near the spot, or moving AWAY from it (brake before turning).
    local slide = (s < 300 and vSide > 3 and speed > 2) or vF < -3
    -- Turn-around (a new target to the side or behind, far enough away):
    -- fly it like a plane, SAGA-style — bank, keep flying speed, let the
    -- wings and engines carry the turn (Carl, build 0019: target switched
    -- behind → SLOWING braked it to a crawl and it pivoted flat, which
    -- stalls the lift). Track = where we're actually going.
    local vHl = vH:len()
    local trackAng = 0
    if vHl > 5 then
      local vt = vH / vHl
      trackAng = math.atan(vt:cross(h):dot(upW), vt:dot(h))        -- + = target left of track
    end
    T.trackAng = trackAng
    -- Turning flag (hysteresis 30° in / 15° out). The turn is flown inside
    -- CRUISE so its learned height/speed control carries it — a separate
    -- simple turn phase let wingless ships sink into the ground (sim).
    if T.turning then
      -- Progress, not a clock (Carl: a big carrier may turn slowly but
      -- fine): each time the target comes 15° further round, the window
      -- restarts. Fail = no 15° of progress in 20 s (30 s for the first,
      -- which includes slowing to turn speed), or drifting further off
      -- than max(3 km, half the distance when the turn began).
      local a = mabs(trackAng)
      if a < T.turnA - math.rad(15) then T.turnA, T.turnT0, T.turnWin = a, now(), 20 end
      if a < math.rad(15) or vHl < 5 or s < 1000 then
        T.turning, T.turnSign = nil, nil
      elseif now() - T.turnT0 > T.turnWin or s > T.turnS0 + mmax(3000, T.turnS0 / 2) then
        -- Not coming round (no wings to turn on, or too fast). A flat turn
        -- on the spot would stall a ship that isn't hovering (Carl: "it
        -- will stall and crash") — so AP off and land here, and say why.
        local name = AP.name or "the target"
        if T.agg then
          -- AGG trip: don't put a big AGG ship down somewhere random —
          -- stop here in the air, the AGG holds it.
          ShowAlert("CAN'T TURN — HOLDING", "Couldn't bank round toward "..name..
            " — AP off, brakes held, the AGG holds the height. Turn by hand, then Alt+1", "#ffc24b", 15)
          Msg("Couldn't bank round toward "..name.." — stopped in the air (AGG holding). Turn by hand, then Alt+1")
          APDisengage(nil)
          ParkBrake = true
          return
        end
        ShowAlert("CAN'T TURN — LANDING", "Couldn't bank round toward "..name..
          " — landing here rather than a flat turn that would stall. Re-engage (Alt+1) once down", "#ffc24b", 15)
        Msg("Couldn't bank round toward "..name.." — landing here (a flat turn would stall). Alt+1 once down to carry on")
        APDisengage(nil)
        SetHover(false, true)
        return
      end
    elseif mabs(trackAng) > math.rad(30) and vHl > 30 and s > 1000 then
      T.turning, T.turnT0, T.turnS0, T.turnA, T.turnWin = true, now(), s, mabs(trackAng), 30
      T.turnSign = trackAng >= 0 and 1 or -1       -- (kept: a target dead behind doesn't flip sides)
    end
    if T.turning then
      if T.phase ~= "CRUISE" then T.pc = nil end   -- cruise restarts from the actual nose
      T.phase = "CRUISE"
    elseif vF > vB * 1.3 + 2 or slide then
      if T.phase ~= "SLOWING" then T.pc = nil end   -- cruise restarts from the actual nose
      T.phase = "SLOWING"
    elseif T.phase == "SLOWING" and vF < vB * 1.1 + 1 and not slide then
      -- (not while still sliding/moving away: it flipped SLOWING↔CLIMB
      -- every frame at 45 km/h going the wrong way — sim)
      T.phase = (r < (T.holdR or T.cruiseR) - 150 and s > 2000) and "CLIMB" or "CRUISE"
    elseif T.phase == "CLIMB" and (r >= (T.holdR or T.cruiseR) - 150 or vF >= vB - 5
        -- (the nose comes down at ~3°/s and we keep climbing meanwhile:
        -- a steep climb overshot the cruise height by 1.2-1.4 km in the
        -- sim — so level off that much sooner)
        or vUp >= LevelOffVUp((T.holdR or T.cruiseR) - r - vUp * 0.5 * mmax(math.asin(clamp(fwd:dot(upW), -1, 1)), 0) / math.rad(3))) then
      -- Start levelling off as soon as we climb faster than the flare
      -- curve allows (Carl: it didn't start levelling soon enough and
      -- corrected a couple of times) — or, on a short hop, as soon as the
      -- approach curve says to stop speeding up.
      T.phase = "CRUISE"
    end
    T.slowBrake = 1
    -- Arrive where the down-facing engines can hold the ship up: near the
    -- end of the trip, if they could hold it in thicker air but not here,
    -- come down (while still fast, the wings carrying it) until they can.
    -- Carl, 1113: engines-all-round ship cruised at 3 km, its up engines
    -- only hold below ~1.5 km, so it slowed up there, sank, and crawled.
    -- Not below the descent start + 350 m (terrain / the spot).
    local upFullA = mmax(((Thrust and Thrust.U) or 0) - ((Thrust and Thrust.G) or 0), 0) / mmax(mass, 1)
    if T.agg then
      -- AGG trip cruising above the AGG height (it's below the highest
      -- ground): come down to the AGG height for the end of the trip.
      if not T.agg.cruise and not T.turning and s < 2 * BrakeDist(mmax(vF, 0), ab) + 1500
         and T.agg.R < (T.holdR or T.cruiseR) - 1 then
        T.holdR = T.agg.R
        if not T.lowMsg then T.lowMsg = true; Msg(string.format("Coming down to the AGG height (%.0f m) for %s", T.agg.alt, AP.name or "the spot")) end
      end
    elseif Thrust and Thrust.atmo and upFullA > glen * 1.15 and upNoG < glen * 1.15 and not T.turning
        and s < 2 * BrakeDist(mmax(vF, 0), ab) + 1500 then
      local want = mmax(r - 150, (AP.descentR or (T.B and T.B.r) or r) + 350)
      if want < (T.holdR or T.cruiseR) - 1 then
        T.holdR = want
        if not T.lowMsg then
          T.lowMsg = true
          Msg("Coming down before slowing — the down-facing engines only hold this ship up in thicker air")
        end
      end
    end
    -- Safety net: a held low height only makes sense near the spot. Far
    -- away (more than two stops + 2 km) always go back to the cruise height.
    if T.holdR and s > 2 * BrakeDist(mmax(vF, 0), ab) + 2000 then T.holdR = nil end
  end

  if T.phase == "LIFT" then
    heading = fl                                   -- no turning before we're up
    local gd = ReadGroundDist()
    local tL = now() - T.t0
    local vUpL = vel:dot(upW)
    -- Full brakes while rising (Carl, 1121: they don't hold the hovers
    -- back, and tapping them only once it slid felt wrong).
    brake = 1
    -- Up at hover height (or above what the sensors can see) → carry on.
    -- Can't get there → AP OFF with a popup, never "carry on low" (Carl:
    -- a ship that can't reach its hover height can't clear hilly ground,
    -- and not every take-off is from a pad). "Can't" = stopped rising
    -- below it for 2 s, or still not there after 12 s.
    if (gd >= HoverHeight - 1.5 and mabs(vUpL) < 0.5) or (gd < 0 and tL > 1) then
      T.phase, T.t0 = "LINE UP", now()
    else
      if tL > 3 and mabs(vUpL) < 0.3 then T.platT = T.platT or now() else T.platT = nil end
      if tL > 12 or (T.platT and now() - T.platT > 2) then
        local got = mmax(gd, 0)
        -- Close enough (Carl, 1118: a loaded ship stopped at 7 of 10 m and
        -- was refused, then flew to space fine by hand): 60% of the hover
        -- height and at least 4 m carries on, with a note. Lower still stops.
        if got >= mmax(4, HoverHeight * 0.6) then
          Msg(string.format("Hovers top out at %.1f m with this load (HoverHeight %.0f m) — carrying on", got, HoverHeight))
          T.phase, T.t0, T.platT = "LINE UP", now(), nil
        else
        ShowAlert("NOT ENOUGH LIFT", string.format("Hovers only reach %.1f m of %.0f m — AP off. Add hovers / boosters or lighten the ship",
          got, HoverHeight), "#ff3b3b", 15)
        Msg(string.format("Take-off stopped: the hovers only lift this ship to %.1f m (HoverHeight %.0f m) — too low to clear rough ground safely", got, HoverHeight))
        APDisengage(nil)
        return
        end
      end
    end
  elseif T.phase == "LINE UP" then
    brake = 1
    local err = math.acos(clamp(fl:dot(h), -1, 1))
    local spin = vec3(construct.getWorldAngularVelocity()):len()
    -- (90 s: a big carrier can take a minute to come round; after 30 s it
    -- set off still turning and banked the rest — Carl, 1114-1403)
    if (err < math.rad(3) and spin < 0.05) or now() - T.t0 > 90 then
      -- Radar check straight ahead before setting off (TakeoffBlocker):
      -- something there → hold here, brakes on, and say so; Alt+1 again
      -- goes anyway (the old automatic check warned on every pad field,
      -- removed 2026-11-13 — now one keypress gets past a false one).
      local who, dB
      if not T.obsOk then who, dB = TakeoffBlocker(pos, h, upW) end
      if who then
        if not T.blocked then
          T.blocked = true
          ShowAlert("CONSTRUCT AHEAD", string.format("%s, %.0f m in front — fly clear by hand, or Alt+1 to go anyway", who, dB), "#ffc24b", 15)
          Msg(string.format("Take-off held: %s is %.0f m in front. Fly clear by hand (brake), or Alt+1 to go anyway", who, dB))
        end
      else
        T.phase, T.t0, T.spoolT = "CLIMB", now(), now()
      end
    end
  elseif T.phase == "SLOWING" then
    -- Brakes (when above the stopping curve), nose level, no thrust (rear
    -- engines would push us on).
    brake = T.slowBrake or 1
    accel = -(T.aR or 0)                          -- back engines help (0 if none)
  elseif T.phase == "CRUISE" then
    -- Hold height (cruise height, or the height we were at when slowing
    -- for a short hop) and heading; speed = min(burn speed cap, what we
    -- can still stop from before the spot). Rear engines only: height is
    -- held by pitching the nose (never steep while slow, max 15° down);
    -- if that means more push than the speed needs, brakes take the excess.
    -- Flown like a pilot: the NOSE controls climb/sink, the THROTTLE
    -- controls speed, each with a slowly learned trim (wings or no
    -- wings, the right level-flight attitude is found by itself), and the
    -- nose moves at most 4°/s. The first version worked the attitude out
    -- as if there were no wings and bounced the nose 0-30° on Carl's
    -- winged ship ("bouncing like crazy").
    local aMax = MaxThrustN / mmax(mass, 1)
    local vT = mmin(CruiseCap(), BurnCap(), T.vB or 1e9)
    if T.turning then
      -- Turning round: speed along the actual track; slow enough that a
      -- 45° banked turn circle stays well inside the distance to the spot
      -- (at full cruise speed the 6:1 sim ship circled the spot for ever),
      -- never below ~200 km/h (the wings need speed); nose leads the track
      -- by 40° so the engines help pull it round; flown, not pivoted.
      vF = vH:len()
      -- (distance taken when the turn began: drifting away must not raise
      -- the speed — the sim sped up to 875 km/h and circled ever wider)
      vT = mmin(CruiseCap(), BurnCap(), clamp(msqrt(glen * (T.turnS0 or s) / 4), 55, 400))
      local vt = vH / mmax(vF, 0.1)
      local lead = math.rad(40) * (T.turnSign or 1)
      heading = norm(vt * math.cos(lead) + upW:cross(vt) * math.sin(lead))
    end
    local tR = T.holdR or T.cruiseR
    -- Slow near the end the wings stop lifting (Carl, build 2208: 130 km/h
    -- at 2.7 km up, 533 m out, sinking → fall-guard brakes 100%, "still
    -- stomps"). The wings are now asked for lift during the trip (they
    -- weren't — only hand flying did, like SAGA). Down-facing engines (pushing up), when
    -- fitted, hold the height (below). Without them the wings + nose hold
    -- what they can; a slow sink is fine, the brakes only catch a fast one.
    -- (A planned glide-down sank to the ground in the sim — dropped.)
    -- (hovers / vertical boosters only reach ~15 m down — not up engines;
    -- Carl's 'Up 193 MN' was all hover/VBoost and it still sank)
    local upA = UpEngN() / mmax(mass, 1)
    local slowF = clamp((120 - vF) / 40, 0, 1)
    local noUp = upA < glen * 0.9 and not T.aggHold
    if slowF > 0 and not T.slowMsg and T.aggHold then
      T.slowMsg = true
      Msg("Slowing for "..(AP.name or "the spot").." — the AGG holding the height")
    elseif slowF > 0 and not T.slowMsg then
      T.slowMsg = true
      -- (has them, but too weak in this thin air: say so — Carl's 2323 run
      -- said "no down-facing engines" on a ship that has them)
      local hasUp = mmax(((Thrust and Thrust.U) or 0) - ((Thrust and Thrust.G) or 0), 0) >= mass * glen * 0.9
      Msg(noUp and "Slowing for "..(AP.name or "the spot").." — "..(hasUp and "down-facing engines too weak up here" or "no down-facing engines")..
        " to hold the height: braking late, may sink up to 25 m/s while slow"
        or "Slowing for "..(AP.name or "the spot").." — down-facing engines holding the height")
    end
    local dh = tR - r
    local vUpDes = dh >= 0 and LevelOffVUp(dh) or -mmin(LevelOffVUp(-dh), 40)
    local tNow = now()
    local dtc = clamp(tNow - (T.tcr or tNow), 0, 0.5)
    T.tcr = tNow
    if not T.pc then
      T.pc = math.asin(clamp(fwd:dot(upW), -1, 1))     -- start from where the nose is
      T.trim, T.thr = 0, 0
    end
    local pMax = capRad * clamp((vF - 15) / 35, 0, 1)
    local vErr = vUpDes - vUp
    -- Down-facing engines (pushing up) hold the height when slow (learned like the
    -- throttle trim); fades out above ~430 km/h where the wings do it.
    if upA > 0.5 and slowF > 0 then
      -- (faster learning: from 0 at 0.4 it took ~8 s to take the weight
      -- the wings gave up, and the ship sank meanwhile — 1113-2355)
      T.vl = clamp((T.vl or 0) + 0.8 * vErr * dtc, 0, upA)
      vAcc = clamp(T.vl + 0.8 * vErr, 0, upA) * slowF
    else
      T.vl = 0
    end
    -- (no steep-and-slow nose-up hold when the engines can hold us)
    -- (nose-up can't hold a slow ship without wings or up engines — it only
    -- pushes us on; level nose, sink instead)
    pMax = mmin(pMax, math.rad(5) + capRad * (1 - slowF))
    -- Point the nose along the climb/sink path we want (at 1,000 km/h a
    -- 10 m/s climb is only ~2°) plus a slowly learned trim (the wings'
    -- angle of attack, or the extra nose-up a wingless ship needs), and
    -- only a small direct correction. 0.015 rad per m/s with the 4°/s
    -- limit made a winged ship oscillate ±10-20° once real turn/engine lag
    -- was in the sim — Carl: "still bouncing".
    local gamDes = math.asin(clamp(vUpDes / mmax(vF, 30), -0.35, 0.35))
    T.trim = clamp(T.trim + 0.0004 * vErr * dtc, -math.rad(15), mmax(pMax, 0))
    local pWant = clamp(gamDes + T.trim + 0.0015 * vErr, -math.rad(15), pMax)
    local step = math.rad(3) * dtc   -- (6°/s when far off brought back a ~9° bounce on slow-turning ships — sim)
    T.pc = T.pc + clamp(pWant - T.pc, -step, step)
    pitch = T.pc
    -- Burn limit on the TOTAL speed: just after a steep climb much of it
    -- is vertical, and the horizontal-only check let the sim reach 1,377
    -- km/h with a 1,300 km/h burn speed.
    local capT = mmin(CruiseCap(), BurnCap())
    local sErr = mmin(vT - vF, capT - speed)
    T.thr = clamp(T.thr + 0.05 * sErr * dtc, 0, aMax)
    local need = T.thr + 0.3 * sErr + glen * mmax(math.sin(pitch), 0)
    -- Over the approach curve: no forward push at all (the learned drag
    -- trim kept pushing against the brakes), only what holds us up.
    if T.vB and vF > vT + 0.3 then
      T.thr = 0
      need = glen * mmax(math.sin(pitch), 0)
    end
    local want0 = h * math.cos(pitch) + upW * math.sin(pitch)
    local ramp = clamp((fwd:dot(want0) - 0.966) / (0.996 - 0.966), 0, 1)
    -- (turning: the nose leads the track on purpose — push anyway, or the
    -- turn bled the speed to 50 km/h with the engines idle — sim)
    if T.turning then ramp = 1 end
    accel = clamp(need, 0, aMax) * ramp
    -- Brakes ease in (DU's command asks for fB x (3*speed + 1) m/s²): about
    -- the approach curve's rate plus a catch-up — not all-or-nothing.
    if vF > vT + 0.3 then
      brake = clamp(((T.aG or 2) * 0.7 + 0.5 * (vF - vT)) / (brakeSpeedFactor * speed + brakeFlatFactor), 0.02, 1)
      -- Back engines on the retro part of the curve: the half push it was
      -- planned with plus a catch-up, never more than they have.
      local aR = T.aR or 0
      if aR > 0.5 then accel = -clamp(aR * 0.5 + 1.0 * (vF - vT), 0, aR) end
    end
    -- Near the spot, ease off any sideways drift too (with the height held
    -- by engines nothing else bled it off and the sim circled 20 m out).
    if s < 300 and speed > 0.5 then
      local vS = (vH - h * vF):len()
      if vS > 0.5 then
        brake = mmax(brake, clamp(0.5 * (vS - 0.3) * speed / mmax(vS, 0.1) / (brakeSpeedFactor * speed + brakeFlatFactor), 0, 1))
      end
    end
    -- Fall guard: slow near the end, the wings may no longer hold us up.
    -- (measured against the planned glide, not level flight)
    -- No up engines and slow: a controlled sink like SAGA's (~15 m/s), not
    -- a brake stomp to hold the height (Carl: "sinking is ok, just not free
    -- falling"). Kept 350 m above the descent start so it still hands over.
    -- Down-facing engines that turn out too weak here (atmo engines lose
    -- push in thin air; the survey's figure can be far above what they
    -- give at 2 km): asked to push and still sinking for 3 s → treat as none.
    -- (Judged on the result, not on the engines being flat out: if they
    -- don't answer the command at all, the saturation test never fires.)
    -- Carl, 1113-2049, engines on all sides: sank 8 m/s at 2.2 km, the
    -- fall guard held the brakes at 100% (brakes also kill the forward
    -- speed) and it crawled the last 500 m at 170 km/h.
    -- (never on an AGG trip: "let it sink" there dropped the Hammer Crest
    -- ~900 m under the lift, where the AGG no longer holds — 1114-1049)
    if not noUp and slowF > 0 and not T.upWeak and not T.agg then
      -- (only once they're asked for at least the full weight, or all they
      -- have: at 97% air it called strong engines weak while their trim
      -- was still building up — 1113-2355)
      -- (and actually SINKING: climbing slower than wanted on the way up to
      -- the cruise height counted as "sinking" and set it off — sim)
      if vAcc >= mmin(glen, upA * slowF * 0.9) and vUp < mmin(vUpDes, 0) - 3 then
        T.upWeakT = T.upWeakT or tNow
        if tNow - T.upWeakT > 3 then
          T.upWeak = true
          Msg("Down-facing engines can't hold the height here (thinner air) — letting it sink, brakes only stop a fast fall")
        end
      else
        T.upWeakT = nil
      end
    end
    if T.upWeak then noUp = true end
    local fallAt = -8
    if T.agg then
      -- AGG trip: stay at the AGG height — brakes from a 4 m/s sink (more
      -- than the planned rate only when coming down to the AGG height).
      fallAt = mmin(-4, vUpDes - 4)
    else
      if noUp and slowF > 0 and AP.descentR and r > AP.descentR + 350 then fallAt = -25 end
      fallAt = mmin(fallAt, vUpDes - 8)
    end
    if vUp < fallAt then
      brake = mmax(brake, clamp((fallAt - vUp) / 10, 0.1, 1))
      if not T.fallMsg then T.fallMsg = true; Msg("Sinking "..math.floor(-vUp + 0.5).." m/s — brakes keeping it to "..math.floor(-fallAt + 0.5).." m/s") end
    end
    if speed > capT + 5 then brake = mmax(brake, clamp((speed - capT - 5) / 20, 0, 1)) end
    -- Braking hard (fall guard, sideways drift, speed cap): DU's brakes
    -- slow ALL the motion, so the throttle saw the forward speed drop and
    -- wound up to 100% against them — full throttle and 72% brake at once,
    -- 26 m from the spot (Carl, 1120, wingless ship sinking 8 m/s). Then
    -- only the push that holds the nose-up attitude, and the speed trim
    -- doesn't wind up meanwhile.
    if brake > 0.3 then
      T.thr = mmin(T.thr or 0, mmax(accel - glen * mmax(math.sin(pitch), 0), 0))
      accel = mmin(accel, clamp(glen * mmax(math.sin(pitch), 0), 0, aMax) * ramp)
    end
  else -- CLIMB
    local vF = vel:dot(fwd)
    local vUp = vel:dot(upW)
    -- Not actually climbing at full angle and good speed (no wings, or
    -- not enough of them: sim, a 1.3:1 ship skimmed the ground at 24°):
    -- raise the angle 3°/s, up to MaxClimbAngle. Climbing well again →
    -- ease it back. The speed rule below still applies on top.
    local tNow = now()
    local dtc = clamp(tNow - (T.tc or tNow), 0, 0.5)
    T.tc = tNow
    -- Atmosphere trips: AtmoClimbAngle (45° by default; was 20° before the
    -- climb learned to flatten with speed, below). Space keeps MaxClimbAngle.
    local climbCap = capRad
    if T.atmo then climbCap = mmin(capRad, math.rad(clamp(tonumber(AtmoClimbAngle) or 45, 5, 60))) end
    climbMax = mmin(climbMax, climbCap)
    -- Real engine push along the nose, measured (smoothed over ~2 s):
    -- DU's max-thrust figure is the thick-air one. Zero-talent toon over
    -- Haven (1120): DU said 1.86 g, the engines really gave 0.76 g at
    -- 37% air, so the climb held 41° and bled speed. The angle comes from
    -- the weaker of the two; strong ships climb as before.
    -- (only at full throttle with no brakes — what the climb commands)
    if T.vP and dtc > 0.02 and (AP.brake or 0) < 0.05 then
      local okA, airA = pcall(construct.getWorldAirFrictionAcceleration)
      airA = okA and airA and vec3(airA) or vec3()
      local push = ((vel - T.vP) / dtc - g - airA):dot(fwd) / mmax(glen, 0.1)
      T.pushG = T.pushG and (T.pushG + (push - T.pushG) * clamp(dtc / 2, 0, 1)) or push
      T.pushN = (T.pushN or 0) + dtc
    end
    T.vP = vel
    if T.pushG and (T.pushN or 0) > 3 and vF > 33 then
      local twrM = mmin(twr, T.pushG)
      climbMax = mmin(climbMax, math.rad(clamp(15 + (twrM - 1) * 30, 10, 60)))
    end
    local full = climbMax + (T.extra or 0)
    -- Forward speed trend (smoothed, m/s²): steepening only helps while
    -- the engines can hold the speed. In thin air (atmo engines and wings
    -- weaken with height) a steeper nose just bleeds speed, then lift,
    -- and the ship sinks (Carl: DU ships fall if pitched up without the
    -- thrust for it).
    if T.vFp and dtc > 0 then
      T.aF = (T.aF or 0) + (((vF - T.vFp) / dtc) - (T.aF or 0)) * clamp(dtc / 2, 0, 1)
    end
    T.vFp = vF
    local losing = (T.aF or 0) < -0.3
    local atAngle = vF > 50 and fwd:dot(upW) > math.sin(full) - 0.05
    -- At the speed cap with the brakes taking the spare push (Carl's main
    -- toon over Alioth, 1120: 1024 km/h on the cap, brakes 1%, nose 10°,
    -- climbing only 7 m/s): raise the nose so that push goes into height
    -- instead (1.5°/s); the easing back below waits until the brakes are off.
    local capE = CruiseCap()
    if inAtmo and B and (B.atm or 0) > 0 and not ThinAirClimb() then capE = mmin(capE, BurnCap()) end
    local capBrake = speed > capE * 0.97 and (AP.brake or 0) > 0.005
    if capBrake and vF > 50 then
      T.extra = (T.extra or 0) + math.rad(1.5) * dtc
    elseif atAngle and vUp < 5 and losing then
      -- Steeper isn't working: ease back toward an angle it can hold.
      T.extra = mmax((T.extra or 0) - math.rad(1.5) * dtc, 0)
    elseif atAngle and vUp < 5 then
      T.extra = (T.extra or 0) + math.rad(3) * dtc
    elseif atAngle and vUp > 20 then
      T.extra = mmax((T.extra or 0) - math.rad(1) * dtc, 0)
    end
    -- (The gentle atmosphere angle is only the START: a ship that isn't
    -- climbing still steepens step by step up to MaxClimbAngle — at a flat
    -- 20° a weak wingless ship flew 38 km at ~100 m in the sim.)
    T.extra = clamp(T.extra or 0, 0, mmax(capRad - climbMax, 0))
    climbMax = climbMax + T.extra
    -- Can't climb any more: at the steepest allowed angle, or steeper only
    -- loses speed — and still not gaining height for 10 s.
    -- (also simply SINKING, whatever the angle: Carl's ship started to
    -- fall in the climb with no message)
    -- (at the burn-speed cap, losing speed is the brakes doing their job,
    -- not a sign the climb is failing — Thades 1115-0629: CAN'T REACH SPACE
    -- at 30 km, 1020 km/h, sitting on the cap)
    local capC = CruiseCap()
    if inAtmo and B and (B.atm or 0) > 0 and not ThinAirClimb() then capC = mmin(capC, BurnCap()) end
    local atCap = speed > capC * 0.97
    -- (a small dip while still speeding up hard is the start of the climb,
    -- not a failure: zero-talent toon off Haven Base, 1120 — sank 3 m/s at
    -- 50 m up while gaining 8 m/s², got CAN'T REACH SPACE 10 s in, and
    -- the warning then blocked the stay-in-the-air switch for the trip)
    local gaining = (T.aF or 0) > 1
    if (vUp < 1.5 and vF > 50 and (climbMax >= capRad - 0.01 or (losing and not atCap))) or (vUp < -2 and vF > 30 and not gaining) then
      T.sinkT = T.sinkT or tNow
      local sinking = vUp < -2
      if tNow - T.sinkT > (sinking and 3 or 10) and not T.warned then
        local rNow = B and (pos - B.c):len() or 0
        local hUp = (T.startR and (rNow - T.startR)) or 0
        -- Heading for space (orbit hop / via space) but the spot is on THIS
        -- planet: stay in the air and fly there as an atmosphere trip at
        -- the height reached, if that clears the highest ground (Carl,
        -- 1120: zero talents + mission load topped out at 3.3 km on
        -- Alioth: "a way to stay in atmo and still fly the route").
        local toAtmo = false
        if not T.atmo and not T.agg and B and AP.surfB == B and (B.atm or 0) > 0 and AP.descentR
           and rNow > (B.top or B.r) + 300 then
          T.atmo, T.cruiseR, toAtmo = true, rNow, true
          T.whyOut = nil
        end
        -- (sinking: cruise at the height it has even if that's low —
        -- holding it beats falling — and say so)
        if sinking and T.atmo and T.cruiseR and hUp <= 150 then
          ShowAlert("CAN'T CLIMB", string.format("Sinking in the climb — holding %.0f m. Watch the terrain, brake to take over", rNow - (B and B.r or 0)), "#ffc24b", 12)
        end
        if T.atmo and T.cruiseR and (hUp > 150 or sinking) then
          -- Atmosphere trip: cruise at the height it reached instead of
          -- fighting thin air for the planned one.
          -- Cruise starts from the attitude that's holding us up right now
          -- (a weak wingless ship needs ~45° nose-up just to stay level;
          -- the cruise's usual level-nose start dropped it 2.4 km — sim).
          -- Not AT the ceiling: there the ship only just holds on (nose
          -- 43°, sinking 4-5 m/s, losing speed — Carl, 1120-2148, "it
          -- should go down some until level flight holds"). Switching from
          -- a space trip: the normal air-trip cruise height (AtmoCruiseR)
          -- if that's lower, else 500 m down. A stalled air trip: 300 m
          -- down. Never under 300 m over the highest ground, and a ship
          -- sinking low in the climb keeps the height it has.
          if toAtmo then
            T.cruiseR = mmax(mmin(rNow - 500, AtmoCruiseR(B)), (B.top or B.r) + 300)
          elseif hUp > 150 then
            T.cruiseR = mmax(rNow - 300, (B.top or B.r) + 300, (T.startR or 0) + 150)
          else
            T.cruiseR = rNow
          end
          T.cruiseR = mmin(T.cruiseR, rNow)
          T.phase = "CRUISE"
          T.pc = math.asin(clamp(fwd:dot(upW), -1, 1))
          T.trim = T.pc - math.asin(clamp(vUp / mmax(speed, 1), -1, 1))
          T.thr = MaxThrustN / mmax(mass, 1)
          if toAtmo then
            ShowAlert("STAYING IN THE AIR", string.format("Can't reach space with this ship/load — flying to %s at %.0f m", AP.name or "the spot", T.cruiseR - B.r), "#ffc24b", 12)
            Msg(string.format("Can't reach space — staying in the air: cruising at %.0f m to %s (brake to take over)", T.cruiseR - B.r, AP.name or "the spot"))
          else
            Msg(string.format("Can't climb higher — cruising at %.0f m", T.cruiseR - (B and B.r or 0)))
          end
        else
          T.warned = true
          local what = T.atmo and "CAN'T CLIMB" or "CAN'T REACH SPACE"
          ShowAlert(what, "Not enough thrust or lift here — brake and fly by hand", "#ff3b3b", 15)
          Msg((T.atmo and "Can't climb" or "Can't climb out to space").." — not enough thrust or lift at this height. Brake and fly by hand")
        end
      end
    else
      T.sinkT = nil
      -- Climbing well again after a warning: re-arm it, so a later stall
      -- still gets the warning (or the switch to an air trip).
      if T.warned and vUp > 5 then
        T.okT = T.okT or tNow
        if tNow - T.okT > 5 then T.warned, T.okT = nil, nil end
      else T.okT = nil end
    end
    -- Rocket boost (ships with rockets): when the climb is struggling —
    -- the check above that leads to CAN'T CLIMB — fire them; off again at
    -- 92% of the burn speed (they can't be throttled, and Carl: "rockets
    -- will get me to burn fairly quickly unless the ship is heavy"), once
    -- climbing well, or when the climb ends. "rockets test" fires them on
    -- the next climb on purpose. (The on/off governor idea is from
    -- ArchHUD's rocket handling — Dodgin's; written our own way.)
    if Thrust and (Thrust.K or 0) > 0 then
      local capB = (inAtmo and B and (B.atm or 0) > 0 and not ThinAirClimb()) and BurnCap() / BURN_FRAC or 1e9
      local struggling = T.sinkT and tNow - T.sinkT > 2
      if RocketTest and vF > 30 and not T.rTest then T.rTest = tNow; RocketTest = nil end
      local testing = T.rTest and tNow - T.rTest < 15
      if not RocketOn then
        if (struggling or testing) and speed < capB * 0.8 and tNow - (T.rOff or 0) > 3 then
          SetRockets(true, struggling and "Climb struggling — rockets on (off near the burn speed or once climbing well)"
                                     or "Rocket test — rockets on for up to 15 s")
          T.rOn = tNow
          if struggling then T.sinkT = tNow end      -- give them time before CAN'T CLIMB
        end
      elseif RocketByAP then
        local why
        if speed > capB * 0.92 then why = "near the burn speed"
        elseif T.rTest and not testing then why = "test done"; T.rTest = nil
        elseif not testing and T.rOn and tNow - T.rOn > 3 and vUp > 15 then why = "climbing well" end
        if why then SetRockets(false, "Rockets off — "..why); T.rOff = tNow end
      end
    end
    -- Atmosphere trips: no steeper than the nose can come back down from
    -- (~3°/s) before the cruise height at today's speed — climbing on
    -- meanwhile at about half the current climb rate. So the climb is as
    -- steep as it can be early on and flattens as the speed builds (a 6:1
    -- ship at a fixed 60° overshot by 1.3 km in the sim; Carl's limit:
    -- never miss the height by 1.5 km).
    -- Same for a take-off that becomes an orbit hop round this planet: aim
    -- at the hop height (air top + 2 km). Climbing full angle to the air
    -- top, it came out at a few hundred m/s straight up and coasted to
    -- 11 km over Haven (hop height 9.9 km), then sank back in an oval
    -- (Carl, 1119). Flattening early also builds the sideways speed the
    -- orbit needs.
    local levelR = T.atmo and T.cruiseR
    if not levelR and B and OrbitHop and AP.surfB == B and AP.descentR and (B.atm or 0) > 0 then
      levelR = B.hard + 2000
    end
    if levelR and B then
      local dhL = levelR - (pos - B.c):len()
      -- (speed ~4 s ahead: a strong ship doubles it in that time)
      local aX = mmax(MaxThrustN / mmax(mass, 1) - glen, 0)
      local vA = mmin(speed + aX * 4, mmax(mmin(CruiseCap(), BurnCap()), speed))
      -- Climb rate it would really have: no more than speed × sin(angle),
      -- and no more than today's climb rate plus ~4 s of spare thrust. A
      -- weak ship needs its nose up just to hold height; judged on speed
      -- alone the nose was pushed down as it sped up and it sank (Carl).
      local p = climbMax
      local function vUpAt(pp) return mmin(vA * math.sin(pp), mmax(vUp, 0) + aX * math.sin(pp) * 4) end
      while p > math.rad(5) and vUpAt(p) * 0.5 * (p / math.rad(3)) > dhL * 0.7 do
        p = p - math.rad(1)
      end
      climbMax = p
      -- Orbit-hop take-off: near the top of the air the wings no longer
      -- end the climb when the nose comes down — the ship coasts up until
      -- gravity stops it (v²/2g: ~5 km at 250 m/s on Haven). Levelling
      -- by the air rule above started at 7 km and it still coasted to
      -- 11.4 km (Carl, 1119-2336). So also: no faster upward than gravity
      -- can stop by the hop height; over that the nose comes down
      -- (smoothly, to ~10% of the angle at 110%).
      if not T.atmo then
        local vOk = msqrt(2 * glen * 0.8 * mmax(dhL, 0))
        local ratio = vUp / mmax(vOk, 1)
        if ratio > 0.8 then climbMax = climbMax * clamp((1.1 - ratio) / 0.3, 0.1, 1) end
      end
    end
    -- Speed first: losing speed well under the speed cap → lower the
    -- nose (2°/s) until the speed builds, then raise it again (1°/s).
    -- Carl's hand climb that worked (zero talents, Haven): nose to 0°,
    -- gain speed, then ~15° out to space. Level only once clear of the
    -- ground and still rising; otherwise no lower than 8°.
    do
      local capS = CruiseCap()
      if inAtmo and B and (B.atm or 0) > 0 and not ThinAirClimb() then capS = mmin(capS, BurnCap()) end
      local hUpS = (B and T.startR) and ((pos - B.c):len() - T.startR) or 0
      if inAtmo and vF > 50 and (T.aF or 0) < -0.5 and speed < capS * 0.85 then
        T.flat = (T.flat or 0) + math.rad(2) * dtc
      elseif (T.aF or 0) > 0.3 or speed >= capS * 0.85 or not inAtmo then
        T.flat = mmax((T.flat or 0) - math.rad(1) * dtc, 0)
      end
      local floorA = (hUpS > 500 and vUp > 10) and 0 or math.rad(8)
      T.flat = clamp(T.flat or 0, 0, mmax(climbMax - floorA, 0))
      if T.flat > math.rad(3) and not T.flatMsg then
        T.flatMsg = true
        Msg("Losing speed in the climb — nose down to build speed first")
      end
      climbMax = climbMax - T.flat
    end
    -- (nose starts up at 8 m/s, full by 33 m/s — was 15 → 50 m/s; Carl
    -- nearly clipped a light on the market pad: "ours could tilt up sooner")
    pitch = climbMax * clamp((vF - 8) / 25, 0, 1)
    local aMax = MaxThrustN / mmax(mass, 1)
    -- Full throttle from the start of the climb (Carl: "max lift asap" —
    -- the speed builds the wing lift and lifts the nose sooner; a strong
    -- ship may touch the burn speed briefly before the cap below brakes it,
    -- an accepted trade-off). It used to push gently until the nose was up.
    accel = aMax
    local cap = CruiseCap()
    if inAtmo and B and (B.atm or 0) > 0 and not ThinAirClimb() then cap = mmin(cap, BurnCap()) end
    if speed > cap then
      -- Keep enough thrust to go on climbing (1.15 g upward) and let the
      -- brakes take the excess speed. Cutting thrust to 'hold speed along
      -- the nose' left less lift than gravity: the sim sank back from
      -- 8.3 km while sitting at the speed cap.
      -- Out to space: 1.15 g only just beats gravity, and the brakes then
      -- ate the climb too (Thades, 30 km: levelled off at the cap). Push
      -- for a real climb (+3 m/s² upward), the brakes keep the speed.
      local upNeed = T.atmo and glen * 1.15 or (glen * 1.15 + 3)
      accel = mmin(aMax, upNeed / mmax(fwd:dot(upW), 0.3))
      brake = clamp((speed - cap) / 20, 0, 1)
    end
  end

  -- Keep the FLIGHT PATH on the destination, not just the nose (Carl: the
  -- destination sat ~1-2° left of the path line while the nose was on it,
  -- so the ship slid in sideways and the descent had to turn to finish;
  -- SAGA held the path line on the destination). If the level track is
  -- off the bearing, aim the nose further the other way (crab), ≤ 10°.
  if (T.phase == "CLIMB" or T.phase == "CRUISE") and heading == h then
    local vL = vel - upW * vel:dot(upW)
    if vL:len() > 30 then
      vL = vL / vL:len()
      local trk = math.atan(vL:cross(h):dot(upW), vL:dot(h))   -- + = turn left to get on track
      AP.trackErr = math.deg(trk)
      -- plus a slowly learned crab angle (engines pushing slightly to one
      -- side, asymmetric drag): takes out the steady remainder.
      local tN = now()
      local dtk = clamp(tN - (T.tk or tN), 0, 0.5)
      T.tk = tN
      T.crab = clamp((T.crab or 0) + 0.3 * trk * dtk, -math.rad(8), math.rad(8))
      local a = clamp(1.5 * trk + T.crab, -math.rad(10), math.rad(10))
      heading = norm(h * math.cos(a) + upW:cross(h) * math.sin(a))
    end
  else
    AP.trackErr = nil
  end

  local want = heading * math.cos(pitch) + upW * math.sin(pitch)
  -- Turn like a plane: heading only round the vertical, climb angle on
  -- its own, and bank into big turns at speed. The shortest-rotation
  -- turn (AlignAV) took a target straight behind "over the top" — a half
  -- loop, then a roll upright (Carl: "80% of ships would crash doing
  -- that"; SAGA and Arch turn like a real plane).
  do
    local flv = fwd - upW * fwd:dot(upW)
    flv = flv:len() > 0.05 and norm(flv) or fl
    local hv = heading - upW * heading:dot(upW)
    hv = hv:len() > 0.01 and norm(hv) or flv
    local yawErr = math.atan(flv:cross(hv):dot(upW), flv:dot(hv))     -- + = turn left
    local pCur = math.asin(clamp(fwd:dot(upW), -1, 1))
    -- (while far off the new heading, hold the nose near level: a steep
    -- nose while turning round loses the turn and the height)
    local pDes = pitch
    if mabs(yawErr) > math.rad(30) and not T.turning then pDes = clamp(pitch, -math.rad(5), math.rad(5)) end
    local wYaw = upW * YawRate(yawErr, upW, 1.2, AlignRate)
    local wPitch = right * clamp((pDes - pCur) * 1.2, -AlignRate, AlignRate)
    -- Bank: up to 30° into the turn, only with speed (a slow ship just
    -- turns flat), level again as it lines up.
    -- SAGA-style bank: 2× how far the TRACK is off the target, up to 45°,
    -- faded in from ~140 to ~290 km/h (slow ships turn flat). In a
    -- turn-around it banks fully to the side it chose, even dead behind.
    local bankMax = math.rad(45) * clamp((speed - 40) / 40, 0, 1)
    -- Less bank while sinking: banking only helps a ship whose wings /
    -- stabilizers carry it; one held up by its engines just loses height
    -- in a bank (wingless sim ships sank ~1.5 km in a 45° turn-around).
    local vUpB = vel:dot(upW)
    if vUpB < -3 then
      T.bankCut = mmin((T.bankCut or 1), clamp(1 + (vUpB + 3) / 12, 0.15, 1))
    elseif vUpB > 0 then
      T.bankCut = mmin(1, (T.bankCut or 1) + 0.002)
    end
    bankMax = bankMax * (T.bankCut or 1)
    local tA = (T.trackAng and speed > 30) and T.trackAng or yawErr
    local bankDes = clamp(-2 * tA, -bankMax, bankMax)                  -- + = right wing low
    if T.turning and T.turnSign then bankDes = -T.turnSign * bankMax end
    local rollErr = math.atan(right:dot(wv), -up:dot(wv))            -- + = right wing low now
    local wRoll = mabs(fwd:dot(wv)) > 0.9 and vec3() or fwd * RollRate(rollErr - bankDes, fwd)
    AP.angVel = wYaw + wPitch + wRoll
  end
  AP.alignErr = math.deg(math.acos(clamp(fwd:dot(want), -1, 1)))
  -- Climb starting slow and still well off the take-off direction (the
  -- LINE UP was skipped: already hovering, or the ground sensors saw
  -- nothing): brakes on and no push until the nose is round within 10°.
  -- Carl, 1121: "90% sure it turned with no brakes".
  if T.phase == "CLIMB" and speed < 15 and not T.turning
     and math.acos(clamp(fl:dot(h), -1, 1)) > math.rad(10) then
    brake, accel = 1, 0
    T.spoolT = now()                  -- then spool up from here too
  end
  -- Spool-up: the first 3 s of the climb, full throttle against the
  -- brakes, then let go (Carl, 1121: "hold the brakes and let the engines
  -- spool up, just like in real life" — the ship then sets off with full
  -- thrust instead of creeping forward while the engines wind up).
  if T.phase == "CLIMB" and T.spoolT and now() - T.spoolT < 3 and speed < 10 then
    brake = 1
  end
  AP.accel, AP.brake, AP.phase = accel, brake, (T.turning and "TURN" or T.phase)
  AP.vAccel = vAcc
  -- Wings: ask them to carry the weight during the trip (hand flying and
  -- SAGA do; the AP sent them nothing). Not on the pad.
  -- (not while the AGG carries the weight: wings asked for it too would
  -- lift the ship off the AGG height)
  AP.wingLift = (T.atmo and T.phase ~= "LIFT" and T.phase ~= "LINE UP" and not T.aggHold) and upW * glen or nil
  if RocketByAP and T.phase ~= "CLIMB" then SetRockets(false, "Rockets off — climb done"); T.rOff = now() end
end

-- ── Orbit hop: far side of the same planet (atmosphere planets only) ──
-- Carl: orbit hops only on planets with an atmosphere; moons keep the
-- normal route at full speed (no SAGA/Arch-style 1000 km/h limits there).
-- Instead of straight lines out to corners, the ship follows the great
-- circle round the planet at the hold-point height (atmosphere top +
-- PlanetClearance) at just under orbital speed: gravity bends the path,
-- the engines mostly coast. Rear engines only — the nose follows the
-- curve, tilted a little up/down to hold height; brakes take any excess
-- speed. Never flips. Near the spot (direct line clear of the planet and
-- within ~2 braking distances) the normal AP does the stop and descent.
-- In orbit round the target's planet (atmosphere planets): going round
-- at 70%+ of the orbital speed, mostly sideways, above the atmosphere
-- trip's cruise height and within one planet radius of the surface.
function OrbitNow(pos)
  local B = AP.surfB
  if not (B and (B.atm or 0) > 0 and AP.descentR) then return false end
  local rel = pos - B.c
  local r = rel:len()
  if r < AtmoCruiseR(B) + 1000 or r > 2 * B.r then return false end
  local up = rel / r
  local vel = vec3(construct.getWorldVelocity())
  local vUp = vel:dot(up)
  local vH = (vel - up * vUp):len()
  local gm = (B.gm or 0) > 0 and B.gm or vec3(core.getWorldGravity()):len() * r * r
  return vH >= 0.7 * msqrt(gm / r) and mabs(vUp) < 0.3 * vH
end

-- orbiting: already in orbit (OrbitNow) — hop round at any height, the
-- orbit settles to the hop height on the way.
function StartOrbitHop(pos, orbiting)
  local B = AP.surfB
  if not (OrbitHop and B and (B.atm or 0) > 0 and AP.target) then return false end
  local R0 = (AP.target - B.c):len()
  local dist = (pos - B.c):len()
  if dist > R0 + 2 * PlanetClearance and not orbiting then                 -- not close: normal route
    Msg(string.format("Orbit hop skipped: %s above the hop height (needs under %s)", FormatDist(dist - R0), FormatDist(2 * PlanetClearance)))
    return false
  end
  local blk = firstBlock(pos, AP.target)
  if blk ~= B then                                                         -- planet not in the way
    if blk then Msg("Orbit hop skipped: "..blk.name.." is in the way first, not "..B.name) end
    return false
  end
  local rp = norm(pos - B.c)
  local q = norm(AP.target - B.c)
  local cr = rp:cross(q)
  local n
  if cr:len() > 0.05 then n = cr / cr:len()
  else
    -- Spot (almost) exactly opposite: any way round is as short; go the
    -- way we're already moving / facing.
    local vel = vec3(construct.getWorldVelocity())
    for _, d in ipairs({ vel, vec3(construct.getWorldOrientationForward()), vec3(0, 0, 1), vec3(1, 0, 0) }) do
      local c = rp:cross(d)
      if d:len() > 1 and c:len() > 0.1 * d:len() then n = c / c:len() break end
    end
  end
  if not n then return false end
  -- Fly round at about the height we start at (Carl: "it would be nice to
  -- stay near the same altitude" — it climbed from ~6 to 16 km to reach
  -- the usual hold height), never under 2 km above the atmosphere and
  -- never higher than that hold height. The hold point above the spot
  -- moves down to the same height, so there's no climb at the end either.
  local Rorb = clamp(dist, B.hard + 2000, R0)
  if Rorb < R0 - 1 then AP.target = B.c + q * Rorb; R0 = Rorb end
  local arc = math.atan(cr:len(), rp:dot(q)) * R0
  AP.orbit = { B = B, R0 = R0, n = n, tc = 0 }
  AP.legs, AP.leg, AP.obs, AP.total = nil, 1, nil, arc
  AP.bk = { time = 0, bands = {} }
  AP.minRemaining, AP.approachDir, AP.aimOff, AP.latFix, AP.maxPast, AP.kdOn = nil, nil, vec3(), false, nil, false
  if ParkHold then ParkHold = nil end
  AP.active, AP.phase, AP.accel, AP.brake, AP.angVel = true, "ORBIT", 0, 0, vec3()
  ParkBrake = false
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  Msg("Orbit hop → "..AP.name.." round "..B.name.." ("..FormatDist(arc)..") — brake to stop")
  return true
end

function APOrbitStep(pos, vel, fwd, up, mass)
  local O = AP.orbit
  local B = O.B
  local rp, r = norm(pos - B.c)
  local q = norm(AP.target - B.c)
  local cr = rp:cross(q)
  local cl = cr:len()
  if cl > 0.05 then O.n = cr / cl end          -- plane through us and the spot
  local n = O.n
  local t = norm(n:cross(rp))                  -- along the circle, toward the spot
  local s = math.atan(cl, rp:dot(q)) * O.R0    -- arc left
  local speed = vel:len()
  local ab = BrakeAccel(mass)
  local remaining = (AP.target - pos):len()
  AP.minRemaining = mmin(AP.minRemaining or remaining, remaining)

  -- Twice a second: hand over to the normal AP once the straight line to
  -- the hold point clears the planet and we're within ~2 stops of it.
  local tn = now()
  if tn - O.tc > 0.5 then
    O.tc = tn
    -- ...and only near the hop height (or right above the spot): handing
    -- over 53 km too high sent the normal AP diving nose-first at the
    -- planet toward the stop point (Carl stopped it). Too high = keep
    -- orbiting, the orbit settles the height first, nose level.
    local nearH = mabs(r - O.R0) < 2000 or s < 3000
    if nearH and s < mmax(2 * BrakeDist(speed, ab), 20000) and SegmentClear(pos, AP.target) then
      Msg("Orbit hop done — final approach to "..AP.name)
      AP.orbit = nil
      if not APEngage(true) then APDisengage(nil) ParkBrake = true end
      return
    end
  end

  local g = vec3(core.getWorldGravity())
  local gIn = -g:dot(rp)                        -- gravity toward the centre
  local gm = (B.gm or 0) > 0 and B.gm or mmax(gIn, 0.01) * r * r
  local vOrb = msqrt(gm / O.R0)
  local vt, vr, vn = vel:dot(t), vel:dot(rp), vel:dot(n)
  local aMax = mmax(MaxThrustN / mmax(mass, 1), 0.1)

  -- Height is held through SPEED, like a real orbit: a bit faster rises,
  -- a bit slower sinks. The speed whose curve (v²/r) gives the wanted
  -- radial acceleration is the target, so the nose stays along the
  -- direction of travel (a first version steered height with thrust and
  -- the nose swung from 20° down to straight up while coasting — sim).
  local vR = clamp((O.R0 - r) / 40, -50, 50)
  -- v²/r = gravity minus the net pull-in we want. Rising too fast (vr > vR)
  -- wants more net pull-in, so LESS speed.
  local inward = gIn + 0.3 * (vR - vr)
  -- Limits from the orbital speed HERE (not at the hop height): 30 km too
  -- high, 0.85× the hop-height speed is nearly orbital, so it couldn't sink
  -- (Carl at 44 km, still climbing).
  local vLoc = msqrt(gm / r)
  local vT = clamp(msqrt(mmax(inward, 0) * r), vLoc * 0.85, vLoc * 1.1)
  vT = mmin(vT, CruiseCap(), BrakeVmax(s, ab))
  local At = 0.5 * (vT - vt)
  local brake = 0
  if vt > vT + 3 then brake = clamp((vt - vT) / 20, 0, 1) end
  -- Climbing (or falling) much faster than wanted: speed alone only bends
  -- the path ~2 m/s², so a fast climb out of the atmosphere coasted up to
  -- 21 km (Carl). Brakes push against ALL of our motion, the climb too,
  -- while the engines keep pushing along the circle: the up/down motion
  -- dies in seconds, nose stays level.
  -- Only against motion the WRONG way (rising when we should hold/sink,
  -- falling when we should hold/climb), and never harder than the engines
  -- can make up along the circle: braking just to "start sinking" stopped
  -- a strong-braked ship dead at 25 km in the sim.
  -- ...and only with speed to spare along the circle: brakes slow ALL our
  -- motion, so under orbital speed they killed the speed the hop needs
  -- (Carl, 1118: engaged at 6 km just out of the climb at 1,700 km/h and
  -- 20° up, it braked to a stop at 8.7 km). Under speed, gravity ends the
  -- climb by itself while the engines push along the circle.
  -- Faded in from 90% to 100% of the wanted speed, not switched at 95%:
  -- sitting right at the switch, it flicked throttle / brake on and off
  -- (Carl, 1119 on Haven at 2,390 km/h).
  local vrErr, bR = vr - vR, 0
  if vrErr > 15 and vr > 5 then bR = (vrErr - 15) / 40
  elseif vrErr < -15 and vr < -5 then bR = (-vrErr - 15) / 40 end
  bR = bR * clamp((vt / mmax(vT, 1) - 0.9) / 0.1, 0, 1)
  bR = clamp(bR, 0, mmin(1, aMax * 0.8 / mmax(ab, 0.1)))
  brake = mmax(brake, bR)
  At = mmax(At, 0)
  -- Still slow (just out of the climb): speed can't hold us up yet, so
  -- part of the thrust lifts (never pushes down), the rest accelerates.
  local Ar = 0
  -- Also a safety floor: within 1 km of the atmosphere top (Carl's hop
  -- started just above it and sank to 5.3 km, into the thin air top, at
  -- 4,100 km/h) lift with thrust too. Higher up the gentle speed-only
  -- climb stays (Carl liked it).
  if vt < vOrb * 0.85 or r < (B.atm or 0) + 1000 then
    Ar = mmax(0.3 * (vR - vr) + gIn - mmax(vt, 0) ^ 2 / r, 0)
  end
  -- Rising much too fast while still under speed (brakes faded out): part
  -- of the push goes DOWN instead, nose up to ~20° below the path, so the
  -- climb dies without losing speed. Carl, 1119 on Haven: the hop started
  -- just out of the air still climbing steeply and coasted from its
  -- ~10 km hop height up past 18 km.
  if vrErr > 15 and vr > 5 and bR < 0.05 then
    Ar = mmin(Ar, mmax(0.3 * (vR - vr) + gIn - mmax(vt, 0) ^ 2 / r, -aMax * 0.34))
  end
  local lat = rp * Ar + n * (-0.5 * vn)
  local ll = lat:len()
  if ll > aMax * 0.7 then lat = lat * (aMax * 0.7 / ll) end
  local along = mmin(At, msqrt(mmax(aMax * aMax - lat:len() ^ 2, 0)))
  -- Nose at most ~20° off the direction of travel: a small sideways or
  -- lift need never swings it round (brakes take any extra speed).
  -- While braking (slowing for the spot, weak brakes) up to 60°, so the
  -- lift doesn't push forward harder than the brakes slow us.
  along = mmax(along, lat:len() * (brake > 0 and 0.58 or 2.75))
  local d = t * along + lat
  local aim, accelWant = t, 0
  if d:len() > 0.05 then aim, accelWant = d / d:len(), d:len() end
  local ramp = clamp((fwd:dot(aim) - 0.966) / (0.996 - 0.966), 0, 1)

  AP.remaining, AP.vAlong, AP.vDes = s, vt, vT
  AP.accel, AP.brake, AP.phase = mmin(accelWant, aMax) * ramp, brake, "ORBIT"
  local right = vec3(construct.getWorldOrientationRight())
  AP.angVel = AlignAV(fwd, aim, up) + RollLevelAV(fwd, right, up, -rp)
  AP.alignErr = math.deg(math.acos(clamp(fwd:dot(aim), -1, 1)))
end

-- Angular velocity that turns `fwd` toward `aim`, proportional to the
-- angle and capped at AlignRate. Torque tracking in FlightFlush adds the
-- damping (same mechanism as manual stick input).
function AlignAV(fwd, aim, up)
  local c = clamp(fwd:dot(aim), -1, 1)
  local axis = fwd:cross(aim)
  local al = axis:len()
  if al < 1e-4 then
    if c > 0 then return vec3() end
    axis, al = up, 1   -- exactly backwards: flip over the top
  end
  return axis / al * mmin(math.acos(c) * 1.2, AlignRate)
end

-- One autopilot physics step (called from onFlush).
--   Steers along the velocity error (desired velocity − actual), so the
--   same rule handles accelerating, killing sideways drift and cruising.
--   Desired speed = min(cruise cap, speed we can still brake from).
-- ── Parking heading: turn in place over the spot ───────────────────
-- Stopped over the spot with a parking heading (|hdg=N on the ::pos,
-- from Navigator): hold there on the brakes (and the up engines / AGG),
-- level, and yaw slowly to face it before the last step — the AGG hold or
-- the landing. Done up high so a big ship's swing clears buildings (Carl).
function ParkTurnThen(after)
  if AP.hdg and AP.surfB then
    AP.parkTurn = { after = after, t0 = now() }
    AP.active = true
    Msg(string.format("Over %s — turning to face %.0f° first", AP.name, AP.hdg))
    return
  end
  after()
end

function APParkTurnStep(pos, vel, fwd, up, mass)
  local PT = AP.parkTurn
  local dn = DownDir(pos, AP.surfB) or -up
  local upW = -dn
  local right = vec3(construct.getWorldOrientationRight())
  local hv = HeadingVec(AP.hdg, upW)
  local fl = fwd - upW * fwd:dot(upW)
  local yawErr = 0
  if hv and fl:len() > 0.05 then
    fl = fl / fl:len()
    yawErr = math.atan(fl:cross(hv):dot(upW), fl:dot(hv))
  end
  local pitchAng = math.asin(clamp(fwd:dot(dn), -1, 1))
  AP.angVel = right * clamp(pitchAng * 1.5, -0.5, 0.5) + RollLevelAV(fwd, right, up, dn)
            + upW * YawRate(yawErr, upW, 0.6, 0.15)
  -- Hold still: brakes, and the up engines take the weight (none / AGG:
  -- the brakes and the AGG do it).
  local glen = vec3(core.getWorldGravity()):len()
  local upA = UpEngN() / mmax(mass, 1)
  local vUp = vel:dot(upW)
  AP.vAccel = upA > 0.5 and clamp(glen - vUp, 0, upA) or 0
  AP.accel, AP.brake, AP.wingLift = 0, 1, nil
  AP.phase = "PARK TURN"
  AP.alignErr = math.deg(mabs(yawErr))
  AP.remaining, AP.vAlong, AP.vDes = 0, 0, 0
  local spin = vec3(construct.getWorldAngularVelocity()):len()
  local done = not hv or (mabs(yawErr) < math.rad(2) and spin < 0.03)
  if not done and now() - PT.t0 > 60 then
    Msg(string.format("Couldn't finish turning to %.0f° (%.0f° off) — carrying on as it is", AP.hdg, math.deg(mabs(yawErr))))
    done = true
  end
  if done then
    AP.parkTurn = nil
    -- How close the ship's position (what the spot was saved with) ended up.
    if AP.spot and AP.surfB then
      local upS = norm(AP.spot - AP.surfB.c)
      local o = pos - AP.spot
      local M = ComWorld()
      local cm = M and (M - pos) or nil
      system.print(string.format("[HELM] Parked %.1f m from the spot%s", (o - upS * o:dot(upS)):len(),
        cm and string.format(" (centre of mass %.0f m from the ship's position)", (cm - upS * cm:dot(upS)):len()) or " (centre of mass unknown)"))
    end
    PT.after()
  end
end

function APStep(pos, vel, fwd, up, mass)
  if AP.parkTurn then return APParkTurnStep(pos, vel, fwd, up, mass) end
  if AP.takeoff then return APTakeoffStep(pos, vel, fwd, up, mass) end
  if AP.descent then return APDescentStep(pos, vel, fwd, up, mass) end
  if AP.orbit then return APOrbitStep(pos, vel, fwd, up, mass) end
  local legs = AP.legs
  -- Final leg: aim at the target shifted by the look-ahead correction
  -- (PredictCorrect), so gravity during braking carries us onto the point.
  local aimPt = legs[AP.leg]
  if AP.leg == #legs and AP.aimOff then aimPt = aimPt + AP.aimOff end
  -- Surface spot, last 300 m: only the position ACROSS the down line
  -- matters (the descent does the height). Aim at the down line at our
  -- own height, so small final moves keep the nose level instead of
  -- pointing it 50-90° down/up at a point a few dozen metres away.
  local tgt = AP.target
  if AP.surface and AP.surfB and AP.leg == #legs then
    local dn, Rh = norm(AP.target - AP.surfB.c)
    local rel = pos - AP.surfB.c
    local h = rel:dot(dn)
    if (rel - dn * h):len() < 300 and mabs(h - Rh) < 500 and h > (AP.descentR or 0) + 100 then
      tgt = AP.surfB.c + dn * h
      aimPt = tgt
    end
  end
  local toAim = norm(aimPt - pos)
  -- Brake for the STRAIGHT-LINE distance to the target, never the longer
  -- dog-leg path: legs get skipped as soon as the direct line clears, and
  -- planning for the long way round then arrives too fast (Carl saw a
  -- ~1 km overshoot after flying round a planet). Straight line ≤ path,
  -- so the ship can always stop, whichever way it ends up going.
  local remaining = (tgt - pos):len() - StopDist()
  local speed = vel:len()
  BrakeMeasure(vel, speed, mass)
  -- Closest the ship got to the target (for the stop report).
  AP.minRemaining = mmin(AP.minRemaining or remaining, remaining)
  local vAlong = vel:dot(toAim)
  local vCap = CruiseCap()
  -- Gravity pushing along our direction of travel eats into braking.
  local gAlong = mmax(0, vec3(core.getWorldGravity()):dot(toAim))
  local ab = BrakeAccel(mass)
  local ab0 = ab
  ab = mmax(ab - gAlong, ab * 0.2)
  local vBrake = BrakeVmax(remaining, ab)
  -- Coming in to a planet the pull GROWS on the way down, and the plan
  -- above only knows today's gravity: far out it's tiny, so the brakes
  -- start too late and the last stretch can't be stopped (zero-talent
  -- toon, Haven → Alioth 1120: overshot the hold point 10 km above the
  -- air and came into the air too fast — damage). Energy instead: the
  -- brakes must take away today's speed plus everything gravity adds
  -- between here and the stop point (GM·(1/r_stop − 1/r_now)).
  do
    local Bt = AP.surfB or NearestBody(tgt)
    if Bt and (Bt.gm or 0) > 0 then
      local Rp, Rt = (pos - Bt.c):len(), (tgt - Bt.c):len()
      local dPhi = Bt.gm * (1 / Rt - 1 / Rp)
      if Rp > Rt and Rt > 1 then
        vBrake = mmin(vBrake, msqrt(mmax(2 * ab0 * mmax(remaining, 0) - 2 * dPhi, 0)))
      elseif Rp < Rt and Rp > 1 then
        -- Climbing to the point: gravity helps the brakes, and the plan
        -- above leaves that out — it stopped ~400 m short of the hold
        -- point 16 km over Alioth, then crawled up the rest on full
        -- throttle + brakes, nose steep (Carl, 1120). Count 80% of it.
        vBrake = mmax(vBrake, msqrt(mmax(2 * ab0 * mmax(remaining, 0) - 2 * 0.8 * dPhi, 0)))
      end
    end
  end
  local vDes = mmin(vCap, vBrake)
  -- Surface spot: the hold point only marks the top of the down line.
  -- Once we're ON that line (within 30 m) and not drifting sideways, the
  -- descent can start right here, above or below the point. Flying on to
  -- the exact point made the AP hunt round it for ~30 s, nose swinging
  -- from 85° down to 89° up (Carl's "flipping around", reproduced in sim).
  local onLine = false
  if AP.surface and AP.surfB and AP.leg == #legs and remaining < 300 and CanDescend(30) then
    local dn = norm(AP.target - AP.surfB.c)
    local vSide = (vel - dn * vel:dot(dn)):len()
    onLine = vSide < 5 and mabs(vel:dot(dn)) < 50
  end
  -- Obstacle on the path (radar, see UpdateThreats): plan to stop at the
  -- stop point in front of it, like a nearer target. Never steers round.
  local obsLeft
  if AP.obs then
    local o = AP.obs
    obsLeft = (o.pt - pos):dot(o.dir)
    -- Threat gone (moved away / was an estimate) while still well short
    -- of it: carry on to the target.
    if now() - o.seen > 3 and speed > 30 and obsLeft > BrakeDist(speed, ab) * 1.5 then
      AP.obs, obsLeft = nil, nil
      Msg("Path clear — AP continuing")
    else
      vDes = mmin(vDes, BrakeVmax(obsLeft, ab))
    end
  end
  AP.remaining, AP.vAlong, AP.vDes = remaining, vAlong, vDes

  local brake, accel, aim = 0, 0, toAim
  if obsLeft and (speed > BrakeVmax(obsLeft, ab) + 2 or obsLeft < 5) then
    brake, AP.phase = 1, "OBSTACLE"
    if speed < 2 then
      local o = AP.obs
      AP.obs, AP.lastObsId = nil, o.id
      ParkBrake = true                    -- hold still, like an arrival
      ShowAlert("AP STOPPED", o.name.." on the path — fly round it, or Alt+1 to carry on", "#ffc24b", 12)
      APDisengage(string.format("stopped — %s on the path, %s ahead. Fly round it, or Alt+1 to carry on anyway",
        o.name, FormatDist(mmax(o.dist - (pos - o.start):dot(o.dir), 0))))
      return
    end
  elseif onLine then
    APArrive()
    StartDescent()
    return
  elseif remaining <= ArriveTol() and AP.leg == #legs then
    brake, AP.phase = 1, "STOPPING"
    if speed < 2 then
      APArrive()
      if CanDescend() then StartDescent()
      elseif not AP.surface then TripDone() end  -- space stop: done here
      return
    end
  elseif speed > vBrake + mmax(3, vBrake * 0.01) or vAlong > vCap * 1.03 + 10 then
    -- Stopping curve checked against the WHOLE speed, not just the part
    -- toward the target: coming out of a dog-leg corner the motion still
    -- points at the old waypoint, brakes push against all of it, and
    -- judging by the toward-target part alone braked too late (Carl's
    -- overshoot after rounding the planet).
    -- Brake for the stopping curve; over the cruise cap only by a margin,
    -- so small sideways-correction burns at cruise don't trigger brakes.
    brake, AP.phase = 1, "BRAKING"
  else
    local vErr = toAim * vDes - vel
    -- Close to a planet (within PlanetClearance of its atmosphere / ground,
    -- real gravity): leaving it, the course change is made with the
    -- engines, never by killing our motion. Carl, leaving Alioth just above
    -- the air at 1,600 km/h climbing: Alt+1 put on full brakes to turn
    -- (KILL DRIFT), that killed the climb too, gravity pulled the ship back
    -- into the air and it burned adjusters off. So here: no braking to
    -- turn, an upward climb is never fought, and gravity is held off.
    local nearB
    do
      local Bn = NearestBody(pos)
      local gl = vec3(core.getWorldGravity()):len()
      if Bn and gl > 0.3 and (pos - Bn.c):len() < Bn.hard + PlanetClearance
         and not (AP.surfB == Bn and AP.leg == #legs and remaining < 20000) then
        nearB = Bn
        local upB = norm(pos - Bn.c)
        local vr, dr = vel:dot(upB), vErr:dot(upB) + vel:dot(upB)   -- now / wanted outward speed
        if vr > 0 and dr < vr then vErr = vErr + upB * (vr - dr) end
      end
    end
    local eLen = vErr:len()
    local alongErr = vErr:dot(toAim)
    local latVec = vErr - toAim * alongErr
    local latLen = latVec:len()
    -- Thrust budget. Rear engines only push along the nose, so sideways
    -- correction comes from TILTING the nose while burning. It gets its
    -- own share of the thrust (up to ~35° of tilt) instead of being
    -- weighed against the huge forward error, which made it tiny (Carl:
    -- "it waits until it's almost there to correct"). Sideways gravity is
    -- cancelled directly; the rest kills sideways drift in ~2 s.
    local aMax = mmax(MaxThrustN / mmax(mass, 1), 0.1)
    local g = vec3(core.getWorldGravity())
    local gLat = g - toAim * g:dot(toAim)
    local correcting, accelWant = false, 0
    if latLen > 50 and eLen > 25 then
      aim, accelWant = vErr / eLen, eLen      -- way off: steer the whole error
      if nearB then
        -- (near a planet: plus enough push to hold off gravity)
        local d = vErr - g
        aim, accelWant = d / d:len(), d:len()
      end
    else
      -- Fade in from 0.5 to 2 m/s of drift: no hard on/off step, so tiny
      -- drifts don't make the nose hunt back and forth (Carl, at 49500).
      local aL = latVec * (0.5 * clamp((latLen - 0.5) / 1.5, 0, 1))
      aL = aL - gLat
      local maxL = aMax * 0.57                -- sin 35°
      if aL:len() > maxL then aL = aL * (maxL / aL:len()) end
      local along
      if alongErr > 25 then
        along = msqrt(mmax(aMax * aMax - aL:len() ^ 2, 0))   -- full burn, tilted
      else
        -- Cruise / at top speed: SMALL tilt (~8°) so the engines actually
        -- fire (thrust only starts within 15°). The old ~27° tilt sat
        -- outside that, so it turned to correct with 0% thrust and hunted.
        -- The extra forward push is harmless at the ship's top speed.
        along = mmax(mmax(0, alongErr) * 0.5, aL:len() * 7)
        correcting = aL:len() > 0.05
      end
      local d = toAim * along + aL
      if d:len() > 0.05 then aim, accelWant = d / d:len(), d:len() end
    end
    AP.latFix = correcting
    -- Thrust ramps in from 15° off to full at 5° off, so the ship starts
    -- fixing its course while still turning (it used to coast until 5°).
    local ramp = clamp((fwd:dot(aim) - 0.966) / (0.996 - 0.966), 0, 1)
    if ramp > 0 then
      accel = mmin(accelWant, aMax) * ramp
      if correcting then AP.phase = "CORRECT"
      else AP.phase = (vAlong >= vCap * 0.97) and "CRUISE" or "BURN" end
    else
      AP.phase = "ALIGN"
    end
    -- Moving well off-course (e.g. engaged while flying elsewhere):
    -- brakes kill the bad velocity while we turn.
    if speed > 30 and vAlong < speed * 0.5 and not nearB then brake, AP.phase = 1, "KILL DRIFT" end
    -- Turning a corner (dog-leg skipped / new heading): if the sideways
    -- motion is more than the engines can fix in ~8 s, bring in the brakes
    -- too (Carl's ship: brakes ~6× the engines). Brake-and-turn instead of
    -- the wide loop the engines alone made after rounding the planet.
    -- Carl (moon corner): start sooner (~4 s of engine work, was 8), but
    -- brake ONLY while the nose is still swinging round (engines can't
    -- help yet). Once it points close enough to thrust, the engines finish
    -- the turn at full speed. Braking until the drift was gone (previous
    -- version) killed too much speed and pulled the path in toward the moon.
    -- Then (Carl, next run: it circled the destination before stopping):
    --  • keep braking a bit longer once started, until the drift is down
    --    to ~2.5 s of engine work (engines still fire whenever the nose
    --    points close enough — accel above is kept);
    --  • anti-orbit: on the final leg, if the engines can't remove the
    --    sideways motion before we'd cover half the remaining distance,
    --    brake to buy time. Otherwise the ship swings round the point.
    local tFix = latLen / aMax
    local orbit = AP.leg == #legs and latLen > 20 and mmax(vAlong, 0) * tFix > mmax(remaining, 0) * 0.5
    local need = (latLen > mmax(50, aMax * 4) and ramp < 0.5)
              or (AP.kdOn and latLen > mmax(30, aMax * 2.5))
              or orbit
    -- Last 300 m: ANY sideways slide past the point gets braked, not just
    -- above 30 m/s. The stop used to end still sliding ~28 m/s sideways
    -- past the point; the AP then swung the nose round to chase it and
    -- hunted for ~30 s, nose 85° down to 89° up (Carl's flip, sim).
    local endSlide = AP.leg == #legs and remaining < 300 and latLen > 3 and speed > 2
    if (speed > 30 and need and not nearB) or endSlide then
      brake, AP.phase, AP.kdOn = 1, "KILL DRIFT", true
    else
      AP.kdOn = false
    end
  end
  -- Space route dipping into the air (e.g. falling back in after leaving
  -- low): never over the burn speed (the AP skipped BurnProtect — Carl
  -- lost adjusters). Steering carries on meanwhile.
  local burnBrake = false
  if brake < 1 and (unit.getAtmosphereDensity() or 0) > 0.0001 and not ThinAirClimb() then
    local capA = BurnCap()
    if speed > capA then brake, burnBrake = mmax(brake, clamp((speed - capA) / 20, 0.2, 1)), true end
  end
  AP.alignErr = math.deg(math.acos(clamp(fwd:dot(aim), -1, 1)))
  AP.brake, AP.accel = brake, accel
  -- While braking in space the nose doesn't matter (brakes push against
  -- our motion whichever way we face), so hold attitude instead of
  -- chasing the line (Carl: pointless turning while braking). In
  -- atmosphere a later version may want to steer here.
  if brake > 0 and AP.phase ~= "KILL DRIFT" and not burnBrake then AP.angVel = vec3()   -- (any braking: the gentle stop must not swing the nose up at the point)
  else AP.angVel = AlignAV(fwd, aim, up) end
  -- In gravity, keep the wings level (roll round the nose only, so the
  -- aim is unchanged). Carl: arriving upside down above a planet would
  -- freak people out.
  local gv = vec3(core.getWorldGravity())
  local dv = DownDir(pos)
  if (gv:len() > 0.5 or AggIsOn()) and dv then AP.angVel = AP.angVel + RollLevelAV(fwd, vec3(construct.getWorldOrientationRight()), up, dv) end

  -- Approach line for the stop report (direction when braking began).
  -- Only the final approach counts (not corner braking).
  if brake > 0 and AP.phase ~= "KILL DRIFT" and AP.leg == #legs and not AP.approachDir then
    -- The REAL line to the target, not toAim: toAim includes the gravity
    -- aim shift, and measuring against that tilted line made the report
    -- show false overshoots / side misses (Carl: "177 m past" with
    -- closest 20 m; "70 m to the side" on a 987 m stop).
    AP.approachDir = norm(AP.target - pos)
  end
  -- Furthest the ship got past the stop point along that line (report).
  if AP.approachDir then
    local past = (pos - (AP.target - AP.approachDir * StopDist())):dot(AP.approachDir)
    AP.maxPast = mmax(AP.maxPast or past, past)
  end
end

-- ── Look-ahead: where will the ship actually stop? ───────────────
-- Brakes push straight back along our motion and rear engines only push
-- forward, so once braking starts nothing can fight a planet's sideways
-- pull (Carl: ~1.5 km off after `farside`). Twice a second we simulate
-- the rest of the trip (coast, then brake along the stopping curve, with
-- planet gravity from the atlas) and shift the aim point by the predicted
-- sideways miss. The ship then builds the right sideways drift early,
-- while the engines can still push, and gravity bends it onto the point.
-- Budget: DU kills a script that does too much in one tick (Carl hit
-- a CPU overload when this summed all 54 atlas bodies × 400 steps). So:
-- only bodies whose pull matters on this trip (usually 1-2), plain
-- numbers instead of vec3 objects, and at most ~100 steps.
function PredictCorrect()
  if not (AP.active and AP.legs and AP.leg == #AP.legs) then return end
  if (AP.brake or 0) > 0 then return end      -- can't steer while braking
  local C = construct
  local pos, vel = vec3(C.getWorldPosition()), vec3(C.getWorldVelocity())
  local mass = C.getMass()
  local T = AP.target
  local u, dist = norm(T - pos)
  -- Bodies that pull > 0.002 m/s² at the ship or the target.
  local G = {}
  for _, B in ipairs(Bodies) do
    if B.gm and B.gm > 0 then
      local r = mmin((B.c - pos):len(), (B.c - T):len())
      if B.gm / (r * r) > 0.002 then G[#G+1] = { B.c.x, B.c.y, B.c.z, B.gm, B.r * 0.5 } end
      if #G >= 3 then break end
    end
  end
  local function grav(x, y, z)
    local gx, gy, gz = 0, 0, 0
    for i = 1, #G do
      local b = G[i]
      local dx, dy, dz = b[1] - x, b[2] - y, b[3] - z
      local r2 = dx*dx + dy*dy + dz*dz
      local r = msqrt(r2)
      if r > b[5] then
        local f = b[4] / (r2 * r)
        gx, gy, gz = gx + dx*f, gy + dy*f, gz + dz*f
      end
    end
    return gx, gy, gz
  end
  -- Scale the atlas pull to what the core actually feels here.
  local k = 1
  local hx, hy, hz = grav(pos.x, pos.y, pos.z)
  local gHere = msqrt(hx*hx + hy*hy + hz*hz)
  local gReal = vec3(core.getWorldGravity()):len()
  if gHere > 0.01 and gReal > 0.01 then k = clamp(gReal / gHere, 0.5, 2) end
  -- While burning / cruising the AP cancels gravity itself, so the only
  -- uncorrectable drift is during braking. Simulate just that: start where
  -- braking will begin, at the speed we'll have there (accelerate from
  -- the current along-speed, capped), on the line, and brake to a stop.
  -- (Simulating a coast from the current speed predicted hours of drift
  -- at low speed → the aim point swung wildly; Carl saw the ship wobble.)
  local ab = BrakeAccel(mass)
  local aa = mmax(MaxThrustN / mmax(mass, 1), 0.1)
  local d = mmax(dist - StopDist(), 0)
  local v0 = mmax(vel:dot(u), 0)
  local vp = msqrt(mmax((2 * d + v0 * v0 / aa) / (1 / aa + 1 / ab), 0))
  vp = mmin(vp, CruiseCap(), mmax(v0, msqrt(2 * ab * d)))
  if vp < 20 then return end
  local dB = mmin(vp * vp / (2 * ab), d)
  local start = T - u * (StopDist() + dB)
  local px, py, pz = start.x, start.y, start.z
  local vx, vy, vz = u.x * vp, u.y * vp, u.z * vp
  local dt = clamp(vp / ab / 50, 0.02, 2)
  for _ = 1, 100 do
    local sp = msqrt(vx*vx + vy*vy + vz*vz)
    if sp < 3 then break end
    local ax, ay, az = 0, 0, 0
    if #G > 0 then ax, ay, az = grav(px, py, pz); ax, ay, az = ax*k, ay*k, az*k end
    local f = ab / sp
    ax, ay, az = ax - vx*f, ay - vy*f, az - vz*f
    local h = mmin(dt, sp / ab)
    vx, vy, vz = vx + ax*h, vy + ay*h, vz + az*h
    px, py, pz = px + vx*h, py + vy*h, pz + vz*h
  end
  local S = T - u * StopDist()
  local miss = vec3(px, py, pz) - S
  local lat = miss - u * miss:dot(u)
  -- Aim the other way by the predicted miss (direct, no running total),
  -- smoothed, and never more than 3% of the distance or 20 km.
  local off = (AP.aimOff or vec3()) * 0.7 - lat * 0.3
  local lim = mmin(dist * 0.03, 20000)
  if off:len() > lim then off = off * (lim / off:len()) end
  AP.aimOff, AP.predMiss = off, lat:len()
end

-- Twice a second: skip dog-leg waypoints as soon as the direct line
-- to a later one is clear.
function APAdvanceLegs()
  if not (AP.active and AP.legs) or AP.leg >= #AP.legs then return end
  local pos = vec3(construct.getWorldPosition())
  for j = #AP.legs, AP.leg + 1, -1 do
    if SegmentClear(pos, AP.legs[j]) then AP.leg = j return end
  end
  if (AP.legs[AP.leg] - pos):len() < 2000 then AP.leg = AP.leg + 1 end
end

-- ── Navigator link ────────────────────────────────────────────────
function PollNavDB()
  if not NavDB then return end
  -- PRINT COORDS from Navigator: a switch-started PB can't print to chat,
  -- so it leaves NAME|::pos{} in nav_print for us to show. Print only —
  -- never a destination. The ::pos goes on its own line so it copies clean.
  local okP, pr = pcall(NavDB.getStringValue, "nav_print")
  if okP and pr and pr ~= "" then
    NavDB.setStringValue("nav_print", "")
    local pname, ppos = pr:match("^(.-)|(::pos%b{})")
    if not ppos then pname, ppos = nil, pr:match("::pos%b{}") end
    if ppos then
      system.print("[NAV] "..((pname and pname ~= "") and pname or "Coordinates"))
      system.print(ppos)
    end
  end
  local ok, raw = pcall(NavDB.getStringValue, "nav_ap_dest")
  if not ok or not raw or raw == "" then return end
  NavDB.setStringValue("nav_ap_dest", "")
  local name, pos = raw:match("^(.-)|(::pos%b{})")
  if not pos then pos = raw:match("::pos%b{}"); name = "Navigator" end
  if not pos then return end
  -- Landed at it already (within 300 m): nothing to fly — don't put it
  -- back over the pilot's map waypoint (Carl, 1119).
  do
    local pp = ParsePos(pos)
    if pp and OnGround and (pp - vec3(construct.getWorldPosition())):len() < 300 then
      system.print("[HELM] From Navigator: "..(name or "Navigator").." — already here, ignored")
      return
    end
  end
  local _, af = pcall(NavDB.getStringValue, "autofly")
  if SetTarget(name, pos, ParseHdg(raw:sub((raw:find("::pos", 1, true) or 1)))) then
    if AP.active then return end   -- already re-planned in SetTarget
    if af == "1" then APEngage()
    else Msg("From Navigator: "..AP.name.."  —  Alt+1 to engage") end
  end
end

-- ── Flight physics (onFlush) ──────────────────────────────────────
local function devIn(axis, fn)
  local v = system.getAxisValue(axis)
  if v == 0 then v = fn() end
  return v
end

function FlightFlush()
  -- While DU is warping the ship, stay out of the way: everything zero.
  -- The AP picks up again after the jump (Carl: "just continue after
  -- warp; to stop it they can hit the brake"). Brake during the warp
  -- cancels that. Waits 1 s after the warp ends for things to settle.
  if IsWarping() then
    if AP.active then
      APDisengage(nil)
      AP.warpResume = true
      Msg("Warping — AP resumes after the jump (brake to cancel)")
    elseif type(AP.warpResume) == "number" then
      AP.warpResume = true      -- warp state flickered: wait for the real end
    end
    Nav:setEngineForceCommand('thrust analog', vec3(), 1)
    Nav:setEngineForceCommand('ground', vec3(), 1)
    Nav:setEngineForceCommand('brake', vec3())
    Nav:setEngineTorqueCommand('torque', vec3(), 1)
    return
  end
  if AP.warpResume == true then
    AP.warpResume = now() + 1
  elseif AP.warpResume and now() >= AP.warpResume then
    AP.warpResume = nil
    if AP.target and not AP.active then
      Msg("Warp done — resuming AP")
      APEngage()
    end
  end
  local C = construct
  local fwd   = vec3(C.getWorldOrientationForward())
  local right = vec3(C.getWorldOrientationRight())
  local up    = vec3(C.getWorldOrientationUp())
  local vel   = vec3(C.getWorldVelocity())
  local speed = vel:len()
  if speed > 2 then OnGround = false end
  local velDir = speed > EPS and vel / speed or vec3()
  local keep, dontKeep, tol = 1, 0, 1

  local fP = clamp(pitchInput + devIn(1, system.getControlDeviceForwardInput), -1, 1)
  local fR = clamp(rollInput  + devIn(0, system.getControlDeviceYawInput), -1, 1)
  local fY = clamp(yawInput   - devIn(2, system.getControlDeviceLeftRightInput), -1, 1)

  if AP.active then APStep(vec3(C.getWorldPosition()), vel, fwd, up, C.getMass()) end

  HoverTick(vel)

  -- Rotation
  local targetAV
  if AP.active then
    targetAV = AP.angVel + fR * rollSpeedFactor * fwd
  else
    targetAV = fP * pitchSpeedFactor * right + fR * rollSpeedFactor * fwd + fY * yawSpeedFactor * up
    -- Auto-level (Carl's calls after flight testing — in space, levelling
    -- to a station's/planet's gravity stops you leaving the ship at an
    -- angle, so space gets none unless you're on the ground engines):
    --   Hovering / landing (any mode, anywhere) : roll + pitch
    --   Atmosphere, Maneuver mode               : roll + pitch
    --   Atmosphere, Flight mode                 : roll only
    --   Space otherwise (incl. park hold)       : none
    local wv = vec3(core.getWorldVertical())
    local inAtmo = (unit.getAtmosphereDensity() or 0) > 0.0001
    -- Hover levelling only while the ground engines can actually see the
    -- ground/pad (or while landing). After G-lift-off and flying away,
    -- HoverOn stays true, and it must not fight the pilot pointing the
    -- nose somewhere (Carl, leaving the station toward the planet).
    local nearGround = false
    if HoverState == "landing" then nearGround = true
    elseif HoverOn then nearGround = (#GroundEngines == 0) or ReadGroundDist() >= 0 end
    local levelBoth = nearGround or (inAtmo and Mode == 2)
    local levelRoll = levelBoth or inAtmo
    LevelActive = false   -- shown as a LEVEL tag on the HUD, so it's never invisible
    if AutoLevel and levelRoll and wv:len() > 0.01 and up:dot(wv) < 0 then
      if fR == 0 and mabs(fwd:dot(wv)) < 0.8 then
        local rollAng = math.asin(clamp(right:dot(wv), -1, 1))    -- + = right wing low
        targetAV = targetAV - fwd * clamp(rollAng * autoRollFactor, -1, 1)
        LevelActive = true
      end
      if fP == 0 and levelBoth then
        local pitchAng = math.asin(clamp(fwd:dot(wv), -1, 1))     -- + = nose low
        targetAV = targetAV + right * clamp(pitchAng * autoRollFactor, -1, 1)
        LevelActive = true
      end
    end
    -- Altitude hold (Alt+7 / "alt N"): the nose holds the height; steering,
    -- roll and throttle stay the pilot's. Pressing pitch doesn't cancel it
    -- (a banked turn needs pitch — Carl): while pitch is pressed the pilot
    -- has the nose, and on release the hold takes it back to the same
    -- height. Burn protection is the normal hand-flying one.
    AltHoldOn = false
    if AltHold then
      local Bh = AltHold.B
      -- (rolling does NOT turn it off: the "fights to level" Carl felt in a
      -- bank was the atmosphere roll auto-level on letting go of roll —
      -- 1120, briefly made roll cancel it, then put back)
      if Mode ~= 1 then AltHoldOff("Maneuver mode has its own height hold")
      elseif not inAtmo then AltHoldOff("out of the atmosphere")
      elseif HoverState == "landing" then AltHoldOff("landing")
      else
        local pos = vec3(C.getWorldPosition())
        local upW, r = norm(pos - Bh.c)
        local vUp = vel:dot(upW)
        local vH = (vel - upW * vUp):len()
        local dh = AltHold.R - r
        local vUpDes = clamp(dh >= 0 and LevelOffVUp(dh) or -LevelOffVUp(-dh), -20, 20)
        local vErr = vUpDes - vUp
        local pNow = math.asin(clamp(fwd:dot(upW), -1, 1))
        local tN = now()
        local dt = clamp(tN - (AltHold.t or tN), 0, 0.5)
        AltHold.t = tN
        -- (starts from the angle that's holding us up right now: a
        -- wingless or slow ship needs its nose up just to stay level)
        if not AltHold.trim then AltHold.trim = pNow - math.asin(clamp(vUp / mmax(speed, 1), -1, 1)) end
        if fP == 0 then
          AltHold.trim = clamp(AltHold.trim + 0.0006 * vErr * dt, -math.rad(15), math.rad(30))
          local gam = math.asin(clamp(vUpDes / mmax(vH, 30), -0.35, 0.35))
          local pWant = clamp(gam + AltHold.trim + 0.002 * vErr, -math.rad(20), math.rad(35))
          -- (banked, turning about the wing raises the nose less)
          local bankC = mmax(up:dot(upW), 0.5)
          targetAV = targetAV + right * clamp((pWant - pNow) * 1.2 / bankC, -0.2, 0.2)
        end
        AltHoldOn = true
      end
    end
  end
  local angAcc = torqueFactor * (targetAV - vec3(C.getWorldAngularVelocity()))
               - vec3(C.getWorldAirFrictionAngularAcceleration())
  Nav:setEngineTorqueCommand('torque', angAcc, keep, 'airfoil', '', '', tol)

  -- Maneuver mode: inputs ask for a VELOCITY in ship axes, not a force.
  -- Throttle → forward/back, strafe keys → left/right, Space/C → up/down,
  -- each as a fraction of ManeuverSpeed. With nothing pressed the ship
  -- holds still (and carries its own weight with the up thrusters).
  local man = (Mode == 2) and not AP.active
  local manAcc, manIdle
  -- (kept across a mode switch under water: both modes hold the same depth)
  if (not man and not UnderwaterNow) or ParkHold or AP.active then ManHoldPos = nil end   -- after AP/park: hold the height you're at then
  -- Under water (below sea level on a planet with air): hovers read 0 there
  -- and push for the surface, so in Maneuver mode they're switched off and
  -- the engines own the height — drive down with C, let go, it holds that
  -- depth (Carl: placing a core needs the seabed; ArchHUD had a setting).
  local underwater = false
  do   -- (any mode: DU's hover hold must stay off under water; the depth
       -- hold itself is Maneuver mode's)
    local Bw = NearestBody(vec3(C.getWorldPosition()))
    underwater = Bw and (Bw.atm or 0) > 0 and (vec3(C.getWorldPosition()) - Bw.c):len() - Bw.r < -3 or false
    -- (sitting landed on the seabed: stay quiet as on land, no engines
    -- holding a ship that's resting on the dirt)
    if HoverState == "landed" and OnGround then underwater = false end
    -- DU's own hover hold works inside the engines, whatever we command:
    -- switch it off under water, back on (if hovering) coming out. Except
    -- after G under water (UwRise): that means "take me up" — leave it on
    -- (Carl, 1115-1059: G on the seabed right after a paste stayed down).
    if underwater and not UwStabOff then
      Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()
      UwStabOff = true
    end
    if not underwater and UnderwaterNow then
      UnderwaterNow, UwStabOff = false, nil
      if not UwRise then RestoreGroundStab() end   -- (a rise hands over itself, at the hover height)
    end
    UnderwaterNow = underwater
    if underwater and not UnderwaterMsg then
      UnderwaterMsg = true
      Msg("Under water — hovers off, the engines hold the depth. Space/C: up/down · G: rise to the surface")
    elseif not underwater then UnderwaterMsg = nil end
  end
  if man then
    local acm = Nav.axisCommandManager
    local vmax = mmax(ManeuverSpeed, 1) / 3.6
    local thr = 0
    if acm:getAxisCommandType(axisCommandId.longitudinal) == axisCommandType.byTargetSpeed then
      thr = clamp(acm:getTargetSpeed(axisCommandId.longitudinal) / 3.6 / vmax, -1, 1)
    else
      local ok, t = pcall(unit.getThrottle)
      thr = (ok and t) and clamp(t / 100, -1, 1) or 0
    end
    thr = clamp(thr + fwdKey, -1, 1)   -- W/S in Maneuver mode
    -- In gravity: forward/strafe move LEVEL (nose pitch doesn't send the
    -- ship up or down), Space/C move straight up/down, and with Space/C
    -- released the ship holds the height it had (Carl: it sank while
    -- moving forward). Out of gravity: plain ship axes.
    local g = vec3(core.getWorldGravity())
    local wv = vec3(core.getWorldVertical())
    local mf, mr, mu = fwd, right, up
    local vUp = upInput * vmax
    if g:len() > 0.1 and wv:len() > 0.5 then
      local fl = fwd - wv * fwd:dot(wv)
      local rl = right - wv * right:dot(wv)
      if fl:len() > 0.1 and rl:len() > 0.1 then
        mf, mr, mu = fl:normalize(), rl:normalize(), -wv
        local p = vec3(C.getWorldPosition())
        if upInput ~= 0 or not ManHoldPos then ManHoldPos = p end
        if upInput == 0 then
          local below = (p - ManHoldPos):dot(wv)          -- + = sunk below the held height
          vUp = clamp(below * 0.8, -vmax, vmax)
        end
      end
    else
      ManHoldPos = nil
    end
    local wantV = mf * (thr * vmax) + mr * (strafeInput * vmax) + mu * vUp
    manIdle = mabs(thr) < 0.01 and strafeInput == 0 and upInput == 0
    manAcc = (wantV - vel) * 1.0 - g
    -- Landed (gear down, no G yet) and no input: stay quiet, same
    -- "no thrust until G" rule as Flight mode.
    if manIdle and not HoverOn and not underwater then manAcc = vec3(); ManHoldPos = nil
    elseif HoverOn and not underwater and upInput == 0 and Thrust and Thrust.G >= Thrust.weight
           and (HoverState == "landing" or GroundDist >= 0) then
      -- Only while the hovers/boosters can actually see the ground: above
      -- their range they push nothing, and handing them the height made
      -- the ship sink.
      -- Hovers/boosters can carry the ship: they own the height. Thrusters
      -- only do the horizontal part, so two controllers never fight over
      -- altitude (that fight is another source of bounce).
      manAcc = manAcc - wv * manAcc:dot(wv)
      ManHoldPos = nil   -- leaving hover range later: hold THAT height, not an old one
    end
  end

  -- Park hold (Alt+5): overrides Flight/Maneuver until released.
  local park = ParkHold ~= nil and not AP.active
  local parkAcc, parkBrake
  if park then
    local hovering = HoverState == "hover" and Thrust and Thrust.G >= Thrust.weight
    parkAcc, parkBrake = ParkStep(vec3(C.getWorldPosition()), vel, hovering)
  end

  -- Brakes
  -- Rising from under water after G (UwRise): our own controlled climb to
  -- HoverHeight above sea level, then DU's hover hold takes over. DU's
  -- hold alone pushed flat out (hovers read 0 under water) and the ship
  -- left the sea fast enough to coast to ~2 km (Carl, 1115-1105).
  local uwRiseAcc, uwRiseBrake = nil, 0
  if UwRise and HoverState == "hover" and not AP.active then
    local p = vec3(C.getWorldPosition())
    local Bs = NearestBody(p)
    local gW = vec3(core.getWorldGravity())
    if Bs and (Bs.atm or 0) > 0 and gW:len() > 0.1 then
      local upW = -gW / gW:len()
      local vUpR = vel:dot(upW)
      local dist = mmax(tonumber(HoverHeight) or 10, 5) - ((p - Bs.c):len() - Bs.r)
      -- up to 25 m/s, easing in at ~1.5 m/s² so it arrives nearly stopped
      local vWant = clamp(msqrt(3 * mmax(dist, 0)), 0, 25)
      if dist < 3 then vWant = mmax(dist, 0) * 0.5 end
      uwRiseAcc = upW * clamp((vWant - vUpR) * 1.5, -3, 15) - gW
      if vUpR > vWant + 2 then uwRiseBrake = clamp((vUpR - vWant) / 5, 0.2, 1) end
      if dist <= 1.5 and mabs(vUpR) < 1.5 then
        UwRise, uwRiseAcc = nil, nil
        RestoreGroundStab()
        -- same as landing on water: brakes held, G sinks (Carl)
        if TakeoffAfterRise then
          -- Alt+1 from under water: on with the take-off now
          TakeoffAfterRise = nil
          if AP.target then APEngage(true) end
        else
        ParkBrake, WaterHold = true, true
        Msg(string.format("At the surface — hovering %.0f m above the water, brakes held. G: sink and land on the bottom", HoverHeight))
        end
      end
    else
      UwRise = nil
    end
  end

  local fB = clamp(brakeInput, 0, 1)
  if ParkBrake then fB = 1 end
  fB = mmax(fB, uwRiseBrake)
  if AP.active then fB = mmax(fB, AP.brake) end
  fB = mmax(fB, LandBrake)
  if park then fB = mmax(fB, parkBrake) end
  if man and manIdle and speed > 0.5 then fB = mmax(fB, clamp(speed / 10, 0, 1)) end
  -- Burn-speed protection while HAND flying in atmosphere (Carl: pushed
  -- the throttle expecting a limit and hit ~2,000 km/h in atmo). Engine
  -- push fades out from 95% to 100% of BurnCap (85% of DU's burn speed),
  -- so the ship levels off just under it; brakes only above 95% of the
  -- real burn speed (e.g. diving). Steering and the throttle setting are
  -- never touched. The AP has its own speed limits.
  local burnScale = 1
  BurnLimitOn = false
  if BurnProtect and not AP.active and (unit.getAtmosphereDensity() or 0) > 0.0001 and not ThinAirClimb() then
    local cap = BurnCap()
    if speed > cap * 0.95 then
      burnScale = clamp((cap - speed) / (cap * 0.05), 0, 1)
      BurnLimitOn = true
    end
    local burn = cap / BURN_FRAC
    if speed > burn * 0.95 then fB = mmax(fB, clamp((speed - burn * 0.95) / 20, 0.2, 1)) end
  end
  Nav:setEngineForceCommand('brake', -fB * (brakeSpeedFactor * vel + brakeFlatFactor * velDir))
  -- Only the push ALONG our motion is limited (slowing down / turning
  -- away is always allowed).
  local function burnLimit(acc)
    if burnScale >= 1 or speed < 1 then return acc end
    local along = acc:dot(velDir)
    if along <= 0 then return acc end
    return acc - velDir * (along * (1 - burnScale))
  end

  if AP.active then
    Nav:setEngineForceCommand('thrust analog longitudinal', fwd * AP.accel, keep)
    Nav:setEngineForceCommand('thrust analog lateral', vec3(), keep)
    Nav:setEngineForceCommand('thrust analog vertical', up * (((AP.takeoff or AP.descent) and AP.vAccel) or 0), keep)
    -- (zero the group first, then the wings — same order as hand flying)
    if AP.takeoff and AP.wingLift then
      Nav:setEngineForceCommand('airfoil vertical', AP.wingLift, keep, 'airfoil', '', '', tol)
    end
    if AP.takeoff then
      -- Take-off: hovers / vertical boosters keep doing their hover job
      -- (lift-off, then holding height during the roll-out).
      local acm = Nav.axisCommandManager
      local gAcc = acm:composeAxisAccelerationFromThrottle('thrust analog vertical', axisCommandId.vertical)
      Nav:setEngineForceCommand('ground', GroundCmd(gAcc), keep, '', '', '', tol)
    end
  elseif park or man then
    -- Every thruster, any direction, solved together (not collinear).
    Nav:setEngineForceCommand('thrust analog', park and parkAcc or manAcc, dontKeep, '', '', '', tol)
    -- Hovers / vertical boosters still follow G exactly as in Flight mode.
    local acm = Nav.axisCommandManager
    local gAcc = acm:composeAxisAccelerationFromThrottle('thrust analog vertical', axisCommandId.vertical)
    -- (under water in Maneuver: hovers off, the engines hold the depth)
    -- (under water in Maneuver: DU's hover hold is off; the hovers /
    -- boosters get the vertical part of the depth hold, so ships whose only
    -- upward push is hovers/boosters hold a depth too)
    local gCmd = GroundCmd(gAcc)
    if man and underwater then
      local wvM = vec3(core.getWorldVertical())
      gCmd = (wvM:len() > 0.5) and wvM * manAcc:dot(wvM) or vec3()
    end
    Nav:setEngineForceCommand('ground', gCmd, keep, '', '', '', tol)
  else
    -- Manual flight: DU's standard throttle / cruise-control handling
    local acm = Nav.axisCommandManager
    local autoTags, autoAcc, autoBrake = '', vec3(), false

    local lonTags = 'thrust analog longitudinal'
    local lonType = acm:getAxisCommandType(axisCommandId.longitudinal)
    if lonType == axisCommandType.byThrottle then
      Nav:setEngineForceCommand(lonTags, burnLimit(acm:composeAxisAccelerationFromThrottle(lonTags, axisCommandId.longitudinal)), keep)
    elseif lonType == axisCommandType.byTargetSpeed then
      autoTags = autoTags..' , '..lonTags
      autoAcc = autoAcc + burnLimit(acm:composeAxisAccelerationFromTargetSpeed(axisCommandId.longitudinal))
      if acm:getTargetSpeed(axisCommandId.longitudinal) == 0 or
         acm:getCurrentToTargetDeltaSpeed(axisCommandId.longitudinal) < -acm:getTargetSpeedCurrentStep(axisCommandId.longitudinal) * 0.5 then
        autoBrake = true
      end
    end

    local latTags = 'thrust analog lateral'
    local latType = acm:getAxisCommandType(axisCommandId.lateral)
    if latType == axisCommandType.byThrottle then
      Nav:setEngineForceCommand(latTags, acm:composeAxisAccelerationFromThrottle(latTags, axisCommandId.lateral), keep)
    elseif latType == axisCommandType.byTargetSpeed then
      autoTags = autoTags..' , '..latTags
      autoAcc = autoAcc + acm:composeAxisAccelerationFromTargetSpeed(axisCommandId.lateral)
    end

    local vrtTags = 'thrust analog vertical'
    local vrtType = acm:getAxisCommandType(axisCommandId.vertical)
    if vrtType == axisCommandType.byThrottle then
      local vAcc = acm:composeAxisAccelerationFromThrottle(vrtTags, axisCommandId.vertical)
      if upInput ~= 0 then
        -- Space / C held: everything that can push vertically helps.
        Nav:setEngineForceCommand(vrtTags, vAcc, keep, 'airfoil', 'ground', '', tol)
        if underwater then ManHoldPos = nil end   -- (let go: hold the new depth)
      elseif underwater and HoverState ~= "landing" then
        -- Under water, Flight mode holds the depth too (hovers are off
        -- there), the same held spot as Maneuver mode — so switching modes
        -- doesn't drop the ship or jerk it back (Carl, 1115-1127).
        local wvD = vec3(core.getWorldVertical())
        local gW = vec3(core.getWorldGravity())
        local p = vec3(C.getWorldPosition())
        if not ManHoldPos then ManHoldPos = p end
        local below = (p - ManHoldPos):dot(wvD)            -- + = sunk below the held depth
        local vWant = clamp(below * 0.8, -10, 10)
        local vUpNow = -vel:dot(wvD)
        -- (hovers / vertical boosters help too, asked for just the push
        -- needed — a ship with no other upward thrust still holds; DU's own
        -- hover hold, which pushes flat out under water, stays off)
        Nav:setEngineForceCommand(vrtTags, -wvD * ((vWant - vUpNow) * 1.0) - gW, keep, 'airfoil', 'ground', '', tol)
      else
        -- No vertical input: vertical THRUSTERS stay silent (otherwise DU
        -- uses them to float the ship against gravity). Order matters —
        -- zero the whole group first, then re-command the subsets.
        Nav:setEngineForceCommand(vrtTags, vec3(), keep)
        Nav:setEngineForceCommand('airfoil vertical', vAcc, keep, 'airfoil', '', '', tol)
        -- Hovers / vertical boosters: on while hovering or landing, exactly
        -- zero when landed.
        Nav:setEngineForceCommand('ground', GroundCmd(vAcc), keep, '', '', '', tol)
      end
    elseif vrtType == axisCommandType.byTargetSpeed then
      autoTags = autoTags..' , '..vrtTags
      autoAcc = autoAcc + acm:composeAxisAccelerationFromTargetSpeed(axisCommandId.vertical)
    end

    if autoAcc:len() > EPS then
      if fB ~= 0 or autoBrake or mabs(velDir:dot(fwd)) < 0.95 then autoTags = autoTags..', brake' end
      Nav:setEngineForceCommand(autoTags, autoAcc, dontKeep, '', '', '', tol)
    end
  end

  if uwRiseAcc then
    Nav:setEngineForceCommand('thrust analog vertical', uwRiseAcc, keep, 'airfoil', 'ground', '', tol)
  end

  Nav:setBoosterCommand('rocket_engine')
end

-- ── Input ─────────────────────────────────────────────────────────
-- ── Park hold ─────────────────────────────────────────────────────
-- Alt+5 / "park": stop, then hold that exact spot (thrusters in every
-- direction fight drift and carry the ship's weight). Rotation stays
-- free. Released by Alt+5 again or any movement input.
ParkHold = nil   -- nil | { phase = "stop"|"hold", pos = vec3 }
function ParkEngage()
  if HoverState == "landed" then
    ParkBrake = true
    Msg("Parked — landed, brakes held")
    return
  end
  if AP.active then APDisengage(nil) end
  local acm = Nav.axisCommandManager
  acm:resetCommand(axisCommandId.longitudinal)
  acm:resetCommand(axisCommandId.lateral)
  acm:resetCommand(axisCommandId.vertical)
  ParkHold = { phase = "stop" }
  local T = Thrust or SurveyThrust()
  local weak = T.weight > 1 and T.U < T.weight and not (HoverState == "hover" and T.G >= T.weight)
  Msg("Park hold — stopping"..(weak and "  (up thrust below weight: it will sink)" or ""))
end
function ParkRelease(why)
  if not ParkHold then return end
  ParkHold = nil
  Msg("Park hold off"..(why and ("  —  "..why) or ""))
end
-- Thruster acceleration + brake level for this frame.
function ParkStep(pos, vel, hovering)
  local g = vec3(core.getWorldGravity())
  local acc, brake
  if ParkHold.phase == "stop" then
    acc, brake = -vel - g, 1
    if vel:len() < 0.3 then
      ParkHold.phase, ParkHold.pos = "hold", pos
      Msg("Park hold — holding position")
    end
  else
    -- Spring back to the spot, critically damped (~1.4 s response).
    acc = (ParkHold.pos - pos) * 0.5 - vel * 1.4 - g
    brake = vel:len() > 3 and 0.5 or 0
  end
  if hovering then   -- hovers/boosters own the height; thrusters do the rest
    local wv = vec3(core.getWorldVertical())
    if wv:len() > 0.01 then wv = wv / wv:len(); acc = acc - wv * acc:dot(wv) end
  end
  return acc, brake
end

-- ── Brake lock (Ctrl+Alt) ─────────────────────────────────────────
-- Latches the same brakes-held state used after landing. Ctrl+Alt again
-- releases it; so does throttle / strafe / up-down (like any park brake).
AltHeld = false
function ToggleBrakeLock()
  ParkBrake = not ParkBrake
  Msg(ParkBrake and "Brakes locked  —  Ctrl+Alt to release" or "Brakes released")
end

local function manualSteer() if AP.active then APDisengage("manual steering") end end
local function releasePark()
  -- Landed: the brake lock stays (Carl: Navigator's no-screen list is
  -- scrolled with the arrow keys, which unlocked the brakes on the pad).
  -- G / Alt+1 release it for take-off; Ctrl+Alt by hand.
  if not (HoverState == "landed" and OnGround) then ParkBrake = false end
  if ParkHold then ParkRelease("you're moving") end
end

-- W/S: pitch in Flight mode, forward/back movement in Maneuver mode.
-- Remember what each press did, so releasing undoes the right thing even
-- if you switch mode while holding the key.
fwdKey = 0
local keyAsMove = {}
-- Landed with the brake lock on: movement keys do nothing (Carl: the
-- no-screen Navigator list scrolls with the arrow keys, which also lifted
-- the ship off the pad and then let the brakes go). Navigator still gets
-- the keys. G / Alt+1 take off; Ctrl+Alt releases the lock by hand.
local PAD_KEYS = { up = true, down = true, strafeleft = true, straferight = true,
                   speedup = true, speeddown = true, forward = true, backward = true }
local padSwallowed, padMsg = {}, false
local function padLocked(a)
  if not (PAD_KEYS[a] and ParkBrake and HoverState == "landed" and OnGround and not AP.active) then return false end
  -- (W/S pitch in Flight mode — harmless on the ground, leave them alone)
  if (a == "forward" or a == "backward") and Mode ~= 2 then return false end
  return true
end
function OnActionStart(a)
  local acm = Nav.axisCommandManager
  if padLocked(a) then
    padSwallowed[a] = true
    if not padMsg then padMsg = true; Msg("Brake lock on — movement keys ignored while landed (Ctrl+Alt releases, G / Alt+1 take off)") end
    return
  end
  if (a == "forward" or a == "backward") and Mode == 2 and not AP.active then
    keyAsMove[a] = true
    fwdKey = (a == "forward") and 1 or -1
    releasePark()
  elseif a == "forward"  then pitchInput = pitchInput - 1; manualSteer()
  elseif a == "backward" then pitchInput = pitchInput + 1; manualSteer()
  elseif a == "left"     then rollInput  = rollInput - 1
  elseif a == "right"    then rollInput  = rollInput + 1
  elseif a == "yawleft"  then yawInput   = yawInput + 1; manualSteer()
  elseif a == "yawright" then yawInput   = yawInput - 1; manualSteer()
  elseif a == "straferight" then strafeInput = 1;  acm:updateCommandFromActionStart(axisCommandId.lateral, 1.0); releasePark()
  elseif a == "strafeleft"  then strafeInput = -1; acm:updateCommandFromActionStart(axisCommandId.lateral, -1.0); releasePark()
  elseif a == "up" then
    upInput = 1
    acm:deactivateGroundEngineAltitudeStabilization()
    acm:updateCommandFromActionStart(axisCommandId.vertical, 1.0); releasePark()
  elseif a == "down" then
    upInput = -1
    acm:deactivateGroundEngineAltitudeStabilization()
    if UwRise then UwRise, UwStabOff = nil, true end   -- C: stay under after all
    acm:updateCommandFromActionStart(axisCommandId.vertical, -1.0); releasePark()
  elseif a == "groundaltitudeup"   then acm:updateTargetGroundAltitudeFromActionStart(1.0)
  elseif a == "groundaltitudedown" then acm:updateTargetGroundAltitudeFromActionStart(-1.0)
  elseif a == "lalt" then
    AltHeld = true
    if brakeInput > 0 then ToggleBrakeLock() end   -- Ctrl held, then Alt
  elseif a == "brake" then
    brakeInput = 1   -- on/off, not a counter: a missed key-up can't stack
    if AP.active then APDisengage("brake pressed") end
    if TakeoffAfterRise then TakeoffAfterRise = nil; Msg("Take-off cancelled — brake pressed (still rising; C stays under)") end
    if AP.warpResume then AP.warpResume = nil; Msg("AP won't resume after the warp — brake pressed") end
    if AltHeld then ToggleBrakeLock() end           -- Alt held, then Ctrl
    -- Plain Ctrl never releases the brake lock / park hold: hold-to-brake only.
    if acm:getAxisCommandType(axisCommandId.longitudinal) == axisCommandType.byTargetSpeed then
      local ts = acm:getTargetSpeed(axisCommandId.longitudinal)
      if mabs(ts) > EPS then acm:updateCommandFromActionStart(axisCommandId.longitudinal, ts > 0 and -1 or 1) end
    end
  elseif a == "stopengines" then
    if AP.active then APDisengage("engines cut") end
    acm:resetCommand(axisCommandId.longitudinal)
  elseif a == "speedup" then
    if AP.active then APDisengage("throttle changed") end
    acm:updateCommandFromActionStart(axisCommandId.longitudinal, 5.0); releasePark()
  elseif a == "speeddown" then
    if AP.active then APDisengage("throttle changed") end
    acm:updateCommandFromActionStart(axisCommandId.longitudinal, -5.0); releasePark()
  elseif a == "booster" then
    -- (Helmsman keeps track, so the HUD tag and the AP's boost stay in step)
    Nav:toggleBoosters()
    RocketOn, RocketByAP = not RocketOn, false
  elseif a == "antigravity" then
    -- The pilot's toggle — the only thing in Helmsman that turns the AGG off.
    if antigrav then
      if AggIsOn() then antigrav.deactivate(); Msg("AGG off")
      else antigrav.activate()
        Msg(AggNoPulsors() and AGG_NOPULS or "AGG on — agg N sets the height, agg here holds where you are") end
    end
  elseif a == "gear" then
    -- hover → landing; landed or landing → hover (G mid-landing aborts it)
    -- G during an AP trip: the pilot takes over — AP off first (Carl,
    -- 1114-1100: G mid take-off said "Landing" but the climb kept full
    -- throttle until he braked).
    if AP.active then APDisengage("G pressed") end
    -- Hovering on water: G sinks and lands on the bottom.
    if WaterHold and HoverState == "hover" then
      WaterHold, WaterSink = nil, true
      ParkBrake = false          -- (held brakes would stop the touchdown being seen)
      if ParkHold then ParkRelease(nil) end
      SetHover(false, true)
      Msg("Sinking — landing on the bottom (G again to hover)")
      return
    end
    WaterHold, WaterSink = nil, nil
    if ParkHold then ParkRelease(nil) end
    -- GLandsDirect: flying (not sitting on anything) → land in one press.
    if GLandsDirect and HoverState == "landed" and not OnGround then
      SetHover(false, true)
    else
      SetHover(HoverState ~= "hover")
    end
    -- G to hover while under water = rise to the surface and hover there
    local underSea = false
    do
      local p = vec3(construct.getWorldPosition())
      local Bs = NearestBody(p)
      underSea = Bs and (Bs.atm or 0) > 0 and (p - Bs.c):len() - Bs.r < -3 or false
    end
    if HoverState == "hover" and underSea then
      UwRise, UwStabOff = true, true
      Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()
      Msg(string.format("Rising to the surface — hovering %.0f m above it (C: stay under)", HoverHeight))
    else
    Msg(HoverState == "hover" and string.format("Hover on — %.0f m", HoverHeight)
        or "Landing — setting down, engines cut when settled")
    end
  elseif a == "light" then
    if unit.isAnyHeadlightSwitchedOn() then unit.switchOffHeadlights() else unit.switchOnHeadlights() end
  elseif a == "option1" then
    if AP.active and AP.takeoff and AP.takeoff.blocked and not AP.takeoff.obsOk then
      AP.takeoff.obsOk = true
      Msg("Going anyway — watch the construct ahead (brake to stop)")
    elseif AP.active then APDisengage("Alt+1") else APEngage(true) end
  elseif a == "option2" then ClearTarget()
  elseif a == "option3" then
    HudOn = not HudOn
    if not HudOn then system.setScreen("") end
  elseif a == "option4" then SetMode(Mode == 2 and 1 or 2)
  elseif a == "option5" then
    if ParkHold then ParkRelease(nil) else ParkEngage() end
  elseif a == "option6" then ToggleFlightHud()
  elseif a == "option7" then
    if AltHold then AltHoldOff() else AltHoldSet(nil) end
  end
end

function OnActionStop(a)
  local acm = Nav.axisCommandManager
  if padSwallowed[a] then padSwallowed[a] = nil return end   -- its press was ignored too
  if (a == "forward" or a == "backward") and keyAsMove[a] then
    keyAsMove[a] = nil
    fwdKey = keyAsMove.forward and 1 or (keyAsMove.backward and -1 or 0)
  elseif a == "forward"  then pitchInput = pitchInput + 1
  elseif a == "backward" then pitchInput = pitchInput - 1
  elseif a == "left"     then rollInput  = rollInput + 1
  elseif a == "right"    then rollInput  = rollInput - 1
  elseif a == "yawleft"  then yawInput   = yawInput - 1
  elseif a == "yawright" then yawInput   = yawInput + 1
  elseif a == "straferight" then strafeInput = 0; acm:updateCommandFromActionStop(axisCommandId.lateral, -1.0)
  elseif a == "strafeleft"  then strafeInput = 0; acm:updateCommandFromActionStop(axisCommandId.lateral, 1.0)
  elseif a == "up" then
    upInput = 0
    acm:updateCommandFromActionStop(axisCommandId.vertical, -1.0)
    RestoreGroundStab()
  elseif a == "down" then
    upInput = 0
    acm:updateCommandFromActionStop(axisCommandId.vertical, 1.0)
    RestoreGroundStab()
  elseif a == "brake" then brakeInput = 0
  elseif a == "lalt" then AltHeld = false
  end
end

function OnActionLoop(a)
  local acm = Nav.axisCommandManager
  if padSwallowed[a] then return end
  if     a == "speedup"   then acm:updateCommandFromActionLoop(axisCommandId.longitudinal, 1.0)
  elseif a == "speeddown" then acm:updateCommandFromActionLoop(axisCommandId.longitudinal, -1.0)
  elseif a == "groundaltitudeup"   then acm:updateTargetGroundAltitudeFromActionLoop(1.0)
  elseif a == "groundaltitudedown" then acm:updateTargetGroundAltitudeFromActionLoop(-1.0)
  end
end

-- ── Anti-gravity generator ───────────────────────────────────────
-- The target height is stored on the AGG element itself (it survives
-- getting up, restarts and reinstalls), so nothing is saved here.
-- Helmsman never turns the AGG off — only the pilot's Alt+G does.
AGG_MIN = 1000
Agg = {}

function AggIsOn()
  if not antigrav then return false end
  local ok, a = pcall(antigrav.isActive)
  return ok and (a == true or a == 1)
end

-- Height above sea level (what the AGG works in).
function SeaAltitude()
  if core then
    local ok, a = pcall(core.getAltitude)
    if ok and tonumber(a) and a ~= 0 then return a end
  end
  local pos = vec3(construct.getWorldPosition())
  local B = NearestBody(pos)
  return B and ((pos - B.c):len() - B.r) or nil
end

function AggRead()
  if not antigrav then return nil end
  local function num(f) if not f then return nil end local ok, v = pcall(f); return ok and tonumber(v) or nil end
  return { on = AggIsOn(), target = num(antigrav.getTargetAltitude) or Agg.setTo,
           base = num(antigrav.getBaseAltitude), field = num(antigrav.getFieldStrength),
           pulsors = num(antigrav.getPulsorCount), alt = SeaAltitude() }
end

-- No pulsors linked to this generator = no lift at all, whatever the
-- heights say (seen on the Hammer Crest: green "holding", ship fell).
function AggNoPulsors(s)
  s = s or AggRead()
  return s and s.pulsors == 0
end
AGG_NOPULS = "AGG has no pulsors linked — it can't lift anything. Link the pulsors to this generator (agg shows the count)"

-- ── AGG trip ──
-- AGG on (with pulsors) and the target a spot on a planet with air: the
-- AP stays in the air and stops over the spot at the AGG's height (above
-- sea level, same as the AGG) instead of landing — for ships that don't
-- land (Carl's L-core carrier has an elevator down to the ground).
-- Returns the plan, or nil + why it's a normal trip instead.
AGG_TERRAIN_MARGIN = 100
function AggTripPlan(B, spotR, mapPick)
  if not (antigrav and B and (B.atm or 0) > 0) then return nil end
  local s = AggRead()
  if not (s and s.on) then return nil end
  if s.pulsors == 0 then return nil, "the AGG has no pulsors linked" end
  local alt = s.target or s.base
  if not alt then return nil end
  local R = B.r + alt
  local safe = R >= B.top + AGG_TERRAIN_MARGIN       -- clears the planet's highest ground
  -- A spot AT the AGG height (within 30 m below to 25 m above it) was
  -- saved in the air while the AGG held the ship (Carl, 1114: his base
  -- spot for the carrier, saved hovering at ~1300 m, made it a normal
  -- trip — climb, then land — instead of a straight run at the AGG height).
  local air = spotR and spotR > R - 30 and spotR <= R + 25
  if spotR and not air and spotR + 30 > R then
    return nil, string.format("the spot is above the AGG height (%.0f m) — set it higher (agg N) to stay up", alt)
  end
  if not spotR and mapPick and not safe then
    return nil, "map pick (ground height unknown) and the AGG height is below the highest ground"
  end
  return { R = R, alt = alt, base = s.base, cruise = safe, air = air }
end

function AggTripNote(ag, spotR)
  if ag.air then
    return string.format("AGG on — the spot is at the AGG height (saved in the air): flies there at %.0f m and holds", ag.alt)
  end
  return string.format("AGG on — stays in the air: stops over the spot at %.0f m%s", ag.alt,
    spotR and string.format(" (%.0f m above it)", ag.R - spotR) or "")
end

-- Over the spot at the AGG height: AP off, brakes held, the AGG holds it.
function AggArrive()
  local name, ag = AP.name, AP.agg
  APDisengage(nil)
  AP.phase = "ARRIVED"
  ParkBrake = true
  local alt = SeaAltitude()
  Msg(string.format("Arrived over %s — AGG holding at %.0f m%s, brakes held", name, ag and ag.alt or (alt or 0),
    (AP.spotR and alt and not (ag and ag.air)) and string.format(" (%.0f m above the spot)", alt - (AP.spotR - AP.surfB.r)) or ""))
  TripDone()
end

-- How fast the lift point is creeping (m/s), for the HUD's time estimate.
function AggTick()
  local s = AggRead()
  if not (s and s.base) then return end
  local t = now()
  if Agg.lastB and t > Agg.lastT then
    local r = mabs(s.base - Agg.lastB) / (t - Agg.lastT)
    if r > 0.05 then Agg.rate = Agg.rate and (Agg.rate * 0.7 + r * 0.3) or r end
  end
  Agg.lastB, Agg.lastT = s.base, t
end

function AggCommand(arg)
  if not antigrav then Msg("No anti-gravity generator linked to the seat") return end
  local s = AggRead()
  if not arg or arg == "" then
    system.print(string.format("[HELM] AGG %s · height set %s · lift at %s · you're at %s%s",
      s.on and "ON" or "OFF",
      s.target and string.format("%.0f m", s.target) or "?",
      s.base and string.format("%.0f m", s.base) or "?",
      s.alt and string.format("%.0f m", s.alt) or "?",
      s.field and string.format(" · field strength %s", tostring(s.field)) or ""))
    -- Raw strength figures DU gives (whatever this AGG supports), to learn
    -- what "enough pulsors" looks like on a ship that holds vs one that sinks.
    local function raw(name)
      local f = antigrav[name]
      if type(f) ~= "function" then return nil end
      local ok, v = pcall(f)
      return ok and v ~= nil and (name:gsub("^get", "").." "..tostring(v)) or nil
    end
    local bits = {}
    for _, n in ipairs({ "getFieldStrength", "getCompensationRate", "getFieldPower", "getPulsorCount", "getMaxPower" }) do
      local r = raw(n); if r then bits[#bits+1] = r end
    end
    system.print(string.format("[HELM] AGG strength: %s · ship mass %.1f t",
      #bits > 0 and table.concat(bits, " · ") or "DU gives no figures", construct.getMass() / 1000))
    system.print("[HELM] agg N sets the height (metres, "..AGG_MIN.." or more) · agg here holds where you are · agg on|off (or Alt+G)")
    return
  end
  -- On/off by chat (for when Alt+G is taken by another program). Still the
  -- pilot's own command — nothing automatic ever turns the AGG off.
  if arg == "on" then
    if s.on then Msg("AGG is already on") else pcall(antigrav.activate); Msg(AggNoPulsors(s) and AGG_NOPULS or "AGG on") end
    return
  elseif arg == "off" then
    if s.on then pcall(antigrav.deactivate); Msg("AGG off") else Msg("AGG is already off") end
    return
  end
  local want
  if arg == "here" then
    want = s.alt and math.floor(s.alt + 0.5)
  else
    local a = arg:gsub("[,%s]", "")
    local km = a:match("^([%d%.]+)km$")
    want = km and tonumber(km) and tonumber(km) * 1000 or tonumber((a:gsub("m$", "")))
  end
  if not want then Msg("agg N (metres) · agg here · agg  —  e.g. agg 2500") return end
  want = math.floor(want + 0.5)
  if want < AGG_MIN then
    Msg(string.format("The AGG can't hold below %d m%s — pick %d or higher", AGG_MIN,
      arg == "here" and string.format(" (you're at %.0f m)", want) or "", AGG_MIN))
    return
  end
  if not pcall(antigrav.setTargetAltitude, want) then Msg("The AGG didn't take the new height") return end
  Agg.setTo = want
  if not s.on then
    Msg(string.format("AGG height set to %d m — the AGG is off (agg on or Alt+G turns it on)", want))
  elseif s.base and mabs(s.base - want) > 2 then
    local eta = (Agg.rate and Agg.rate > 0.05) and (" (~"..FormatTime(mabs(want - s.base) / Agg.rate)..")") or ""
    Msg(string.format("AGG height set to %d m — but the lift is still at %.0f m: until it creeps here%s the AGG pulls you toward %.0f m, not here. Hold height with your engines until the AGG row turns green",
      want, s.base, eta, s.base))
  else
    Msg(string.format("AGG height set to %d m", want))
  end
end

-- ── Lua chat commands ─────────────────────────────────────────────
function PrintHelp()
  system.print("── Helmsman v"..VERSION.." ──")
  system.print("::pos{...}            fly there (or Name ::pos{...})")
  system.print("goto ::pos{...}       same as pasting")
  system.print("ap / ap on / ap off   engage / disengage   (Alt+1)")
  system.print("clear                 clear target         (Alt+2)")
  system.print("hud                   toggle HUD           (Alt+3)")
  system.print("hud scale N · hud bottom N · hud shift N · hud opacity N   HUD size / height / sideways / see-through, saved")
  system.print("hudtheme NAME         cyan amber green red purple white #RRGGBB, saved")
  system.print("mode / mode flight / mode maneuver       (Alt+4)")
  system.print("alt / alt N / alt here / alt off         (Alt+7) altitude hold while hand flying: N m above sea level; Alt+7 returns to the last height held (this seat session), alt here = height now")
  system.print("thrust                engine push in all 6 directions")
  system.print("landsafety N          landing margin 0.1-1 (lower = gentler), saved")
  system.print("park                  stop and hold position (Alt+5)")
  system.print("agg N / agg here      AGG hover height (min "..AGG_MIN.." m, kept on the AGG) · agg = status")
  system.print("agg on / agg off      AGG on/off (same as Alt+G)")
  system.print("hdg · hdg N/here/off  nose heading · parking heading for this target (or |hdg=N after a ::pos)")
  system.print("rockets · rockets test  rocket status · fire them on the next AP climb (test)")
  system.print("mass                  mass and safe mass (2:1 rule): engines, hovers, brakes")
  system.print("planets               nearest atlas bodies, and which one the target is on")
  system.print("climb log             on/off: a line every 2 s (height, air, speed, angles, lift, drag, engine push)")
  system.print("autowarp on / off     AP warps by itself when READY to its destination (this session)")
  system.print("fhud                  fighter-style attitude HUD on/off (Alt+6)")
  system.print("navinfo [on|off]      AUTOPILOT panel (target, ETA, brake distance)")
  system.print("farside               test: target the far side of the nearest planet")
  system.print("ahead [N]             test: target empty space N su off the nose (default 1)")
  system.print("autolevel on/off      auto-levelling (LEVEL tag shows when active)")
  system.print("fuel                  every tank: litres / capacity / %")
  system.print("radar                 radar contacts: size, distance, what DU tells us")
  system.print("fueltalents A S R O C fuel talents 0-5: handling atmo/space/rocket, fuel opt, container opt")
  system.print("engines               list every engine type and its tags")
  system.print("speed N               AP cruise cap km/h (0 = max)")
  system.print("stopdist N            stop N metres short of target")
  system.print("brakes [reset]        brake force DU reports vs what the AP measured")
  system.print("target                print current target")
  system.print("links                 list what is linked in each seat slot")
  system.print("settings              show what is saved on the databank (read only)")
end

-- Every Lua chat line reaches every running script (seat AND Navigator
-- PB). Lines that start with another script's command word are not for
-- us — above all Navigator's "add NAME ::pos{}" / "addstop ROUTE ::pos{}",
-- which would otherwise look like "fly there".
local FOREIGN = { add=true, addstop=true, delstop=true, del=true, delete=true, delroute=true,
  newroute=true, rename=true, renameroute=true, setcoords=true, mark=true, nav=true, next=true, prev=true,
  autofly=true, coords=true, list=true, routes=true, sync=true, firstsync=true, push=true,
  importarch=true, importsaga=true, navdbkeys=true, theme=true, hudpos=true, search=true, id=true }

function OnInputText(text)
  local t = (text or ""):match("^%s*(.-)%s*$")
  local lo = t:lower()
  if FOREIGN[lo:match("^(%S+)") or ""] then return end
  if t:find("::pos{", 1, true) then
    local name, pos = t:match("^(.-)%s*(::pos%b{})")
    -- "goto ::pos", "/goto ::pos" (Arch habit) or just "::pos" all work
    name = (name or ""):gsub("^/?[Gg][Oo][Tt][Oo]%s*", ""):gsub("^/%s*", "")
    if SetTarget(name, pos or t, ParseHdg(t:sub(t:find("::pos{", 1, true)))) and AutoEngagePaste and not AP.active then APEngage() end
  elseif lo == "help" or lo == "?" then PrintHelp()
  elseif lo == "ap" then if AP.active then APDisengage("chat") else APEngage(true) end
  elseif lo == "ap on" or lo == "go" then APEngage(true)
  elseif lo == "ap off" or lo == "stop" then
    if AP.active then APDisengage("chat") else Msg("AP is already off") end
  elseif lo == "clear" then ClearTarget()
  elseif lo == "hud" then HudOn = not HudOn; if not HudOn then system.setScreen("") end
  elseif lo:match("^hud%s+%a+") then
    -- hud scale N | hud bottom N | hud shift N | hud opacity N  (saved)
    local key, n = lo:match("^hud%s+(%a+)%s*([%-%d%.]*)")
    n = tonumber(n)
    local set = {
      scale   = function(v) HudScale   = clamp(v, 0.5, 2);  DbSetNum("sf_hud_scale", HudScale);     return HudScale end,
      bottom  = function(v) HudBottom  = clamp(v, 0, 80);   DbSetNum("sf_hud_bottom", HudBottom);   return HudBottom end,
      shift   = function(v) HudShift   = clamp(v, -50, 50); DbSetNum("sf_hud_shift", HudShift);     return HudShift end,
      opacity = function(v) HudOpacity = clamp(v, 0.3, 1);  DbSetNum("sf_hud_opacity", HudOpacity); return HudOpacity end,
    }
    if set[key] and n then
      Msg(string.format("HUD %s: %s", key, tostring(set[key](n))))
    else
      Msg(string.format("HUD  scale %.2f · bottom %s · shift %s · opacity %.2f  —  e.g. hud bottom 10, hud shift -5",
        HudScale, tostring(HudBottom), tostring(HudShift), HudOpacity))
    end
  elseif lo:match("^hudtheme") then
    local arg = t:match("^%S+%s+(.+)$")
    if arg and ApplyTheme(arg) then
      if NavDB then pcall(NavDB.setStringValue, "sf_theme", ThemeName) end
      Msg("HUD theme: "..ThemeName..(NavDB and "  (saved)" or ""))
    else
      Msg("HUD theme: "..ThemeName.."  —  hudtheme cyan | amber | green | red | purple | white | #RRGGBB")
    end
  elseif lo == "settings" then
    -- Read only: what the databank holds, and what is in use now (the Lua
    -- parameter menu always shows the script's defaults — DU can't change it).
    if not NavDB then
      Msg("No databank linked — nothing is saved; the Lua parameters are used as set")
    else
      local function sv(k) local ok, v = pcall(NavDB.getStringValue, k); return (ok and v and v ~= "") and v or nil end
      local function onoff(v) if v == nil then return nil end return (tonumber(v) == 1) and "on" or "off" end
      local rows = {
        { "HUD theme",        sv("sf_theme"),       ThemeName },
        { "HUD scale",        sv("sf_hud_scale"),   HudScale },
        { "HUD bottom",       sv("sf_hud_bottom"),  HudBottom },
        { "HUD shift",        sv("sf_hud_shift"),   HudShift },
        { "HUD opacity",      sv("sf_hud_opacity"), HudOpacity },
        { "Flight HUD",       onoff(sv("sf_fhud")),  FlightHud and "on" or "off" },
        { "Nav info",         onoff(sv("sf_navinfo")), NavInfo and "on" or "off" },
        { "AutoLevel",        onoff(sv("sf_autolevel")), AutoLevel and "on" or "off" },
        { "LandSafety",       sv("sf_landsafety"),  LandSafety },
        { "Atmo tank handling",  sv("sf_ft_handling"), TankH.atmo },
        { "Space tank handling", sv("sf_ft_handling_s"), TankH.space },
        { "Rocket tank handling", sv("sf_ft_handling_r"), TankH.rocket },
        { "Fuel optimization",   sv("sf_ft_fuelopt"),  FuelTankOptimization },
        { "Container optim.",    sv("sf_ft_contopt"),  ContainerOptimization },
        { "Brake strength (learned)", sv(PK("sf_brake_k3")), string.format("%.3f", BrakeK) },
        { "Ground sensor range (learned)", sv("sf_ground_range"), string.format("%.1f m", GroundRangeSeen or 0) },
      }
      system.print("[HELM] ── Saved on the databank (in use now) ──")
      for _, r in ipairs(rows) do
        system.print(string.format("[HELM]   %-30s %s   (in use: %s)", r[1], r[2] and tostring(r[2]) or "— not saved", tostring(r[3])))
      end
      local tgt = sv("sf_target")
      system.print("[HELM]   Target: "..(tgt and (tgt:match("^([^|]*)") or tgt) or "— none"))
      system.print("[HELM]   (Autopilot/flight settings aren't saved — they come from the Lua parameters.)")
      system.print("[HELM]   Change a saved one with: hudtheme NAME · hud scale N · hud bottom N · hud shift N · hud opacity N")
    end
  elseif lo == "links" then
    -- What the seat actually sees in each link slot (diagnostic)
    local named = { slot1=slot1, slot2=slot2, slot3=slot3, slot4=slot4, slot5=slot5,
      slot6=slot6, slot7=slot7, slot8=slot8, slot9=slot9, slot10=slot10,
      slot11=slot11, slot12=slot12, slot13=slot13, slot14=slot14, slot15=slot15, slot16=slot16,
      slot17=slot17, slot18=slot18, slot19=slot19, slot20=slot20, slot21=slot21, slot22=slot22,
      slot23=slot23, slot24=slot24, slot25=slot25,
      core=core, navdb=navdb, antigrav=antigrav, warpdrive=warpdrive, radar=radar, radar_1=radar_1 }
    local order = { "core","navdb","antigrav","warpdrive","radar","radar_1",
      "slot1","slot2","slot3","slot4","slot5","slot6","slot7","slot8","slot9","slot10",
      "slot11","slot12","slot13","slot14","slot15","slot16","slot17","slot18","slot19","slot20",
      "slot21","slot22","slot23","slot24","slot25" }
    local n = 0
    for _, k in ipairs(order) do
      local e = named[k]
      if type(e) == "table" then
        n = n + 1
        local okC, c  = pcall(function() return e.getClass() end)
        local okN, nm = pcall(function() return e.getName() end)
        local extra = ""
        if classOf(e):find("radar") then
          local okS, s = pcall(function() return e.getOperationalState() end)
          extra = "  · operational state "..tostring(okS and s or "?")
        end
        system.print(string.format("[HELM] %-8s %s | %s%s", k,
          tostring(okC and c or "?"), tostring(okN and nm or "?"), extra))
      end
    end
    system.print(string.format("[HELM] %d linked · radars found %d", n, #Radars))
  elseif lo == "park" then if ParkHold then ParkRelease(nil) else ParkEngage() end
  elseif lo == "alt" or lo:match("^alt%s") then
    local arg = lo:match("^alt%s+(.-)%s*$")
    if arg == "off" then
      if AltHold then AltHoldOff() else Msg("Altitude hold is off") end
    elseif arg == "here" then AltHoldSet(nil, true)
    elseif arg == nil or arg == "" then
      if AltHold then AltHoldOff() else AltHoldSet(nil) end
    else
      local n = tonumber((arg:gsub("[,%s]", ""):gsub("m$", "")))
      if n then AltHoldSet(n) else Msg("alt N — hold N m above sea level · alt / Alt+7 — on (last height held) / off · alt here — hold this height · alt off") end
    end
  elseif lo == "agg" or lo:match("^agg%s") then AggCommand(lo:match("^agg%s+(.-)%s*$"))
  elseif lo == "autowarp" or lo == "autowarp on" or lo == "autowarp off" then
    if not WarpDrive then Msg("No warp drive linked")
    else
      if lo ~= "autowarp" then AutoWarp = (lo == "autowarp on") end
      Msg(AutoWarp and "Auto-warp ON (this session): the AP warps when the drive is READY and the map's warp destination is where it's going"
                    or "Auto-warp off — warp by hand (the AP still carries on after a jump)")
    end
  elseif lo == "mass" then
    local low, list, m = SafeMass()
    Msg("Mass "..fmtT(m).." · safe mass (ArchHUD's 2:1 rule, gravity here):")
    for _, e in ipairs(list) do
      system.print(string.format("[HELM]   %-14s %s%s", e[1], e[2] > 0 and fmtT(e[2]) or "none",
        (low and e == low) and "  ← the limit" or ""))
    end
    if low then system.print(string.format("[HELM]   %s", m > low[2] and ("over by "..fmtT(m - low[2]))
      or ("room for about "..fmtT(low[2] - m).." more"))) end
  elseif lo == "planets" then
    -- Which atlas bodies are near, and which one the target is on
    -- (diagnostic: a 20 km trip on Alioth went via space with PlanetTrips
    -- auto, and Alt+1 in orbit didn't orbit — is the target's "Alioth"
    -- the same atlas entry as the one we're over?)
    local pos = vec3(construct.getWorldPosition())
    local list = {}
    for _, B in ipairs(Bodies) do list[#list+1] = { B = B, d = (pos - B.c):len() - B.r } end
    table.sort(list, function(a, b) return a.d < b.d end)
    local near = list[1] and list[1].B
    Msg(string.format("%d atlas bodies · nearest 6 (distance to sea level):", #Bodies))
    for i = 1, mmin(6, #list) do
      local B = list[i].B
      local tags = (B == near and "  ← nearest" or "")..(B == AP.surfB and "  ★ target's body" or "")
      system.print(string.format("[HELM]   %s (system %s, id %s) · %s · radius %.1f km · air top %.1f km · ground top %.1f km%s",
        B.name, tostring(B.sys), tostring(B.id), FormatDist(mmax(list[i].d, 0)), B.r / 1000,
        (B.atm > 0 and (B.atm - B.r) or 0) / 1000, (B.top - B.r) / 1000, tags))
    end
    if AP.surfB and AP.surfB ~= near then
      local same = 0
      for _, B in ipairs(Bodies) do if B.name == AP.surfB.name then same = same + 1 end end
      system.print(string.format("[HELM]   Target's body: %s (system %s, id %s), %s away — not the nearest%s",
        AP.surfB.name, tostring(AP.surfB.sys), tostring(AP.surfB.id), FormatDist((pos - AP.surfB.c):len() - AP.surfB.r),
        same > 1 and string.format(" (%d bodies are named %s!)", same, AP.surfB.name) or ""))
    end
  elseif lo == "climb log" or lo == "climblog" or lo == "climb log off" then
    if ClimbLog or lo == "climb log off" then
      ClimbLog = nil
      Msg("Climb log off")
    else
      ClimbLog = {}
      Msg("Climb log ON — a line every 2 s (forces in g: 1.00 = the ship's weight here). Stops itself in space · climb log again = off")
    end
  elseif lo == "rockets" or lo == "rockets test" then
    local K = Thrust and Thrust.K or 0
    if K <= 0 then Msg("No rocket engines found on this ship")
    elseif lo == "rockets test" then RocketTest = true; Msg("Rocket test armed — the next AP climb fires the rockets for up to 15 s (off near the burn speed)")
    else Msg(string.format("Rockets %s · %s forward · the AP fires them when a climb struggles · B toggles by hand", RocketOn and "ON" or "off", fmtN(K))) end
  elseif lo == "hdg" or lo:match("^hdg%s") then
    -- hdg = which way the nose faces · hdg N / hdg here / hdg off = the
    -- current target's parking heading
    local arg = lo:match("^hdg%s+(.-)%s*$")
    local pos = vec3(construct.getWorldPosition())
    local dv = DownDir(pos)
    local cur = dv and HeadingOf(vec3(construct.getWorldOrientationForward()), -dv)
    if not arg then
      Msg(cur and string.format("Facing %.0f° (0 = north, 90 = east) — add |hdg=%.0f after a ::pos to park facing this way", cur, cur)
              or "No heading here (no planet nearby, nose straight up/down, or at a pole)")
      if AP.target then Msg(AP.hdg and string.format("%s parks facing %.0f°", AP.name, AP.hdg) or (AP.name.." has no parking heading")) end
    elseif not (AP.target and AP.surfB) then Msg("Set a surface destination first")
    elseif arg == "off" then AP.hdg = nil; SaveTarget(); Msg(AP.name.." — no parking heading")
    else
      local h = arg == "here" and cur or tonumber(arg)
      if not h then Msg("hdg N (0-360), hdg here, or hdg off")
      else AP.hdg = h % 360; SaveTarget(); Msg(string.format("%s parks facing %.0f°", AP.name, AP.hdg)) end
    end
  elseif lo == "fhud" then ToggleFlightHud()
  elseif lo:match("^navinfo") then
    local arg = lo:match("^navinfo%s+(%a+)")
    if arg == "on" then NavInfo = true elseif arg == "off" then NavInfo = false else NavInfo = not NavInfo end
    DbSetNum("sf_navinfo", NavInfo and 1 or 0)
    Msg("AUTOPILOT panel "..(NavInfo and "ON" or "OFF")..(NavDB and "  (saved)" or "  (no databank — resets on restart)"))
  elseif lo == "farside" then
    -- Test target: mirror our position through the nearest planet's
    -- centre (same distance from it), so the planet is squarely in the
    -- way. Sets the target only — Alt+1 to fly it.
    local pos = vec3(construct.getWorldPosition())
    local best, bd
    for _, B in ipairs(Bodies) do
      local d = (pos - B.c):len() - B.r
      if not bd or d < bd then best, bd = B, d end
    end
    if not best then Msg("No planets in the atlas")
    else
      local p = best.c * 2 - pos
      if SetTarget("Far side of "..best.name, string.format("::pos{0,0,%.4f,%.4f,%.4f}", p.x, p.y, p.z)) then
        system.print(AP.posStr)
        Msg("Target: far side of "..best.name.." ("..FormatDist((p - pos):len())..")  —  Alt+1 to fly around it")
      end
    end
  elseif lo:match("^ahead") then
    -- Test target in empty space straight off the nose: N su (default 1).
    -- Nothing there to hit, so an overshoot is harmless.
    local n = tonumber(lo:match("^ahead%s+([%d%.]+)")) or 1
    n = clamp(n, 0.05, 50)
    local pos = vec3(construct.getWorldPosition())
    local p = pos + vec3(construct.getWorldOrientationForward()) * (n * SU)
    local B = InsideBody(p)
    if B then Msg(string.format("%.2f su ahead is inside %s — point somewhere else", n, B.name))
    elseif SetTarget(string.format("%.2f su ahead", n), string.format("::pos{0,0,%.4f,%.4f,%.4f}", p.x, p.y, p.z)) then
      -- Copy-able coordinates (also set as the DU map destination by SetTarget).
      system.print("[HELM] Coordinates: "..AP.posStr)
      Msg(string.format("Target: empty space %.2f su ahead  —  Alt+1 to fly", n))
    end
  elseif lo:match("^autolevel") then
    local arg = lo:match("^autolevel%s+(%a+)")
    if arg == "on" or arg == "off" then
      AutoLevel = (arg == "on")
      DbSetNum("sf_autolevel", AutoLevel and 1 or 0)
    end
    Msg("Auto-level "..(AutoLevel and "ON" or "OFF")..(arg and "" or "  —  autolevel on / autolevel off"))
  elseif lo == "mode" then SetMode(Mode == 2 and 1 or 2)
  elseif lo == "mode flight" or lo == "flight" then SetMode(1)
  elseif lo == "mode maneuver" or lo == "maneuver" then SetMode(2)
  elseif lo == "engines" or lo == "tags" then PrintEngineTags()
  elseif lo == "fuelinfo" or lo == "fuel" then PrintFuelInfo()
  elseif lo:match("^fueltalents") then
    -- A S R O C (handling per fuel type), or the old H O C (one handling for all)
    local a, sp, r, o, c = lo:match("^fueltalents%s+(%d)%s+(%d)%s+(%d)%s+(%d)%s+(%d)")
    if not a then
      local h
      h, o, c = lo:match("^fueltalents%s+(%d)%s+(%d)%s+(%d)%s*$")
      a, sp, r = h, h, h
    end
    if a then
      TankH.atmo, TankH.space, TankH.rocket = clamp(tonumber(a), 0, 5), clamp(tonumber(sp), 0, 5), clamp(tonumber(r), 0, 5)
      FuelTankOptimization, ContainerOptimization = clamp(tonumber(o), 0, 5), clamp(tonumber(c), 0, 5)
      DbSetNum("sf_ft_handling", TankH.atmo)
      DbSetNum("sf_ft_handling_s", TankH.space)
      DbSetNum("sf_ft_handling_r", TankH.rocket)
      DbSetNum("sf_ft_fuelopt", FuelTankOptimization)
      DbSetNum("sf_ft_contopt", ContainerOptimization)
      ReadFuel()
    end
    Msg("Fuel talents: "..TalentsText()..
      (a and (NavDB and "  (saved)" or "  (no databank — resets on restart)") or "  —  fueltalents A S R O C to change"))
  elseif lo == "radar" then
    PrintRadar()
  elseif lo == "thrust" then
    PrintThrust()
    LandingReport()
    local w = ManeuverWarning()
    if w then Msg("Maneuver: "..w) end
  elseif lo:match("^speed") then
    local n = tonumber(lo:match("^speed%s+([%d%.]+)"))
    if n then MaxCruiseSpeed = n end
    Msg("AP cruise cap: "..((MaxCruiseSpeed or 0) > 0 and string.format("%.0f km/h", MaxCruiseSpeed) or "ship max"))
  elseif lo:match("^landsafety") then
    local n = tonumber(lo:match("^landsafety%s+([%d%.]+)"))
    if n then
      LandSafety = clamp(n, 0.1, 1)
      DbSetNum("sf_landsafety", LandSafety)
    end
    Msg(string.format("Land safety: %.2f%s", LandSafety,
        n and (NavDB and "  (saved)" or "  (no databank — resets on restart)") or "  —  landsafety N to change"))
  elseif lo == "brakes" or lo == "brakes reset" then
    if lo == "brakes reset" then
      BrakeK = 1
      DbSetNum(PK("sf_brake_k3"), 1)
      Msg("Brake factor reset to 1.00")
    end
    RefreshShipStats()
    local mass = construct.getMass()
    local function mn(n) return n and string.format("%.2f MN", n / 1e6) or "not seen yet" end
    system.print(string.format("[HELM] Brakes (DU getMaxBrake): now %s · space %s · atmo %s",
      mn(MaxBrakeN), mn(BrakeSeenSpace), mn(BrakeSeenAtmo)))
    system.print(string.format("[HELM]   mass %.1f t → DU decel %.1f m/s² · learned factor %.2f · BrakeSafety %.2f → AP plans %.1f m/s²",
      mass / 1000, MaxBrakeN / mmax(mass, 1), BrakeK, BrakeSafety, BrakeAccel(mass)))
    local bk = AP.bk
    if bk and bk.ratio then
      system.print(string.format("[HELM]   last AP braking, by speed (%.0f s):", bk.time))
      for _, l in ipairs(BrakeBandLines()) do system.print("[HELM]     "..l) end
    end
  elseif lo:match("^stopdist") then
    local n = tonumber(lo:match("^stopdist%s+([%d%.]+)"))
    if n then StopDistance = mmax(50, n) end
    Msg("Stop distance: "..FormatDist(StopDistance))
  elseif lo == "target" then
    if AP.target then
      system.print("[HELM] "..AP.name..(AP.note and ("  ("..AP.note..")") or ""))
      system.print(AP.posStr)
    else Msg("No target") end
  end
  -- Anything else is silently ignored: it's probably for another script.
end

-- ── HUD (AR overlay) ──────────────────────────────────────────────
local PHASE_COL = { OFF="#7f8c99", ALIGN="#ffc24b", BURN="ACC", CRUISE="#5be37a",
  BRAKING="#ff9a3c", STOPPING="#ff9a3c", OBSTACLE="#ff3b3b", DESCENT="ACC", LIFT="ACC", ["LINE UP"]="#ffc24b", CLIMB="ACC", ORBIT="ACC", SLOWING="#ff9a3c", TURN="#ffc24b", ["KILL DRIFT"]="#ffc24b", CORRECT="#ffc24b", ["PARK TURN"]="#ffc24b", ARRIVED="#5be37a" }

-- ── Fighter-style attitude HUD (Alt+6 / "fhud") ───────────────────
-- Centre-screen SVG: pitch ladder + horizon, roll scale, fixed ship
-- marker, flight path marker (where you're actually going), autopilot
-- target marker, speed / altitude / vertical speed. "Level" = against
-- gravity, or in weak gravity the nearest planet in the atlas. Drawn in a
-- 1920×1080 viewBox and scaled to the screen. Angles are relative to the
-- ship, so it lines up best in first-person view.
function ToggleFlightHud()
  FlightHud = not FlightHud
  DbSetNum("sf_fhud", FlightHud and 1 or 0)
  Msg("Flight HUD "..(FlightHud and "ON" or "OFF").."  (Alt+6)")
end

local function nearestBody(pos)
  local best, bd
  for _, B in ipairs(Bodies) do
    local d = (pos - B.c):len() - B.r
    if not bd or d < bd then best, bd = B, d end
  end
  return best, bd
end

function FlightHudSvg(acc)
  local C = construct
  local pos   = vec3(C.getWorldPosition())
  local vel   = vec3(C.getWorldVelocity())
  local fwd   = vec3(C.getWorldOrientationForward())
  local right = vec3(C.getWorldOrientationRight())
  local up    = vec3(C.getWorldOrientationUp())
  local B, alt = nearestBody(pos)
  local g = vec3(core.getWorldGravity())
  local upW
  -- (not from gravity alone: an AGG holding the ship makes it ~0 and
  -- pointing anywhere — horizon upside down)
  local dv = DownDir(pos)
  if dv and (g:len() > 0.05 or AggIsOn()) then upW = -dv
  elseif B and alt and alt < 2 * SU then upW = norm(pos - B.c) end
  local col = "rgb("..acc..")"
  local fs = clamp(FlightHudScale, 0.4, 1.5)
  local CX, CY, PPD = 960, 540, 12

  local s = {}
  local function a(x) s[#s+1] = x end
  local function txt(x, y, str, anchor, size, extra)
    a(string.format('<text x="%.0f" y="%.0f" text-anchor="%s" font-size="%d" fill="%s" stroke="none"%s>%s</text>',
      x, y, anchor or "middle", size or 14, col, extra or "", str))
  end
  a('<svg viewBox="0 0 1920 1080" preserveAspectRatio="none" '..
    'style="position:absolute;left:0;top:0;width:100vw;height:100vh">')

  -- ── Part 1: attitude instrument, FIXED at the screen centre ─────
  -- The ship's own pitch / roll against the nearest planet, scaled by
  -- FlightHudScale. Compact on purpose: it never follows the camera.
  a(string.format('<g transform="translate(%d %d) scale(%.2f) translate(%d %d)" ', CX, CY, fs, -CX, -CY)..
    'fill="none" stroke="'..col..'" stroke-width="2" stroke-linecap="round" '..
    'font-family="Montserrat,Arial,sans-serif" opacity="0.85">')
  if upW then
    local pitch = math.deg(math.asin(clamp(fwd:dot(upW), -1, 1)))          -- + nose up
    local roll  = math.deg(math.atan(-right:dot(upW), up:dot(upW)))        -- + right wing low
    a(string.format('<g transform="translate(%d,%d) rotate(%.2f) translate(0,%.1f)">', CX, CY, -roll, pitch * PPD))
    local p1 = math.ceil((pitch - 22) / 10) * 10
    for p = p1, p1 + 40, 10 do
      if p >= -90 and p <= 90 then
        local y = -p * PPD
        if p == 0 then
          a('<line x1="-280" y1="0" x2="-70" y2="0"/><line x1="70" y1="0" x2="280" y2="0"/>')
        else
          local dash = p < 0 and ' stroke-dasharray="10 7"' or ''
          local tick = p > 0 and 10 or -10
          a(string.format('<polyline points="-140,%.0f -50,%.0f"%s/><polyline points="-140,%.0f -140,%.0f"/>', y, y, dash, y, y + tick))
          a(string.format('<polyline points="50,%.0f 140,%.0f"%s/><polyline points="140,%.0f 140,%.0f"/>', y, y, dash, y, y + tick))
          txt(-155, y + 5, tostring(mabs(p)), "end", 13)
          txt(155, y + 5, tostring(mabs(p)), "start", 13)
        end
      end
    end
    a('</g>')
    local R = 270
    for _, t in ipairs({-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60}) do
      local r1 = (t % 30 == 0) and R - 16 or R - 9
      local rad = math.rad(t)
      a(string.format('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>',
        CX + R * math.sin(rad), CY - R * math.cos(rad), CX + r1 * math.sin(rad), CY - r1 * math.cos(rad)))
    end
    local pr = math.rad(clamp(-roll, -70, 70))
    local px, py = CX + (R - 22) * math.sin(pr), CY - (R - 22) * math.cos(pr)
    a(string.format('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" stroke="none" transform="rotate(%.1f %.1f %.1f)"/>',
      px, py - 2, px - 8, py + 12, px + 8, py + 12, col, math.deg(pr), px, py))
    txt(CX, CY + 300, string.format("P %+.0f°   R %+.0f°", pitch, roll), "middle", 14)
  else
    txt(CX, CY - 70, "NO HORIZON", "middle", 14, ' opacity="0.7"')
  end
  -- Fixed centre marker: the reference the ladder is read against.
  a(string.format('<polyline points="%d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d" stroke-width="2.5"/>',
    CX - 60, CY, CX - 28, CY, CX - 14, CY + 14, CX, CY, CX + 14, CY + 14, CX + 28, CY, CX + 60, CY))
  local sp = vel:len()
  txt(CX - 330, CY + 6, string.format("%.0f", sp * 3.6), "end", 20, ' font-weight="700"')
  txt(CX - 330, CY + 26, "km/h", "end", 12)
  if B and alt then
    local vs = upW and vel:dot(upW) or 0
    txt(CX + 330, CY + 6, FormatDist(mmax(alt, 0)), "start", 20, ' font-weight="700"')
    txt(CX + 330, CY + 26, string.format("ALT · %s%.0f m/s", vs >= 0 and "▲" or "▼", mabs(vs)), "start", 12)
    txt(CX + 330, CY + 44, esc(B.name), "start", 12, ' opacity="0.7"')
  end
  a('</g>')

  -- ── Part 2: markers ON the world (camera projection) ────────────
  -- These line up with real things (DU's own target marker), in first or
  -- third person. getCameraWorldPos/Forward/Right are confirmed (Arch);
  -- Up and FOV fall back if the game doesn't have them.
  local okP, cp = pcall(function() return vec3(system.getCameraWorldPos()) end)
  local okF, cf = pcall(function() return vec3(system.getCameraWorldForward()) end)
  local okR, cr = pcall(function() return vec3(system.getCameraWorldRight()) end)
  if not (okP and okF and okR) then cp, cf, cr = pos, fwd, right end
  local okU, cu = pcall(function() return vec3(system.getCameraWorldUp()) end)
  if not okU then cu = cr:cross(cf) end
  local okH, hf = pcall(function() return system.getCameraHorizontalFov() end)
  local okV, vf = pcall(function() return system.getCameraVerticalFov() end)
  hf = (okH and tonumber(hf) and hf > 1) and hf or 90
  local tx = math.tan(math.rad(hf) / 2)
  local ty = (okV and tonumber(vf) and vf > 1) and math.tan(math.rad(vf) / 2) or tx * 9 / 16
  local function proj(dir)
    local z = dir:dot(cf)
    if z <= 1e-6 then return nil end
    return 960 + (dir:dot(cr) / z) / tx * 960, 540 - (dir:dot(cu) / z) / ty * 540
  end
  a('<g fill="none" stroke="'..col..'" stroke-width="2" stroke-linecap="round" '..
    'font-family="Montserrat,Arial,sans-serif" opacity="0.9">')
  -- Flight path marker: where the ship is actually going.
  if sp > 2 then
    local x, y = proj(vel)
    if x and x > 0 and x < 1920 and y > 0 and y < 1080 then
      local r = 9 * fs
      a(string.format('<circle cx="%.1f" cy="%.1f" r="%.1f"/><line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>'..
        '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/><line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>',
        x, y, r, x - r * 2.4, y, x - r, y, x + r, y, x + r * 2.4, y, x, y - r, x, y - r * 2))
    end
  end
  -- Autopilot target: diamond on the target; off-screen/behind → arrow.
  if AP.target then
    local to = AP.target - cp
    local x, y = proj(to)
    if x and x > 40 and x < 1880 and y > 40 and y < 1040 then
      local r = 12 * fs
      a(string.format('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" stroke="#ffc24b"/>',
        x, y - r, x + r, y, x, y + r, x - r, y))
      a(string.format('<text x="%.1f" y="%.1f" text-anchor="middle" font-size="%.0f" fill="#ffc24b" stroke="none">%s</text>',
        x, y + 30 * fs, 13 * fs, FormatDist((AP.target - pos):len())))
    else
      local ex, ey = to:dot(cr), -to:dot(cu)
      local el = math.sqrt(ex * ex + ey * ey)
      if el > 1e-6 then
        ex, ey = ex / el, ey / el
        local ax, ay = CX + ex * 360 * fs, CY + ey * 280 * fs
        local ang = math.deg(math.atan(ex, -ey))
        a(string.format('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="#ffc24b" stroke="none" transform="rotate(%.1f %.1f %.1f)"/>',
          ax, ay - 14 * fs, ax - 9 * fs, ay + 6 * fs, ax + 9 * fs, ay + 6 * fs, ang, ax, ay))
      end
    end
  end
  a('</g></svg>')
  return table.concat(s)
end

function PopupHtml()
  -- Centre popup: red collision (always), contact on the AP's path (the
  -- AP is flying, so the pilot may be looking away), ship below while
  -- landing, or an event alert. Blinks so it catches the eye.
  local pT, pX, pC
  if Threat and (Threat.danger or AP.active) then
    pC = Threat.danger and '#ff3b3b' or '#ffc24b'
    pT = Threat.danger and 'COLLISION — BRAKE NOW' or 'CONTACT ON PATH'
    pX = string.format('%s [%s] · %s ahead · passes ~%s off%s', esc(Threat.name), esc(Threat.size),
      FormatDist(Threat.dist), FormatDist(Threat.miss), Threat.est and ' (est)' or '')
  elseif ShipBelow then
    local s = ShipBelow
    pC, pT = '#ffc24b', 'SHIP BELOW'
    pX = string.format('%s [%s] · %s down · ~%s off your line%s', esc(s.name), esc(s.size),
      FormatDist(s.depth), FormatDist(s.off), s.est and ' (est)' or '')
  elseif Alert and now() < Alert.untilT then
    pC, pT, pX = Alert.col, esc(Alert.title), esc(Alert.text)
  end
  if pT then
    local blink = (now() % 1) < 0.6 and '1' or '.55'
    return ('<div style="position:absolute;left:0;width:100vw;top:18vh;text-align:center;'..
        'font-family:Montserrat,Arial,sans-serif;pointer-events:none">'..
        '<div style="display:inline-block;padding:10px 30px;background:rgba(8,6,14,.85);border:2px solid '..pC..
        ';border-radius:6px;opacity:'..blink..'">'..
        '<div style="font-size:28px;font-weight:800;letter-spacing:3px;color:'..pC..'">'..pT..'</div>'..
        '<div style="font-size:15px;color:#e8eef4;margin-top:4px">'..pX..'</div></div></div>')
  end
  return ''
end

local popupShown = false
function DrawHUD()
  if not HudOn then
    -- HUD hidden (Alt+3): the popup still shows.
    local p = PopupHtml()
    if p ~= '' or popupShown then system.setScreen(p) end
    popupShown = p ~= ''
    return
  end
  local acc = string.format("%d,%d,%d", ThemeAcc[1], ThemeAcc[2], ThemeAcc[3])
  local bgc = string.format("%d,%d,%d", ThemeBg[1], ThemeBg[2], ThemeBg[3])
  local op  = clamp(HudOpacity, 0.3, 1)
  local C = construct
  local pos = vec3(C.getWorldPosition())
  local speed = vec3(C.getWorldVelocity()):len()
  local mass = C.getMass()
  local h = {}
  local function add(s) h[#h+1] = s end
  local function row(k, v) add('<div class="r"><span class="k">'..k..'</span><span class="v">'..v..'</span></div>') end
  local function lvlCol(p) return p > 0.5 and "#5be37a" or (p > 0.2 and "#ffc24b" or "#ff5a5a") end
  -- AUTOPILOT panel: on by default (third-person pilots can't see a
  -- Navigator screen); players who'd rather watch Navigator turn it off.
  local showNav = NavInfo
  local sc = clamp(HudScale, 0.5, 2)

  -- Compact bottom bar: fixed-width panels, only as wide as what's shown,
  -- centred (+HudShift). FLIGHT | [AUTOPILOT] | SYSTEMS, then a strip for
  -- the latest message + key hints. HudScale shrinks/grows the lot.
  add('<style>'..
      '.hb{position:absolute;left:'..HudShift..'vw;width:100vw;bottom:'..HudBottom..'vh;text-align:center;'..
      'font-family:Montserrat,Arial,sans-serif;font-size:12px;color:#d8e2ea}'..
      '.in{display:inline-block;text-align:left;transform:scale('..sc..');transform-origin:50% 100%}'..
      -- (fixed minimum height: the bar sits on the screen bottom, so rows
      -- coming and going — predicted miss, tags, notes — made the panel
      -- tops jump up and down as the AP changed phase; Carl, 1114)
      '.cols{display:flex;gap:8px;align-items:stretch;min-height:172px}'..
      '.p{width:15vw;min-width:230px;background:rgba('..bgc..','..op..');border:1px solid rgba('..acc..',.32);'..
      'border-top:2px solid rgb('..acc..');border-radius:4px;padding:6px 10px}'..
      '.p.ap{width:18vw;min-width:270px}'..
      '.hd{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:700;'..
      'letter-spacing:2px;color:rgb('..acc..');margin-bottom:3px}'..
      '.ph{padding:1px 6px;border-radius:3px;color:#05090e;letter-spacing:1px}'..
      '.big{font-size:18px;font-weight:700;line-height:1.1}.big small{font-size:11px;font-weight:400;color:#9aa8b5}'..
      '.tg{font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'..
      '.nt{font-size:10px;color:#9aa8b5}.p.ap .nt{min-height:26px}'..
      '.r{display:flex;justify-content:space-between;margin-top:3px}'..
      '.k{color:#8a98a6;font-size:10px;letter-spacing:1px}.v{font-weight:600}'..
      '.bar{height:3px;background:rgba(255,255,255,.1);border-radius:2px;margin-top:5px}'..
      '.bar i{display:block;height:100%;border-radius:2px;background:rgb('..acc..')}'..
      '.tags{margin-top:5px;font-size:9px;letter-spacing:1px}'..
      '.tags b{color:#ffc24b;font-weight:700;margin-right:7px}.tags u{text-decoration:none;color:#5be37a;font-weight:700;margin-right:7px}'..
      '.strip{display:flex;flex-wrap:wrap;justify-content:space-between;gap:1px 10px;margin-bottom:5px;padding:3px 10px;'..
      'background:rgba('..bgc..','..op..');border:1px solid rgba('..acc..',.22);border-radius:4px;font-size:10px}'..
      '.msg{color:#ffc24b;margin-right:14px}'..
      '.keys{color:#8a98a6;margin-left:auto;text-align:right}'..
      '</style>')
  add('<div class="hb"><div class="in">')
  -- Collision warning strip (radar): amber = contact on the path, red =
  -- too close to stop with the brakes.
  if Threat then
    local col = Threat.danger and '#ff3b3b' or '#ffc24b'
    add(string.format('<div class="strip" style="border-color:%s;justify-content:center;font-size:12px;font-weight:700;color:%s">'..
      '!! %s: %s [%s] · %s · %.0f s · passes ~%s off%s</div>',
      col, col, Threat.danger and 'COLLISION — BRAKE NOW' or 'CONTACT ON PATH', esc(Threat.name), esc(Threat.size),
      FormatDist(Threat.dist), Threat.t, FormatDist(Threat.miss), Threat.est and ' (est)' or ''))
  end
  if ShipBelow and not Threat then
    local s = ShipBelow
    add(string.format('<div class="strip" style="border-color:#ffc24b;justify-content:center;font-size:12px;font-weight:700;color:#ffc24b">'..
      'SHIP BELOW: %s [%s] · %s down · ~%s off your line%s</div>',
      esc(s.name), esc(s.size), FormatDist(s.depth), FormatDist(s.off), s.est and ' (est)' or ''))
  end
  -- Line 1: key hints only.
  add('<div class="strip"><span class="keys">Alt+ 1 AP · 2 clear · 3 hide · 4 mode · 5 park · 6 HUD · 7 alt hold · Ctrl+Alt brake lock · G hover/land</span><span class="keys">v'..VERSION..' · build '..esc(BUILD)..'</span></div>')
  -- Line 2: latest message on the left, warp (only with a warp drive) on
  -- the right. Hidden when there's neither.
  local warpHtml = ''
  if WarpDrive then
    local st = Warp.status
    local wc = st == 15 and '#5be37a' or ((st == 3 or st == 4) and ('rgb('..acc..')')
               or ((st == 6 or st == 7) and '#ffc24b' or '#ff5a5a'))
    local w = '<span class="k">WARP</span> <span style="color:'..wc..';font-weight:700">'..esc(Warp.text)..'</span>'
    if Warp.dest then
      w = w..' · → '..esc(Warp.dest)..(Warp.dist and (' '..FormatDist(Warp.dist)) or '')
    end
    if Warp.need and Warp.cells then
      w = w..string.format(' · cells %d/<span style="color:%s">%d</span>',
        Warp.need, Warp.cells >= Warp.need and '#5be37a' or '#ff5a5a', Warp.cells)
    end
    if AutoWarp then
      local m = AP.target and Warp.dest and WarpMatches()
      w = w..(m and ' · <b style="color:#5be37a">AUTO</b>'
              or ' · <b style="color:#ffc24b">AUTO: '..(AP.target and (Warp.dest and "not the AP's destination" or "set it on the map") or "no AP target")..'</b>')
    end
    warpHtml = '<span class="keys" style="color:#d8e2ea">'..w..'</span>'
  end
  if StatusMsg ~= '' or warpHtml ~= '' then
    add('<div class="strip"><span class="msg">'..esc(StatusMsg)..'</span>'..warpHtml..'</div>')
  end
  add('<div class="cols">')
  local ph = AP.phase
  local pc = PHASE_COL[ph] or "#7f8c99"
  if pc == "ACC" then pc = "rgb("..acc..")" end

  -- ── Panel 1: FLIGHT ─────────────────────────────────────────────
  local acm = Nav.axisCommandManager
  local cap = (Mode == 2 and not AP.active) and (ManeuverSpeed/3.6) or CruiseCap()
  -- Header badges: Maneuver mode, and (when the AUTOPILOT panel is hidden
  -- because Navigator shows the trip info) the autopilot's phase.
  local badges = ''
  if Mode == 2 then badges = badges..'<span class="ph" style="background:#ffc24b">MANEUVER</span>' end
  if not showNav and (AP.active or ph == "ARRIVED") then
    badges = badges..'<span class="ph" style="background:'..pc..';margin-left:4px">AP '..ph..'</span>'
  end
  add('<div class="p"><div class="hd"><span>FLIGHT</span><span>'..badges..'</span></div>')
  add('<div class="big">'..string.format("%.0f", speed*3.6)..' <small>/ '..string.format("%.0f", cap*3.6)..' km/h</small></div>')
  -- Throttle / cruise (replaces DU's seat widget, which is hidden)
  if AP.active then
    -- AP flying: show what the AP is commanding (the seat throttle sits at
    -- 0 meanwhile). Carl: "if the throttle could show what it's doing".
    local thr = MaxThrustN > 0 and clamp((AP.accel or 0) * mass / MaxThrustN, 0, 1) or 0
    local br = AP.brake or 0
    row("THROTTLE (AP)", string.format("%d%%", math.floor(thr * 100 + 0.5))..
      (br > 0.01 and string.format(" · brake %d%%", math.floor(br * 100 + 0.5)) or ""))
  elseif acm:getAxisCommandType(axisCommandId.longitudinal) == axisCommandType.byTargetSpeed then
    row("CRUISE", string.format("%.0f km/h", acm:getTargetSpeed(axisCommandId.longitudinal)))
  else
    local okT, t = pcall(unit.getThrottle)
    row("THROTTLE", string.format("%.0f%%", (okT and tonumber(t)) or 0))
  end
  -- Landed / parked: the brake distance row (0 m then) shows the safe mass
  -- instead — the time you're loading cargo.
  local safeLow = (not AP.active and speed < 1) and SafeMass() or nil
  if safeLow then
    local col = mass > safeLow[2] and "#ff3b3b" or mass > safeLow[2] * 0.9 and "#ffc24b" or nil
    row("MASS · SAFE", (col and '<span style="color:'..col..'">' or '')..fmtT(mass).." · "..fmtT(safeLow[2])..
      (col and '</span>' or '')..' <span class="k">('..safeLow[1]..')</span>')
  elseif showNav then row("BRAKE DIST", FormatDist(BrakeDist(speed, BrakeAccel(mass) / BrakeSafety))) end
  if not showNav and AP.active then
    local thr = MaxThrustN > 0 and clamp(AP.accel * mass / MaxThrustN, 0, 1) or 0
    row("AP ALIGN · THRUST", string.format("%.1f° · %d%%", AP.alignErr, math.floor(thr*100 + 0.5)))
    if AP.legs and #AP.legs > 1 then row("AP LEG", AP.leg.." of "..#AP.legs.."  (around planet)") end
  end
  if Mode == 2 and Thrust then
    local d = {}
    for _, k in ipairs({"F","B","L","R","U","D"}) do
      d[#d+1] = '<span style="margin-left:5px;color:'..(Thrust[k] >= 1 and '#5be37a' or '#ff5a5a;opacity:.6')..'">'..k..'</span>'
    end
    row("THRUSTERS", table.concat(d))
  end
  local tags = {}
  if HoverState == "hover" then tags[#tags+1] = '<u>HOVER '..string.format("%.0f", Nav:getTargetGroundAltitude())..' m</u>'
  elseif HoverState == "landing" then
    tags[#tags+1] = LandPhase == "stop" and '<b>LANDING · STOPPING</b>' or
      ('<b>LANDING '..(GroundDist >= 0 and string.format("%.0f m", GroundDist) or "")..
       string.format(" @ %.0f km/h", LandVSet * 3.6)..'</b>')
  end
  if ParkHold then tags[#tags+1] = ParkHold.phase == "stop" and '<b>PARK · STOPPING</b>' or '<u>PARK HOLD</u>' end
  if ParkBrake then tags[#tags+1] = '<b>BRAKES LOCKED</b>' end
  if brakeInput > 0 then tags[#tags+1] = '<b>BRAKE</b>' end
  local okG, gear = pcall(unit.isAnyLandingGearDeployed)
  if okG and gear then tags[#tags+1] = '<b>GEAR</b>' end
  if LevelActive then tags[#tags+1] = '<u>LEVEL</u>' end
  if RocketOn then tags[#tags+1] = '<b style="color:#ff5a5a">ROCKETS'..(RocketByAP and ' (AP)' or '')..'</b>' end
  if BurnLimitOn then tags[#tags+1] = '<b style="color:#ff9a3c">BURN LIMIT</b>' end
  if AltHoldOn and AltHold then tags[#tags+1] = string.format('<u>ALT HOLD %.0f m</u>', AltHold.R - AltHold.B.r) end
  if Mode == 2 and Thrust and Thrust.weight > 1 and Thrust.U < Thrust.weight then
    tags[#tags+1] = '<b style="color:#ff5a5a">UP THRUST &lt; WEIGHT</b>'
  end
  -- Navigator link tags live here when the AUTOPILOT panel is hidden.
  local ntags = {}
  if NavDB then
    if NavKind == "hud" then
      ntags[#ntags+1] = '<u>NAV LINK</u>'
      local _, af = pcall(NavDB.getStringValue, "autofly")
      if af == "1" then ntags[#ntags+1] = '<u>AUTO FLY</u>' end
    elseif NavKind == "main" then
      ntags[#ntags+1] = '<b style="color:#ff5a5a">WRONG DATABANK</b>'
    end
  end
  if not showNav then for _, t in ipairs(ntags) do tags[#tags+1] = t end end
  if #tags > 0 then add('<div class="tags">'..table.concat(tags)..'</div>') end
  add('</div>')

  -- ── Panel 2: AUTOPILOT (hidden when Navigator shows the trip info) ──
  if showNav then
  add('<div class="p ap"><div class="hd"><span>AUTOPILOT</span><span class="ph" style="background:'..pc..'">'..ph..'</span></div>')
  if AP.target then
    add('<div class="tg">'..esc(AP.name)..'</div>')
    if AP.note then add('<div class="nt">'..esc(AP.note)..'</div>') end
    local dist = (AP.target - pos):len()
    -- Near the planet of a surface spot, AP.target is the hold point up in
    -- space: show the distance over the ground to the spot instead (Carl,
    -- 1114: parked 1 km from the spot it said 15.1 km and a negative ETA).
    local spotDist
    if AP.spot and AP.surfB and (pos - AP.surfB.c):len() < AP.surfB.hard + 1000 then
      local Bs = AP.surfB
      local rp, rr = norm(pos - Bs.c)
      local dS = norm(AP.spot - Bs.c)
      spotDist = math.atan(rp:cross(dS):len(), rp:dot(dS)) * rr
    end
    if AP.active and AP.takeoff and AP.takeoff.atmo and AP.remaining then dist = AP.remaining
    elseif not AP.active and spotDist then dist = spotDist end
    local remaining = AP.active and AP.remaining or (spotDist and dist or (dist - StopDist()))
    remaining = mmax(remaining or 0, 0)
    local vAlong = AP.active and AP.vAlong or 0
    local eta = CalcETA(remaining, vAlong, CruiseCap(), MaxThrustN / mmax(mass, 1), BrakeAccel(mass))
    row("DISTANCE · ETA", FormatDist(dist).." · "..(AP.active and FormatTime(eta) or ("~"..FormatTime(eta))))
    if AP.active then
      local thr = MaxThrustN > 0 and clamp(AP.accel * mass / MaxThrustN, 0, 1) or 0
      row("ALIGN · THRUST", string.format("%.1f° · %d%%", AP.alignErr, math.floor(thr*100 + 0.5)))
      if AP.takeoff and AP.trackErr then
        -- Flight path vs the destination's bearing (+ = destination is left).
        row("TRACK", string.format("%+.1f° %s", AP.trackErr, AP.trackErr > 0.05 and "(dest. left)" or (AP.trackErr < -0.05 and "(dest. right)" or "")))
      end
      if AP.predMiss then
        row("PREDICTED MISS · AIM SHIFT", FormatDist(AP.predMiss).." · "..FormatDist((AP.aimOff or vec3()):len()))
      end
      if AP.legs and #AP.legs > 1 then row("LEG", AP.leg.." of "..#AP.legs) end
      if (AP.total or 0) > 0 and not AP.takeoff then
        local pct = clamp(1 - mmax(remaining, 0) / mmax(AP.total - StopDist(), 1), 0, 1)
        add('<div class="bar"><i style="width:'..string.format("%.1f", pct*100)..'%"></i></div>')
      end
    else
      add('<div class="nt" style="margin-top:4px">Alt+1 to engage</div>')
    end
  else
    add('<div class="tg" style="color:#8a98a6">No target</div>')
    add('<div class="nt">Paste a ::pos{} in Lua chat, or NAVIGATE in Navigator</div>')
  end
  if #ntags > 0 then add('<div class="tags">'..table.concat(ntags)..'</div>') end
  add('</div>')
  end   -- showNav

  -- ── Panel 3: SYSTEMS (fuel per tank, radar) ─────────────────────
  add('<div class="p"><div class="hd"><span>SYSTEMS</span><span></span></div>')
  local anyFuel = false
  for _, k in ipairs({ {"atmo","ATMO"}, {"space","SPACE"}, {"rocket","ROCKET"} }) do
    local f = Fuel[k[1]]
    if f then
      anyFuel = true
      local right = (f.n > 1 and "low " or "")..(f.over and "~" or "")..string.format("%d%%", math.floor(f.lowPct*100 + 0.5))
      if f.soonest then right = right..'<span style="color:#9aa8b5;font-weight:400"> · '..FormatTime(f.soonest)..'</span>' end
      row(k[2].." FUEL"..(f.n > 1 and (" ("..f.n..")") or ""), '<span style="color:'..lvlCol(f.lowPct)..'">'..right..'</span>')
      -- One thin bar per tank, size letter above it; bigger tanks get a
      -- wider bar so the row hints at capacity. "+" = above basic tier.
      local WIDTH = { xs = 1, s = 1, m = 1.3, l = 1.7, xl = 2.2, xxl = 2.7 }
      local segs = {}
      for _, tk in ipairs(f.tanks) do
        local lbl = string.upper(tk.size or "?")..((tk.tier or 1) > 1 and "+" or "")
        segs[#segs+1] = '<span style="flex:'..(WIDTH[tk.size] or 1)..';min-width:0">'..
          '<span style="display:block;font-size:11px;line-height:13px;font-weight:700;color:#aab6c2;letter-spacing:.5px">'..lbl..'</span>'..
          '<span style="display:block;height:4px;background:rgba(255,255,255,.1);border-radius:2px;overflow:hidden">'..
          '<i style="display:block;height:100%;width:'..string.format("%.1f", tk.pct*100)..'%;background:'..lvlCol(tk.pct)..'"></i></span></span>'
      end
      add('<div style="display:flex;gap:4px;margin-top:2px">'..table.concat(segs)..'</div>')
    end
  end
  if not anyFuel then add('<div class="nt">No fuel tanks found</div>') end
  if #Radars > 0 then
    row("RADAR", ActiveRadar and (RadarContacts.." contact"..(RadarContacts == 1 and "" or "s"))
                 or '<span style="color:#ff5a5a">not operational here</span>')
  end
  -- AGG: off (grey) · lift creeping to the set height (amber, with a time
  -- estimate) · holding (green). Plus how far you are from the lift.
  if antigrav then
    local s = AggRead()
    local tgt = s.target
    local v
    if not s.on then
      v = '<span style="color:#8a98a6">off'..(tgt and string.format(" · set %.0f m", tgt) or "")..'</span>'
    elseif s.pulsors == 0 then
      v = '<span style="color:#ff5a5a">no pulsors linked</span>'
    elseif s.base and tgt and mabs(s.base - tgt) > 2 then
      local eta = (Agg.rate and Agg.rate > 0.05) and (" · ~"..FormatTime(mabs(tgt - s.base) / Agg.rate)) or ""
      v = '<span style="color:#ffc24b">'..string.format("%.0f → %.0f m", s.base, tgt)..eta..'</span>'
    else
      v = '<span style="color:#5be37a">'..string.format("holding %.0f m", s.base or tgt or 0)..'</span>'
    end
    row("AGG", v)
    if s.on and s.pulsors == 0 then
      add('<div class="nt" style="color:#ff5a5a">no lift — link the pulsors to this generator</div>')
    elseif s.on and s.base and s.alt and mabs(s.alt - s.base) > 100 then
      add('<div class="nt">you\'re '..FormatDist(mabs(s.alt - s.base))..(s.alt < s.base and ' below' or ' above')..' the lift</div>')
    end
  end
  add('</div>')

  add('</div>')   -- /cols

  add('</div></div>')   -- /in /hb
  if FlightHud then add(FlightHudSvg(acc)) end

  add(PopupHtml())
  system.setScreen(table.concat(h))
end


-- ── Climb log (chat: climb log) ───────────────────────────────────
-- Every 2 s while on: height, air, speed, nose / path angle, climb rate,
-- and the forces in g (local gravity): lift and drag from DU's air
-- reading, engine push worked out from what's left (measured speed change
-- − gravity − air), next to the push DU reports for the forward engines.
-- To learn how big ships really climb out (Carl: they need speed first,
-- then ~20° at most, or they don't reach space). Stops itself in space.
ClimbLog = nil
function ClimbLogTick()
  local L = ClimbLog
  if not L then return end
  local tN = now()
  local pos = vec3(construct.getWorldPosition())
  local vel = vec3(construct.getWorldVelocity())
  if L.t and tN - L.t < 2 then return end
  local B = NearestBody(pos)
  local gv = vec3(core.getWorldGravity())
  local glen = mmax(gv:len(), 0.01)
  local upW = B and norm(pos - B.c) or (gv:len() > 0.01 and -gv / gv:len() or vec3(construct.getWorldOrientationUp()))
  local dens = unit.getAtmosphereDensity() or 0
  local fwd = vec3(construct.getWorldOrientationForward())
  local speed = vel:len()
  local vUp = vel:dot(upW)
  local nose = math.deg(math.asin(clamp(fwd:dot(upW), -1, 1)))
  local path = speed > 1 and math.deg(math.asin(clamp(vUp / speed, -1, 1))) or 0
  local alt = B and ((pos - B.c):len() - B.r) or 0
  local okA, air = pcall(construct.getWorldAirFrictionAcceleration)
  air = okA and air and vec3(air) or vec3()
  local lift, drag = 0, 0
  if speed > 1 then
    local vh = vel / speed
    drag = -air:dot(vh)
    local u = upW - vh * upW:dot(vh)                 -- "up", square to the path
    if u:len() > 0.01 then lift = air:dot(u / u:len()) end
  end
  local txt
  if L.t and L.v then
    local dt = tN - L.t
    local acc = (vel - L.v) / dt                     -- what really happened
    local eng = acc - gv - air                       -- the rest: engines (+ brakes)
    local dSpd = (speed - L.v:len()) / dt
    local mass = mmax(construct.getMass(), 1)
    local duF = (MaxThrustN or 0) / (mass * glen)
    local thr = "?"
    if AP.active then thr = "AP"
    else
      local okT, tv = pcall(function() return Nav.axisCommandManager:getThrottleCommand(axisCommandId.longitudinal) end)
      if okT and type(tv) == "number" then thr = string.format("%.0f%%", tv * 100) end
    end
    local okB, burn = pcall(construct.getFrictionBurnSpeed)
    burn = (okB and type(burn) == "number") and burn or 0
    txt = string.format("[CLIMB] %.2f km · air %.0f%% · %.0f km/h (burn %.0f) · nose %.0f° path %.0f° · up %.0f m/s · speed %+.1f m/s² · lift %.2f g · drag %.2f g · engines %.2f g (DU says %.2f g) · throttle %s · brake %.0f%%",
      alt / 1000, dens * 100, speed * 3.6, burn * 3.6, nose, path, vUp, dSpd,
      lift / glen, drag / glen, eng:dot(fwd) / glen, duF, thr, (AP.brake or 0) * 100)
  end
  L.t, L.v = tN, vel
  if txt and dens > 0.0001 and ThinAirClimb() then txt = txt.." · burn cap off (under 2% air, climbing)" end
  if txt then system.print(txt) end
  L.n = (L.n or 0) + 1
  if dens <= 0.0001 and L.n > 1 then
    if (L.outN or 0) >= 2 then
      ClimbLog = nil
      Msg(string.format("Climb log: out of the air at %.1f km — log off", alt / 1000))
    else L.outN = (L.outN or 0) + 1 end
  end
end

function FlightTick(id)
  if id == "hud" then
    ApplyGear()
    if StatusMsg ~= "" and now() > StatusUntil then StatusMsg = "" end
    DrawHUD()
  elseif id == "nav" then
    RefreshShipStats()
    SurveyThrust()   -- atmo/space and gravity change as you fly
    TeleDown()       -- learns which telemeters point down (a hit straight below)
    if NavDB then NavKind = BankKind(NavDB) end   -- blank bank → hud once Navigator sends
    ReadFuel()
    UpdateRadar()
    ReadWarp()
    AutoWarpTick()
    AggTick()
    PollNavDB()
    APAdvanceLegs()
    PredictCorrect()
    ClimbLogTick()
  end
end

-- ── Startup ───────────────────────────────────────────────────────
local okR, remote = pcall(unit.isRemoteControlled)
if okR and (remote == true or remote == 1) then player.freeze(true) end

-- Start with no thrust on any axis. Parked: brakes held, gear down,
-- hover off until G. Sat down while already moving: keep hovering so
-- the ship doesn't drop.
do
  local acm = Nav.axisCommandManager
  acm:resetCommand(axisCommandId.longitudinal)
  acm:resetCommand(axisCommandId.lateral)
  acm:resetCommand(axisCommandId.vertical)
  if vec3(construct.getWorldVelocity()):len() < 5 then
    ParkBrake, OnGround = true, true
    SetHover(false)
    local gd = ReadGroundDist()
    if gd >= 0 and gd < 6 then GroundRest = gd end
  else
    SetHover(true)
  end
end
RefreshShipStats()

if NavDB then
  local ok, saved = pcall(NavDB.getStringValue, "sf_target")
  if ok and saved and saved ~= "" then
    local name, pos = saved:match("^(.-)|(::pos%b{})")
    -- Already sitting at it (within 300 m): the trip is over — drop it
    -- instead of putting it back over a new map waypoint (Carl, 1119:
    -- sat down 2 m from the last spot and his new map point was replaced).
    local pp = pos and ParsePos(pos)
    if pp and (pp - vec3(construct.getWorldPosition())):len() < 300 then
      pcall(NavDB.setStringValue, "sf_target", "none")
      system.print("[HELM] Already at "..(name or "the last target").." — old target dropped")
      pos = nil
    end
    if pos and ParsePos(pos) then
      local m = Msg; Msg = function() end   -- restore quietly
      SetTarget(name, pos, ParseHdg(saved:sub(saved:find("::pos", 1, true) or 1)))
      Msg = m
      -- (one line, so a target that comes back can be traced — Carl, 1120)
      system.print("[HELM] Saved target restored: "..AP.name.." (Alt+2 clears)")
    end
  end
end

system.showScreen(true)
if HideDUWidget then pcall(unit.hideWidget) end   -- the HUD's FLIGHT panel replaces it
if HideBuildHelper then pcall(system.showHelper, false) end   -- DU's top "BUILD HELPER" bar (restored in onStop)
unit.setTimer("hud", 0.05)   -- 20 Hz so the attitude HUD moves smoothly
unit.setTimer("nav", 0.5)
system.print("[HELM] Helmsman v"..VERSION.." (build "..BUILD..")"..
  "  |  atlas="..(Atlas and (AtlasName.." ("..#Bodies.." bodies)") or "MISSING")..
  "  |  databank="..(NavDB and ({ hud = "Navigator HUD bank", main = "WRONG BANK",
      mine = "OK (no Navigator yet)", blank = "OK (no Navigator yet)", other = "OK (other data)" })[BankKind(NavDB)] or "none")..
  "  |  antigrav="..(antigrav and "OK" or "none")..
  "  |  ground sensors="..#GroundEngines..
  (#Telemeters > 0 and ("  |  telemeter="..(select(2, TeleDown()) > 0 and "pointing down" or "linked, not seen pointing down")) or "")..
  "  |  radars="..#Radars..(#Switches > 0 and ("  |  switches="..#Switches) or "")..
  "  |  warp="..(WarpDrive and "OK" or "none"))
ScanFuelTanks()
ReadFuel()
system.print(string.format("[HELM] %d fuel tanks read (no links needed) · talents %d/%d/%d/%d/%d%s", #FuelTankList,
  TankH.atmo, TankH.space, TankH.rocket, FuelTankOptimization, ContainerOptimization,
  (TankH.atmo + TankH.space + TankH.rocket + FuelTankOptimization + ContainerOptimization == 0 and #FuelTankList > 0)
    and "  —  set yours with: fueltalents A S R O C" or ""))
UpdateRadar()
ReadWarp()
if WarpDrive then pcall(function() WarpDrive.hideWidget() end) end   -- HUD shows warp instead
if #GroundEngines == 0 then
  system.print("[HELM] Tip: link a vertical booster or hover engine to the seat for fast landings (it reads ground distance)")
end
PrintThrust()
LandingReport()   -- landing speed this ship can stop from / warning if it can barely hold itself up
do local m = Msg; Msg = function() end; SetMode(StartMode); Msg = m end
-- Already sitting at a surface target (landed there last time): don't
-- announce it as "restored" (Carl). At = within 150 m of the down line
-- and below the point where the descent hands over to the landing.
local atTarget = false
if AP.target and AP.surfB and AP.descentR then
  local dn = norm(AP.target - AP.surfB.c)
  local off = vec3(construct.getWorldPosition()) - AP.surfB.c
  atTarget = (off - dn * off:dot(dn)):len() < 150 and off:dot(dn) < AP.descentR + 50
end
Msg((AP.target and not atTarget) and ("Target restored: "..AP.name.."  —  Alt+1 to engage") or "Ready — paste a ::pos{} or type help")
if NavKind == "main" then
  Msg("Linked databank is Navigator's MAIN bank — link its navdatabank (the Arch/Saga one) instead")
end

--[[@
slot=unit
event=onStop
]]
pcall(player.freeze, false)
system.showScreen(false)
if HideBuildHelper then pcall(system.showHelper, true) end
for _, sw in ipairs(Switches or {}) do pcall(sw.deactivate) end   -- seat switches off (never the AGG)

--[[@
slot=unit
event=tick(timerId)
]]
FlightTick(tag or timerId)

--[[@
slot=system
event=onUpdate
]]
Nav:update()

--[[@
slot=system
event=onFlush
]]
FlightFlush()

--[[@
slot=system
event=actionStart(action)
]]
OnActionStart(action)

--[[@
slot=system
event=actionStop(action)
]]
OnActionStop(action)

--[[@
slot=system
event=actionLoop(action)
]]
OnActionLoop(action)

--[[@
slot=system
event=inputText(text)
]]
OnInputText(text)
