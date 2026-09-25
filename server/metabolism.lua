-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- the needs core (metabolism), framework-agnostic via w_lib
--
--   Every need is on a 0-100 scale:
--     hunger · thirst · cleanliness
--   And buffs are 0-100 each, decaying on the server and applied by the client.
--
--   * Stored against the character identifier (exports.w_lib:FwGetCharacterIdentifier)
--     => works on every framework (VORP/RSG/QBR) without needing metadata.
--   * The server is the authority (anti-cheat): decay and clamping live here.
--   * Broadcast to the client through the existing HUD event plus a full one.
--
-- ★ Disable vorp_metabolism on VORP servers -- this resource replaces it entirely.
-- ════════════════════════════════════════════════════════════════════════════

local Scale = 100

--- The needs persisted to the database (cleanliness is computed client-side from ped dirt)
local PERSIST  = { 'hunger', 'thirst' }
local DEFAULTS = { hunger = 100, thirst = 100, cleanliness = 100 }

--- [src] = { hunger=…, thirst=…, …, buffs = { health = 40, … } }
local State = {}

--- [src] = the citizen id State[src] was loaded for.
--- ★ Kept beside State and not inside it: State is sent to the client whole (the state bag,
---   the needs callback), and the id has no business travelling with it. A deletion
---   (server/purge.lua) finds the entry of a deleted character through this table.
local Owner = {}

--- An internal interface used by the other server files in this resource
--- (server/consumables.lua loads before this file, so the call must happen at runtime,
--- not at load time)
WNeeds = {}

