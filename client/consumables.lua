-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- client-side consumption (animation · props · cores · screen effect)
--
--   The server has already settled the needs and removed the item; here we give the
--   act its picture: a fitting animation, a prop in hand, the health/stamina cores,
--   and a screen effect where one exists.
--
--   Ported in substance from vorp_metabolism/client/useItemsActions.lua, with the
--   smoking animation from the old script, plus a model-validity guard so a wrong
--   prop name cannot break the whole animation.
-- ════════════════════════════════════════════════════════════════════════════

local busy  = false -- repeat guard (the old script called it antyspam)

-- ════════════════════════════════════════════════════════════════════════════
-- Helpers -- the library streams the assets and owns the props
-- ════════════════════════════════════════════════════════════════════════════

--- w.requestAnimDict errors on a missing dictionary or a timeout; here that is a false.
---@param dict string
---@return boolean
local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    local ok = pcall(w.requestAnimDict, dict, 3000)
    return ok
end

--- Create a prop through the library: a bad model name yields nil instead of freezing the
--- game on a model that never loads. Networked so the others see what is in the hand;
--- w.entity deletes what is left of them when the resource stops.
---@param name string
---@return integer|nil
local function makeProp(name)
    if not name or name == '' then return nil end
    if not IsModelValid(joaat(name)) then return nil end

    local ok, prop = pcall(w.entity.create, name, GetEntityCoords(cache.ped), 0.0, true)
    if not ok or not prop or prop == 0 then return nil end

    return prop
end

local function dropProp(prop)
    if not prop or not DoesEntityExist(prop) then return end

    DetachEntity(prop, true, true)
    w.entity.delete(prop)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Animations
--
--   One style per way of consuming, each built on the clip set the game itself uses
--   for that shape of thing, with the prop that set was made around as its default.
--   An entry says `anim = '<style>'` and, when its own model fits better than the
--   style's default, `prop = '<model>'`.
--
--     bite           hand-held solid food, several bites    bread · fruit · meat · cake
--     can            tinned food, eaten from the can        beans · peaches · salmon
--     stew           bowl or plate, with a spoon            stews · soups · platters
--     mug            hot drink from a mug or cup            coffee · tea · cocoa
--     bottle         tall bottle: uncork, then chug         whiskey · wine · spirits
--     bottle_small   short bottle                           beer · water · soda
--     jar            mason jar                              moonshine · milk
--     glass          a glass or a beer mug                  lemonade · cocktails · shots
--     canteen        the canteen
--     tonic          small medicine bottle, one quick gulp  tonics · medicine · elixirs
--     cigarette · cigar · pipe                              smoked
--     syringe · bandage                                     medical
--
--   eat / drink / coffee / smoke remain as aliases of the nearest style, so an entry
--   written against the old names keeps working.
-- ════════════════════════════════════════════════════════════════════════════
local Anims = {}

