-- ============================================================
-- w_hud · shared/wheel.lua
-- The weapon wheel -- configuration and static data
--
-- ═══ Why a separate file ═══
--
-- config.lua is the HUD's business (cores, compass, metabolism), and this wheel is a
-- system in its own right: a layout, a press cadence, and a stats table for every weapon
-- in the game. Mixing them meant a thousand-line file in which a server owner could not
-- find what they were looking for.
--
-- ═══ What the inventory owns and what the wheel owns ═══
--
-- w_inventory alone knows: what is in the bag, each weapon's reserve, its condition, and
-- which hand holds it. All of it read in one call: exports.w_inventory:getWeaponWheelState().
--
-- And the wheel owns: where each weapon is drawn, how its stats are read, and which key
-- opens it. So the classification lives here, not there -- written into the inventory it
-- would need editing every time the server wanted a different ordering.
-- ============================================================

Wheel = {}

----------------------------------------------------------------
-- Switches
----------------------------------------------------------------

--- false = our wheel disappears and the game's own wheel returns in its place.
Wheel.Enabled = false

--- ═══ The two press sources ═══
---
--- ★ OpenKey -- the DEFAULT key of a named keybind (w.addKeybind -> RegisterKeyMapping),
---   so it shows up in Settings > Key Bindings and the player can rebind it. This is the
---   source of record; see bindOpenKey in client/wheel.lua.
---
--- ★ OpenControl -- the game's wheel control. We read it too, for two indispensable reasons:
---     1) we disable it every frame, or the game's wheel appears under ours
---     2) the gamepad: a keyboard mapping cannot see L1/LB, so it arrives only through this
---
--- Key names accepted in OpenKey: any RegisterKeyMapping key name -- a letter ("Q"), a
--- digit ("5"), TAB/LSHIFT/LCONTROL/LMENU/SPACE/F1..F12 and the like.
Wheel.OpenKey = 'TAB'
Wheel.OpenControl = `INPUT_OPEN_WHEEL_MENU`

--- ═══ The game keys we silence ═══
---
--- ★ TAB in RDR2 is not one key but three on the same key:
---     INPUT_OPEN_WHEEL_MENU        the weapon wheel
---     OpenEmoteWheel        0xE2B557A3   the emote wheel -- the 'Emote Wheel' prompt
---     OpenEmoteWheelHorse   0x8B3FA65E   the horse emote wheel
---
---   So disabling the first alone hides the stock weapon wheel and leaves the emote wheel
---   and its prompt visible on top of ours. The hashes come from vorp_stables/keys.lua.
---
--- ⚠️ They are disabled every frame for as long as the wheel is enabled -- not only while
---   it is open: the prompt appears the moment a context allows it, before any press.
Wheel.BlockControls = {
    0xE2B557A3, -- OpenEmoteWheel
    0x8B3FA65E, -- OpenEmoteWheelHorse
}

--- Switching tab (weapons / items / horse) -- the R button in RDR2.
Wheel.TabControl = `INPUT_SELECT_NEXT_WEAPON`

--- Opening the Ability Loadout -- Space in RDR2 (triangle/Y on the pad).
Wheel.AbilityControl = `INPUT_JUMP`

----------------------------------------------------------------
-- Press cadence -- the difference between a tap and a hold
--
-- RDR2 distinguishes them: a hold opens the wheel, a tap draws the quick-select weapon,
-- and a double tap holsters. The threshold below is the dividing line -- shorter is a tap.
----------------------------------------------------------------

Wheel.HoldThreshold = 180  -- ms before a press counts as a 'hold' and opens the wheel
Wheel.DoubleTapWindow = 320 -- ms between two taps for them to count as a double tap (holster)

--- Is quick-select enabled? (tap = the assigned weapon · another tap = the previous one)
Wheel.QuickSelect = true

--- Holster the weapon on a quick double tap.
Wheel.DoubleTapHolster = true

----------------------------------------------------------------
-- Time dilation
--
-- ★ In story mode the game slows time rather than stopping it -- and this wheel is on a
--   multiplayer server, where SetTimeScale is local and slows only your own screen. So the
--   default is moderate: enough to choose with, and no advantage in a firefight.
--
--   1.0 = no dilation (Red Dead Online behaviour)
----------------------------------------------------------------