-- ════════════════════════════════════════════════════════════════════════════
-- The table + migration
-- ════════════════════════════════════════════════════════════════════════════
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `w_hud_needs` (
            `cid` VARCHAR(64) NOT NULL,
            `hunger` INT DEFAULT 100,
            `thirst` INT DEFAULT 100,
            PRIMARY KEY (`cid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    -- Migrating older tables: we add only the missing columns.
    -- ADD COLUMN IF NOT EXISTS is not supported on MySQL 8, so we ask information_schema.
    local have = MySQL.query.await([[
        SELECT COLUMN_NAME FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'w_hud_needs'
    ]]) or {}

    local present = {}
    for i = 1, #have do present[string.lower(have[i].COLUMN_NAME)] = true end

    -- ★ The toxicity/bladder/bowel columns stay in the database, neither read nor written.
    --   Dropping a column is irreversible, and leaving it costs nothing.
    local wanted = {}

    for column, definition in pairs(wanted) do
        if not present[column] then
            MySQL.query.await(('ALTER TABLE `w_hud_needs` ADD COLUMN `%s` %s'):format(column, definition))
            w.print.info(('added column `%s` to w_hud_needs'):format(column))
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Helpers
-- ════════════════════════════════════════════════════════════════════════════
local function cidOf(src)
    local ok, id = pcall(function() return exports.w_lib:FwGetCharacterIdentifier(src) end)
    return ok and id or nil
end

local function clamp(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 elseif v > Scale then return Scale end
    return math.floor(v + 0.5)
end

--- A notice to one player. `key` is a dictionary key: it travels as a key (with its
--- format `args`) and the client translates it (client/func.lua, w_hud:client:notice)
--- in the player's own language and text direction -- the server only knows the convar,
--- and the library's server-side w.notify can neither format a key nor pick the direction.
---@param src number
---@param key string
---@param color? string
---@param icon? string
---@param duration? number
---@param args? table format arguments for the key
---@param description? string shown as it is (numbers)
local function notify(src, key, color, icon, duration, args, description)
    if not key then return end

    TriggerClientEvent('w_hud:client:notice', src, {
        title = key, args = args, description = description,
        color = color, icon = icon, duration = duration,
    })
end
WNeeds.notify = notify

local function broadcast(src)
    local s = State[src]; if not s then return end

    -- The legacy event -- we do not break any script listening for it
    TriggerClientEvent('hud:client:UpdateNeeds', src, s.hunger, s.thirst, s.cleanliness or 100)

    TriggerClientEvent('w_hud:client:needs', src, {
        hunger = s.hunger, thirst = s.thirst, buffs = s.buffs,
    })

    local Ply = Player(src)
    if Ply and Ply.state then Ply.state:set('needs', s, true) end

    -- ★ And the framework mirror: on RSG half the server reads hunger from the core's
    --   metadata, not from us. The function throttles itself (5s) so calling it here costs nothing.
    -- ⚠️ pcall, always: this sits in the needs broadcast, so anything that throws here
    --    stops eating and drinking altogether. The mirror is a courtesy to other RSG
    --    scripts -- it must never be able to take the core down with it.
    if WFwSrv and WFwSrv.mirror then pcall(WFwSrv.mirror, src, s) end
end

-- ════════════════════════════════════════════════════════════════════════════
-- Loading and saving
-- ════════════════════════════════════════════════════════════════════════════
local function load(src)
    local cid = cidOf(src); if not cid then return end

    local row = MySQL.single.await(
        'SELECT hunger, thirst FROM w_hud_needs WHERE cid = ?', { cid })

    local s = { buffs = {}, cleanliness = 100 }

    -- ★ No row with us? Ask the framework before assuming a hundred.
    --   On RSG hunger and thirst live in the core metadata, so an existing character
    --   has a real value -- and the assumption would wipe it. (Details in server/framework.lua)
    local seed = (not row) and WFwSrv and WFwSrv.seed and WFwSrv.seed(src) or nil

    for i = 1, #PERSIST do
        local key = PERSIST[i]
        s[key] = (row and row[key]) or (seed and seed[key]) or DEFAULTS[key]
    end

    State[src], Owner[src] = s, cid

    if not row then
        MySQL.insert(
            'INSERT INTO w_hud_needs (cid, hunger, thirst) VALUES (?, ?, ?)',
            { cid, s.hunger, s.thirst })
    end

    broadcast(src)
end

local function save(src)
    local s, cid = State[src], cidOf(src)
    if not s or not cid then return end

    MySQL.update([[
        INSERT INTO w_hud_needs (cid, hunger, thirst)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            hunger = VALUES(hunger), thirst = VALUES(thirst)
    ]], { cid, s.hunger, s.thirst })

    -- ⚠️ No throttle here: this is also called on disconnect, and a value lost to the
    --   throttle on the final save means metadata five seconds stale forever.
    if WFwSrv and WFwSrv.mirror then pcall(WFwSrv.mirror, src, s, true) end
end

-- ════════════════════════════════════════════════════════════════════════════
-- Reading and writing needs
-- ════════════════════════════════════════════════════════════════════════════

--- The player's state, or an attempt to load it.
---
--- ★ Without this, every edit dropped silently when the state was not loaded: the
---   player eats, the piece is removed, hunger does not rise, and not one console line
---   explains why. It happens whenever the load event is missed -- a resource restart,
---   or a boot order where the item is used before 'w_hud:server:load' arrives.
---@param src number
---@return table|nil
local function ensure(src)
    if State[src] then return State[src] end
    if not cidOf(src) then return nil end -- no character loaded yet

    load(src)
    return State[src]
end

local function getNeed(src, key)
    local s = ensure(src); return s and s[key]
end

local function setNeed(src, key, v)
    local s = ensure(src); if not s or DEFAULTS[key] == nil then return end
    s[key] = clamp(v)
    broadcast(src)
end

local function addNeed(src, key, d)
    local s = ensure(src); if not s or DEFAULTS[key] == nil then return end
    s[key] = clamp((s[key] or 0) + (tonumber(d) or 0))
    broadcast(src)
end

--- Changing several needs in one broadcast -- used by item consumption
local function addNeeds(src, deltas)
    local s = ensure(src); if not s then return end

    for key, d in pairs(deltas) do
        if DEFAULTS[key] ~= nil and d ~= 0 then
            s[key] = clamp((s[key] or 0) + d)
        end
    end

    broadcast(src)
end

local function reset(src)
    if not State[src] then State[src] = { buffs = {} } end
    local s = State[src]
    s.hunger, s.thirst = 100, 100
    s.buffs = {}
    broadcast(src); save(src)
end

WNeeds.get, WNeeds.set, WNeeds.add, WNeeds.addMany = getNeed, setNeed, addNeed, addNeeds
WNeeds.save, WNeeds.broadcast = save, broadcast
WNeeds.state = function(src) return State[src] end

-- ════════════════════════════════════════════════════════════════════════════
-- Buffs
-- ════════════════════════════════════════════════════════════════════════════
local function giveBuff(src, kind, amount)
    local s = ensure(src); if not s then return false end
    if not (Config.Buffs and Config.Buffs[kind]) then return false end

    s.buffs = s.buffs or {}
    local v = (s.buffs[kind] or 0) + (tonumber(amount) or 0)
    s.buffs[kind] = (v > Scale) and Scale or (v < 0 and 0 or v)

    if s.buffs[kind] <= 0 then s.buffs[kind] = nil end

    broadcast(src)
    return true
end
WNeeds.giveBuff = giveBuff

-- ════════════════════════════════════════════════════════════════════════════
-- What a CLIENT may do to its own needs and buffs
--
-- ⚠️ w_hud:server:setNeed, w_hud:server:giveBuff, w_hud:server:vorpCompat and
--   w_hud:server:respawn are net events: any client can fire them, with any value. They
--   used to be honoured as sent, so one line in a cheat menu -- setNeed('hunger', 100) --
--   replaced eating altogether. Food is charged and applied on the SERVER
--   (server/consumables.lua); these events went around it.
--
--   Now a client may still LOWER its own needs or buffs (a script that makes you vomit, a
--   salty snack: nothing is gained by faking that), but it may RAISE them only by what a
--   server-side script allowed a moment before:
--     exports.w_hud:AllowNeedRaise(src, 'hunger' | 'thirst', amount, seconds?)
--     exports.w_hud:AllowBuff(src, kind, amount, seconds?)
--   A server script should rather call exports.w_hud:AddNeed / SetNeed / GiveBuff itself.
--   The refill after a revive is honoured only when this server saw the player go down
--   (hospital:server:SetDeathStatus on RSG / w_ambulancejob, vorp:ImDead on VORP), and never
--   while w_ambulancejob runs: it refills on the server with the revive (w_hud:server:respawn).
--
--   `setr w_hud:clientNeeds open` brings the old trust back, for a server that runs a
--   client-only script it cannot change and accepts the risk.
-- ════════════════════════════════════════════════════════════════════════════
local Credit = {} -- src -> { needs = { [need] = { amount, until_ } }, buffs = { [kind] = { ... } } }
local Downed = {} -- src -> GetGameTimer() when the server last heard the player went down
local warnedAt = {}

local function clientsTrusted()
    return GetConvar('w_hud:clientNeeds', 'guarded') == 'open'
end

local function grant(src, bucket, key, amount, seconds)
    src, amount = tonumber(src), tonumber(amount)
    if not src or not amount or amount ~= amount or amount <= 0 or type(key) ~= 'string' then return false end
    local now = GetGameTimer()
    Credit[src] = Credit[src] or {}
    local b = Credit[src][bucket] or {}
    Credit[src][bucket] = b
    local cur = b[key]
    local left = (cur and cur.until_ > now) and cur.amount or 0
    b[key] = { amount = left + amount, until_ = now + math.floor((tonumber(seconds) or 30) * 1000) }
    return true
end

--- How much of `amount` a grant covers (and uses it up)
local function spend(src, bucket, key, amount)
    local b = Credit[src] and Credit[src][bucket]
    local cur = b and b[key]
    if not cur then return 0 end
    if cur.until_ <= GetGameTimer() then b[key] = nil; return 0 end
    local used = math.min(cur.amount, amount)
    cur.amount = cur.amount - used
    if cur.amount <= 0 then b[key] = nil end
    return used
end

local function refused(src, what)
    local now = GetGameTimer()
    if (warnedAt[src] or 0) > now then return end
    warnedAt[src] = now + 60000
    w.print.warn(('%s (%s) asked from the client to raise %s without a server grant - refused')
        :format(GetPlayerName(src) or '?', tostring(src), what))
end

--- A client's own request for a need's new value: lower freely, raise only by a grant.
---@return boolean changed
local function clientSetNeed(src, key, value, via)
    if key ~= 'hunger' and key ~= 'thirst' then return false end
    value = tonumber(value)
    if not value or value ~= value then return false end
    local s = ensure(src)
    if not s then return false end
    value = clamp(value)
    local now = s[key] or 0
    if value <= now or clientsTrusted() then
        setNeed(src, key, value)
        return true
    end
    local allowed = spend(src, 'needs', key, value - now)
    if allowed > 0 then setNeed(src, key, now + allowed) end
    if allowed < value - now then
        refused(src, ('%s (%s)'):format(key, via))
        broadcast(src) -- the client already showed its own number: put the real one back
    end
    return allowed > 0
end

RegisterNetEvent('w_hud:server:giveBuff', function(kind, amount)
    local src = source
    if not exports.w_lib:FwGetUser(src) then return end
    amount = tonumber(amount)
    if not amount or amount ~= amount or type(kind) ~= 'string' then return end
    if amount <= 0 or clientsTrusted() then
        giveBuff(src, kind, amount)
        return
    end
    local allowed = spend(src, 'buffs', kind, amount)
    if allowed > 0 then giveBuff(src, kind, allowed) end
    if allowed < amount then refused(src, 'buff ' .. kind) end
end)

-- The deaths this server hears about (the refill after a revive checks them)
RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
    if isDead == true then Downed[source] = GetGameTimer() end
end)
RegisterNetEvent('hospital:server:SetLaststandStatus', function(down)
    if down == true then Downed[source] = GetGameTimer() end
end)
RegisterNetEvent('vorp:ImDead', function(isDead)
    if isDead == true then Downed[source] = GetGameTimer() end
end)

exports('AllowNeedRaise', function(src, need, amount, seconds)
    if need ~= 'hunger' and need ~= 'thirst' then return false end
    return grant(src, 'needs', need, amount, seconds)
end)
exports('AllowBuff', function(src, kind, amount, seconds)
    if type(kind) ~= 'string' or not (Config.Buffs and Config.Buffs[kind]) then return false end
    return grant(src, 'buffs', kind, amount, seconds)
end)

-- -- the buff loop -----------------------------------------------------------
-- They decay here, and whatever among them touches **needs** is applied here too
-- (calming and feeding): applying it on the client would have meant a network event
-- every two seconds per player. What touches the ped itself (health · cores · horse
-- stamina) belongs on the client -- client/needs.lua.
CreateThread(function()
    while true do
        Wait((Config.Buffs and Config.Buffs.TickInterval) or 2000)

        if Config.Systems.buffs then
            for src, s in pairs(State) do
                if s.buffs and next(s.buffs) then
                    -- Healthy food: renews hunger and thirst
                    if (s.buffs.vegan or 0) > 0 then
                        local gain = Config.Buffs.vegan.amount or 2
                        s.hunger = clamp((s.hunger or 0) + gain)
                        s.thirst = clamp((s.thirst or 0) + gain)
                    end

                    for kind, value in pairs(s.buffs) do
                        local cfg = Config.Buffs[kind]
                        local left = value - ((cfg and cfg.drain) or 1)

                        s.buffs[kind] = (left > 0) and left or nil
                    end

                    broadcast(src)
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Lifecycle
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('w_hud:server:load', function() load(source) end)

-- The RSG-style client events (client/event.lua hud:client:UpdateHunger / UpdateThirst) and
-- w_inventory's RSG bridge (an item's `status`) send the new absolute value from the client:
-- lowered freely, raised only by a server grant (see "What a CLIENT may do" above).
RegisterNetEvent('w_hud:server:setNeed', function(key, value)
    clientSetNeed(source, key, value, 'setNeed')
end)

AddEventHandler('playerDropped', function()
    local src = source; save(src); State[src], Owner[src] = nil, nil
    Credit[src], Downed[src], warnedAt[src] = nil, nil, nil
end)

-- A deleted character leaves memory with its rows (server/purge.lua). Normally its player was
-- kicked and the entry is already gone; a deletion from the character selection leaves the
-- player connected, and the dead character's needs would keep decaying and broadcasting.
WHudPurge = WHudPurge or {}
WHudPurge.needs = function(cid)
    local n = 0
    for src, owner in pairs(Owner) do
        if owner == cid then
            State[src], Owner[src] = nil, nil
            n = n + 1
        end
    end
    return n
end

-- Periodic save
CreateThread(function()
    while true do
        Wait(120000)
        for src in pairs(State) do save(src) end
    end
end)

-- -- live resource restart ---------------------------------------------------
-- Character-selection events fire once at login and are not replayed on `ensure w_hud`.
-- So after a restart State stays empty and nothing reaches the client -- which is why
-- the HUD 'never loads and hangs'. The server takes the initiative here: it walks every
-- connected player with a loaded character, reads their values from the database and
-- pushes them down.
AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(1000) -- a grace period until the framework bridge (w_lib) and the database are ready

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)

            if src and cidOf(src) then
                load(src)
                TriggerClientEvent('w_hud:client:forceLoaded', src)
            end
        end
    end)

    -- ★ An explicit warning: running vorp_metabolism alongside us means double decay and conflicting values.
    CreateThread(function()
        Wait(3000)

        if GetResourceState('vorp_metabolism') == 'started' then
            w.print.error('vorp_metabolism is running alongside w_hud.')
            w.print.error('  w_hud fully replaces it - disable it in server.cfg (#ensure vorp_metabolism)')
            w.print.error('  Otherwise needs decay twice and the two values diverge.')
        end
    end)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The decay and refill loops
-- ════════════════════════════════════════════════════════════════════════════

-- Hunger and thirst
--
-- ★ Read inside the loop, not once above it. These numbers are the admin's now
--   (server/admin.lua), and an admin who moves the rate expects the next tick to use
--   it -- not the next restart. Hoisting the interval out of the loop is what made the
--   old values permanent for the life of the process.
--
-- ⚠️ The floor of one second is not decoration. WHudSrv is clamped on arrival, but this
--   loop is the thing that would spin if a zero ever reached it, so it refuses one here
--   too. Two guards on the same value is the correct number when the failure is a
--   server that stops responding.
--
-- ⚠️ It counts seconds rather than sleeping the interval.
--
--   Reading the numbers at the top of the loop and then sleeping the interval looks like
--   it reacts to a change, and it does not: the sleep already under way is the *old*
--   interval, so an admin who drops 1800 seconds to 30 waits out the remaining half hour
--   before anything happens. Every report of "I changed it and nothing changed" comes
--   from that shape. Ticking once a second and counting up costs nothing and means a
--   change is picked up on the next second.
CreateThread(function()
    local elapsed = 0

    while true do
        Wait(1000)

        local srv = WHudSrv and WHudSrv.needs or nil

        local seconds = srv and tonumber(srv.interval) or (Config.NeedsDecreaseInterval or 144)
        if not seconds or seconds < 1 then seconds = 1 end

        elapsed = elapsed + 1

        -- A shortened interval must not leave a long count standing.
        if elapsed >= seconds then
            elapsed = 0

            local hungerRate = srv and tonumber(srv.hungerRate) or (Config.HungerDecreaseRate or 1)
            local thirstRate = srv and tonumber(srv.thirstRate) or (Config.ThirstDecreaseRate or 1)

            for src, s in pairs(State) do
                s.hunger = clamp(s.hunger - hungerRate)
                s.thirst = clamp(s.thirst - thirstRate)
                broadcast(src)
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- vorp_metabolism compatibility
--
--   We disabled that resource, but vorp_core itself and a great many scripts still fire
--   its events. The client converts the scale (0-1000 => 0-100) then passes them here.
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('w_hud:server:vorpCompat', function(mode, need, value)
    local src = source
    if not State[src] then return end
    if need ~= 'hunger' and need ~= 'thirst' then return end

    if mode == 'set' then
        clientSetNeed(src, need, value, 'vorp set')
    else
        local d = tonumber(value)
        if not d or d ~= d then return end
        if d <= 0 then
            addNeed(src, need, d)
        else
            clientSetNeed(src, need, (State[src][need] or 0) + d, 'vorp add')
        end
    end
end)

-- Reset after a revive: only when this server heard the player go down (a client cannot
-- refill itself by claiming a revive), or with the old trust (w_hud:clientNeeds open).
RegisterNetEvent('w_hud:server:respawn', function()
    local src = source
    if not State[src] then return end
    -- ⚠️ With w_ambulancejob running the request is dropped, quietly. That resource refills hunger
    --   and thirst itself, on the server, with every revive and heal it grants (its refillNeeds ->
    --   SetNeed), so the refill has already come. And the "went down" this gate reads is only the
    --   client's own word (hospital:server:SetDeathStatus / vorp:ImDead are net events): a cheat
    --   menu sent "dead", then this, then "alive" and had both needs full whenever it liked.
    if not clientsTrusted() and GetResourceState('w_ambulancejob') == 'started' then
        Downed[src] = nil
        return
    end
    local downedAt = Downed[src]
    if not clientsTrusted() and not (downedAt and GetGameTimer() - downedAt < 30 * 60000) then
        refused(src, 'a refill after a revive (never seen down)')
        return
    end
    Downed[src] = nil
    reset(src)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The public interface (exports) -- for other resources
-- ════════════════════════════════════════════════════════════════════════════
exports('ResetNeeds', function(src) reset(src) end)
exports('SaveNeeds', function(src) save(src) end)
exports('GetNeeds', function(src) return State[src] end)
exports('GetNeed', function(src, key) return getNeed(src, key) end)
exports('SetNeed', function(src, key, v) setNeed(src, key, v); return true end)
exports('AddNeed', function(src, key, d) addNeed(src, key, d); return true end)
exports('AddNeeds', function(src, deltas) addNeeds(src, deltas); return true end)

exports('GiveBuff', function(src, kind, amount) return giveBuff(src, kind, amount) end)
exports('GetBuffs', function(src) local s = State[src]; return s and s.buffs or {} end)
exports('ClearBuffs', function(src)
    local s = State[src]; if not s then return false end
    s.buffs = {}; broadcast(src); return true
end)

w.callback.register('w_hud:getNeed', function(src, key) return getNeed(src, key) end)
w.callback.register('w_hud:getNeeds', function(src) return State[src] end)

--- For the admin console: just hunger and thirst (0-100), loading the state from the
--- database if this player has a character but no state in memory yet. nil when the
--- player has no character loaded. (GetNeeds above returns the whole state and does
--- not attempt a load.)
---@param src number
---@return { hunger: number, thirst: number }|nil
exports('GetNeedsPair', function(src)
    local s = ensure(tonumber(src) or 0)
    if not s then return nil end
    return { hunger = s.hunger or 0, thirst = s.thirst or 0 }
end)