--- The held styles: attach the prop to a bone, play a clip (with an optional intro
--- such as uncorking), wait it out, tidy up. PH_R_HAND is the game's own prop-hand
--- helper bone and resolves like any skeleton bone.
local HELD = {
    bite = {
        dict = 'mech_inventory@eating@multi_bite@sphere_d8-2_sandwich', clip = 'quick_left_hand',
        bone = 'SKEL_L_Finger01', offset = { 0.04, -0.03, -0.01 }, rot = { 0.0, 19.0, 46.0 },
        ms = 5000, prop = 'p_cs_sandwich01x',
    },
    can = {
        dict = 'mech_inventory@eating@canned_food@cylinder@d8-2_h10-5', clip = 'left_hand',
        bone = 'SKEL_L_Finger00', offset = { 0.10, -0.03, 0.02 }, rot = { 20.0, -70.0, -20.0 },
        ms = 4500, prop = 's_canrigbeans01x',
    },
    bottle = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-3_h30-5_neck_a13_b2-5',
        intro = 'uncork', introMs = 500, clip = 'chug_a',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 5000, prop = 'p_bottlejd01x',
    },
    bottle_small = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8',
        intro = 'uncork', introMs = 500, clip = 'chug_a',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 4500, prop = 'p_bottlebeer01a',
    },
    jar = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8', clip = 'chug_a',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 4500, prop = 'p_masonjarmoonshine01x',
    },
    glass = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8', clip = 'chug_a',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 4000, prop = 'p_whiskeyglass01x',
    },
    canteen = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8', clip = 'chug_a',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 4500, prop = 'p_canteen01x',
    },
    tonic = {
        dict = 'mech_inventory@item@fallbacks@tonic@unarmed', clip = 'quick_consume_drink_small_cork',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 3500, prop = 'p_bottlemedicine01x',
    },
    syringe = {
        dict = 'mech_inventory@item@stimulants@inject@quick', clip = 'quick_stimulant_inject_lhand',
        bone = 'SKEL_L_HAND', offset = { 0.10, 0.0, 0.03 }, rot = { 0.0, -80.0, -90.0 },
        ms = 2500, prop = 's_inv_syringe01x',
    },
    bandage = {
        dict = 'mini_games@story@mob4@heal_jules@bandage@arthur', clip = 'tourniquet_slow',
        bone = 'SKEL_L_HAND', offset = { 0.10, 0.0, 0.03 }, rot = { 0.0, -60.0, -90.0 },
        ms = 5500, prop = 'p_cs_bandage01x',
    },
}

local function playHeld(spec, propName)
    if not loadAnimDict(spec.dict) then return end

    local prop = makeProp(propName or spec.prop)
    if not prop and propName then prop = makeProp(spec.prop) end -- a bad model name falls back to the style's own

    if prop then
        local bone = GetEntityBoneIndexByName(cache.ped, spec.bone)
        local o, r = spec.offset, spec.rot
        AttachEntityToEntity(prop, cache.ped, bone, o[1], o[2], o[3], r[1], r[2], r[3],
            true, true, false, true, 1, true, false, false)
    end

    if spec.intro then
        TaskPlayAnim(cache.ped, spec.dict, spec.intro, 1.0, 8.0, spec.introMs, 31, 0.0, false, false, false)
        Wait(spec.introMs)
    end

    TaskPlayAnim(cache.ped, spec.dict, spec.clip, 1.0, 8.0, spec.ms, 31, 0.0, false, false, false)
    Wait(spec.ms)

    dropProp(prop)
    ClearPedSecondaryTask(cache.ped)
    RemoveAnimDict(spec.dict)
end

for style, spec in pairs(HELD) do
    Anims[style] = function(propName) playHeld(spec, propName) end
end

--- A hot drink: the game's own coffee interaction, which fills and tips the mug itself.
--- Any cup-shaped model rides the same interaction (the tea cup, the tin cup).
function Anims.mug(propName)
    local prop = makeProp(propName or 'p_mugcoffee01x')
    if not prop then return playHeld(HELD.glass, nil) end

    Citizen.InvokeNative(0x669655FFB29EF1A9, prop, 0, 'CTRL_cupFill', 1.0)
    TaskItemInteraction_2(cache.ped, joaat('CONSUMABLE_COFFEE'), prop,
        joaat('P_MUGCOFFEE01X_PH_R_HAND'), joaat('DRINK_COFFEE_HOLD'), 1, 0, -1082130432)

    Wait(8000)
    dropProp(prop)
end

--- A bowl or plate with a spoon: the game's own stew interaction. Stews, soups and
--- plated meals all ride it - only the dish model differs.
function Anims.stew(propName)
    local bowl = makeProp(propName or 'p_bowl04x_stew')
    if not bowl and propName then bowl = makeProp('p_bowl04x_stew') end
    if not bowl then return playHeld(HELD.bite, nil) end

    local spoon = makeProp('p_beefstew_spoon01x')

    Citizen.InvokeNative(0x669655FFB29EF1A9, bowl, 0, 'Stew_Fill', 1.0)
    Citizen.InvokeNative(0xCAAF2BCCFEF37F77, bowl, 20)
    TaskItemInteraction_2(cache.ped, 599184882, bowl, joaat('p_bowl04x_stew_PH_L_HAND'), -583731576, 1, 0, -1.0)

    if spoon then
        Citizen.InvokeNative(0xCAAF2BCCFEF37F77, spoon, 82)
        TaskItemInteraction_2(cache.ped, 599184882, spoon, joaat('p_spoon01x_PH_R_HAND'), -583731576, 1, 0, -1.0)
    end

    Citizen.InvokeNative(0xB35370D5353995CB, cache.ped, -583731576, 1.0)

    Wait(9000)
    dropProp(bowl); dropProp(spoon)