Wheel.TimeScale = 0.45
Wheel.TimeScaleInCombat = 1.0 -- no dilation while the player is targeted / firing

----------------------------------------------------------------
-- قفل النظر بعد الإغلاق
--
-- ═══ العطل ═══
--
-- تُغلق العجلة فتقفز الكاميرا. وعلى الحصان وحده يُرى ذلك واضحاً.
--
-- ═══ السبب ═══
--
-- العجلة تأخذ مؤشّراً حقيقيّاً وتترك المدخلات (SetNuiFocusKeepInput)، فمحورا
-- النظر يُعطَّلان كلّ إطارٍ ما دامت مفتوحة. لكنّ الماوس لم يتوقّف: هو يُحرّك
-- مؤشّر الواجهة. وفي اللحظة التي يُطلَق فيها التركيز يعود المحرّك يقرأ الماوس
-- من مكانه الجديد، فيصله فرقٌ كبيرٌ دفعةً واحدة.
--
-- وعلى القدمين رجّةٌ لا تكاد تُرى. وكاميرا الحصان كاميرا **تابعة** لها عطالة،
-- فتأخذ الدفعة وتُكملها — فتراها تدور.
--
-- ═══ العلاج ═══
--
-- لا يعود المحوران لحظةَ الإغلاق بل بعد مهلةٍ قصيرة. والفرق ليس مخزوناً
-- ينتظر: الماوس يُقرأ طازجاً كلّ إطار، فإطاراتٌ قليلةٌ معطَّلةٌ تبتلعه ويستقرّ
-- المؤشّر قبل أن يعود النظر.
--
-- 0 = بلا مهلة (السلوك القديم).
----------------------------------------------------------------

Wheel.LookLockAfterClose = 250 -- ms

--- محاور النظر التي تُعطَّل ما دامت العجلة مفتوحة وطوال المهلة بعدها.
--- ★ قائمةٌ لا ثابتان: من غيّر خريطة تحكّمه أو لعِب بدراعٍ قد يُحرّك الكاميرا
---   بمدخلٍ آخر، فيُضيفه هنا بلا لمس المحرّك.
Wheel.LookControls = { `INPUT_LOOK_LR`, `INPUT_LOOK_UD` }

----------------------------------------------------------------
-- Maintenance and cleaning from inside the wheel
----------------------------------------------------------------

--- The inspect/clean button on the hovered weapon (R3 in RDR2).
Wheel.InspectControl = `INPUT_CONTEXT_X`

Wheel.AllowCleaning = true

----------------------------------------------------------------
-- The wheel's slot range
--
-- ★ The wheel shows the **equipped loadout**, not the whole bag -- which is what RDR2 does.
--   And slots 1..5 are the quick bar in w_inventory itself (keys 1-5, and the `slot > 5`
--   condition in its weapon module). So what is not put on the bar does not appear in the
--   wheel, weapon or item.
--
--   Widen max to your inventory's slot count to show everything.
--
-- ⚠️ And this range is bypassed automatically on an inventory with no real slots (VORP):
--   the number there is a loadout row's ordering, not a position the player picks, so
--   cutting it at the first five hides weapons the player has no way to bring forward.
--   They are all shown, bounded only by the wheel's sector count.
----------------------------------------------------------------

Wheel.SlotRange = { min = 1, max = 5 }

----------------------------------------------------------------
-- Display order -- the slot is the order
--
-- ★ 'slot' (the default): the first sector in the wheel for the first weapon in the bag,
--   the second for the second, and so on to the last sector. So what you see on the quick
--   bar you find in the wheel in the same sequence, and the player never has to memorise
--   'where does the wheel put my weapon'.
--
--   And interleaved items shift nothing: a slot holding bread between two sidearms is
--   skipped and the two sidearms land adjacent. That is, the count is over weapons, not
--   over slot numbers.
--
-- ★ 'class': the old distribution over fixed roles (right/left holster, back, shoulder...)
--   as in RDR2. Kept exactly as it was for whoever wants it -- nothing of it was removed.
--
-- OrderExtras: the sectors that are not weapons, appended after the last weapon in the
-- first free position. Empty it to {} for a pure weapons wheel (holstering stays on left
-- click and on the double tap, so nothing is lost).
----------------------------------------------------------------

