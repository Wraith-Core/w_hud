-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- needs configuration
--   Hunger · thirst · buffs · horse care · voice level
--
-- Every need here is on a 0-100 scale, and the server is the authority over it
-- (server/metabolism.lua). The client reads the broadcast values and applies the
-- effect to the ped only.
--
-- ★ The stress, toxicity, bladder and bowel systems were removed entirely at the
--   owner's request. They were not left switched off behind flags: dead code that is
--   merely disabled still gets read, still gets maintained, and still confuses whoever
--   comes next.
--
-- ★ Loaded immediately after shared/config.lua. Every label here is a dictionary key
--   (locales/{ar,en}.json) resolved with locale() where it is shown.
-- ════════════════════════════════════════════════════════════════════════════

----------------------------------
-- 1. System switches
----------------------------------
Config.Systems = {
    buffs       = true, -- the buff system
    horseCare   = true, -- horse-care items (feed/stamina/brush)
    consumables = true, -- registering food and drink items with w_inventory
}

----------------------------------
-- 2. The buff system
--   Each buff is 0-100, decays over time, and its effect is applied every tick.
--   Granted from the `buff` field in shared/consumables.lua, or by the events below.
--
--   From another script (client):  TriggerEvent('w_hud:client:giveBuff', 'health', 50)
--   From the server:               exports.w_hud:GiveBuff(src, 'health', 50)
--
-- ★ The `calm` buff went out with the stress system: its only effect was lowering
--   stress, so once that was gone it became a buff with no effect.
----------------------------------
Config.Buffs = {
    TickInterval = 2000, -- the tick that applies every buff

    health = { -- health regeneration (medicine)
        label  = 'buff.health',
        drain  = 2,   -- how much the buff decays each tick
        amount = 10,  -- how much health is added each tick (RDR scale)
        color  = '#e05555',
    },
    cowboy = { -- horse stamina (moonshine)
        label  = 'buff.cowboy',
        drain  = 1,
        amount = 1000.0, -- how much stamina is added to the last horse ridden
        color  = '#c9a227',
    },
    vegan = { -- hunger and thirst regeneration (stew/vegetables)
        label  = 'buff.vegan',
        drain  = 1,
        amount = 2,   -- added to hunger and thirst alike each tick
        color  = '#5fa85f',
    },
    energy = { -- player stamina regeneration (coffee/sugar)
        label  = 'buff.energy',
        drain  = 1,
        amount = 5,   -- the inner stamina core (0-100)
        color  = '#d98c2b',
    },
    vigor = { -- inner health-core regeneration (roasted meat)
        label  = 'buff.vigor',
        drain  = 1,
        amount = 3,
        color  = '#b0563a',
    },
}

----------------------------------
-- 3. Voice -- four levels on the mouse wheel
--
-- ★ pma-voice has only three levels and exports no function to set a specific one
--   (mode is an internal variable of its own, and cycleproximity only cycles forward).
--   So instead of editing an external resource we own the levels here and push the
--   distance into it through its declared overrideProximityRange export. Not one line
--   of pma-voice is touched.
----------------------------------
Config.Voice = {
    Enabled       = true,
    ScrollControl = true, -- the mouse wheel changes the level
    Default       = 2,    -- the level on login

    -- Distance in game units. Keep them ascending -- the UI fills the core in proportion.
    Levels = {
        { label = 'voice.whisper', distance = 3.0 },
        { label = 'voice.normal', distance = 7.0 },
        { label = 'voice.loud', distance = 12.0 },
        { label = 'voice.shouting', distance = 18.0 },
    },
}

----------------------------------
-- 4. Horse care
----------------------------------
Config.HorseCare = {
    MaxDistance = 3.0,  -- the furthest distance at which use is accepted (metres)
    FeedTime    = 5000, -- duration of the feeding animation
    BrushTime   = 8000, -- duration of the brushing animation
}

