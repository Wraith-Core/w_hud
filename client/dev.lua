-- ============================================================
-- w_hud · client/dev.lua
-- Dev mode -- values by hand, to preview how the HUD behaves
--
-- ★ Why a display layer instead of really editing the player?
--
--   To preview health at 10% you would have to actually drop it -- which kills the
--   player before they ever see the red state. And hunger and thirst live in the
--   database, so every edit is a round trip to the server and back, then the decay
--   loop writes over it seconds later. Real previewing is fought from every side.
--
--   This layer intercepts the payload just before it goes to the UI and writes over
--   whatever it likes: no death, no server round trip, no loop erasing what you set.
--   The game underneath has not changed one bit -- switch the mode off and everything
--   is back on the very next frame.
-- ============================================================

WHudDev = { on = false, over = {} }

--- The keys that may be overridden -- and their short names.
--- ★ The short name is not a luxury: these are commands you type dozens of times a session.
local ALIAS = {
    health = 'health', hp = 'health', hea = 'health',
    stamina = 'stamina', stam = 'stamina', st = 'stamina',
    hunger = 'hunger', food = 'hunger', hu = 'hunger',
    thirst = 'thirst', water = 'thirst', th = 'thirst',
    horsehealth = 'horsehealth', hh = 'horsehealth', horse = 'horsehealth',
    horsestamina = 'horsestamina', hs = 'horsestamina',
    voice = 'voiceLevel', v = 'voiceLevel',
}

--- What 'all' covers -- the six needs, without voice (voice is a rank, not a need).
local ALL = { 'health', 'stamina', 'hunger', 'thirst', 'horsehealth', 'horsestamina' }

local function resolve(name)
    return ALIAS[tostring(name or ''):lower()]
end