Wheel.Order = 'slot'
Wheel.OrderExtras = { 'unarmed', 'dual' }

--- The items tab likewise: 'slot' in bag order · 'rules' by the Wheel.ItemWheel lists
Wheel.ItemsOrder = 'slot'

----------------------------------------------------------------
-- What each button does -- the new wheel behaviour
--
-- ═══ Three actions, not one ═══
--
--   release the key with the cursor on a weapon  ->  takes it in hand (at the ready)
--   left click on a weapon                       ->  returns it to its holster on the body
--   right click on a weapon                      ->  assigns it as a 'default' (visible on you)
--   a quick TAB tap                              ->  draws the default at once without opening
--
-- ★ Why left click holsters rather than equips: releasing already equips, so if the two
--   buttons did the same thing one of them would be wasted. And holstering had no direct
--   route: you closed the wheel then double-tapped. Now it has its own button.
--
--   'stow'  = returns the weapon to its holster (back/belt depending on the weapon)
--   'equip' = the old behaviour: left click takes the weapon and closes the wheel
----------------------------------------------------------------

Wheel.LeftClick = 'stow'

--- Does left click close the wheel afterwards? false = it stays open so you can holster several.
Wheel.LeftClickCloses = false

----------------------------------------------------------------
-- Default weapons -- more than one
--
-- ★ Quick-select used to be a **single** target: assign a second and the first was dropped.
--   But a real going-out kit is not one weapon, it is a set -- a sidearm and a sidearm, or
--   a sidearm and a rifle. So the default became a list: right click adds, a second right
--   click on the same weapon removes, and the quick tap draws them all in order.
--
--   QuickMax caps how many are drawn together. There are two hands, so the default is 2.
--   Set it to 0 to draw the whole list (the inventory drops what a hand cannot hold anyway).
----------------------------------------------------------------

Wheel.QuickMax = 2

--- Assigning a default shows it on the body at once (holstering it if it was in hand).
Wheel.QuickStowsOnAssign = true

----------------------------------------------------------------
-- The inventory -- which system the wheel reads from
--
-- ★ 'auto' detects on its own, in this order: w_inventory, then vorp_inventory, then
--   rsg-inventory. Pin it by hand if you run more than one and want a particular one.
--
-- ⚠️ And every inventory has what it has and what it has not, and the wheel switches off
--   what does not exist rather than showing an invented number or a button that does nothing:
--
--                     Condition  Cleaning  Ammo types  Dual wield
--     w_inventory        ✓        ✓          ✓          ✓
--     vorp_inventory     ✗        ✗          ✗          ✓
--     rsg-inventory      ✓        ✗          ✗          ✗
--
--   (RSG's condition is info.quality on the item itself -- a real number read, not invented.
--    Repairing it there is a gunsmith's job, not a button in a wheel, so cleaning is off.
--    And dual wield is not in rsg-weapons at all.)
----------------------------------------------------------------

Wheel.Inventory = 'auto' -- 'auto' | 'w_inventory' | 'vorp_inventory' | 'rsg-inventory'

