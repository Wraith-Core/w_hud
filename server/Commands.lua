-- ============================================================================
-- Money refresh -- cash and gold through the w_lib bridge (every framework),
-- bank and dirty money straight from the database on VORP (only VORP keeps them there);
-- on the RSG family the bank is PlayerData.money.bank and there is no dirty money.
--
-- The bank is a sum, not a row: a character may hold an account in Valentine and
-- another in Rhodes, and showing one of them is showing the wrong number.
--
-- The cost, and why it is cached
--   client/thread.lua fires this every second, per player. A bank query on each
--   would be one query per player per second -- 128 of them on a full server,
--   for a number that changes when somebody walks up to a teller. So the answer
--   is cached and re-read at most every BANK_TTL, and a real deposit skips the
--   wait by asking for a refresh of its own (w_hud:server:refreshBank).
-- ============================================================================

local BANK_TTL <const> = 5000 -- ms; the ceiling on how stale the bank figure may be

local bankCache = {} -- [src] = { bank = number, dirty = number, at = ms }

--- Read the bank total and the dirty money in one round trip.
---@param src integer
---@return number bank, number dirty
local function readFromDb(src)
    -- ! VORP only, and asked first. bank_users and characters.blackmoney are VORP's own tables:
    --   on the RSG family (Wraith Core / RSG / QBR) the bank is a field on PlayerData.money and
    --   dirty money does not exist, so this query could only ever fail there -- once per player
    --   every BANK_TTL, which is what was filling the console. The library's bridge already
    --   answers with the core's own player object, so the bank comes from the same place the
    --   cash and gold above it do.
    if not w.framework:is('vorp') then
        local player = exports.w_lib:FwGetUser(src)
        local money = type(player) == 'table' and type(player.PlayerData) == 'table' and player.PlayerData.money
        return tonumber(type(money) == 'table' and money.bank) or 0.0, 0.0
    end

    local charId = exports.w_lib:FwGetCharacterIdentifier(src)
    if not charId then return 0.0, 0.0 end

    local ok, row = pcall(function()
        return MySQL.single.await([[
            SELECT
                (SELECT IFNULL(SUM(money), 0) FROM bank_users WHERE charidentifier = ?) AS bank,
                IFNULL(blackmoney, 0) AS dirty
            FROM characters
            WHERE charidentifier = ?
            LIMIT 1
        ]], { charId, charId })
    end)

    if not ok or type(row) ~= 'table' then return 0.0, 0.0 end

    return tonumber(row.bank) or 0.0, tonumber(row.dirty) or 0.0
end

--- The cached pair, re-read only when it has gone stale (or when forced).
---@param src integer
---@param force? boolean
---@return number bank, number dirty
local function bankAndDirty(src, force)
    local now = GetGameTimer()
    local hit = bankCache[src]

    if not force and hit and (now - hit.at) < BANK_TTL then
        return hit.bank, hit.dirty
    end

    local bank, dirty = readFromDb(src)
    bankCache[src] = { bank = bank, dirty = dirty, at = now }

    return bank, dirty
end

local function pushMoney(src, force)
    if not exports.w_lib:FwGetUser(src) then return end

    local cashD = exports.w_lib:FwGetMoney(src) or 0.0
    local goldD = exports.w_lib:FwGetGold(src) or 0.0
    local bankD, dirtyD = bankAndDirty(src, force)

    TriggerClientEvent('w_hud:client:updateMoney', src, cashD, goldD, bankD, dirtyD)
end

RegisterNetEvent('w_hud:server:updateMoney', function()
    pushMoney(source, false)
end)

-- A deposit or a withdrawal must not wait out BANK_TTL: the client asks for this
-- the moment vorp_banking says the balance moved, and after the bank menu closes.
RegisterNetEvent('w_hud:server:refreshBank', function()
    pushMoney(source, true)
end)

