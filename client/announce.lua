-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · client/announce.lua                                              2.1.0
-- The announcement under the compass: what server/announce.lua sends, handed to the page
-- (web/src/Announcement.tsx) with the game's own chime.
--
--   exports.w_hud:ShowAnnouncement(text, seconds, title)   this player only (no server state)
--   exports.w_hud:ClearAnnouncement()                       this player only
--
-- ★ The page owns the timer: it is told how many seconds, shows the shard for exactly that long
--   and fades it out. No native has a duration ceiling to work around here, because nothing is
--   posted to the game's feed -- its font has no Arabic letters.
-- ════════════════════════════════════════════════════════════════════════════

-- The game's own "news" chime (Ledger_Sounds/INFO_SHOW, the one w_lib's notices play).
local SOUND, SOUNDSET = 'INFO_SHOW', 'Ledger_Sounds'
local localSeq = 0

---@param p table { id, title?, text, seconds }
local function show(p, silent)
    if type(p) ~= 'table' or type(p.text) ~= 'string' or p.text == '' then return end
    local secs = tonumber(p.seconds)
    if not secs or secs ~= secs then secs = 10 end
    secs = math.max(1, math.min(secs, 1800))
    SendNUIMessage({
        action = 'announce',
        id = p.id,
        title = type(p.title) == 'string' and p.title or nil,
        text = p.text,
        seconds = secs,
    })
    if not silent then PlaySoundFrontend(SOUND, SOUNDSET, true, 0) end
end

RegisterNetEvent('w_hud:client:announce', function(p) show(p) end)
RegisterNetEvent('w_hud:client:announceClear', function()
    SendNUIMessage({ action = 'announce:clear' })
end)

-- A page that has just come up (join, w_hud restart) shows the running announcement for the
-- time it has left -- quietly: the chime belongs to the moment it was sent.
AddEventHandler('w_hud:client:pageReady', function()
    CreateThread(function()
        local ok, p = pcall(w.callback.await, 'w_hud:server:announcement', false)
        if ok and type(p) == 'table' then show(p, true) end
    end)
end)

exports('ShowAnnouncement', function(text, seconds, title)
    localSeq = localSeq - 1 -- negative ids: never equal to one the server numbered
    show({ id = localSeq, text = tostring(text or ''), seconds = seconds, title = title })
end)
exports('ClearAnnouncement', function()
    SendNUIMessage({ action = 'announce:clear' })
end)