----------------------------------------------------------------
-- The horse tab
--
-- ★ It does not open merely because a horse exists: it requires a horse **registered to
--   you with a real satchel**. And the reliable marker is horseUUID in the entity's
--   statebag -- the same thing the inventory requires before opening a horse satchel
--   (the horse-satchel opener in w_inventory/client.lua: 'the horse is not part of our
--   system' then return). So a wild horse, another player's horse, or a horse with no registered
--   satchel: the tab is off.
----------------------------------------------------------------

Wheel.HorseTab = true
Wheel.HorseDistance = 4.5 -- metres -- 'near the horse' is enough, as in the game

--- Requiring the registered satchel. Set false to accept mere proximity to any horse.
Wheel.HorseRequiresStorage = true

----------------------------------------------------------------
-- The Ability Loadout
--
-- Not a feature of the VORP core, so it is off by default. Enable it and write the name of
-- the event that opens your card loadout (w_abilities or your equivalent) and the hint will
-- appear under the wheel as it does in Red Dead Online.
----------------------------------------------------------------

Wheel.AbilityLoadout = {
    enabled = false,
    event   = 'w_abilities:open', -- a client event fired on press
}

----------------------------------------------------------------
-- Image and sound sources
--
-- ★ We duplicate no asset: the RDR2 art set (textures and menu sounds) exists in both
--   w_crafting and w_inventory, and nui:// reads from any resource that declares its files.
--
-- ⚠️ And we point at w_inventory rather than w_crafting: the first is the inventory this
--   wheel is built for (the manifest declares only w_lib and oxmysql -- the started
--   inventory is detected at runtime and its folder replaces these defaults), while the
--   second may not be installed on every server -- and then the wheel opens with no icons,
--   no sound and no visible reason.
----------------------------------------------------------------

-- ════════════════════════════════════════════════════════════════════════════
-- Where images come from -- candidates in order, not one path
--
-- ★ Every inventory names its image folder as it pleases, and names a given item as it
--   pleases. So one path written into the config means a wheel with no icons on every server
--   not running that exact inventory -- the worst possible fault, because it looks like it works.
--
--   So the list is tried one after another: the image fails and the next is tried, until one
--   hits or the list runs out and no image is drawn at all (and the wheel stays usable).
--   This works even if we guessed a folder wrong: the bad guess is skipped without trace.
--
--   And the order is deliberate: the active inventory's folder first -- the names come from it, so its images fit best.
-- ════════════════════════════════════════════════════════════════════════════

Wheel.ImageSources = {
    w_inventory      = { 'nui://w_inventory/web/images/' },
    vorp_inventory   = { 'nui://vorp_inventory/html/img/items/', 'nui://vorp_inventory/html/img/' },
    ['rsg-inventory'] = { 'nui://rsg-inventory/html/images/', 'nui://rsg-inventory/html/img/' },
}

--- RDR textures and sounds -- the first started resource among these wins.
--- ★ They belong to no one inventory: the w_crafting set carries them too, and the wheel
---   works without any of them (frames without texture and silence instead of a tone), so
---   nothing breaks if they are absent.
Wheel.TexSources = {
    { resource = 'w_inventory', path = 'nui://w_inventory/web/build/tex/ui/' },
    { resource = 'w_crafting',  path = 'nui://w_crafting/web/build/tex/ui/' },
    { resource = 'w_hud',       path = 'nui://w_hud/web/build/tex/ui/' },
}

Wheel.SoundSources = {
    { resource = 'w_inventory', path = 'nui://w_inventory/web/build/sounds/' },
    { resource = 'w_crafting',  path = 'nui://w_crafting/web/build/sounds/' },
    { resource = 'w_hud',       path = 'nui://w_hud/web/build/sounds/' },
}

Wheel.Assets = {
    -- ⚠️ Replaced at runtime by the active inventory's candidates (WheelInv.assets).
    --    What is here is the default for when no inventory is detected.
    items  = 'nui://w_inventory/web/images/',         -- item and weapon images
    tex    = 'nui://w_inventory/web/build/tex/ui/',    -- RDR UI textures
    sounds = 'nui://w_inventory/web/build/sounds/',    -- RDR menu sounds

    -- ★ RDR2's own fist -- a real image, not a vector drawing.
    --   It lives in w_lib's web/build/assets/images/wheel set, which w_lib declares, so it
    --   is available. If you want a different one, put weapon_unarmed.png in
    --   w_inventory/web/images and it will take precedence automatically.
    unarmed = 'nui://w_lib/web/build/assets/images/wheel/weapon_unarmed.png',

    -- ★ RDR2's own dual-wield icon -- the two arrows with their worn texture, not an
    --   imitation drawing and not two weapon images composited.
    dualwield = 'nui://w_lib/web/build/assets/images/wheel/weapon_dualwield.png',
}

----------------------------------------------------------------
-- The 'items' and 'horse' tabs
--
-- ★ Why an explicit list rather than 'everything in the bag':
--   RDR2's wheel does not show your whole inventory -- it has eight places for things
--   consumed quickly (provisions, tonics, kit). Pour everything into it and fish, bait and
--   pelts turn up in the tonic slots, and those are not items used from a wheel.
--
--   include  specific names, and their order is the display order
--   prefixes fragments matched anywhere in the name (for sets named to a pattern)
--   exclude  what is excluded even if it matched the above
--   fallback if the eight are not filled: top them up with whatever the player carries most
--            of -- better than an empty wheel on a server whose item names are not what we expected
----------------------------------------------------------------

Wheel.ItemWheel = {
    include  = { 'water', 'bread', 'canned_beans', 'consumable_potent_medicine',
                 'consumable_potent_tonic', 'consumable_potent_snake_oil' },
    prefixes = { 'consumable_', 'provision_', 'kit_', 'tonic', 'medicine', 'snake_oil',
                 'food', 'drink', 'coffee', 'meat_', 'stew', 'biscuit', 'jerky' },
    exclude  = { 'a_c_fish', 'p_bait', 'p_crawdad', 'kit_gun_oil' },
    fallback = true,
}

Wheel.HorseWheel = {
    include  = { 'horse_reviver' },
    prefixes = { 'horse_', 'brush', 'feed', 'hay', 'carrot', 'sugar_cube', 'apple', 'oatcake' },
    exclude  = {},
    fallback = false,
}

----------------------------------------------------------------
-- The wheel layout -- eight sectors
--
-- The angles are in degrees from the top of the screen, clockwise, exactly as drawn.
-- And the width (sweep) alternates: narrow at the cardinal directions (0/90/180/270) and
-- wide on the diagonals -- which is what makes the shape match the game's wheel.
--
--   34x4 + 56x4 = 360 exactly. Any edit must keep the sum at 360.
--
-- role  = the sector's role (what goes in it)
-- suit  = the card symbol beside the counter: a diamond for the left holster and a club for
--         the right -- the same two symbols the HUD uses
----------------------------------------------------------------

Wheel.Sectors = {
    { role = 'dual',            angle = 0,   sweep = 34 },
    { role = 'sidearmRight',    angle = 45,  sweep = 56, suit = 'club',    hand = 0 },
    { role = 'unarmed',         angle = 90,  sweep = 34 },
    { role = 'longarmShoulder', angle = 135, sweep = 56, mount = 'shoulder' },
    { role = 'throwable',       angle = 180, sweep = 34 },
    { role = 'longarmBack',     angle = 225, sweep = 56, mount = 'back' },
    { role = 'melee',           angle = 270, sweep = 34 },
    { role = 'sidearmLeft',     angle = 315, sweep = 56, suit = 'diamond', hand = 1 },
}

----------------------------------------------------------------
-- Classification -- which weapon goes to which sector
--
-- Read in order, and the first rule that matches wins. `match` is a Lua pattern against the
-- weapon name in upper case, and `flag` is a raw attribute from the inventory.
----------------------------------------------------------------

Wheel.Classify = {
    { class = 'lasso',     match = '^WEAPON_LASSO' },
    { class = 'kit',       match = '^WEAPON_KIT' },
    { class = 'kit',       match = 'LANTERN' },
    { class = 'throwable', flag  = 'throwable' },
    -- The sawn-off shotgun goes in the holster, not on the back -- exactly as in the game.
    { class = 'sidearm',   match = 'SHOTGUN_SAWEDOFF' },
    { class = 'sidearm',   match = '^WEAPON_REVOLVER' },
    { class = 'sidearm',   match = '^WEAPON_PISTOL' },
    { class = 'melee',     match = '^WEAPON_MELEE' },
    { class = 'melee',     match = 'KNIFE' },
    { class = 'melee',     match = 'HATCHET' },
    { class = 'melee',     match = 'MACHETE' },
    { class = 'melee',     match = 'CLEAVER' },
    { class = 'melee',     match = 'TORCH' },
}

--- The sectors each class accepts. The order is the order of preference.
Wheel.ClassSectors = {
    sidearm   = { 'sidearmRight', 'sidearmLeft' },
    longarm   = { 'longarmShoulder', 'longarmBack' },
    melee     = { 'melee' },
    throwable = { 'throwable' },
    lasso     = { 'throwable' },
    kit       = { 'melee' },
}

--- ★ The order in which classes are processed -- required, not decorative.
---
--- pairs() in Lua guarantees no order, and two sectors are shared by two classes (the lasso
--- and throwables on 'throwable', the kit and melee on 'melee'). So without an explicit
--- order one class wins one time and the other the next, and a weapon's position shifts
--- between one opening and another for no reason. And whoever loses the sector drops to the
--- first free position -- so the whole wheel's ordering changes.
Wheel.ClassOrder = { 'sidearm', 'longarm', 'melee', 'throwable', 'lasso', 'kit' }

--- The cap on what is carried on the body per class -- the rest is on the horse, as in the game.
--- (Set it to 0 to disable the cap entirely.)
Wheel.CarryLimits = {
    sidearm = 2,
    longarm = 2,
}

----------------------------------------------------------------
-- Weapon stats -- the Damage / Range / Fire Rate / Reload / Accuracy bars
--
-- ★ Why a written table rather than a read from the engine:
--   RDR3 exposes no native returning the bar values the game's wheel shows. The values live
--   in the weaponinfo files inside the RPF and the client has no route to them. So the honest
--   alternative is a visible table that can be edited, not an invented number presented as a reading.
--
-- The values run 0 to 100 and preserve the game's own ordering between weapons (the Elephant
-- hits hardest, the Carcano reaches furthest, the Mauser fires fastest...). Adjust them to
-- suit your server's balance -- the file is pure data.
--
-- Gunsmith bonuses coming from the inventory (Weapon.GetModifiers) are then added on top, so
-- an upgraded weapon really does show stronger in the wheel, not just nominally.
----------------------------------------------------------------