local function clampv(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

--- The upper bound differs: needs are 0..100 and the voice level is 1..number of levels.
local function limitOf(key)
    if key ~= 'voiceLevel' then return 0, 100 end
    return 1, math.max(1, #(((Config.Voice or {}).Levels) or {}))
end

----------------------------------------------------------------
-- The interception -- called from client/thread.lua before every send
----------------------------------------------------------------

--- ⚠️ Always returns the payload itself, even with the mode off: the call site writes
--- SendNUIMessage(WHudDev.apply({...})), so returning nil would send an empty message
--- and blank the HUD for no visible reason.
---@param payload table
---@return table
function WHudDev.apply(payload)
    if not WHudDev.on then return payload end

    for key, value in pairs(WHudDev.over) do
        payload[key] = value
    end

    -- ★ The horse cores are only drawn with onHorse. So whoever sets horse health
    --   wants to see it, even standing on their own two feet -- otherwise it looks broken.
    if WHudDev.over.horsehealth or WHudDev.over.horsestamina then
        payload.onHorse = true
    end

    return payload
end

----------------------------------------------------------------
-- Display
----------------------------------------------------------------

--- A text bar showing the two stages as the eye sees them: the ring, then the icon.
--- ★ The number alone is not enough -- the question is always 'where are we relative
---   to the halfway point?', and this answers it by shape rather than by arithmetic.
local function bar(v)
    v = clampv(tonumber(v) or 0, 0, 100)

    local ring = v >= 50 and (v - 50) * 2 or 0
    local icon = v >= 50 and 100 or v * 2

    local function cells(pct)
        local filled = math.floor(pct / 10 + 0.5)
        return ('#'):rep(filled) .. ('.'):rep(10 - filled)
    end

    return ('%6.1f  ring[%s] icon[%s]'):format(v, cells(ring), cells(icon))
end

local function dump()
    print('^3== w_hud . dev mode ==================================^0')
    print(('  state: %s^0'):format(WHudDev.on and '^2ON' or '^1OFF'))

    for i = 1, #ALL do
        local key = ALL[i]
        local v   = WHudDev.over[key]

        print(('  %-14s %s'):format(key, v and bar(v) or '^8-- follows the game^0'))
    end

    local vl = WHudDev.over.voiceLevel
    print(('  %-14s %s'):format('voiceLevel', vl and tostring(vl) or '^8-- follows the game^0'))

    local thr = Config.Thresholds or {}
    print(('^7  thresholds: warn <= %s · danger <= %s^0'):format(thr.warnLow or 40, thr.dangerLow or 20))
end

----------------------------------------------------------------
-- Commands
----------------------------------------------------------------

--- ★ The snapshot starts at 100 rather than the live value on purpose: the first thing
---   you want when previewing is a known starting point, then you walk it down with
---   /hudadd or /hudsweep.
local function snapshot()
    for i = 1, #ALL do
        if WHudDev.over[ALL[i]] == nil then
            WHudDev.over[ALL[i]] = 100
        end
    end
end

RegisterCommand('hudev', function(_, args)
    local arg = tostring(args[1] or ''):lower()

    if arg == 'on' then
        WHudDev.on = true; snapshot()
    elseif arg == 'off' then
        WHudDev.on = false
    elseif arg == '' then
        WHudDev.on = not WHudDev.on
        if WHudDev.on then snapshot() end
    else
        print('^3[w_hud]^7 usage: /hudev [on|off]^0')
        return
    end

    dump()

    if WHudDev.on then
        print('^7  /hudset <need|all> <0-100>   set directly')
        print('^7  /hudadd <need|all> <+/-value> raise and lower')
        print('^7  /hudsweep [seconds]           walk 100 down to 0 to watch both stages')
        print('^7  names: hp · stam · food · water · hh · hs · voice · all^0')
    end
end, false)

--- Collects the intended key names from a single argument.
---@param name string
---@return table|nil
local function targets(name)
    if tostring(name or ''):lower() == 'all' then return ALL end

    local key = resolve(name)
    if not key then return nil end

    return { key }
end

local function badName(name)
    print(('^1[w_hud]^7 unknown name \'%s\'. names: hp · stam · food · water · hh · hs · voice · all^0')
        :format(tostring(name)))
end

--- /hudset and /hudadd -- same logic; the difference is one line.
---@param mode string 'set' or 'add'
local function change(mode)
    return function(_, args)
        if not WHudDev.on then
            print('^3[w_hud]^7 dev mode is off -- turn it on with /hudev^0')
            return
        end

        local keys = targets(args[1])

        if not keys then badName(args[1]); return end

        local num = tonumber(args[2])

        if not num then
            print(('^1[w_hud]^7 usage: /hud%s <need|all> <%s>^0')
                :format(mode, mode == 'set' and '0-100' or '+/-value'))
            return
        end

        for i = 1, #keys do
            local key = keys[i]
            local lo, hi = limitOf(key)
            local base = WHudDev.over[key] or hi

            WHudDev.over[key] = clampv(mode == 'set' and num or (base + num), lo, hi)
        end

        dump()
    end
end

RegisterCommand('hudset', change('set'), false)
RegisterCommand('hudadd', change('add'), false)

-- ════════════════════════════════════════════════════════════════════════════
-- /hudsweep -- a continuous walk from 100 down to 0
--
-- ★ The most useful command in this file. Jumping from 60 to 40 shows you two states;
--   the transition between them -- the moment the ring empties and the icon starts to
--   drain -- is only visible continuously. And that is exactly where the cores are
--   measured for consistency against one another.
-- ════════════════════════════════════════════════════════════════════════════
local sweeping = false

RegisterCommand('hudsweep', function(_, args)
    if not WHudDev.on then
        WHudDev.on = true; snapshot()
        print('^3[w_hud]^7 dev mode switched on automatically.^0')
    end

    if sweeping then
        sweeping = false
        print('^3[w_hud]^7 sweep stopped.^0')
        return
    end

    local seconds = math.max(1.0, tonumber(args[1]) or 12.0)
    local keys    = targets(args[2] or 'all') or ALL

    sweeping = true
    print(('^2[w_hud]^7 walking 100 down to 0 over %.1fs -- /hudsweep to stop.^0'):format(seconds))

    CreateThread(function()
        local step  = 50 -- ms per step
        local ticks = math.floor(seconds * 1000 / step)

        for i = 0, ticks do
            if not sweeping then break end

            local value = 100 - (i / ticks) * 100

            for k = 1, #keys do
                if keys[k] ~= 'voiceLevel' then WHudDev.over[keys[k]] = value end
            end

            Wait(step)
        end

        if sweeping then
            sweeping = false
            print('^2[w_hud]^7 sweep finished -- /hudset all 100 to restore.^0')
        end
    end)
end, false)

-- And clean up when the resource stops, or the thread keeps writing into a dead table.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then sweeping = false end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /hudgold -- preview the gilding without eating a tonic
--
-- ★ Only two items in the whole catalogue gild anything, and one of them is moonshine.
--   So reviewing how the gold reads meant hunting down a specific item every time --
--   and the gilding is exactly the kind of thing you want to look at twice while
--   tuning the colour.
--
--     /hudgold                 both cores fully gilded
--     /hudgold health ring     the ring alone -- a half gilding
--     /hudgold stamina both    ring and icon -- a full one
--     /hudgold off             clear it
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('hudgold', function(_, args)
    if type(WHudGold) ~= 'table' then
        return print('^1[w_hud]^7 WHudGold is missing -- client/consumables.lua did not load^0')
    end

    local which = tostring(args[1] or 'all'):lower()
    local how   = tostring(args[2] or 'both'):lower()

    if which == 'off' then
        WHudGold.health = { ring = 0, icon = 0 }
        WHudGold.stamina = { ring = 0, icon = 0 }
        return print('^2[w_hud]^7 gilding cleared.^0')
    end

    -- ⚠️ A long window on purpose: the default duration is 30s, and reviewing a colour
    --    outlasts that. This is preview, not simulation.
    local until_ = GetGameTimer() + 600000

    local function set(slot)
        slot.ring = until_
        slot.icon = (how == 'both') and until_ or 0
    end

    if which == 'health' or which == 'hp' or which == 'all' then set(WHudGold.health) end
    if which == 'stamina' or which == 'stam' or which == 'all' then set(WHudGold.stamina) end

    print(('^2[w_hud]^7 gilded %s (%s) for 10 minutes -- /hudgold off to clear.^0')
        :format(which, how == 'both' and 'ring + icon' or 'ring only'))
end, false)