end

--- Smoking -- the wander loop from the old script, which reads well standing still.
--- Three styles, three props: what is between the fingers is the whole difference.
local function smoke(propName, fallback)
    local dict, clip = 'amb_wander@code_human_smoking_wander@cigar@male_a@base', 'base'
    if not loadAnimDict(dict) then return end

    SetCurrentPedWeapon(cache.ped, joaat('weapon_unarmed'), true)
    Wait(200)

    local prop = makeProp(propName or fallback)
    if not prop and propName then prop = makeProp(fallback) end
    local bone = GetEntityBoneIndexByName(cache.ped, 'SKEL_R_FINGER12')

    TaskPlayAnim(cache.ped, dict, clip, 5.0, 5.0, 10000, 1, 0.0, false, false, false)

    if prop then
        AttachEntityToEntity(prop, cache.ped, bone, 0.0, 0.03, 0.01, 0.0, 180.0, 90.0,
            true, true, false, true, 1, true, false, false)
    end

    Wait(9000)
    dropProp(prop)
    ClearPedTasks(cache.ped)
    RemoveAnimDict(dict)
end

function Anims.cigarette(propName) smoke(propName, 'p_cigarette01x') end
function Anims.cigar(propName) smoke(propName, 'p_cigar01x') end
function Anims.pipe(propName) smoke(propName, 'p_pipe01x') end

-- The old names, for entries written against them
Anims.eat    = Anims.bite
Anims.drink  = Anims.bottle_small
Anims.coffee = Anims.mug
Anims.smoke  = Anims.cigarette

-- ════════════════════════════════════════════════════════════════════════════
-- Cores and screen effect
-- ════════════════════════════════════════════════════════════════════════════
local CORE_HEALTH, CORE_STAMINA = 0, 1

local function addCore(index, delta)
    if not delta or delta == 0 then return end

    local v = GetAttributeCoreValue(cache.ped, index) + delta
    if v > 100 then v = 100 elseif v < 0 then v = 0 end

    Citizen.InvokeNative(0xC6258F41D86676E0, cache.ped, index, v) -- SetAttributeCoreValue
end

-- ════════════════════════════════════════════════════════════════════════════
-- The gilded state, as our HUD sees it
--
-- ★ Why we track it ourselves: the engine offers no native that reads the overpower
--   state back. EnableAttributeOverpower writes and never answers. So the only way our
--   own cores can show the gilding is to remember what we applied.
--
-- ⚠️ And the duration is ours, not the item's number. Those numbers are magnitudes on
--    an engine scale, not seconds -- one item carries 30/10 and another 1000/500, and
--    reading either as a duration gives a gilding lasting either a blink or a quarter
--    of an hour. So the flag says *whether* it is gilded and Config.Gold.Duration says
--    for how long our HUD shows it.
-- ════════════════════════════════════════════════════════════════════════════

WHudGold = { health = { ring = 0, icon = 0 }, stamina = { ring = 0, icon = 0 } }

--- Apply the gilding to the engine, and record it for our own cores.
---@param index number CORE_HEALTH or CORE_STAMINA
---@param outer number|nil gilds the ring
---@param inner number|nil gilds the icon as well
local function gild(index, outer, inner)
    outer, inner = tonumber(outer) or 0, tonumber(inner) or 0
    if outer <= 0 and inner <= 0 then return end

    EnableAttributeOverpower(cache.ped, index, math.max(outer, inner) + 0.0, true)

    local slot = (index == CORE_HEALTH) and WHudGold.health or WHudGold.stamina
    local until_ = GetGameTimer() + (((Config.Gold or {}).Duration) or 30000)

    -- ★ The longer of the two wins rather than the newer: eating a second tonic while
    --   the first still glows must not cut the glow short.
    if outer > 0 and until_ > slot.ring then slot.ring = until_ end
    if inner > 0 and until_ > slot.icon then slot.icon = until_ end