local function stat(damage, range, fireRate, reload, accuracy)
    return { damage = damage, range = range, fireRate = fireRate, reload = reload, accuracy = accuracy }
end

Wheel.Stats = {
    -- -- revolvers ---------------------------------------------
    WEAPON_REVOLVER_CATTLEMAN               = stat(35, 40, 55, 55, 40),
    WEAPON_REVOLVER_CATTLEMAN_MEXICAN       = stat(35, 40, 55, 55, 40),
    WEAPON_REVOLVER_CATTLEMAN_PIG           = stat(35, 40, 55, 55, 40),
    WEAPON_REVOLVER_DOUBLEACTION            = stat(30, 35, 80, 60, 30),
    WEAPON_REVOLVER_DOUBLEACTION_GAMBLER    = stat(30, 35, 80, 60, 30),
    WEAPON_REVOLVER_DOUBLEACTION_EXOTIC     = stat(30, 35, 80, 60, 30),
    WEAPON_REVOLVER_SCHOFIELD               = stat(45, 45, 50, 50, 45),
    WEAPON_REVOLVER_SCHOFIELD_GOLDEN        = stat(45, 45, 50, 50, 45),
    WEAPON_REVOLVER_SCHOFIELD_CALLOWAY      = stat(45, 45, 50, 50, 48),
    WEAPON_REVOLVER_LEMAT                   = stat(40, 40, 65, 35, 35),
    WEAPON_REVOLVER_NAVY                    = stat(40, 42, 52, 48, 42),
    WEAPON_REVOLVER_NAVY_CROSSOVER          = stat(40, 42, 52, 48, 42),

    -- -- pistols ----------------------------------------------
    WEAPON_PISTOL_VOLCANIC                  = stat(55, 45, 40, 45, 50),
    WEAPON_PISTOL_M1899                     = stat(30, 40, 70, 65, 45),
    WEAPON_PISTOL_MAUSER                    = stat(25, 40, 85, 60, 40),
    WEAPON_PISTOL_MAUSER_DRUNK              = stat(25, 40, 85, 60, 40),
    WEAPON_PISTOL_SEMIAUTO                  = stat(32, 42, 75, 62, 45),

    -- -- repeaters --------------------------------------------
    WEAPON_REPEATER_CARBINE                 = stat(45, 55, 62, 55, 50),
    WEAPON_REPEATER_CARBINE_SADDLERING      = stat(45, 55, 62, 55, 52),
    WEAPON_REPEATER_WINCHESTER              = stat(48, 58, 58, 52, 55),
    WEAPON_REPEATER_HENRY                   = stat(52, 60, 55, 48, 55),
    WEAPON_REPEATER_EVANS                   = stat(45, 55, 60, 40, 50),

    -- -- rifles -----------------------------------------------
    WEAPON_RIFLE_VARMINT                    = stat(15, 55, 60, 55, 60),
    WEAPON_RIFLE_SPRINGFIELD                = stat(78, 80, 25, 30, 70),
    WEAPON_RIFLE_BOLTACTION                 = stat(70, 78, 40, 45, 75),
    WEAPON_RIFLE_ELEPHANT                   = stat(100, 70, 15, 20, 65),
    WEAPON_SNIPERRIFLE_ROLLINGBLOCK         = stat(85, 90, 20, 25, 80),
    WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC  = stat(85, 90, 20, 25, 82),
    WEAPON_SNIPERRIFLE_CARCANO              = stat(75, 95, 30, 35, 85),

    -- -- shotguns ---------------------------------------------
    WEAPON_SHOTGUN_SAWEDOFF                 = stat(65, 20, 45, 40, 25),
    WEAPON_SHOTGUN_DOUBLEBARREL             = stat(75, 30, 40, 35, 30),
    WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC      = stat(75, 30, 40, 35, 32),
    WEAPON_SHOTGUN_PUMP                     = stat(70, 35, 55, 45, 35),
    WEAPON_SHOTGUN_REPEATING                = stat(68, 33, 60, 40, 33),
    WEAPON_SHOTGUN_SEMIAUTO                 = stat(65, 35, 70, 45, 35),

    -- -- bow --------------------------------------------------
    WEAPON_BOW                              = stat(60, 50, 30, 35, 55),
    WEAPON_BOW_IMPROVED                     = stat(65, 55, 32, 38, 60),

    -- -- melee ------------------------------------------------
    WEAPON_MELEE_KNIFE                      = stat(28, 5, 60, 0, 0),
    WEAPON_MELEE_KNIFE_HORROR               = stat(30, 5, 60, 0, 0),
    WEAPON_MELEE_KNIFE_JAWBONE              = stat(32, 5, 58, 0, 0),
    WEAPON_MELEE_KNIFE_MINER                = stat(34, 5, 52, 0, 0),
    WEAPON_MELEE_KNIFE_CIVIL_WAR            = stat(30, 5, 58, 0, 0),
    WEAPON_MELEE_HATCHET                    = stat(38, 6, 48, 0, 0),
    WEAPON_MELEE_HATCHET_VIKING             = stat(42, 6, 46, 0, 0),
    WEAPON_MELEE_HATCHET_HUNTER             = stat(40, 6, 48, 0, 0),
    WEAPON_MELEE_MACHETE                    = stat(40, 8, 50, 0, 0),
    WEAPON_MELEE_CLEAVER                    = stat(36, 5, 52, 0, 0),
    WEAPON_MELEE_TORCH                      = stat(20, 5, 45, 0, 0),
    WEAPON_MELEE_LANTERN                    = stat(15, 5, 40, 0, 0),

    -- -- throwables -------------------------------------------
    WEAPON_THROWN_DYNAMITE                  = stat(90, 30, 20, 0, 25),
    WEAPON_THROWN_MOLOTOV                   = stat(70, 30, 25, 0, 25),
    WEAPON_THROWN_THROWING_KNIVES           = stat(45, 35, 45, 0, 40),
    WEAPON_THROWN_TOMAHAWK                  = stat(55, 32, 35, 0, 35),
    WEAPON_THROWN_TOMAHAWK_ANCIENT          = stat(60, 32, 35, 0, 38),
    WEAPON_THROWN_BOLAS                     = stat(10, 30, 35, 0, 35),
    WEAPON_THROWN_POISONBOTTLE              = stat(50, 30, 25, 0, 25),

    -- -- lasso and fists ---------------------------------------
    WEAPON_LASSO                            = stat(0, 25, 25, 0, 30),
    WEAPON_LASSO_REINFORCED                 = stat(0, 28, 25, 0, 32),

    --- Fists: tiny damage, even tinier range, and the rest empty -- exactly as the game shows them.
    UNARMED                                 = stat(20, 6, 0, 0, 0),
}

