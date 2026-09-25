-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · server/purge.lua
-- A deleted character leaves nothing here, so its citizen id can be handed to someone else.
--
--   exports.w_hud:PurgeCharacter(citizenid, ctx) -> true, { [table] = rows, ... } | false, reason
--
--   Called by w_core from a server thread, with the character offline (w_core kicks the
--   player and waits for the logout save first). Everything w_hud keeps for a character is
--   that character's own data -- its needs, its satchel upgrade, its HUD layout, and the RSG
--   telegrams the HUD counts -- so everything is deleted. Nothing here is money, an asset
--   others see, or history.
--
-- ★ One transaction: the rows go together or not at all. A second call finds nothing and
--   answers true with an empty report.
-- ★ The caches are keyed by server id, not by character. metabolism.lua and satchels.lua each
--   register a hook in WHudPurge that drops what they hold for this citizen id: a deletion
--   from the character selection leaves the player connected, holding the dead character's
--   state in memory until their next login.
-- ════════════════════════════════════════════════════════════════════════════

WHudPurge = WHudPurge or {}

--- Every table that holds a citizen id, and its column.
--- ★ Each is looked up before it is touched. Ours are created by a boot thread and telegrams
---   belongs to the RSG mail resource (absent on most servers): a DELETE on a missing table
---   would roll the whole transaction back and the character's rows would survive.
local TABLES = {
    { 'w_hud_needs',    'cid' },
    { 'w_hud_satchels', 'cid' },
    { 'w_hud_settings', 'cid' },
    { 'telegrams',      'citizenid' },
}

--- The citizen id as the tables store it: a non-empty string without spaces.
--- ⚠️ A number from another resource may arrive as a float (12.0): written as '%d', never '12.0'.
---@param id any
---@return string|nil
local function normalize(id)
    if type(id) == 'number' and id == math.floor(id) then id = ('%d'):format(id) end
    if type(id) ~= 'string' or id == '' or #id > 64 or id:find('[%s%c]') then return nil end
    return id
end

---@param name string
---@return boolean
local function tableExists(name)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
    return (tonumber(n) or 0) > 0
end

exports('PurgeCharacter', function(citizenid, ctx)
    -- only w_core deletes characters: any other caller could wipe a live character's needs
    if GetInvokingResource() ~= 'w_core' then return false, 'forbidden' end
    local cid = normalize(citizenid)
    if not cid then return false, 'invalid_id' end

    local report, queries = {}, {}

    local ok, err = pcall(function()
        for _, t in ipairs(TABLES) do
            local name, column = t[1], t[2]

            if tableExists(name) then
                local n = tonumber(MySQL.scalar.await(
                    ('SELECT COUNT(*) FROM `%s` WHERE `%s` = ?'):format(name, column), { cid })) or 0

                if n > 0 then
                    report[name] = n
                    queries[#queries + 1] = {
                        query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(name, column), values = { cid } }
                end
            end
        end
    end)

    if not ok then
        w.print.error(('PurgeCharacter %s: %s'):format(cid, tostring(err)))
        return false, 'database'
    end

    if #queries > 0 then
        local called, done = pcall(MySQL.transaction.await, queries)
        if not called or done ~= true then
            w.print.error(('PurgeCharacter %s: the deletion was rolled back (%s)'):format(cid, tostring(done)))
            return false, 'database'
        end
    end

    -- After the rows, not before: a refused deletion keeps the player's state as it was.
    local dropped = 0
    for _, forget in pairs(WHudPurge) do
        local okF, n = pcall(forget, cid)
        if okF then dropped = dropped + (tonumber(n) or 0) end
    end
    if dropped > 0 then report.cache = dropped end

    return true, report
end)