----------------------------------
-- 4b. Gilding (overpower)
--
-- ★ How long our own cores keep the gold after a tonic. It is a setting rather than the
--   item's own number because those numbers are engine magnitudes, not seconds: one item
--   carries 30/10 and another 1000/500. (Detail in client/consumables.lua.)
--
--   The item still decides *what* is gilded: goldHealthOuter gilds the ring, and
--   goldHealthInner gilds the icon with it -- so 'outer only' is a half gilding and
--   'both' is a full one.
Config.Gold = {
    Duration = 30000, -- ms
}

----------------------------------
-- 4c. التسمُّم — حالةٌ مؤقّتة لا حاجةٌ دائمة
--
-- ═══ لماذا مؤقّتة ═══
--
-- الجوع والعطش حاجتان: قيمتان تُحفظان في قاعدة البيانات وتنقصان أبداً. والتسمُّم
-- ليس كذلك — هو **ما جرى لك قبل قليل**: تأكل لحماً فاسداً فتمرض دقيقة ثمّ تُشفى.
-- فحفظُه عموداً في الجدول يعني لاعباً يخرج من السيرفر مسموماً ويعود مسموماً بعد
-- أسبوع، وهو ما لا يتوقّعه أحد.
--
-- فهو مؤقّتٌ في ذاكرة العميل، ينتهي بانتهاء مدّته أو بالترياق أو بالموت.
--
-- ═══ ما يراه اللاعب ═══
--
-- قلبُ الهود يخضرّ ويتصاعد منه دخانٌ عفن (web/src/App.tsx و hud.css)، وضربةٌ
-- كلّ Tick تُنقص صحّته. والترياق منقوع الأعشاب — curesPoison في consumables.
--
-- ⚠️ ولا يقتل: يقف عند MinHealth. سمٌّ يقتل من تلقاء نفسه يعني موتاً لا يملك
--   اللاعب دفعه بعد أن أكل، وهو عقابٌ لا لعبة. اجعله 0 إن أردته قاتلاً.
----------------------------------
Config.Poison = {
    Enabled   = true,
    Tick      = 2000,  -- ms بين ضربةٍ وأخرى
    Damage    = 12,    -- ما تُنقصه كلّ ضربة من الصحّة (مقياس RDR ٠-٦٠٠)
    MinHealth = 60,    -- لا تنزل الصحّة تحته بالسمّ (0 = يقتل)

    -- مؤثّر الشاشة ما دام مسموماً. '' = بلا مؤثّر.
    -- ★ من طقم اللعبة نفسه، والاسم في KNOWN_FX في client/consumables.lua.
    Fx        = 'PlayerPoisoned',

    -- كور الستامينا يُستنزف معه: المسموم لا يجري.
    StaminaDrain = 3, -- كلّ ضربة، على مقياس ٠-١٠٠
}

-- 5. State colour thresholds
--
-- ★ RDR's language is three colours and no more: white for the normal state, yellow
--   for warning, red for danger. The colour says the **state**, not the **kind of
--   need** -- the kind is said by its icon. Which is why there is no per-need colour.
--
-- ★ All of our needs now drain and never fill, so one threshold each is enough.
--   (warnHigh/dangerHigh existed for needs that filled up -- they went with them.)
----------------------------------
Config.Thresholds = {
    warnLow   = 40, -- yellow on falling to
    dangerLow = 20, -- red on falling to
}

----------------------------------
-- 6. Displaying needs in the UI
--   ★ This is the layer the player settings panel will read later.
--
--   show      whether it appears at all
--   color     colour of the ring and icon (empty = white, and the state overrides it)
--   alwaysOn  always visible
--   showBelow if not alwaysOn: only appears below this value
----------------------------------
Config.Display = {
    health    = { show = true, alwaysOn = true },
    stamina   = { show = true, alwaysOn = true },
    hunger    = { show = true, alwaysOn = true },
    thirst    = { show = true, alwaysOn = true },

    -- Horse: one key for health and stamina together (both appear only while mounted)
    horse     = { show = true },

    buffs     = { show = true, alwaysOn = false },
}
