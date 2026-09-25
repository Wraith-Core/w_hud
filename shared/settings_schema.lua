-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · shared/settings_schema.lua
-- The live settings: what the admin console (w_admin › Scripts › w_hud, and its Food & drink
-- page) may change while the server runs, each value explained in plain words.
--
-- ═══ How it works ═══
--
--   The manifest says `w_settings 'yes'`; w_lib's w.settings module (modules/settings) does the
--   rest from the definition below: it registers WSettingsSchema / WSettingsValues /
--   WSettingsApply in THIS resource, validates every change, saves it, writes it into Config in
--   place, and pushes the client half to every player (the ones who join later ask for it).
--
--   Two kinds of storage:
--     own      needs · damage · features · identity: the blob w_hud already keeps in
--              `w_hud_server` (server/admin.lua). The F7 panel's admin section and the console
--              edit the SAME values; WHudAdmin.save is the one save path.
--     central  food · buffs · poison · gold · horse · animals · satchels · systems: one row per
--              CHANGED value in `w_admin_settings`, applied on top of the final Config at boot.
--              Everything the admin did not touch keeps following the code.
--
-- ★ Loaded LAST in shared_scripts: use_rules.lua has already reshaped Config.Consumables and
--   replaced Config.HorseItems, and an override must land on the final table.
--
-- ⚠️ Structure is not a setting: anim, prop, scenario, pack, requirement, consume, blocked,
--   kind and focus belong to the code. The five items that are not food (the two cigarette
--   packs, coffee grounds, hair tonic and grease) are listed but locked.
--
-- Texts: locales/{ar,en}.json, "settings" (label / help / example / unit of every value).
-- ════════════════════════════════════════════════════════════════════════════

local S = w.settings

-- ════════════════════════════════════════════════════════════════════════════
-- own groups: the w_hud_server blob (server/admin.lua keeps it in WHudSrv)
-- ════════════════════════════════════════════════════════════════════════════

--- Where a key lives inside the blob
local OWN_PATH = {
    ['needs.hungerRate'] = { 'needs', 'hungerRate' },
    ['needs.thirstRate'] = { 'needs', 'thirstRate' },
    ['needs.interval']   = { 'needs', 'interval' },
    ['damage.enabled']   = { 'damage', 'enabled' },
    ['damage.hungerAt']  = { 'damage', 'hungerAt' },
    ['damage.thirstAt']  = { 'damage', 'thirstAt' },
    ['damage.amount']    = { 'damage', 'amount' },
    ['damage.interval']  = { 'damage', 'interval' },
    ['damage.canKill']   = { 'damage', 'canKill' },
    ['identity.name']    = { 'name' },
    ['identity.logoUrl'] = { 'logo', 'url' },
    ['identity.logoWidth']  = { 'logo', 'width' },
    ['identity.logoHeight'] = { 'logo', 'height' },
    ['identity.x']       = { 'identity', 'x' },
    ['identity.y']       = { 'identity', 'y' },
    ['identity.scale']   = { 'identity', 'scale' },
    ['identity.opacity'] = { 'identity', 'opacity' },
}

local FEATURES = {
    'health', 'stamina', 'hunger', 'thirst', 'voice', 'horse', 'buffs',
    'ammo', 'money', 'identity', 'compass', 'location', 'playerImages', 'playerPanel',
}
for _, id in ipairs(FEATURES) do OWN_PATH['features.' .. id] = { 'features', id } end

--- The values in effect: the blob on the server, the copy the server sent on the client
local function blob()
    return type(WHudSrv) == 'table' and WHudSrv or nil
end

local function ownRead(key, fallback)
    return function()
        local node = blob()
        for _, part in ipairs(OWN_PATH[key]) do
            if type(node) ~= 'table' then return fallback end
            node = node[part]
        end
        if node == nil then return fallback end
        return node
    end
end