--- Fallback stats for when a weapon is not in the table (a mod, or an added weapon).
--- Better than empty bars implying the weapon has no value at all.
Wheel.StatsFallback = {
    sidearm   = stat(38, 42, 55, 52, 42),
    longarm   = stat(55, 60, 45, 45, 55),
    melee     = stat(30, 5, 50, 0, 0),
    throwable = stat(55, 30, 30, 0, 30),
    lasso     = stat(0, 25, 25, 0, 30),
    kit       = stat(10, 5, 30, 0, 0),
}

--- The order of the bars in the centre panel -- the game's own order.
Wheel.StatOrder = { 'damage', 'range', 'fireRate', 'reload', 'accuracy', 'condition' }

----------------------------------------------------------------
-- Text
----------------------------------------------------------------

--- The keys of every wheel string the UI draws, in locales/{ar,en}.json (section `wheel`).
--- The labels of the wheel's prompt group (tabSwitch, ammoPrev/ammoNext, ability, stow,
--- quickAdd, close) are read by client/wheel.lua and drawn by the library, not by the UI.
Wheel.TextKeys = {
    'weapons',
    'items',
    'horse',
    'unarmed',
    'unarmedSub',
    'dual',
    'dualSub',
    'empty',
    'damage',
    'range',
    'fireRate',
    'reload',
    'accuracy',
    'condition',
    'quick',
    'statsTitle',
    'moveSelect',
    'clip',
    'handRight',
    'handLeft',
    'catSidearm',
    'catLongarm',
    'catMelee',
    'catThrow',
    'catLasso',
    'catKit',
    'clean',
    'cleaning',
    'noOil',
    'onHorse',
    'rounds',
    'stowed',
    'draw',
    'quickTag',
}