end

--- What the HUD payload carries. nil while nothing is gilded, so the fingerprint stays quiet.
---@return table|nil
function WHudGold.snapshot()
    local now = GetGameTimer()
    local h, s = WHudGold.health, WHudGold.stamina

    local out = {
        healthRing   = h.ring > now,
        healthIcon   = h.icon > now,
        staminaRing  = s.ring > now,
        staminaIcon  = s.icon > now,
    }

    if out.healthRing or out.healthIcon or out.staminaRing or out.staminaIcon then
        return out
    end

    return nil
end


-- ════════════════════════════════════════════════════════════════════════════
-- التسمُّم — حالةٌ مؤقّتة يراها اللاعب في قلبه
--
-- ═══ لماذا هنا وبهذا الشكل ═══
--
-- على مثال التذهيب فوقه بالضبط: المحرّك لا يحفظ لنا الحالة ولا يُجيب عنها، فنحن
-- نتذكّرها ونبثّها إلى الواجهة في كلّ نبضة. والإعداد في shared/needs.lua.
--
-- ★ وهي مؤقّتةٌ في ذاكرة العميل لا حاجةٌ في قاعدة البيانات: التسمُّم ما جرى لك
--   قبل دقيقة، لا صفةٌ تُحفظ. لاعبٌ يخرج مسموماً ويعود مسموماً بعد أسبوع خطأٌ
--   لا ميزة.
--
-- ⚠️ وينتهي بثلاثة: انقضاء المدّة، أو الترياق (curesPoison)، أو الموت. والموت
--   لازمٌ صراحةً: مسمومٌ يُنعَش فيجد قلبه أخضر ولا يعرف لماذا.
-- ════════════════════════════════════════════════════════════════════════════

WHudPoison = { until_ = 0, total = 0 }

--- ما تراه الواجهة. nil ما دام سليماً، فتبقى بصمة الحمولة هادئة.
---@return table|nil
function WHudPoison.snapshot()
    local now = GetGameTimer()
    if WHudPoison.until_ <= now then return nil end

    local left = WHudPoison.until_ - now

    return {
        active = true,
        left   = math.ceil(left / 1000),
        -- نسبة ما بقي — الواجهة تُشدّد الدخان في أوّله وتُخفّفه في آخره.
        ratio  = WHudPoison.total > 0 and math.min(1.0, left / WHudPoison.total) or 1.0,
    }
end

function WHudPoison.isActive()
    return WHudPoison.until_ > GetGameTimer()
end

--- إبطال السمّ — من الترياق أو الموت.
function WHudPoison.cure()
    if WHudPoison.until_ == 0 then return end

    WHudPoison.until_, WHudPoison.total = 0, 0

    local fx = (Config.Poison or {}).Fx
    if fx and fx ~= '' then pcall(AnimpostfxStop, fx) end
end

--- تسميمٌ لمدّةٍ بالثواني.
---
--- ★ الأطول يفوز لا الأحدث: من أكل لحماً فاسداً ثمّ زهرةً سامّة لا يجوز أن
---   تُقصّر الثانيةُ أثرَ الأولى. (نفس قاعدة التذهيب فوقه.)
---@param seconds number
function WHudPoison.apply(seconds)
    local config = Config.Poison or {}
    if config.Enabled == false then return end

    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return end

    local now = GetGameTimer()
    local until_ = now + math.floor(seconds * 1000)

    if until_ <= WHudPoison.until_ then return end

    local fresh = not WHudPoison.isActive()

    WHudPoison.until_ = until_
    WHudPoison.total  = until_ - now

    if fresh then
        local fx = config.Fx
        if fx and fx ~= '' then pcall(AnimpostfxPlay, fx) end

        PlaySoundFrontend('Core_Fill_Down', 'Consumption_Sounds', true, 0)
    end
