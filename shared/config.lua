Config                         = {}

----------------------------------
-- Language
--
-- There is no language setting here. The library (w_lib) owns the system language:
-- the server default is the convar `w_lib:locale` (ar | en) and each player may pick
-- their own in /w_lib. Every text this resource shows comes from locales/{ar,en}.json
-- through locale('key'); the React UI receives the strings and the text direction from
-- client/metabolism.lua (sendLocale) and re-renders on w_lib:setLocale.
----------------------------------

----------------------------------
-- Who may open the Admin section of the HUD panel
--
-- ★ One ACE node, checked on the server through exports.w_lib:HasPermissionNode: the
--   console always passes, framework admins (exports.w_lib:IsAdmin) pass, and so does
--   this exact ACE or a wildcard parent (w_hud.*, *). Put this in server.cfg:
--
--       add_ace group.admin w_hud.admin allow
--
-- ⚠️ Read on the **server**. What the client is told is only whether to draw the
--   section; whether a save is honoured is decided again server-side.
----------------------------------
Config.AdminAce                = 'w_hud.admin'

----------------------------------
-- HUD control panel (the player's own layout and colours)
--
-- ★ The key that opens it. Leave it '' and the panel is reachable by /hudmenu only,
--   and the player can bind it themselves from the game's keybinding screen -- which is
--   the right choice on a server that has already spent every key it has.
--
-- ⚠️ Whatever is chosen here is a **default** binding: a player who rebinds it keeps
--   their choice, and changing this line will not take it from them.
----------------------------------
Config.HudMenuKey              = 'F7' -- '' = unbound; /hudmenu always works

----------------------------------
-- hud player display settings
----------------------------------
Config.HidePlayerHealthNative  = true
Config.HidePlayerStaminaNative = true
Config.HidePlayerDeadEyeNative = true

----------------------------------
-- hud horse display settings
----------------------------------
Config.HideHorseHealthNative   = true
Config.HideHorseStaminaNative  = true
Config.HideHorseCourageNative  = true

----------------------------------
-- telegrame check settings
----------------------------------
Config.TelegramCheck           = 5000 -- amount of milliseconds to check your telegrams

----------------------------------
-- minimap / compass settings
----------------------------------
Config.OnFootMinimap           = true  -- set to true/false to disable/enable minimap when on foot
Config.OnFootCompass           = false -- true = have the minimap set to a compass instead of off or normal minimap
Config.MounttMinimap           = true  -- set to false if you want to disable the minimap when on mount
Config.MountCompass            = false -- set to true if you want to have a compass instead of normal minimap while on a mount

----------------------------------
-- turn health damage on/off
----------------------------------
Config.DoHealthDamage          = false

----------------------------------
-- turn screen effect on/off
----------------------------------
Config.DoHealthDamageFx        = false

----------------------------------
-- turn health damage sound on/off
----------------------------------
Config.DoHealthPainSound       = true

----------------------------------
-- temp settings (only one setting)
----------------------------------
Config.TempFormat              = 'celsius'
--Config.TempFormat = 'fahrenheit'

-- ⚠️ Disabled every frame (client/thread.lua). INPUT_TOGGLE_WEAPON_SCOPE must NOT be in
--    this list: it is the key that enters the scope view, and client/scope.lua presses it
--    for the player (Config.AutoScope). With it disabled no scoped rifle could ever zoom.
-- ⚠️ 2026-09-18: INPUT_SPECIAL_ABILITY_SECONDARY (the right mouse button / LT) is OUT of this
--    list. /sstrace showed SS-Stable's client polling IsControlPressed on exactly that control
--    every frame beside its wagon, and /hudbisect keys off brought its stash / send-away prompts
--    back: a disabled control reads as never pressed and hides the prompts bound to it. Nothing
--    in w_hud needs it disabled. (/hudkeys in F8 switches any single entry off at runtime.)
Config.KeysDisabled            = {
    `INPUT_NEXT_WEAPON`,
    `INPUT_SELECT_PREV_WEAPON`,
    `INPUT_PREV_WEAPON`,
    -- `INPUT_SPECIAL_ABILITY_SECONDARY`, -- see above: SS-Stable's wagon prompts depend on it
    `INPUT_QUICK_SHORTCUT_ABILITIES_MENU`,
    `INPUT_RADIAL_MENU_SLOT_NAV_NEXT`,
    `INPUT_CARRIABLE_SUICIDE`,
    `INPUT_INTERROGATE_RELEASE`,
}

-- ★ The game's own ammo counter is hidden by client/ammo.lua through the HUD context
--    HUD_CTX_INFINITE_AMMO (1058184710 = 0x3F129E06), per frame while a gun is in hand; the
--    context is switched off again the moment the gun is put away. (SS-Stable's wagon prompts
--    were hidden by a disabled control, see Config.KeysDisabled below -- not by this.)
--    false = never hide it.
Config.HideNativeAmmoCounter   = true

----------------------------------
-- warmth add while wearing
----------------------------------
Config.WearingHat              = 0
Config.WearingShirt            = 0
Config.WearingPants            = 0
Config.WearingBoots            = 0
Config.WearingCoat             = 15
Config.WearingOpenCoat         = 15
Config.WearingGloves           = 0
Config.WearingVest             = 0
Config.WearingPoncho           = 0
Config.WearingSkirt            = 0
Config.WearingChaps            = 0

----------------------------------
-- warmth limit before impacts health
----------------------------------
Config.MinTemp                 = -5
Config.MaxTemp                 = 40

----------------------------------
-- cleanliness limit before impacts health
----------------------------------
Config.FlyEffect               = false -- toggle flies on/off
Config.MinCleanliness          = 30

----------------------------------
-- amount of health to remove if min/max temp reached
----------------------------------
Config.RemoveHealth            = 5

----------------------------------
-- hunger / thirst decrease settings
-- 100 points ÷ 1 per tick = 100 ticks × 144 seconds = 14400 seconds = 240 minutes (4 hours)
----------------------------------
Config.HungerDecreaseRate      = 1    -- amount to decrease hunger each interval
Config.ThirstDecreaseRate      = 1    -- amount to decrease thirst each interval
Config.NeedsDecreaseInterval   = 144  -- interval in seconds between each decrease (144s × 100 = 4 hours)

----------------------------------
-- hunger / thirst health damage settings
----------------------------------
Config.HungerThirstDamage      = true  -- enable health damage when hungry/thirsty
Config.HungerDamageThreshold   = 5     -- start damage when hunger below this value
Config.ThirstDamageThreshold   = 5     -- start damage when thirst below this value
Config.NeedsDamageAmount       = 1     -- health to remove each tick (very small)
Config.NeedsDamageInterval     = 15000 -- ms between each damage tick (15 seconds)

-- ★ Config.Intensity and Config.EffectInterval went out with the stress system --
--   they were its shake-strength and shake-duration tables; nothing reads them now.

-- All framework access goes through w.framework / exports.w_lib; no core object is read here.

Config.EnableMail    = false                 -- RSG telegrams/mail only (enable on RSG servers)
Config.HiddenCoords  = vector3(-1000.0, -3000.0, 100.0) -- temporary hide coordinate (RSG.HiddenCoords fix)

----------------------------------
-- Auto scope (client/scope.lua)
--   true: aiming a rifle that carries a scope (or a Carcano / Rolling Block, scoped by
--   design) enters the scope view by itself -- no mouse wheel, no toggle key.
--   false: the game's own behaviour (aim, then press the scope key).
----------------------------------
Config.AutoScope               = true
-- (AutoScopeRetryMs is gone: the scope key is pressed once per aim, and only repeated -- at most
--  twice -- while the camera's field of view says the scope has not opened. See client/scope.lua.)