--- The wheel strings in the player's language, built at open time so a language switch
--- in /w_lib reaches the next open without a restart.
---@return table<string, string>
function Wheel.Text()
    local out = {}

    for i = 1, #Wheel.TextKeys do
        local key = Wheel.TextKeys[i]
        out[key] = locale('wheel.' .. key)
    end

    return out
end

----------------------------------------------------------------
-- Shared functions
----------------------------------------------------------------

--- A weapon's class from its name and raw attributes.
---@param weapon table a row from getWeaponWheelState
---@return string class
function Wheel.ClassOf(weapon)
    local name = tostring(weapon and weapon.name or ''):upper()

    for i = 1, #Wheel.Classify do
        local rule = Wheel.Classify[i]

        if rule.flag then
            if weapon[rule.flag] then return rule.class end
        elseif rule.match and name:find(rule.match) then
            return rule.class
        end
    end

    -- What is left: one-handed firearm is a sidearm, two-handed is a longarm, non-firearm is melee.
    if weapon and weapon.isGun then
        return weapon.oneHanded and 'sidearm' or 'longarm'
    end

    return 'melee'
end

--- A weapon's stats after gunsmith modifiers are added.
---@param weapon table
---@return table stats values 0..100
function Wheel.StatsOf(weapon)
    local base = Wheel.Stats[tostring(weapon and weapon.name or ''):upper()]
        or Wheel.StatsFallback[Wheel.ClassOf(weapon)]
        or Wheel.StatsFallback.sidearm

    local mods = weapon and weapon.stats or {}
    local out  = {}

    for key, value in pairs(base) do
        out[key] = math.max(0, math.min(100, value + (tonumber(mods[key]) or 0)))
    end

    return out
end