end

-- ★ خيطٌ واحدٌ نائم: لا يستيقظ إلّا وأنت مسموم، فلا يُكلّف شيئاً وأنت سليم.
CreateThread(function()
    while true do
        local config = Config.Poison or {}
        local tick = math.max(250, math.floor(tonumber(config.Tick) or 2000))

        if not WHudPoison.isActive() then
            Wait(1000)
        else
            Wait(tick)

            -- انقضت المدّة أثناء النوم؟ أوقِف المؤثّر ولا تضرب ضربةً زائدة.
            if not WHudPoison.isActive() then
                WHudPoison.cure()
            elseif IsEntityDead(cache.ped) then
                -- ⚠️ الموت يُبطل السمّ: من يُنعَش يجد قلبه أخضر بلا سببٍ يفهمه.
                WHudPoison.cure()
            else
                local floor = math.max(0, math.floor(tonumber(config.MinHealth) or 0))
                local damage = math.max(0, math.floor(tonumber(config.Damage) or 0))
                local health = GetEntityHealth(cache.ped)

                -- ★ لا يقتل: يقف عند الحدّ. والحدّ صفرٌ لمن أراده قاتلاً.
                if damage > 0 and health > floor then
                    SetEntityHealth(cache.ped, math.max(floor, health - damage), 0)
                end

                -- المسموم لا يجري: الستامينا تُستنزف معه.
                local drain = tonumber(config.StaminaDrain) or 0

                if drain > 0 then
                    local value = GetAttributeCoreValue(cache.ped, CORE_STAMINA) - drain
                    Citizen.InvokeNative(0xC6258F41D86676E0, cache.ped, CORE_STAMINA,
                        math.max(0, math.floor(value)))
                end
            end
        end
    end
end)

--- للموارد الأخرى: هل اللاعب مسموم؟ وتسميمُه/شفاؤه من الخارج.
exports('isPoisoned', function() return WHudPoison.isActive() end)
exports('poisonPlayer', function(seconds) WHudPoison.apply(seconds) end)
exports('curePoison', function() WHudPoison.cure() end)

RegisterNetEvent('w_hud:client:poison', function(seconds) WHudPoison.apply(seconds) end)
RegisterNetEvent('w_hud:client:curePoison', function() WHudPoison.cure() end)

local function applyCores(entry)
    addCore(CORE_STAMINA, entry.stamina)
    addCore(CORE_HEALTH, entry.innerHealth)

    if entry.outerHealth and entry.outerHealth ~= 0 then
        local h = GetEntityHealth(cache.ped) + entry.outerHealth
        if h < 1 then h = 1 end
        SetEntityHealth(cache.ped, h, 0)
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Gilding (overpower)
    --
    -- ⚠️ The engine native has no inner/outer split. It used to be called twice per
    --    core -- once with goldHealthOuter and once with goldHealthInner, both on the
    --    same attribute index -- so the second simply overwrote the first and one of
    --    the two numbers was always discarded silently. Now it is called once per core
    --    with the larger of the two.
    --
    -- ★ The inner/outer distinction is real all the same, but it lives in **our** HUD
    --   rather than in the engine: outer gilds the ring, inner gilds the icon too.
    --   See goldState below and the .gold-* rules in hud.css.
    -- ════════════════════════════════════════════════════════════════════════
    gild(CORE_HEALTH,  entry.goldHealthOuter,  entry.goldHealthInner)
    gild(CORE_STAMINA, entry.goldStaminaOuter, entry.goldStaminaInner)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Screen effects (animpostfx)