--- The real defaults are sanitise(nil) in server/admin.lua (not config.lua's old numbers)
local OWN_DEFAULT = {
    ['needs.hungerRate'] = 1, ['needs.thirstRate'] = 1.4, ['needs.interval'] = 90,
    ['damage.enabled'] = true, ['damage.hungerAt'] = 15, ['damage.thirstAt'] = 15,
    ['damage.amount'] = 2, ['damage.interval'] = 20, ['damage.canKill'] = true,
    ['identity.name'] = '', ['identity.logoUrl'] = '', ['identity.logoWidth'] = 30, ['identity.logoHeight'] = 0,
    ['identity.x'] = 98.2, ['identity.y'] = 2.0, ['identity.scale'] = 1, ['identity.opacity'] = 1,
}
for _, id in ipairs(FEATURES) do OWN_DEFAULT['features.' .. id] = true end

--- One save for every own change of a batch: the same sanitise + store + broadcast as the panel
local function ownApply(changes)
    if type(WHudAdmin) ~= 'table' or type(WHudSrv) ~= 'table' then return false, 'not_ready' end
    local cfg = S.copy(WHudSrv)
    for _, c in ipairs(changes) do
        local path = OWN_PATH[c.key]
        if not path then return false, 'unknown_key' end
        local node = cfg
        for i = 1, #path - 1 do
            node[path[i]] = type(node[path[i]]) == 'table' and node[path[i]] or {}
            node = node[path[i]]
        end
        node[path[#path]] = S.copy(c.value)
    end
    local ok, result = WHudAdmin.save(cfg)
    return ok, result
end

local function own(kind, key, def)
    def.key = key
    def.default = OWN_DEFAULT[key]
    def.read = ownRead(key, OWN_DEFAULT[key])
    return S[kind](def)
end

--- A logo is drawn in an <img> on every screen: only http, https and nui (as sanitise does)
local function safeUrl(value)
    if value == '' or value:match('^https://') or value:match('^http://') or value:match('^nui://') then return nil end
    return 'out_of_range'
end

-- ════════════════════════════════════════════════════════════════════════════
-- central values of Config (read / written in place; the module keeps the originals)
-- ════════════════════════════════════════════════════════════════════════════

--- A number at Config[a][b]...: read, and written back as a number
local function cfgPath(...)
    local path = { ... }
    local function parent()
        local node = Config
        for i = 1, #path - 1 do
            if type(node[path[i]]) ~= 'table' then node[path[i]] = {} end
            node = node[path[i]]
        end
        return node
    end
    return function() return parent()[path[#path]] end, function(v) parent()[path[#path]] = v end
end

local function central(kind, key, def, read, write)
    def.key = key
    def.read, def.write = read, write
    return S[kind](def)
end

--- ms in Config, seconds on the page
local function msAsSeconds(read, write)
    return function() return (tonumber(read()) or 0) / 1000 end,
        function(v) write(math.floor(v * 1000 + 0.5)) end
end

-- ════════════════════════════════════════════════════════════════════════════
-- food: one row per item of Config.Consumables
-- ════════════════════════════════════════════════════════════════════════════

local FRUIT = {
    consumable_apple = true, consumable_beets = true, consumable_carrot = true, consumable_celery = true,
    consumable_corn = true, consumable_peach = true, consumable_pear = true,
}

--- The families of the page's chips and bulk edit (derived from the item, not stored)
local function familyOf(item, entry)
    if entry.blocked or entry.pack then return 'locked' end
    local kind = entry.kind
    if kind == 'poison' then return 'poison' end
    if kind == 'alcohol' then return 'alcohol' end
    if kind == 'drink' then return 'drinks' end
    if kind == 'medical' then return 'medicine' end
    if kind == 'drug' then return 'tobacco' end
    if item:find('_oregano_cooked$') or item:find('_thyme_cooked$') or item:find('mint_cooked$') then return 'meat_herbed' end
    if item:find('_cooked$') then return 'meat' end
    if item:find('_can$') then return 'canned' end
    if item:find('^consumable_herb_') then
        if item:find('berry') or item:find('currant') then return 'fruit' end
        return 'herbs'
    end
    if item == 'rdr_saltbush' or item == 'rdr_seasoning' then return 'herbs' end
    if FRUIT[item] then return 'fruit' end
    return 'bread'
end

local FAMILY_ORDER = {
    fruit = 1, herbs = 2, meat = 3, meat_herbed = 4, canned = 5, bread = 6, drinks = 7,
    alcohol = 8, tobacco = 9, medicine = 10, poison = 11, locked = 12,
}

--- Why an item's numbers are not a setting (a text key of locales/*.json)
local function lockOf(entry)
    if entry.pack then return 'settings.food.locked.pack' end
    if entry.kind == 'ingredient' then return 'settings.food.locked.ingredient' end
    if entry.blocked then return 'settings.food.locked.unused' end
    return nil
end

--- The item's name in both languages and its picture, from w_inventory's catalogue (asked only
--- when the page opens the table; cached once found)
local described = {}
local function describeItem(item)
    if described[item] then return described[item] end
    local out = { image = ('nui://w_inventory/web/images/%s.png'):format(item) }
    if GetResourceState('w_inventory') == 'started' then
        local ok, data = pcall(function() return exports.w_inventory:Items(item) end)
        if ok and type(data) == 'table' then
            local source = type(data.i18n) == 'table' and data.i18n or data
            local label = source.label
            if type(label) == 'table' and (label.ar or label.en) then
                out.label = { ar = label.ar or label.en, en = label.en or label.ar }
            elseif type(source.label_ar) == 'string' or type(source.label_en) == 'string' then
                out.label = { ar = source.label_ar or source.label_en, en = source.label_en or source.label_ar }
            elseif type(data.label) == 'string' then
                out.label = { ar = data.label, en = data.label }
            end
            local image = type(data.client) == 'table' and data.client.image or nil
            if type(image) == 'string' and image:match('^[%w_%-%.]+$') then
                out.image = 'nui://w_inventory/web/images/' .. image
            end
            described[item] = out
        end
    end
    if not out.label then
        local name = item:gsub('^consumable_', ''):gsub('^rdr_', ''):gsub('_', ' ')
        name = name:gsub('^%l', string.upper)
        out.label = { ar = name, en = name }
    end
    return out
end

local function entryOf(row) return Config.Consumables[row] end

--- A number column: absent reads as 0, 0 is written as absent (every reader does `or 0`)
local function foodNumber(col, def)
    def.key = col
    def.read = function(row)
        local e = entryOf(row)
        return e and tonumber(e[col]) or 0
    end
    def.write = function(row, v)
        local e = entryOf(row)
        if e then e[col] = (v ~= 0) and v or nil end
    end
    return S.number(def)
end

local function foodBool(col)
    return S.bool({
        key = col,
        read = function(row)
            local e = entryOf(row)
            return e ~= nil and e[col] == true
        end,
        write = function(row, v)
            local e = entryOf(row)
            if e then e[col] = v == true or nil end
        end,
    })
end

local GILD_OPTIONS = { { value = 'none' }, { value = 'ring' }, { value = 'core' }, { value = 'both' } }

--- Gilding: goldXOuter (the ring) and goldXInner (the icon) as one choice
local function foodGild(col, outer, inner)
    return S.enum({
        key = col,
        options = GILD_OPTIONS,
        advanced = true,
        read = function(row)
            local e = entryOf(row)
            if not e then return 'none' end
            local o, i = (tonumber(e[outer]) or 0) > 0, (tonumber(e[inner]) or 0) > 0
            return (o and i and 'both') or (o and 'ring') or (i and 'core') or 'none'
        end,
        write = function(row, v)
            local e = entryOf(row)
            if not e then return end
            e[outer] = (v == 'ring' or v == 'both') and 1 or nil
            e[inner] = (v == 'core' or v == 'both') and 1 or nil
        end,
    })
end

local BUFF_OPTIONS = {
    { value = 'none' }, { value = 'health' }, { value = 'vegan' }, { value = 'energy' }, { value = 'vigor' }, { value = 'cowboy' },
}

local FX_OPTIONS = { { value = 'none' }, { value = 'PlayerDrunkSaloon1' }, { value = 'PlayerDrunkStrong' } }

local FOOD_COLUMNS = {
    foodNumber('hunger', { min = -50, max = 100, step = 1, integer = true, derived = { kind = 'needAfter', args = { need = 'hunger', start = 20 } } }),
    foodNumber('thirst', { min = -50, max = 100, step = 1, integer = true, derived = { kind = 'needAfter', args = { need = 'thirst', start = 20 } } }),
    foodNumber('stamina', { min = -100, max = 100, step = 1, integer = true }),
    foodNumber('innerHealth', { min = -100, max = 100, step = 1, integer = true }),
    foodNumber('outerHealth', { min = -300, max = 600, step = 5, integer = true, derived = { kind = 'healthPercent', args = { max = 600 } } }),
    S.enum({
        key = 'buffType',
        options = BUFF_OPTIONS,
        read = function(row)
            local e = entryOf(row)
            return e and type(e.buff) == 'table' and e.buff.type or 'none'
        end,
        write = function(row, v)
            local e = entryOf(row)
            if not e then return end
            if v == 'none' then
                e.buff = nil
            else
                e.buff = { type = v, amount = (type(e.buff) == 'table' and tonumber(e.buff.amount)) or 50 }
            end
        end,
    }),
    S.number({
        key = 'buffAmount', min = 0, max = 100, step = 5, integer = true,
        derived = { kind = 'buffTime', args = { type = 'buffType' } },
        read = function(row)
            local e = entryOf(row)
            return e and type(e.buff) == 'table' and (tonumber(e.buff.amount) or 50) or 0
        end,
        write = function(row, v)
            local e = entryOf(row)
            if e and type(e.buff) == 'table' then e.buff.amount = v end
        end,
    }),
    foodNumber('outerStamina', { min = 0, max = 100, step = 5, integer = true, advanced = true }),
    foodGild('goldHealth', 'goldHealthOuter', 'goldHealthInner'),
    foodGild('goldStamina', 'goldStaminaOuter', 'goldStaminaInner'),
    S.enum({
        key = 'fx',
        options = FX_OPTIONS,
        advanced = true,
        read = function(row)
            local e = entryOf(row)
            return e and e.fx or 'none'
        end,
        write = function(row, v)
            local e = entryOf(row)
            if e then e.fx = (v ~= 'none') and v or nil end
        end,
    }),
    S.number({
        key = 'fxTime', min = 0, max = 10, step = 0.5, advanced = true,
        read = function(row)
            local e = entryOf(row)
            if not e then return 0 end
            -- the client plays a drunk effect for 1 minute when the item names none
            return tonumber(e.fxTime) or (e.fx and 1 or 0)
        end,
        write = function(row, v)
            local e = entryOf(row)
            if e then e.fxTime = v end
        end,
    }),
    foodNumber('poison', { min = 0, max = 600, step = 1, integer = true, advanced = true }),
    foodBool('curesPoison'),
    foodBool('heal'),
}
FOOD_COLUMNS[#FOOD_COLUMNS - 1].advanced = true
FOOD_COLUMNS[#FOOD_COLUMNS].advanced = true

local FOOD_FAMILIES = {}
for id in pairs(FAMILY_ORDER) do FOOD_FAMILIES[#FOOD_FAMILIES + 1] = { id = id } end
table.sort(FOOD_FAMILIES, function(a, b) return FAMILY_ORDER[a.id] < FAMILY_ORDER[b.id] end)

local function foodRows()
    local list = {}
    for item, entry in pairs(Config.Consumables or {}) do
        if type(entry) == 'table' and item:match('^[%w_%-]+$') then
            list[#list + 1] = { id = item, family = familyOf(item, entry), locked = lockOf(entry) }
        end
    end
    table.sort(list, function(a, b)
        local fa, fb = FAMILY_ORDER[a.family] or 99, FAMILY_ORDER[b.family] or 99
        if fa ~= fb then return fa < fb end
        return a.id < b.id
    end)
    return list
end

-- ════════════════════════════════════════════════════════════════════════════
-- horse food (Config.HorseItems, replaced whole by use_rules.lua) and satchels
-- ════════════════════════════════════════════════════════════════════════════

local function horseColumn(col)
    return S.number({
        key = col, min = 0, max = 100, step = 1, integer = true,
        read = function(row)
            local h = (Config.HorseItems or {})[row]
            return h and type(h.effect) == 'table' and tonumber(h.effect[col]) or 0
        end,
        write = function(row, v)
            local h = (Config.HorseItems or {})[row]
            if not h then return end
            h.effect = type(h.effect) == 'table' and h.effect or {}
            h.effect[col] = (v ~= 0) and v or nil
        end,
    })
end

local function satchelRows()
    local list = {}
    for item, entry in pairs(Config.Satchels or {}) do
        if type(entry) == 'table' and item:match('^[%w_%-]+$') then list[#list + 1] = { id = item, rank = entry.rank or 0 } end
    end
    table.sort(list, function(a, b) return a.rank < b.rank end)
    for _, r in ipairs(list) do r.rank = nil end
    return list
end

-- ════════════════════════════════════════════════════════════════════════════
-- the definition
-- ════════════════════════════════════════════════════════════════════════════

local buffTick = { cfgPath('Buffs', 'TickInterval') }
local poisonTick = { cfgPath('Poison', 'Tick') }
local goldDuration = { msAsSeconds(cfgPath('Gold', 'Duration')) }
local animalDistance = { cfgPath('AnimalCare', 'Distance') }
local animalDuration = { msAsSeconds(cfgPath('AnimalCare', 'Duration')) }
local animalCooldown = { msAsSeconds(cfgPath('AnimalCare', 'Cooldown')) }

local function buffFields()
    local list = {
        central('number', 'buffs.tick', { min = 500, max = 10000, step = 100, integer = true, advanced = true,
            unit = 'settings.units.ms' }, buffTick[1], buffTick[2]),
    }
    local ranges = {
        health = { max = 60, step = 1 },
        vegan = { max = 10, step = 0.5 },
        energy = { max = 25, step = 1 },
        vigor = { max = 25, step = 1 },
        cowboy = { max = 2000, step = 50, advanced = true },
    }
    for _, kind in ipairs({ 'health', 'vegan', 'energy', 'vigor', 'cowboy' }) do
        local r = ranges[kind]
        local amountRead, amountWrite = cfgPath('Buffs', kind, 'amount')
        local drainRead, drainWrite = cfgPath('Buffs', kind, 'drain')
        list[#list + 1] = central('number', ('buffs.%s.amount'):format(kind),
            { min = 0, max = r.max, step = r.step, advanced = r.advanced }, amountRead, amountWrite)
        list[#list + 1] = central('number', ('buffs.%s.drain'):format(kind),
            { min = 0.5, max = 20, step = 0.5, advanced = true, derived = { kind = 'buffTime', args = { buff = kind } } },
            drainRead, drainWrite)
    end
    return list
end

local function systemField(key, restart)
    local read, write = cfgPath('Systems', key)
    return central('bool', 'systems.' .. key, { requiresRestart = restart or nil },
        function() return read() == true end, function(v) write(v == true) end)
end

WHudLive = S.define({
    resource = 'w_hud',
    version = 1,
    accessAce = Config.AdminAce or 'w_hud.admin',
    access = function(src)
        return type(WHudAdmin) == 'table' and WHudAdmin.isAdmin(src) == true
    end,
    links = {
        { id = 'hudmenu', command = 'hudmenu' },
    },
    groups = {
        -- ── own: the w_hud_server blob ────────────────────────────────────────
        {
            id = 'needs', store = 'own', clientVisible = true, apply = ownApply,
            fields = {
                own('number', 'needs.hungerRate', { min = 0, max = 25, step = 0.1, unit = 'settings.units.points',
                    derived = { kind = 'drainTime', args = { rate = 'needs.hungerRate', interval = 'needs.interval' } } }),
                own('number', 'needs.thirstRate', { min = 0, max = 25, step = 0.1, unit = 'settings.units.points',
                    derived = { kind = 'drainTime', args = { rate = 'needs.thirstRate', interval = 'needs.interval' } } }),
                own('number', 'needs.interval', { min = 5, max = 1800, step = 1, integer = true, unit = 'settings.units.s' }),
            },
        },
        {
            id = 'damage', store = 'own', clientVisible = true, apply = ownApply,
            fields = {
                own('bool', 'damage.enabled', {}),
                own('number', 'damage.hungerAt', { min = 0, max = 99, step = 1, integer = true }),
                own('number', 'damage.thirstAt', { min = 0, max = 99, step = 1, integer = true }),
                own('number', 'damage.amount', { min = 0.5, max = 25, step = 0.5, unit = 'settings.units.percent' }),
                own('number', 'damage.interval', { min = 3, max = 600, step = 1, integer = true, unit = 'settings.units.s',
                    derived = { kind = 'deathTime', args = { amount = 'damage.amount', interval = 'damage.interval', enabled = 'damage.enabled', canKill = 'damage.canKill' } } }),
                own('bool', 'damage.canKill', {}),
            },
        },
        {
            id = 'features', store = 'own', clientVisible = true, apply = ownApply,
            fields = (function()
                local list = {}
                for _, id in ipairs(FEATURES) do list[#list + 1] = own('bool', 'features.' .. id, {}) end
                return list
            end)(),
        },
        {
            id = 'identity', store = 'own', clientVisible = true, apply = ownApply,
            fields = {
                own('text', 'identity.name', { maxLength = 48 }),
                own('text', 'identity.logoUrl', { maxLength = 400, validate = safeUrl }),
                own('number', 'identity.logoWidth', { min = 2, max = 160, step = 1, unit = 'settings.units.rem' }),
                own('number', 'identity.logoHeight', { min = 0, max = 160, step = 1, unit = 'settings.units.rem' }),
                own('number', 'identity.x', { min = -20, max = 120, step = 0.1, unit = 'settings.units.percent', advanced = true }),
                own('number', 'identity.y', { min = -20, max = 120, step = 0.1, unit = 'settings.units.percent', advanced = true }),
                own('number', 'identity.scale', { min = 0.4, max = 3, step = 0.05, advanced = true }),
                own('number', 'identity.opacity', { min = 0.15, max = 1, step = 0.05, advanced = true }),
            },
        },

        -- ── central: Config, changed in place ─────────────────────────────────
        {
            id = 'food', store = 'central', clientVisible = true,
            rows = foodRows,
            describe = describeItem,
            columns = FOOD_COLUMNS,
            families = FOOD_FAMILIES,
            -- a buff strength needs a buff: the amount of 'none' is not a value anybody can see
            checkRow = function(_, cells, changed)
                if cells.buffType == 'none' and changed.buffAmount and (cells.buffAmount or 0) ~= 0 then
                    return 'bad_type'
                end
                return nil
            end,
        },
        {
            id = 'buffs', store = 'central', clientVisible = true,
            fields = buffFields(),
        },
        {
            id = 'poison', store = 'central', clientVisible = true,
            fields = (function()
                local enabledRead, enabledWrite = cfgPath('Poison', 'Enabled')
                local damageRead, damageWrite = cfgPath('Poison', 'Damage')
                local minRead, minWrite = cfgPath('Poison', 'MinHealth')
                local drainRead, drainWrite = cfgPath('Poison', 'StaminaDrain')
                local fxRead, fxWrite = cfgPath('Poison', 'Fx')
                return {
                    central('bool', 'poison.enabled', {}, function() return enabledRead() ~= false end, enabledWrite),
                    central('number', 'poison.damage', { min = 0, max = 60, step = 1, integer = true }, damageRead, damageWrite),
                    central('number', 'poison.minHealth', { min = 0, max = 600, step = 5, integer = true }, minRead, minWrite),
                    central('number', 'poison.staminaDrain', { min = 0, max = 20, step = 1, integer = true }, drainRead, drainWrite),
                    central('number', 'poison.tick', { min = 500, max = 10000, step = 100, integer = true, advanced = true,
                        unit = 'settings.units.ms' }, poisonTick[1], poisonTick[2]),
                    central('enum', 'poison.fx', { advanced = true, options = { { value = 'PlayerPoisoned' }, { value = 'PlayerHealthLow' }, { value = '' } } },
                        function() return fxRead() or '' end, fxWrite),
                }
            end)(),
        },
        {
            id = 'gold', store = 'central', clientVisible = true,
            fields = {
                central('number', 'gold.duration', { min = 5, max = 300, step = 1, unit = 'settings.units.s' }, goldDuration[1], goldDuration[2]),
            },
        },
        {
            -- server only: w_stables applies and saves the effect on the horse
            id = 'horse', store = 'central', clientVisible = false,
            rows = function()
                local list = {}
                for item in pairs(Config.HorseItems or {}) do
                    if item:match('^[%w_%-]+$') then list[#list + 1] = { id = item } end
                end
                table.sort(list, function(a, b) return a.id < b.id end)
                return list
            end,
            describe = describeItem,
            columns = { horseColumn('hunger'), horseColumn('stamina'), horseColumn('health') },
        },
        {
            id = 'animals', store = 'central', clientVisible = true,
            fields = {
                central('number', 'animals.distance', { min = 1, max = 6, step = 0.5, unit = 'settings.units.m' }, animalDistance[1], animalDistance[2]),
                central('number', 'animals.cooldown', { min = 0, max = 600, step = 1, unit = 'settings.units.s' }, animalCooldown[1], animalCooldown[2]),
                central('number', 'animals.duration', { min = 2, max = 15, step = 0.5, unit = 'settings.units.s', advanced = true }, animalDuration[1], animalDuration[2]),
            },
        },
        {
            -- server only; a change rewrites every character who owns that satchel (confirmed first)
            id = 'satchels', store = 'central', clientVisible = false,
            rows = satchelRows,
            describe = describeItem,
            columns = {
                S.number({
                    key = 'bonus', min = 0, max = 200, step = 1, integer = true, unit = 'settings.units.kg',
                    derived = { kind = 'kg', args = { base = 30 } },
                    read = function(row)
                        local s = (Config.Satchels or {})[row]
                        return s and math.floor((tonumber(s.bonus) or 0) / 1000 + 0.5) or 0
                    end,
                    write = function(row, v)
                        local s = (Config.Satchels or {})[row]
                        if s then s.bonus = math.floor(v * 1000) end
                    end,
                }),
            },
            onChange = function(changes)
                if type(WHudSatchels) ~= 'table' then return end
                for _, c in ipairs(changes) do
                    local s = (Config.Satchels or {})[c.row]
                    if s then WHudSatchels.setRankBonus(s.rank, s.bonus) end
                end
            end,
        },
        {
            id = 'systems', store = 'central', clientVisible = true,
            fields = {
                systemField('buffs', false),
                systemField('consumables', true),
                systemField('horseCare', true),
            },
        },
    },
})
