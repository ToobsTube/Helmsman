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
VERSION = "0.1.0"

-- ── Server ────────────────────────────────────────────────────────
CustomAtlas = "atlas"  --export: Atlas file for your server. "atlas" = game default. Put custom files in Game/data/lua/autoconf/custom/ (or Game/data/lua/) and enter the file name without .lua

-- ── Autopilot ─────────────────────────────────────────────────────
MaxCruiseSpeed  = 0      --export: AP cruise speed cap in km/h. 0 = use the ship's max speed.
StopDistance    = 1000   --export: How far short of the target (m) the autopilot comes to a full stop.
PlanetClearance = 10000  --export: Extra margin (m) kept outside atmospheres/surfaces when routing around planets.
BrakeSafety     = 0.8    --export: Fraction of max brake force the AP plans with. Lower = starts braking earlier.
AlignRate       = 0.5    --export: Max AP turn rate in rad/s. Lower it if a big ship overshoots when aligning.
AutoEngagePaste = true   --export: Engage the AP immediately when you paste a ::pos{} into Lua chat.
-- ── HUD ───────────────────────────────────────────────────────────
HudTheme  = "cyan" --export: HUD colour theme: cyan, amber, green, red, purple, white, a hex colour like "#FF8800", or custom (uses AccentR/G/B). Live: hudtheme NAME
HudOpacity = 0.9  --export: HUD panel opacity 0.3-1 (live: hud opacity N)
HudScale  = 1     --export: Size of the bottom HUD (1 = compact default, 1.3 = bigger, 0.8 = smaller; live: hud scale N)
HudShift  = 0     --export: Move the HUD bar sideways, % of screen width (negative = left, positive = right; live: hud shift N)
HudBottom = 7     --export: HUD bar distance from the bottom of the screen, % of screen height (live: hud bottom N)
NavInfo   = true  --export: AUTOPILOT panel (target, ETA, brake distance). Off = hide it, e.g. when Navigator's screen already shows those. Live: navinfo on/off, saved
FlightHud = true  --export: Fighter-style attitude HUD in the centre of the screen: pitch ladder, roll, flight path marker, target marker (Alt+6 toggles; saved)
FlightHudScale = 0.75 --export: Size of the fighter-style HUD (1 = large, 0.75 = default)
HideDUWidget = true --export: Hide DU's own seat panel (throttle, cruise/travel) — the HUD shows the same info
AccentR = 0    --export: Custom HUD accent (red 0-255), used when HudTheme = custom
AccentG = 200  --export: Custom HUD accent (green 0-255)
AccentB = 255  --export: Custom HUD accent (blue 0-255)
CollisionWarn = true --export: Radar collision warning: a contact on or near your path shows on the HUD (red = too close to stop with brakes). Never flies the ship you're flying. Needs a linked radar
CollisionStop = true --export: When the AUTOPILOT is flying toward a radar contact on its path, it stops short of it and hands back to you (Alt+1 carries on anyway). Manual flight is never taken over
-- ── Flight feel (DU default values) ───────────────────────────────
AutoLevel        = true  --export: Auto-level roll in atmosphere when you're not rolling
HoverHeight      = 4     --export: Hover height in metres when you press G to lift off (hover engines / vertical boosters)
AutoLand         = true  --export: Surface targets: after stopping above the spot, the AP descends straight down (through the atmosphere, under the burn speed) and lands. Off = it stops above and waits for G
GLandsDirect     = false --export: G while flying lands in one press. Off = G goes to hover first, then G again lands
StartMode        = 1     --export: Mode when you sit down. 1 = Flight, 2 = Maneuver (Alt+4 switches)
LandSpeed        = 150   --export: Fastest landing descent in km/h, used while well above the highest terrain (atlas) or when hovers/boosters can see far enough to stop. Below that without hovers/boosters: TouchdownSpeed.
TouchdownSpeed   = 15    --export: Landing speed in km/h for the last 2 m before touchdown (and the whole landing if no hover/booster is linked). Higher = quicker but harder touchdown
FuelTankHandling     = 0   --export: Fuel tank handling talent level (0-5) of the tanks' owner: bigger tanks. Or type "fueltalents H O C" in Lua chat; saved to the databank.
FuelTankOptimization = 0   --export: Fuel tank optimization talent level (0-5): lighter fuel
ContainerOptimization = 0  --export: Container optimization talent level (0-5): lighter fuel
FuelTierStep         = 1.5 --export: Leave at 1.5 unless the fuel % reads wrong
LandSafety       = 0.3   --export: Share of the ship's spare stopping power a landing plans with. Lower = starts slowing higher, gentler (0.1-1). Tune live with "landsafety N" in Lua chat; saved to the databank.
ManeuverSpeed    = 100   --export: Maneuver mode top speed in km/h (throttle / strafe / up-down are a fraction of this)
pitchSpeedFactor = 0.8   --export
yawSpeedFactor   = 1     --export
rollSpeedFactor  = 1.5   --export
brakeSpeedFactor = 3     --export
brakeFlatFactor  = 1     --export
torqueFactor     = 2     --export
autoRollFactor   = 2     --export

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
                   radar, radar_1, radar_2, warpdrive, warpdrive_1,
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
  end