--
-- ⚠️ An animpostfx belongs to the **engine**, not to us. It keeps running after the
--    resource that started it dies -- and the thread that was going to stop it dies
--    with the resource. So a player who drinks a whiskey and then sees the server
--    restart w_hud is left drunk forever, with no command and no way out.
--
--    (The exact same trap as the wheel effect in client/wheel.lua, which is why that
--     file stops its own on onResourceStop.)
--
-- ★ And a running tally rather than a flag per call: drinking a second whiskey while
--   the first is still on used to have the first timer stop the effect early, so the
--   second drink was shorter than the first. Now only the last one out turns off the light.
-- ════════════════════════════════════════════════════════════════════════════

local activeFx = {}   -- fx name -> how many are running

--- Stop one effect regardless of the tally -- used when clearing everything.
---@param fx string
local function killFx(fx)
    activeFx[fx] = nil
    pcall(AnimpostfxStop, fx)
end

--- Stop every effect we started. Safe to call at any time.
local function clearFx()
    for fx in pairs(activeFx) do killFx(fx) end
end

--- A temporary screen effect -- must not block the main thread
local function screenFx(fx, minutes)
    if not fx or fx == '' then return end

    activeFx[fx] = (activeFx[fx] or 0) + 1

    CreateThread(function()
        AnimpostfxPlay(fx)
        Wait(((tonumber(minutes) or 1) * 60000))

        -- Another drink is still counting on it? Leave it burning for them.
        local left = (activeFx[fx] or 1) - 1

        if left > 0 then
            activeFx[fx] = left
        else
            killFx(fx)
        end
    end)
end

-- ★ The three ways out that used to be missing.
--   Without these the effect outlives whatever caused it, and the player has no recourse.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearFx() end
end)

AddEventHandler('playerSpawned', clearFx)          -- a respawn sobers you up
RegisterNetEvent('vorp:SelectedCharacter', clearFx) -- and so does a new character
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', clearFx)

-- ════════════════════════════════════════════════════════════════════════════
-- /hudfx -- clear a stuck screen effect
--
-- ★ Required, not spare. An effect started **before** this fix existed cannot be
--   cleared by it: the tally is empty on a fresh start while the engine is still
--   drawing. So this command names the usual suspects outright and stops them all.
--
--     /hudfx                  stop everything we know of
--     /hudfx PlayerDrunk      stop one by name
-- ════════════════════════════════════════════════════════════════════════════
local KNOWN_FX = {
    'PlayerDrunkSaloon1', 'PlayerDrunk', 'PlayerDrunk01', 'PlayerDrunk02',
    'PlayerDrunkStrong', 'PlayerHealthLow', 'PlayerPoisoned', 'PlayerCold',
    'WheelHUDIn', 'PlayerAbilityDeadEye', 'MP_Downed',
}

RegisterCommand('hudfx', function(_, args)
    local one = args[1]

    if one and one ~= '' then
        killFx(one)
        return w.print.info(('stopped "%s".'):format(one))
    end

    clearFx()
    for i = 1, #KNOWN_FX do pcall(AnimpostfxStop, KNOWN_FX[i]) end
    pcall(AnimpostfxStopAll)

    w.print.info('all screen effects stopped.')
end, false)

-- ════════════════════════════════════════════════════════════════════════════
-- Event: consume an item
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('w_hud:client:consume', function(item)
    local entry = Config.Consumables and Config.Consumables[item]
    if not entry then return end

    PlaySoundFrontend('Core_Fill_Up', 'Consumption_Sounds', true, 0)

    -- The notice is shown here, in the player's own language, with the item's name from
    -- our dictionary (item.<name>) or from the inventory.
    WHudLocale.notify('needs.consumed', '#34b895', 'mp_anim_eat', 4000, { WHudLocale.itemLabel(item) })

    applyCores(entry)
    screenFx(entry.fx, entry.fxTime)

    -- ★ الترياق قبل السمّ: لو حمل غرضٌ الاثنين لكان إبطالاً ثمّ تسميماً، وهو
    --   الترتيب المعقول. ولا غرض عندنا يحملهما — لكنّ الترتيب يجب أن يكون
    --   محسوماً لا متروكاً لمن يُضيف غرضاً بعدنا.
    if entry.curesPoison then WHudPoison.cure() end
    if entry.poison then WHudPoison.apply(entry.poison) end

    -- Medical healing: picked up by medical resources if any are present
    if entry.heal then TriggerEvent('w_hud:client:healed', item) end

    local play = entry.anim and Anims[entry.anim]
    if not play or busy then return end

    busy = true

    CreateThread(function()
        pcall(play, entry.prop)
        busy = false
    end)
end)