AddEventHandler('playerDropped', function()
    bankCache[source] = nil
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /feed -- fill hunger and thirst
--
--   /feed            -> fills your own needs
--   /feed 50         -> adds 50 to your hunger and thirst (capped at 100)
--   /feed 100 12     -> adds 100 to the needs of citizen 12 ('#12' = whoever is on server id 12)
--
-- ★ The target is a citizen id, never a bare server id: server ids change on every
--   connection and, now that citizen ids are plain digits, the two collide. A citizen
--   who is not in the game is fed the offline way: his w_hud_needs row, read at his next login.
--
-- ⚠️ The command lives on the **server**, not the client: the values are stored in
-- w_hud_needs and broadcast from there, so a client-side command would not survive
-- the decay loop or the first save.
--
-- ★ Admin-only on purpose. This is a convenience for the owner, not a gameplay
--   feature: without a guard every player on the server stops needing to eat, and
--   the whole food economy collapses.
--   exports.w_lib:IsAdmin accepts an 'admin' permission in the framework or the ACE
--   principal 'command'.
-- ════════════════════════════════════════════════════════════════════════════

local FEED_ADMIN_ONLY = true -- set false to open it to everyone (not advised on a live server)

--- A reply in the player's own language: `key` is a dictionary key the client translates
--- (WNeeds.notify -> w_hud:client:notice); `description` is shown as it is (numbers).
local function feedReply(src, key, description)
    if src == 0 then return print(('[w_hud] %s %s'):format(locale(key), description or '')) end

    WNeeds.notify(src, key, '#F2F2F2', 'awards_set_g_013', 4000, nil, description)
end

local FEED_SCALE = 100 -- the needs scale (server/metabolism.lua: Scale)

local function clampNeed(v)
    v = tonumber(v) or FEED_SCALE
    if v < 0 then return 0 elseif v > FEED_SCALE then return FEED_SCALE end
    return math.floor(v + 0.5)
end

--- Feed a character who is not in the game: his w_hud_needs row, which his next login reads
--- (server/metabolism.lua load). With no row yet, the starting point is what that login would
--- have seeded from: the core's metadata (RSG keeps hunger/thirst there), else a full bar.
---@param cid string the citizen id (w_hud_needs.cid)
---@param amount number|nil nil = fill
---@return number|nil hunger, number|nil thirst (nil when the database refused)
local function feedOffline(cid, amount)
    local ok, row = pcall(MySQL.single.await, 'SELECT hunger, thirst FROM w_hud_needs WHERE cid = ?', { cid })
    if not ok then return nil end

    if not row then
        row = {}
        local okRows, rows = pcall(function() return exports.w_lib:FwCharacterRows('citizenid', cid) end)
        local md = okRows and type(rows) == 'table' and rows[1] and rows[1].metadata
        if type(md) == 'string' then
            local okJson, decoded = pcall(json.decode, md)
            md = okJson and decoded or nil
        end
        if type(md) == 'table' then row.hunger, row.thirst = tonumber(md.hunger), tonumber(md.thirst) end
    end

    local hunger = amount and clampNeed((tonumber(row.hunger) or FEED_SCALE) + amount) or FEED_SCALE
    local thirst = amount and clampNeed((tonumber(row.thirst) or FEED_SCALE) + amount) or FEED_SCALE

    local okWrite = pcall(MySQL.update.await, [[
        INSERT INTO w_hud_needs (cid, hunger, thirst)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE hunger = VALUES(hunger), thirst = VALUES(thirst)
    ]], { cid, hunger, thirst })
    if not okWrite then return nil end

    return hunger, thirst
end

-- ★ Through the library: the chat suggestion carries the help text in the server language,
--   the parameters are parsed and validated before the handler runs.
--   The target has no `type`: 'playerId' answers only a player in the game and 'string'
--   refuses digits, while /feed takes any citizen id ('12', the old 'OMG95204', '#<server
--   id>') and also reaches one who is offline.
w.addCommand('feed', {
    help = locale('feed.help'),
    params = {
        { name = 'amount', type = 'number', help = locale('feed.argAmountHelp'), optional = true },
        { name = 'target', help = locale('feed.argPlayerHelp'), optional = true },
    },
}, function(source, args)
    local src = source

    if FEED_ADMIN_ONLY and src ~= 0 then
        local ok, admin = pcall(function() return exports.w_lib:IsAdmin(src) end)

        if not (ok and admin) then
            return feedReply(src, 'feed.adminOnly')
        end
    end

    -- No value = fill to the brim. With a value = add, capped at 100 inside addNeed.
    local amount = tonumber(args.amount)

    -- Second argument: another player's citizen id. Its absence means yourself -- and the
    -- console has no 'self'.
    local target, who, reason = src, nil, nil

    if args.target then
        who, reason = w.citizen.resolve(args.target, { self = src ~= 0 and src or nil })

        if not who then
            return feedReply(src, 'feed.noPlayer', w.citizen.reasonText(reason, src ~= 0 and src or nil))
        end

        if not who.online then
            local hunger, thirst = feedOffline(who.citizenid, amount)
            if not hunger then return feedReply(src, 'feed.noPlayer', w.citizen.label(who)) end

            return feedReply(src, 'feed.resultOffline', ('%s: %s · %s'):format(w.citizen.label(who), hunger, thirst))
        end

        target = who.source
    end

    if target == 0 then
        return feedReply(src, 'feed.console')
    end

    if not exports.w_lib:FwGetUser(target) then
        return feedReply(src, 'feed.noPlayer')
    end

    if amount then
        exports.w_hud:AddNeed(target, 'hunger', amount)
        exports.w_hud:AddNeed(target, 'thirst', amount)
    else
        exports.w_hud:SetNeed(target, 'hunger', 100)
        exports.w_hud:SetNeed(target, 'thirst', 100)
    end

    -- The periodic save runs every two minutes, so we pin it now lest a sudden disconnect lose it.
    exports.w_hud:SaveNeeds(target)

    local needs = exports.w_hud:GetNeeds(target) or {}
    local done = ('%s · %s'):format(tostring(needs.hunger), tostring(needs.thirst))

    -- the admin sees whom he fed by name and citizen id, never by server id
    feedReply(src, 'feed.result', (who and target ~= src) and ('%s: %s'):format(w.citizen.label(who), done) or done)
    if target ~= src then feedReply(target, 'feed.result', done) end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /needsdebug -- why does nothing go up when I eat?
--
-- ★ The eating chain has four links, and a break in any of them gives exactly the
--   same result: you use the item and nothing moves. This command names them one by one.
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('needsdebug', function(source)
    local src = source
    local function line(label, ok, detail)
        print(('%s %-38s %s'):format(ok and '^2[✓]^7' or '^1[✗]^7', label, detail or ''))
    end

    print('^3== w_hud - NEEDS DIAGNOSTIC ==============================^0')

    -- 1) is the inventory running?
    local invName = exports.w_lib:InvName()
    local invOk = exports.w_lib:InvReady() == true
    line('inventory bridge ready', invOk, tostring(invName or 'none'))

    -- 2) does the inventory accept registration? (its registry is lost on every restart)
    local registered = false
    if invOk then
        registered = pcall(function()
            return exports.w_lib:InvCall('RegisterUsableItem', '__w_hud_probe__', function() end)
        end)
        -- ★ Do not leave a phantom entry in the inventory registry after the probe
        pcall(function() exports.w_lib:InvCall('UnregisterUsableItem', '__w_hud_probe__') end)
    end
    line('export RegisterUsableItem', registered,
        registered and '' or '^1inventory refuses registration^7')

    -- 3) is the item in the inventory catalogue?
    local probe, catalogued = 'cooked_meat', false
    if invOk then
        local ok, item = pcall(function() return exports.w_lib:InvItems(probe) end)
        catalogued = ok and item ~= nil
    end
    line(('item "%s" in catalogue'):format(probe), catalogued,
        catalogued and '' or '^1not defined in data/items.lua^7')

    -- 4) is the entry in our own table?
    local known = Config.Consumables and Config.Consumables[probe] ~= nil
    line(('entry "%s" in shared/consumables.lua'):format(probe), known)

    local okReg, isReg = pcall(function()
        return exports.w_lib:InvCall('IsUsableItemRegistered', probe)
    end)
    line(('"%s" in usable-item registry'):format(probe), okReg and isReg == true,
        okReg and (isReg and '' or '^1NOT registered - restart w_hud^7')
        or '^3inventory has no IsUsableItemRegistered export^7')

    local okWho, who = pcall(function()
        return exports.w_lib:InvCall('WhichUseItemHandler')
    end)
    line('active server.UseItem handler', okWho and who == 'bridge (shared registry)',
        okWho and tostring(who) or '^3unknown^7')

    -- 5) is the player state loaded? <- the most common cause of silence
    local cid = src ~= 0 and select(2, pcall(function()
        return exports.w_lib:FwGetCharacterIdentifier(src)
    end)) or nil
    line('character identifier', cid and cid ~= false, tostring(cid))

    local needs = src ~= 0 and exports.w_hud:GetNeeds(src) or nil
    line('needs state loaded', needs ~= nil,
        needs and ('hunger=%s thirst=%s'):format(needs.hunger, needs.thirst)
        or '^1NOT loaded - nothing will increase no matter what you eat^7')

    print('^3════════════════════════════════════════════════════^0')
