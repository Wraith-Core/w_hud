-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · server/announce.lua                                              2.1.0
-- One announcement service for the whole server: a message to every player, drawn at the top
-- centre under the compass (client/announce.lua -> web/src/Announcement.tsx), for as long as
-- the sender asked.
--
-- ═══ The API (server exports; only server code can call them) ═══
--
--   exports.w_hud:Announce(text, seconds, opts) -> ok, err
--       text     string   the message (control characters and ~game tokens~ removed,
--                         at most Config.Announce.MaxText letters)
--       seconds  number?  how long it stays, clamped to MinSeconds..MaxSeconds
--                         (nil -> DefaultSeconds)
--       opts     table?   { title = string?  (a short line above; nil -> "إعلان" / "Announcement"),
--                           target = number? (one player's server id; nil -> everyone),
--                           by = string?     (who sent it, for the console line) }
--       err      'empty' | 'bad_target'
--
--   exports.w_hud:ClearAnnouncement()          takes the current one off every screen
--   exports.w_hud:SplitDuration(text) -> seconds|nil, rest
--       "5m text" / "30s text" / "5د text" / "30ث text" -> 300, "text". A chat command's optional
--       first word; a message that does not start with one comes back whole.
--
-- ═══ What is trusted ═══
--
--   ⚠️ Nothing here checks a permission: an export is reachable from server code only, and every
--     caller (w_admin, w_chat, w_connector, wraith_cinema) checks its own admin rights first.
--     There is deliberately no net event a client can fire to announce.
--
--   ★ The newest announcement replaces the one on screen; one to everyone is also kept here until
--     it ends, so a player who joins (or restarts the HUD) during a 20-minute event notice still
--     sees it for the time that is left.
-- ════════════════════════════════════════════════════════════════════════════

local CFG = Config.Announce or {}
local DEFAULT_S = tonumber(CFG.DefaultSeconds) or 10
local MIN_S = tonumber(CFG.MinSeconds) or 3
local MAX_S = tonumber(CFG.MaxSeconds) or 1800
local MAX_TEXT = tonumber(CFG.MaxText) or 300
local MAX_TITLE = tonumber(CFG.MaxTitle) or 60

local EV_SHOW = 'w_hud:client:announce'
local EV_CLEAR = 'w_hud:client:announceClear'
local CB_CURRENT = 'w_hud:server:announcement'

--- The announcement to everyone that is still running: { payload, endsAt (GetGameTimer ms) }.
local current = nil
local seq = 0

--- A clean single line of at most `max` letters, or nil when nothing is left.
--- ⚠️ Cut by letters (utf8), never by bytes: a byte cut splits an Arabic letter in two and the
---    page draws a broken glyph at the end. Invalid UTF-8 is refused outright.
---@param s any
---@param max number
---@return string|nil
local function clean(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%z\1-\31\127]', ' ')       -- control characters (a new line included) -> a space
    s = s:gsub('%^%d', '')                  -- chat colour codes ^0-^9
    s = s:gsub('~[^~ ]*~', '')              -- the game's ~COLOR_X~ / ~e~ markup
    -- ⚠️ a plain ' ', never %s: %s follows the C locale, and under a Latin-1 one it matches the
    --    bytes 0x85 / 0xA0 -- the second byte of Arabic letters such as م -- and would cut them
    s = s:gsub(' +', ' '):gsub('^ ', ''):gsub(' $', '')
    if s == '' then return nil end
    local n = utf8.len(s)
    if not n then return nil end
    if n > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

--- Whole seconds inside the allowed range; nil / NaN / infinity / a string -> the default.
---@param v any
---@return integer
local function duration(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return DEFAULT_S end
    v = math.floor(v + 0.5)
    if v < MIN_S then return MIN_S end
    if v > MAX_S then return MAX_S end
    return v
end

---@param text string
---@param seconds number|nil
---@param opts table|nil
---@return boolean ok, string|nil err
local function Announce(text, seconds, opts)
    opts = type(opts) == 'table' and opts or {}
    local body = clean(text, MAX_TEXT)
    if not body then return false, 'empty' end

    local target = -1
    if opts.target ~= nil then
        target = tonumber(opts.target)
        if not target or target ~= math.floor(target) or (target ~= -1 and not GetPlayerName(target)) then
            return false, 'bad_target'
        end
    end

    local secs = duration(seconds)
    seq = seq + 1
    local payload = { id = seq, title = clean(opts.title, MAX_TITLE), text = body, seconds = secs }

    if target == -1 then
        current = { payload = payload, endsAt = GetGameTimer() + secs * 1000 }
    end
    TriggerClientEvent(EV_SHOW, target, payload)

    print(('[w_hud] announcement #%d to %s for %ds%s: %s'):format(seq, target == -1 and 'everyone' or ('player ' .. target),
        secs, type(opts.by) == 'string' and (' by ' .. opts.by) or '', body:sub(1, 120)))
    return true
end

local function ClearAnnouncement()
    current = nil
    TriggerClientEvent(EV_CLEAR, -1)
    print('[w_hud] announcement cleared')
    return true
end

--- Units a chat command may put after the number: seconds or minutes, in English or Arabic.
local UNIT = { s = 1, sec = 1, m = 60, min = 60, ['ث'] = 1, ['د'] = 60 }

---@param text any
---@return integer|nil seconds, string rest
local function SplitDuration(text)
    if type(text) ~= 'string' then return nil, '' end
    local amount, unit, rest = text:match('^ *([0-9]+)([^ ]+) +(.+)$') -- ' ' not %s: see clean()
    -- ⚠️ the exact unit first: string.lower follows the C locale and may rewrite the bytes of an
    --    Arabic letter (it did under a Latin-1 locale), so only an ASCII unit is lowered
    local mult = unit and (UNIT[unit] or (not unit:find('[\128-\255]') and UNIT[unit:lower()]) or nil)
    if not amount or not mult then return nil, text end
    return tonumber(amount) * mult, rest
end

exports('Announce', Announce)
exports('ClearAnnouncement', ClearAnnouncement)
exports('SplitDuration', SplitDuration)

--- What a page that has just come up should show: the running announcement with the time left.
w.callback.register(CB_CURRENT, function()
    if not current then return nil end
    local left = math.floor((current.endsAt - GetGameTimer()) / 1000)
    if left < 1 then current = nil; return nil end
    local p = current.payload
    return { id = p.id, title = p.title, text = p.text, seconds = left }
end)
