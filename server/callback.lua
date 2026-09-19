-- Is a character actually selected? (the server is the authority.) Keeps the HUD
-- off the character-selection screen: while selecting, no character is loaded, so
-- FwGetCharacterIdentifier returns nil -> false.
w.callback.register('w_hud:server:isCharLoaded', function(source)
    local ok, cid = pcall(function() return exports.w_lib:FwGetCharacterIdentifier(source) end)
    return ok and cid ~= nil and cid ~= false
end)

-- Telegrams (mail) are RSG-only -- returns 0 elsewhere. Via w.callback + the w_lib identifier.
-- Resource-prefixed name: w_lib's registry keeps one owner per callback name.
w.callback.register('w_hud:server:getTelegramsAmount', function(source)
    if exports.w_lib:FwName() ~= 'rsgcore' then return 0 end
    local cid = exports.w_lib:FwGetCharacterIdentifier(source)
    if not cid then return 0 end
    local result = MySQL.prepare.await(
        'SELECT COUNT(*) FROM telegrams WHERE citizenid = ? AND (status = ? OR birdstatus = ?)', { cid, 0, 0 })
    return result or 0
end)