end, true)

-- ════════════════════════════════════════════════════════════════════════════
-- /useprobe -- what exactly does RegisterUsableItem return?
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('useprobe', function()
    local NAME = '__w_hud_probe__'
    local cb = function() end

    print('^3== w_hud - RegisterUsableItem PROBE ======================^0')

    local a1, a2, a3 = exports.w_lib:InvCall('RegisterUsableItem', NAME, cb)
    print(('  bridge → 1=%s(%s)  2=%s(%s)  3=%s(%s)')
        :format(tostring(a1), type(a1), tostring(a2), type(a2), tostring(a3), type(a3)))
    print(('  registered? %s'):format(tostring(exports.w_lib:InvCall('IsUsableItemRegistered', NAME))))

    exports.w_lib:InvCall('UnregisterUsableItem', NAME)

    local c1 = exports.w_lib:InvCall('CreateUseableItem', NAME, cb)
    print(('  Create -> 1=%s(%s)  registered? %s')
        :format(tostring(c1), type(c1), tostring(exports.w_lib:InvCall('IsUsableItemRegistered', NAME))))

    exports.w_lib:InvCall('UnregisterUsableItem', NAME)

    local ok, names = pcall(function() return exports.w_lib:InvCall('GetUsableItemNames') end)
    print(('  registry size: %s'):format(ok and type(names) == 'table' and #names or 'unknown'))
    if ok and type(names) == 'table' and #names > 0 then
        print('  sample: ' .. table.concat(names, ', ', 1, math.min(8, #names)))
    end

    print('^3════════════════════════════════════════════════════^0')
end, true)