end
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
  if s.nav_ap_dest or s.nav_arch_dest or s.nav_saga_dest or s.SavedLocations or s.SagaConf or s.SagaRoutes then return "hud" end
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
BrakeK = clamp(DbGetNum("sf_brake_k3") or 1, 0.3, 1)   -- learned, see BrakeMeasure
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
  elseif s == "custom" then
    a = { clamp(AccentR, 0, 255), clamp(AccentG, 0, 255), clamp(AccentB, 0, 255) }
    ThemeName = "custom"
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
FuelTankHandling      = clamp(math.floor(persisted("sf_ft_handling", FuelTankHandling, 0)), 0, 5)
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
function SetHover(on, forceLand)
  local acm = Nav.axisCommandManager
  if on then
    HoverState, HoverOn = "hover", true
    pcall(unit.retractLandingGears)
    acm:setTargetGroundAltitude(HoverHeight)
    acm:activateGroundEngineAltitudeStabilization(HoverHeight)
    ParkBrake = false
  elseif HoverState == "hover" or forceLand then
    HoverState, HoverOn = "landing", true
    pcall(unit.deployLandingGears)
    acm:deactivateGroundEngineAltitudeStabilization()
    -- Phase 1 "stop": nothing may keep pushing the ship while it stops.
    acm:resetCommand(axisCommandId.longitudinal)
    acm:resetCommand(axisCommandId.lateral)
    acm:resetCommand(axisCommandId.vertical)
    LandPhase = "stop"
    landStart, landSettle = now(), nil
  else
    HoverState, HoverOn = "landed", false
    pcall(unit.deployLandingGears)
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

local function landSpeedFor(d, glen, mass)
  -- Spare stopping power = brakes + ground engines − gravity, per tonne
  -- of CURRENT mass (cargo makes it land slower automatically), then
  -- scaled by LandSafety.
  local push = MaxBrakeN * 0.8 + ((Thrust and Thrust.G) or 0)
  local aPlan = mmax((push / mmax(mass, 1) - glen) * LandSafety, 0.3)
  local vMax = mmax(LandSpeed, 5) / 3.6
  local clear = ClearAboveTerrain()
  if #GroundEngines == 0 then
    -- Can't see the ground: fast only while above the highest terrain.
    if clear and clear > 0 then return clamp(msqrt(2 * aPlan * clear), LandRate, vMax) end
    return LandRate
  end
  if d < 0 then
    -- Ground not in sensor range: it's at least the sensor range away,
    -- and at least our height above the highest terrain.
    local gMin = mmax(GroundRangeSeen, clear or 0)
    return clamp(msqrt(2 * aPlan * gMin), LandRate, vMax)
  end
  return clamp(msqrt(2 * aPlan * mmax(d - 2, 0)), LandRate, vMax)
end

LandBrake = 0
function HoverTick(vel)
  LandBrake = 0
  if HoverState ~= "landing" then return end
  local g = vec3(core.getWorldGravity())
  local glen = g:len()
  local function done()
    SetHover(false)
    ParkBrake, OnGround = true, true
    Msg("Landed — engines off, brakes held")
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
    end
    return
  end

  -- Phase 2: DESCEND.
  local vSet = landSpeedFor(GroundDist, glen, construct.getMass())
  LandVSet = vSet
  LandAcc = wv * ((vSet - vDown) * 2.0) - g
  -- Brakes help when falling faster than wanted (they work at any height,
  -- the ground engines only once the ground is in range) and kill any
  -- sideways drift over 1 m/s.
  LandBrake = mmax(clamp((vDown - vSet - 0.5) / 3, 0, 1),
                   hSpeed > 1 and clamp(hSpeed / 5, 0, 1) or 0)
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