--- Is the client busy with an animation right now? (used by client/needs.lua)
function IsConsumeBusy() return busy end
function SetConsumeBusy(v) busy = v and true or false end

-- ════════════════════════════════════════════════════════════════════════════
-- Horse care -- ported from rb94_horses in the old script
-- ════════════════════════════════════════════════════════════════════════════
local function lastMount()
    local horse = Citizen.InvokeNative(0x4C8B59171957BCF7, cache.ped) -- GetLastMount
    if not horse or horse == 0 or not DoesEntityExist(horse) then return nil end
    return horse
end

local function horseInReach(entry)
    local horse = lastMount()
    if not horse then return nil end

    local max = (entry and entry.distance) or (Config.HorseCare and Config.HorseCare.MaxDistance) or 3.0
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) > max then return nil end

    return horse
end

local function horseInteract(horse, hash, duration)
    Citizen.InvokeNative(0xCD181A959CFDD7F4, cache.ped, horse, hash, 0, 0) -- TaskHorseInteraction
    Wait(duration)
end

local function brushHorse(horse)
    horseInteract(horse, GetHashKey('INTERACTION_BRUSH'), (Config.HorseCare and Config.HorseCare.BrushTime) or 8000)

    Citizen.InvokeNative(0xE3144B932DFDFF65, horse, 0.0, -1, 1, 1)
    ClearPedEnvDirt(horse)
    ClearPedDamageDecalByZone(horse, 10, 'ALL')
    ClearPedBloodDamage(horse)
    Citizen.InvokeNative(0xD8544F6260F5F01E, horse, 10)
end

local function feedHorse(horse, coreIndex, amount)
    horseInteract(horse, -224471938, (Config.HorseCare and Config.HorseCare.FeedTime) or 5000)

    PlaySoundFrontend('Core_Fill_Up', 'Consumption_Sounds', true, 0)

    local v = GetAttributeCoreValue(horse, coreIndex) + amount
    if v > 100 then v = 100 end

    Citizen.InvokeNative(0xC6258F41D86676E0, horse, coreIndex, v)
end

--- Run the care action then call `done` -- shared by the pure and the dual item
local function doHorseCare(horse, entry, done)
    busy = true

    CreateThread(function()
        if entry.kind == 'brush' then
            brushHorse(horse)
        elseif entry.kind == 'stamina' then
            feedHorse(horse, CORE_STAMINA, entry.amount or 20)
        else -- feed / reviver
            feedHorse(horse, CORE_HEALTH, entry.amount or 20)
        end

        busy = false
        if done then done() end
    end)
end

-- A horse-only item: the server has not removed the piece yet, so we confirm only on success
RegisterNetEvent('w_hud:client:horseCare', function(item)
    local entry = Config.HorseItems and Config.HorseItems[item]
    if not entry or busy then return end

    local horse = horseInReach(entry)

    if not horse then
        WHudLocale.notify(lastMount() and 'needs.horseFar' or 'needs.horseNone', '#ff6b6b', 'cross', 4000)
        return
    end

    doHorseCare(horse, entry, function()
        TriggerServerEvent('w_hud:server:horseCareDone', item)
    end)
end)

-- A dual item: the piece is already gone -- we pick the branch and tell the server which one
RegisterNetEvent('w_hud:client:dualUse', function(item)
    local entry = Config.HorseItems and Config.HorseItems[item]
    local horse = entry and not busy and horseInReach(entry) or nil

    if horse then
        doHorseCare(horse, entry, function()
            TriggerServerEvent('w_hud:server:dualResult', item, 'horse')
        end)
    else
        TriggerServerEvent('w_hud:server:dualResult', item, 'player')
    end
end)
