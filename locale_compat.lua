-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- translation compatibility shim: defines Locale/Lang the way rsg-core did
-- (after dropping @rsg-core/shared/locale.lua) so locales/*.lua still load cleanly
-- and Lang:t keeps working on every framework through w_lib.
-- ════════════════════════════════════════════════════════════════════════════
if not Locale then
    Locale = {}
    Locale.__index = Locale

    function Locale:new(opts)
        local o = setmetatable({}, Locale)
        o.phrases = (opts and opts.phrases) or {}
        o.fallback = opts and opts.fallbackLang
        return o
    end

    function Locale:t(key, ...)
        local cur = self.phrases
        for part in tostring(key):gmatch('[^%.]+') do
            if type(cur) ~= 'table' then cur = nil; break end
            cur = cur[part]
        end
        if cur == nil and self.fallback then return self.fallback:t(key, ...) end
        if type(cur) == 'string' then
            local args = { ... }
            if #args > 0 then
                return (cur:gsub('%%s', function() return tostring(table.remove(args, 1) or '') end))
            end
            return cur
        end
        return key
    end
end