-- ── Fuel (every tank, no links, no lookup table) ──────────────────
-- Confirmed against Carl's tanks in game (2026-11-07):
--   litres   = (current mass − empty mass) ÷ (density × mass talents)
--   capacity = base for the size × 1.5 per tier above basic × handling
-- The core gives every tank's current mass and item; the item gives its
-- empty mass, size and tier. Only the owner's fuel talents are unknown —
-- those are parameters ("fueltalents H O C"), saved to the databank.
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
            cap0 = base * (FuelTierStep ^ (tier - 1)),
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
  local cap = t.cap0 * (1 + HANDLING_STEP[t.kind] * FuelTankHandling)
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
  system.print(string.format("[HELM] %d fuel tanks · talents: handling %d, fuel tank opt %d, container opt %d",
    #FuelTankList, FuelTankHandling, FuelTankOptimization, ContainerOptimization))
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
local function rcall(r, f, ...)
  if not r[f] then return nil end
  local ok, v = pcall(r[f], ...)
  if ok then return v end
  return nil
end
function UpdateThreats()
  Threat = nil
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
  for i, id in ipairs(ids) do
    if i > 60 then break end                    -- CPU budget
    local d = rcall(r, "getConstructDistance", id)
    if type(d) == "number" then
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
      if v > 20 and tCA and tCA > 0 and miss and alongCA then
        -- Rp = physical size (its core class + ~15 m for us); R adds a
        -- warning margin that grows with speed (3 s of travel, 30-150 m),
        -- so slow flying round a station doesn't flag every element
        -- (Carl, small ship at 150 km/h: everything within ~280 m warned).
        local Rp = (CORE_R[rcall(r, "getConstructCoreSize", id) or ""] or 64) + 15
        local R = Rp + clamp(v * 3, 30, 150)
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
  -- AP flying into it: stop short (CollisionStop). Only while the AP is
  -- in control — manual flight is never taken over (Carl: players hate
  -- scripts grabbing the ship). Stop point = 50 m before the warning zone.
  if stopBest and AP.active and CollisionStop then
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

-- (Warp is started by the game itself on its warp key, Alt+J; the
-- script only shows the drive's state.)

-- ── Planets (from DU's built-in atlas) ────────────────────────────
-- hard = the shell the AP must never enter: atmosphere top, or for
-- airless moons the highest terrain. Every star system in the atlas is
-- included — custom servers don't always put everything in system 0.
Bodies = {}
if Atlas then
  for _, sys in pairs(Atlas) do
    if type(sys) == "table" then
      for id, b in pairs(sys) do
        local r = type(b) == "table" and tonumber(b.radius) or 0
        if r > 0 and type(b.center) == "table" then
          local n = b.name; if type(n) == "table" then n = n[1] end
          local atm  = tonumber(b.atmosphereRadius) or 0
          local surf = r + (tonumber(b.surfaceMaxAltitude) or r*0.05)
          local gm = tonumber(b.GM) or ((tonumber(b.gravity) or 0) * r * r)
          Bodies[#Bodies+1] = { id=id, name=tostring(n or ("body "..tostring(id))), c=V(b.center), r=r, hard=mmax(atm, surf), top=surf, atm=atm, gm=gm }
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
  if (a - B.c):len() < R or (b - B.c):len() < R then R = B.hard + 500 end
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
  T.F, T.B = along('thrust analog', construct.getOrientationForward())
  T.R, T.L = along('thrust analog', construct.getOrientationRight())
  T.U, T.D = along('thrust analog', construct.getOrientationUp())
  T.G = along('ground', construct.getOrientationUp())
  T.weight = construct.getMass() * vec3(core.getWorldGravity()):len()
  Thrust = T
  return T
end
function PrintThrust()
  local T = SurveyThrust()
  system.print("[HELM] Thrust ("..(T.atmo and "atmo" or "space").."):  Fwd "..fmtN(T.F).." · Back "..fmtN(T.B)..
    " · Left "..fmtN(T.L).." · Right "..fmtN(T.R).." · Up "..fmtN(T.U).." · Down "..fmtN(T.D))
  system.print("[HELM] Hover/VBoost "..fmtN(T.G).." · Weight here "..fmtN(T.weight))
end
-- Warnings that matter for Maneuver mode; returns nil when all is well.
function ManeuverWarning()
  local T = Thrust or SurveyThrust()
  local miss = {}
  for _, k in ipairs({ {"F","fwd"}, {"B","back"}, {"L","left"}, {"R","right"}, {"U","up"}, {"D","down"} }) do
    if T[k[1]] < 1 then miss[#miss+1] = k[2] end
  end
  if T.weight > 1 and T.U < T.weight then
    return "Up thrust "..fmtN(T.U).." < weight "..fmtN(T.weight).." — can't hold altitude"
  end
  if #miss > 0 then return "No thrust: "..table.concat(miss, ", ") end
  return nil
end

function SetMode(m)
  Mode = (m == 2) and 2 or 1
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
    DbSetNum("sf_brake_k3", string.format("%.3f", BrakeK))
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
  pcall(NavDB.setStringValue, "sf_target", AP.target and (AP.name.."|"..AP.posStr) or "")
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

function SetTarget(name, posStr)
  local descentR
  local p, err = ParsePos(posStr)
  if not p then Msg("Bad location: "..err) return false end
  local note
  local B = InsideBody(p)
  if B then
    -- Space-only for now: hold position above the destination instead.
    local up = norm(p - B.c)
    note = "stops in space above "..B.name
    -- The DU map often gives the body's CENTRE when you pick a planet or
    -- moon. "Above the centre" has no direction, so use the side facing
    -- the ship (closest, and no trip round the body).
    if (p - B.c):len() < B.r * 0.05 or up:len() < EPS then
      local sp = vec3(construct.getWorldPosition())
      up = norm(sp - B.c)
      if up:len() < EPS then up = vec3(0, 0, 1) end
      note = "centre of "..B.name.." picked — stops above the side facing you"
    end
    -- Fast descent ends 500 m above the spot when its altitude can be
    -- trusted (saved/pasted from the ground: above sea level). Altitude 0
    -- or less is typical of map picks, so then only down to the atlas
    -- highest terrain + 300 m; the landing's sensors do the rest.
    local spotR = (p - B.c):len()
    if note:find("centre of", 1, true) then
      descentR = nil                                  -- no real spot: no auto-descent
    elseif spotR > B.r + 1 then
      descentR = spotR + 500
    else
      descentR = B.top + 300
    end
    p = B.c + up * (B.hard + PlanetClearance)
  end
  local wasActive = AP.active
  if wasActive then APDisengage(nil) end
  name = (name and name:match("^%s*(.-)%s*$")) or ""
  AP.target, AP.posStr, AP.note = p, posStr:match("::pos%b{}"), note
  AP.surface, AP.surfB, AP.descentR, AP.descent = B ~= nil, B, descentR, false
  AP.name = name ~= "" and name or "Pasted location"
  AP.legs, AP.leg = nil, 1
  AP.lastObsId, AP.obs = nil, nil   -- new target: an old "carry on anyway" doesn't carry over
  system.setWaypoint(AP.posStr)
  SaveTarget()
  Msg("Target: "..AP.name..(note and ("  ("..note..")") or ""))
  -- Never leave the ship coasting: a new target mid-flight re-plans and
  -- keeps flying (if that fails, brakes go on).
  if wasActive and not APEngage() then ParkBrake = true end
  return true
end

function ClearTarget()
  if AP.active then APDisengage(nil) end
  AP.warpResume = nil
  AP.target, AP.name, AP.posStr, AP.note, AP.legs = nil, "", "", nil, nil
  system.setWaypoint("")
  SaveTarget()
  Msg("Target cleared")
end

-- ── Autopilot engage / disengage ──────────────────────────────────
function APEngage()
  if not AP.target then Msg("No target — paste a ::pos{...} into Lua chat") return false end
  AP.descent = false
  -- Already above the surface spot (e.g. braked during the descent, Alt+1
  -- again): carry on down instead of refusing for being in atmosphere.
  if CanDescend() then StartDescent() return true end
  if (unit.getAtmosphereDensity() or 0) > 0.0001 then
    Msg("Autopilot is space-only for now — leave the atmosphere first") return false
  end
  local pos = vec3(construct.getWorldPosition())
  local B = InsideBody(pos)
  if B then Msg("Too close to "..B.name.." — climb clear of it first") return false end
  RefreshShipStats()
  if MaxBrakeN <= 0 then Msg("No brakes detected — the AP needs brakes to stop") return false end
  if (AP.target - pos):len() <= StopDist() + 50 then Msg("Already at "..AP.name) return false end
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
  AP.descent = false
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

-- ── Descent: hold point above a surface spot → straight down → landing ──
-- Carl: players like to be in the atmosphere before the landing starts
-- (it's quicker). After the stop above the spot the AP falls straight down
-- the down line: gravity does the accelerating, brakes hold the speed to
-- the lower of (a) what it can still stop from before AP.descentR,
-- (b) 85% of the ship's atmospheric burn speed (only on bodies with an
-- atmosphere), (c) the `speed` cap. No engine thrust, nose kept level.
-- At AP.descentR, or as soon as the hovers/boosters see the ground, the
-- normal landing (the one G starts) takes over.
function BurnCap()
  local ok, v = pcall(construct.getFrictionBurnSpeed)
  if ok and type(v) == "number" and v > 10 then return v * 0.85 end
  return 250                                   -- ~900 km/h if DU won't say
end

function CanDescend()
  if not (AutoLand and AP.target and AP.surfB and AP.descentR) then return false end
  local pos = vec3(construct.getWorldPosition())
  local B = AP.surfB
  local up = norm(AP.target - B.c)
  local rel = pos - B.c
  local side = (rel - up * rel:dot(up)):len()           -- off the down line
  local r = rel:len()
  -- On the down line (within 200 m), above where the descent ends, and
  -- no higher than the hold point (+2 km slack).
  return rel:dot(up) > 0 and side < 200 and r > AP.descentR + 20
     and r < (AP.target - B.c):len() + 2000
end

function StartDescent()
  AP.active, AP.descent, AP.phase = true, true, "DESCENT"
  AP.accel, AP.brake, AP.angVel = 0, 0, vec3()
  ParkBrake = false
  Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
  local B = AP.surfB
  local h = (vec3(construct.getWorldPosition()) - B.c):len() - AP.descentR
  Msg("Descending to "..AP.name.." ("..FormatDist(h).." down) — brake to stop")
end

function APDescentStep(pos, vel, fwd, up, mass)
  local B = AP.surfB
  local g = vec3(core.getWorldGravity())
  local glen = g:len()
  local rel = pos - B.c
  local dn = norm(B.c - pos)                     -- straight down
  local goal = rel:len() - AP.descentR           -- metres of fast descent left
  local vDown = vel:dot(dn)
  local hSpeed = (vel - dn * vDown):len()
  -- Braking while falling: brakes minus gravity.
  local ab = mmax(BrakeAccel(mass) - glen, 0.3)
  local vmax = BrakeVmax(mmax(goal, 0), ab)
  if (B.atm or 0) > 0 then vmax = mmin(vmax, BurnCap()) end
  vmax = mmin(vmax, CruiseCap())
  local brake = 0
  if vDown > vmax + 1 then brake = 1 end
  -- Sideways drift: brakes (they push against all of our motion).
  -- All of it, not just above 2 m/s: 2 m/s for a 90 s fall is ~180 m off
  -- the line (sim). Brakes also slow the fall a little, which is fine.
  if hSpeed > 0.2 then brake = mmax(brake, clamp(hSpeed / 2, 0.2, 1)) end
  AP.remaining, AP.vAlong, AP.vDes = goal, vDown, vmax
  AP.brake, AP.accel, AP.phase = brake, 0, "DESCENT"
  -- Nose level (pitch + roll to the horizon), heading kept.
  local wv = glen > 0.01 and g / glen or dn
  local rollAng  = math.asin(clamp(vec3(construct.getWorldOrientationRight()):dot(wv), -1, 1))
  local pitchAng = math.asin(clamp(fwd:dot(wv), -1, 1))
  local right = vec3(construct.getWorldOrientationRight())
  AP.angVel = right * clamp(pitchAng * 1.5, -0.5, 0.5) - fwd * clamp(rollAng * 1.5, -0.5, 0.5)
  AP.alignErr = math.deg(mabs(pitchAng))
  -- Hand over to the landing: fast part done (and slowed), or the ground
  -- engines can already see the ground (spot higher than we thought).
  local seesGround = #GroundEngines > 0 and ReadGroundDist() >= 0
  if (goal <= 5 and vDown < 5) or seesGround then
    local name = AP.name
    APDisengage(nil)
    SetHover(false, true)
    Msg("Descent done — landing on "..name)
  end
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
function APStep(pos, vel, fwd, up, mass)
  if AP.descent then return APDescentStep(pos, vel, fwd, up, mass) end
  local legs = AP.legs
  -- Final leg: aim at the target shifted by the look-ahead correction
  -- (PredictCorrect), so gravity during braking carries us onto the point.
  local aimPt = legs[AP.leg]
  if AP.leg == #legs and AP.aimOff then aimPt = aimPt + AP.aimOff end
  local toAim, aimDist = norm(aimPt - pos)
  -- Brake for the STRAIGHT-LINE distance to the target, never the longer
  -- dog-leg path: legs get skipped as soon as the direct line clears, and
  -- planning for the long way round then arrives too fast (Carl saw a
  -- ~1 km overshoot after flying round a planet). Straight line ≤ path,
  -- so the ship can always stop, whichever way it ends up going.
  local remaining = (AP.target - pos):len() - StopDist()
  local speed = vel:len()
  BrakeMeasure(vel, speed, mass)
  -- Closest the ship got to the target (for the stop report).
  AP.minRemaining = mmin(AP.minRemaining or remaining, remaining)
  local vAlong = vel:dot(toAim)
  local vCap = CruiseCap()
  -- Gravity pushing along our direction of travel eats into braking.
  local gAlong = mmax(0, vec3(core.getWorldGravity()):dot(toAim))
  local ab = BrakeAccel(mass)
  ab = mmax(ab - gAlong, ab * 0.2)
  local vBrake = BrakeVmax(remaining, ab)
  local vDes = mmin(vCap, vBrake)
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
      APDisengage(string.format("stopped — %s on the path, %s ahead. Fly round it, or Alt+1 to carry on anyway",
        o.name, FormatDist(mmax(o.dist - (pos - o.start):dot(o.dir), 0))))
      return
    end
  elseif remaining <= ArriveTol() and AP.leg == #legs then
    brake, AP.phase = 1, "STOPPING"
    if speed < 2 then
      APArrive()
      if CanDescend() then StartDescent() end
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
    if speed > 30 and vAlong < speed * 0.5 then brake, AP.phase = 1, "KILL DRIFT" end
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
    if speed > 30 and need then
      brake, AP.phase, AP.kdOn = 1, "KILL DRIFT", true
    else
      AP.kdOn = false
    end
  end
  AP.alignErr = math.deg(math.acos(clamp(fwd:dot(aim), -1, 1)))
  AP.brake, AP.accel = brake, accel
  -- While braking in space the nose doesn't matter (brakes push against
  -- our motion whichever way we face), so hold attitude instead of
  -- chasing the line (Carl: pointless turning while braking). In
  -- atmosphere a later version may want to steer here.
  if brake == 1 and AP.phase ~= "KILL DRIFT" then AP.angVel = vec3()
  else AP.angVel = AlignAV(fwd, aim, up) end

  -- Approach line for the stop report (direction when braking began).
  -- Only the final approach counts (not corner braking).
  if brake == 1 and AP.phase ~= "KILL DRIFT" and AP.leg == #legs and not AP.approachDir then
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
  if AP.brake == 1 then return end            -- can't steer while braking
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
  local ok, raw = pcall(NavDB.getStringValue, "nav_ap_dest")
  if not ok or not raw or raw == "" then return end
  NavDB.setStringValue("nav_ap_dest", "")
  local name, pos = raw:match("^(.-)|(::pos%b{})")
  if not pos then pos = raw:match("::pos%b{}"); name = "Navigator" end
  if not pos then return end
  local _, af = pcall(NavDB.getStringValue, "autofly")
  if SetTarget(name, pos) then
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
  if not man or ParkHold then ManHoldPos = nil end   -- after AP/park: hold the height you're at then
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
    if manIdle and not HoverOn then manAcc = vec3(); ManHoldPos = nil
    elseif HoverOn and upInput == 0 and Thrust and Thrust.G >= Thrust.weight
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
  local fB = clamp(brakeInput, 0, 1)
  if ParkBrake then fB = 1 end
  if AP.active then fB = mmax(fB, AP.brake) end
  fB = mmax(fB, LandBrake)
  if park then fB = mmax(fB, parkBrake) end
  if man and manIdle and speed > 0.5 then fB = mmax(fB, clamp(speed / 10, 0, 1)) end
  Nav:setEngineForceCommand('brake', -fB * (brakeSpeedFactor * vel + brakeFlatFactor * velDir))

  if AP.active then
    Nav:setEngineForceCommand('thrust analog longitudinal', fwd * AP.accel, keep)
    Nav:setEngineForceCommand('thrust analog lateral', vec3(), keep)
    Nav:setEngineForceCommand('thrust analog vertical', vec3(), keep)
  elseif park or man then
    -- Every thruster, any direction, solved together (not collinear).
    Nav:setEngineForceCommand('thrust analog', park and parkAcc or manAcc, dontKeep, '', '', '', tol)
    -- Hovers / vertical boosters still follow G exactly as in Flight mode.
    local acm = Nav.axisCommandManager
    local gAcc = acm:composeAxisAccelerationFromThrottle('thrust analog vertical', axisCommandId.vertical)
    Nav:setEngineForceCommand('ground', GroundCmd(gAcc), keep, '', '', '', tol)
  else
    -- Manual flight: DU's standard throttle / cruise-control handling
    local acm = Nav.axisCommandManager
    local autoTags, autoAcc, autoBrake = '', vec3(), false

    local lonTags = 'thrust analog longitudinal'
    local lonType = acm:getAxisCommandType(axisCommandId.longitudinal)
    if lonType == axisCommandType.byThrottle then
      Nav:setEngineForceCommand(lonTags, acm:composeAxisAccelerationFromThrottle(lonTags, axisCommandId.longitudinal), keep)
    elseif lonType == axisCommandType.byTargetSpeed then
      autoTags = autoTags..' , '..lonTags
      autoAcc = autoAcc + acm:composeAxisAccelerationFromTargetSpeed(axisCommandId.longitudinal)
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
  ParkBrake = false
  if ParkHold then ParkRelease("you're moving") end
end

-- W/S: pitch in Flight mode, forward/back movement in Maneuver mode.
-- Remember what each press did, so releasing undoes the right thing even
-- if you switch mode while holding the key.
fwdKey = 0
local keyAsMove = {}
function OnActionStart(a)
  local acm = Nav.axisCommandManager
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
    acm:updateCommandFromActionStart(axisCommandId.vertical, -1.0); releasePark()
  elseif a == "groundaltitudeup"   then acm:updateTargetGroundAltitudeFromActionStart(1.0)
  elseif a == "groundaltitudedown" then acm:updateTargetGroundAltitudeFromActionStart(-1.0)
  elseif a == "lalt" then
    AltHeld = true
    if brakeInput > 0 then ToggleBrakeLock() end   -- Ctrl held, then Alt
  elseif a == "brake" then
    brakeInput = 1   -- on/off, not a counter: a missed key-up can't stack
    if AP.active then APDisengage("brake pressed") end
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
  elseif a == "booster" then Nav:toggleBoosters()
  elseif a == "antigravity" then
    if antigrav then if antigrav.isActive() then antigrav.deactivate() else antigrav.activate() end end
  elseif a == "gear" then
    -- hover → landing; landed or landing → hover (G mid-landing aborts it)
    if ParkHold then ParkRelease(nil) end
    -- GLandsDirect: flying (not sitting on anything) → land in one press.
    if GLandsDirect and HoverState == "landed" and not OnGround then
      SetHover(false, true)
    else
      SetHover(HoverState ~= "hover")
    end
    Msg(HoverState == "hover" and string.format("Hover on — %.0f m", HoverHeight)
        or "Landing — setting down, engines cut when settled")
  elseif a == "light" then
    if unit.isAnyHeadlightSwitchedOn() then unit.switchOffHeadlights() else unit.switchOnHeadlights() end
  elseif a == "option1" then
    if AP.active then APDisengage("Alt+1") else APEngage() end
  elseif a == "option2" then ClearTarget()
  elseif a == "option3" then
    HudOn = not HudOn
    if not HudOn then system.setScreen("") end
  elseif a == "option4" then SetMode(Mode == 2 and 1 or 2)
  elseif a == "option5" then
    if ParkHold then ParkRelease(nil) else ParkEngage() end
  elseif a == "option6" then ToggleFlightHud()
  end
end

function OnActionStop(a)
  local acm = Nav.axisCommandManager
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
  if     a == "speedup"   then acm:updateCommandFromActionLoop(axisCommandId.longitudinal, 1.0)
  elseif a == "speeddown" then acm:updateCommandFromActionLoop(axisCommandId.longitudinal, -1.0)
  elseif a == "groundaltitudeup"   then acm:updateTargetGroundAltitudeFromActionLoop(1.0)
  elseif a == "groundaltitudedown" then acm:updateTargetGroundAltitudeFromActionLoop(-1.0)
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
  system.print("hud scale|bottom|shift|opacity N   size / position / opacity, saved")
  system.print("hudtheme NAME         cyan amber green red purple white #RRGGBB, saved")
  system.print("mode / mode flight / mode maneuver       (Alt+4)")
  system.print("thrust                engine push in all 6 directions")
  system.print("landsafety N          landing margin 0.1-1 (lower = gentler), saved")
  system.print("park                  stop and hold position (Alt+5)")
  system.print("fhud                  fighter-style attitude HUD on/off (Alt+6)")
  system.print("navinfo [on|off]      AUTOPILOT panel (target, ETA, brake distance)")
  system.print("farside               test: target the far side of the nearest planet")
  system.print("ahead [N]             test: target empty space N su off the nose (default 1)")
  system.print("autolevel on/off      auto-levelling (LEVEL tag shows when active)")
  system.print("fuel                  every tank: litres / capacity / %")
  system.print("radar                 radar contacts: size, distance, what DU tells us")
  system.print("fueltalents H O C     your fuel talents 0-5: handling, fuel opt, container opt")
  system.print("engines               list every engine type and its tags")
  system.print("speed N               AP cruise cap km/h (0 = max)")
  system.print("stopdist N            stop N metres short of target")
  system.print("brakes [reset]        brake force DU reports vs what the AP measured")
  system.print("target                print current target")
  system.print("links                 list what is linked in each seat slot")
end

-- Every Lua chat line reaches every running script (seat AND Navigator
-- PB). Lines that start with another script's command word are not for
-- us — above all Navigator's "add NAME ::pos{}" / "addstop ROUTE ::pos{}",
-- which would otherwise look like "fly there".
local FOREIGN = { add=true, addstop=true, delstop=true, del=true, delete=true, delroute=true,
  newroute=true, rename=true, setcoords=true, mark=true, nav=true, next=true, prev=true,
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
    if SetTarget(name, pos or t) and AutoEngagePaste and not AP.active then APEngage() end
  elseif lo == "help" or lo == "?" then PrintHelp()
  elseif lo == "ap" then if AP.active then APDisengage("chat") else APEngage() end
  elseif lo == "ap on" or lo == "go" then APEngage()
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
      Msg(string.format("HUD  scale %.2f · bottom %s · shift %s · opacity %.2f  —  hud scale|bottom|shift|opacity N",
        HudScale, tostring(HudBottom), tostring(HudShift), HudOpacity))
    end
  elseif lo:match("^hudtheme") then
    local arg = t:match("^%S+%s+(.+)$")
    if arg and ApplyTheme(arg) then
      if NavDB then pcall(NavDB.setStringValue, "sf_theme", ThemeName) end
      Msg("HUD theme: "..ThemeName..(NavDB and "  (saved)" or ""))
    else
      Msg("HUD theme: "..ThemeName.."  —  hudtheme cyan | amber | green | red | purple | white | #RRGGBB | custom")
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
    local h, o, c = lo:match("^fueltalents%s+(%d)%s+(%d)%s+(%d)")
    if h then
      FuelTankHandling, FuelTankOptimization, ContainerOptimization =
        clamp(tonumber(h), 0, 5), clamp(tonumber(o), 0, 5), clamp(tonumber(c), 0, 5)
      DbSetNum("sf_ft_handling", FuelTankHandling)
      DbSetNum("sf_ft_fuelopt", FuelTankOptimization)
      DbSetNum("sf_ft_contopt", ContainerOptimization)
      ReadFuel()
    end
    Msg(string.format("Fuel talents: handling %d · fuel tank opt %d · container opt %d%s",
      FuelTankHandling, FuelTankOptimization, ContainerOptimization,
      h and (NavDB and "  (saved)" or "  (no databank — resets on restart)") or "  —  fueltalents H O C to change"))
  elseif lo == "radar" then
    PrintRadar()
  elseif lo == "thrust" then
    PrintThrust()
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
      DbSetNum("sf_brake_k3", 1)
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
  BRAKING="#ff9a3c", STOPPING="#ff9a3c", OBSTACLE="#ff3b3b", DESCENT="ACC", ["KILL DRIFT"]="#ffc24b", CORRECT="#ffc24b", ARRIVED="#5be37a" }

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
  if g:len() > 0.05 then upW = g / -g:len()
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

function DrawHUD()
  if not HudOn then return end
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
      '.cols{display:flex;gap:8px;align-items:stretch}'..
      '.p{width:15vw;min-width:230px;background:rgba('..bgc..','..op..');border:1px solid rgba('..acc..',.32);'..
      'border-top:2px solid rgb('..acc..');border-radius:4px;padding:6px 10px}'..
      '.p.ap{width:18vw;min-width:270px}'..
      '.hd{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:700;'..
      'letter-spacing:2px;color:rgb('..acc..');margin-bottom:3px}'..
      '.ph{padding:1px 6px;border-radius:3px;color:#05090e;letter-spacing:1px}'..
      '.big{font-size:18px;font-weight:700;line-height:1.1}.big small{font-size:11px;font-weight:400;color:#9aa8b5}'..
      '.tg{font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'..
      '.nt{font-size:10px;color:#9aa8b5}'..
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
  -- Line 1: key hints only.
  add('<div class="strip"><span class="keys">Alt+ 1 AP · 2 clear · 3 hide · 4 mode · 5 park · 6 HUD · Ctrl+Alt brake lock · G hover/land</span></div>')
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
  if acm:getAxisCommandType(axisCommandId.longitudinal) == axisCommandType.byTargetSpeed then
    row("CRUISE", string.format("%.0f km/h", acm:getTargetSpeed(axisCommandId.longitudinal)))
  else
    local okT, t = pcall(unit.getThrottle)
    row("THROTTLE", string.format("%.0f%%", (okT and tonumber(t)) or 0))
  end
  if showNav then row("BRAKE DIST", FormatDist(BrakeDist(speed, BrakeAccel(mass) / BrakeSafety))) end
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
    local remaining = AP.active and AP.remaining or (dist - StopDist())
    local vAlong = AP.active and AP.vAlong or 0
    local eta = CalcETA(remaining, vAlong, CruiseCap(), MaxThrustN / mmax(mass, 1), BrakeAccel(mass))
    row("DISTANCE · ETA", FormatDist(dist).." · "..(AP.active and FormatTime(eta) or ("~"..FormatTime(eta))))
    if AP.active then
      local thr = MaxThrustN > 0 and clamp(AP.accel * mass / MaxThrustN, 0, 1) or 0
      row("ALIGN · THRUST", string.format("%.1f° · %d%%", AP.alignErr, math.floor(thr*100 + 0.5)))
      if AP.predMiss then
        row("PREDICTED MISS · AIM SHIFT", FormatDist(AP.predMiss).." · "..FormatDist((AP.aimOff or vec3()):len()))
      end
      if #AP.legs > 1 then row("LEG", AP.leg.." of "..#AP.legs) end
      if AP.total > 0 then
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
  add('</div>')

  add('</div>')   -- /cols

  add('</div></div>')   -- /in /hb
  if FlightHud then add(FlightHudSvg(acc)) end
  system.setScreen(table.concat(h))
end


function FlightTick(id)
  if id == "hud" then
    if StatusMsg ~= "" and now() > StatusUntil then StatusMsg = "" end
    DrawHUD()
  elseif id == "nav" then
    RefreshShipStats()
    SurveyThrust()   -- atmo/space and gravity change as you fly
    if NavDB then NavKind = BankKind(NavDB) end   -- blank bank → hud once Navigator sends
    ReadFuel()
    UpdateRadar()
    ReadWarp()
    PollNavDB()
    APAdvanceLegs()
    PredictCorrect()
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
  else
    SetHover(true)
  end
end
RefreshShipStats()

if NavDB then
  local ok, saved = pcall(NavDB.getStringValue, "sf_target")
  if ok and saved and saved ~= "" then
    local name, pos = saved:match("^(.-)|(::pos%b{})")
    if pos and ParsePos(pos) then
      local m = Msg; Msg = function() end   -- restore quietly
      SetTarget(name, pos)
      Msg = m
    end
  end
end

system.showScreen(true)
if HideDUWidget then pcall(unit.hideWidget) end   -- the HUD's FLIGHT panel replaces it
unit.setTimer("hud", 0.05)   -- 20 Hz so the attitude HUD moves smoothly
unit.setTimer("nav", 0.5)
system.print("[HELM] Helmsman v"..VERSION..
  "  |  atlas="..(Atlas and (AtlasName.." ("..#Bodies.." bodies)") or "MISSING")..
  "  |  databank="..(NavDB and ({ hud = "Navigator HUD bank", main = "WRONG BANK",
      mine = "OK (no Navigator yet)", blank = "OK (no Navigator yet)", other = "OK (other data)" })[BankKind(NavDB)] or "none")..
  "  |  antigrav="..(antigrav and "OK" or "none")..
  "  |  ground sensors="..#GroundEngines..
  "  |  radars="..#Radars..
  "  |  warp="..(WarpDrive and "OK" or "none"))
ScanFuelTanks()
ReadFuel()
system.print(string.format("[HELM] %d fuel tanks read (no links needed) · talents %d/%d/%d%s", #FuelTankList,
  FuelTankHandling, FuelTankOptimization, ContainerOptimization,
  (FuelTankHandling + FuelTankOptimization + ContainerOptimization == 0 and #FuelTankList > 0)
    and "  —  set yours with: fueltalents H O C" or ""))
UpdateRadar()
ReadWarp()
if WarpDrive then pcall(function() WarpDrive.hideWidget() end) end   -- HUD shows warp instead
if #GroundEngines == 0 then
  system.print("[HELM] Tip: link a vertical booster or hover engine to the seat for fast landings (it reads ground distance)")
end
PrintThrust()
do local m = Msg; Msg = function() end; SetMode(StartMode); Msg = m end
Msg(AP.target and ("Target restored: "..AP.name.."  —  Alt+1 to engage") or "Ready — paste a ::pos{} or type help")
if NavKind == "main" then
  Msg("Linked databank is Navigator's MAIN bank — link its navdatabank (the Arch/Saga one) instead")
end

--[[@
slot=unit
event=onStop
]]
pcall(player.freeze, false)
system.showScreen(false)

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
