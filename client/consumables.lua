-- Only the server's completed transaction applies effects.
local busy, active = false, nil
local props, dictionaries = {}, {}
local function actionWait(ms)
    local stop = GetGameTimer() + ms
    repeat
        if not active or active.coroutine ~= coroutine.running() or active.cancelled or IsEntityDead(cache.ped) or IsPedRagdoll(cache.ped)
            or IsControlJustPressed(0, Config.Use.CancelControl) then error('consumption cancelled') end
        Wait(math.min(100, math.max(0, stop - GetGameTimer())))
    until GetGameTimer() >= stop
end

-- ════════════════════════════════════════════════════════════════════════════
-- Helpers -- the library streams the assets and owns the props
-- ════════════════════════════════════════════════════════════════════════════

--- w.requestAnimDict errors on a missing dictionary or a timeout; here that is a false.
---@param dict string
---@return boolean
local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    local operation = active
    local ok = pcall(w.requestAnimDict, dict, 3000)
    if active ~= operation then
        if ok then RemoveAnimDict(dict) end
        return false
    end
    if ok then dictionaries[dict] = true end
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

    local operation = active
    local ok, prop = pcall(w.entity.create, name, GetEntityCoords(cache.ped), 0.0, true)
    if not ok or not prop or prop == 0 then return nil end
    if active ~= operation then w.entity.delete(prop); return nil end

    props[prop] = true
    return prop
end

local function dropProp(prop)
    if not prop or not DoesEntityExist(prop) then return end

    DetachEntity(prop, true, true)
    w.entity.delete(prop)
    props[prop] = nil
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
-- 2026-11-12 (owner: "drinking stops me; it should walk and drink like eating"): every bottle style plays the
-- game's walking drink, mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8@quick / use_quick_right_hand
-- (5.5 s, its own dictionary, read with CodeX), the same kind of quick clip as the bite; the old chug_a / uncork
-- clips are standing clips and held the player in place.
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
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8@quick', clip = 'use_quick_right_hand',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 5500, prop = 'p_bottlejd01x',
    },
    bottle_small = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8@quick', clip = 'use_quick_right_hand',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 5500, prop = 'p_bottlebeer01a',
    },
    jar = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8@quick', clip = 'use_quick_right_hand',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 5500, prop = 'p_masonjarmoonshine01x',
    },
    glass = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8@quick', clip = 'use_quick_right_hand',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 5500, prop = 'p_whiskeyglass01x',
    },
    canteen = {
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-55_h18_neck_a8_b1-8@quick', clip = 'use_quick_right_hand',
        bone = 'PH_R_HAND', offset = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },
        ms = 5500, prop = 'p_canteen01x',
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
    if not loadAnimDict(spec.dict) then return false end

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
        actionWait(spec.introMs)
    end

    TaskPlayAnim(cache.ped, spec.dict, spec.clip, 1.0, 8.0, spec.ms, 31, 0.0, false, false, false)
    actionWait(100)
    if not IsEntityPlayingAnim(cache.ped, spec.dict, spec.clip, 3) then return false end
    actionWait(spec.ms - 100)

    dropProp(prop)
    ClearPedSecondaryTask(cache.ped)
    RemoveAnimDict(spec.dict)
    return true
end

for style, spec in pairs(HELD) do
    Anims[style] = function(propName) return playHeld(spec, propName) end
end

--- A hot drink: the game's own coffee interaction, which fills and tips the mug itself.
--- Any cup-shaped model rides the same interaction (the tea cup, the tin cup).
function Anims.mug(propName)
    local prop = makeProp(propName or 'p_mugcoffee01x')
    if not prop then return playHeld(HELD.glass, nil) end

    Citizen.InvokeNative(0x669655FFB29EF1A9, prop, 0, 'CTRL_cupFill', 1.0)
    Citizen.InvokeNative(0x72F52AA2D2B172CC, cache.ped, joaat('CONSUMABLE_COFFEE'), prop,
        joaat('P_MUGCOFFEE01X_PH_R_HAND'), joaat('DRINK_COFFEE_HOLD'), 1, 0, -1082130432)

    actionWait(700)
    if not Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) then return false end
    Citizen.InvokeNative(0xB35370D5353995CB, cache.ped, joaat('DRINK_COFFEE_DRINK'), 1.0)
    actionWait(7300)
    dropProp(prop)
    return true
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
    Citizen.InvokeNative(0x72F52AA2D2B172CC, cache.ped, 599184882, bowl, joaat('p_bowl04x_stew_PH_L_HAND'), -583731576, 1, 0, -1.0)

    if spoon then
        Citizen.InvokeNative(0xCAAF2BCCFEF37F77, spoon, 82)
        Citizen.InvokeNative(0x72F52AA2D2B172CC, cache.ped, 599184882, spoon, joaat('p_spoon01x_PH_R_HAND'), -583731576, 1, 0, -1.0)
    end

    actionWait(700)
    if not Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) then return false end
    Citizen.InvokeNative(0xB35370D5353995CB, cache.ped, joaat('EAT_STEW_BOWL_EAT_FINISH_DISCARD'), 1.0)
    actionWait(8300)
    dropProp(bowl); dropProp(spoon)
    return true
end

--- Smoking -- the wander loop from the old script, which reads well standing still.
--- Three styles, three props: what is between the fingers is the whole difference.
local function smoke(propName, fallback)
    local dict, clip = 'amb_wander@code_human_smoking_wander@cigar@male_a@base', 'base'
    if not loadAnimDict(dict) then return false end

    SetCurrentPedWeapon(cache.ped, joaat('weapon_unarmed'), true)
    actionWait(200)

    local prop = makeProp(propName or fallback)
    if not prop and propName then prop = makeProp(fallback) end
    local bone = GetEntityBoneIndexByName(cache.ped, 'SKEL_R_FINGER12')

    TaskPlayAnim(cache.ped, dict, clip, 5.0, 5.0, 10000, 1, 0.0, false, false, false)

    if prop then
        AttachEntityToEntity(prop, cache.ped, bone, 0.0, 0.03, 0.01, 0.0, 180.0, 90.0,
            true, true, false, true, 1, true, false, false)
    end

    actionWait(100)
    if not IsEntityPlayingAnim(cache.ped, dict, clip, 3) then return false end
    actionWait(8900)
    dropProp(prop)
    ClearPedTasks(cache.ped)
    RemoveAnimDict(dict)
    return true
end

function Anims.cigarette(propName) return smoke(propName, 'p_cigarette01x') end
function Anims.cigar(propName) return smoke(propName, 'p_cigar01x') end
function Anims.pipe(propName) return smoke(propName, 'p_pipe01x') end

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

-- Ring and core overpower are separate engine attributes.

WHudGold = { health = { ring = 0, icon = 0 }, stamina = { ring = 0, icon = 0 } }

--- Apply the gilding to the engine, and record it for our own cores.
---@param index number CORE_HEALTH or CORE_STAMINA
---@param outer number|nil gilds the ring
---@param inner number|nil gilds the icon as well
local function gild(index, outer, inner)
    outer, inner = tonumber(outer) or 0, tonumber(inner) or 0
    if outer <= 0 and inner <= 0 then return end

    local seconds = (((Config.Gold or {}).Duration) or 30000) / 1000.0
    if outer > 0 then Citizen.InvokeNative(0xF6A7C08DF2E28B28, cache.ped, index, seconds, true) end
    if inner > 0 then Citizen.InvokeNative(0x4AF5A4C7B9157D14, cache.ped, index, seconds, true) end

    local slot = (index == CORE_HEALTH) and WHudGold.health or WHudGold.stamina
    local until_ = GetGameTimer() + (((Config.Gold or {}).Duration) or 30000)

    -- ★ The longer of the two wins rather than the newer: eating a second tonic while
    --   the first still glows must not cut the glow short.
    if outer > 0 and until_ > slot.ring then slot.ring = until_ end
    if inner > 0 and until_ > slot.icon then slot.icon = until_ end
end

-- ════════════════════════════════════════════════════════════════════════════
-- The horse's boosters
--
-- ★ w_stables' potent / special horse medicine and stimulants put an engine overpower on the
--   horse (w_stables client/care.lua) and announce it with the local event below. This is the same
--   bookkeeping WHudGold keeps for the player, per horse, so that the horse being ridden has its
--   health or stamina circle drawn in the booster colour while it lasts. Keyed by the entity
--   handle, which is the same in every resource on this client.
--
-- ⚠️ AddEventHandler, not RegisterNetEvent: a local announcement from another resource on this
--   client. The server cannot raise it.
-- ════════════════════════════════════════════════════════════════════════════
WHudGold.horses   = {}                           -- [ped] = { health = until, stamina = until }
WHudGold.horseDev = { health = 0, stamina = 0 }  -- /hudgold horse (client/dev.lua)

AddEventHandler('w_stables:horseBoosted', function(ped, core, seconds)
    ped, core, seconds = tonumber(ped), tonumber(core), tonumber(seconds)
    if not ped or ped == 0 or not seconds or seconds <= 0 then return end
    if core ~= CORE_HEALTH and core ~= CORE_STAMINA then return end

    local now = GetGameTimer()

    -- the table only ever holds a horse or two: drop the ones whose boosters have run out
    for handle, slot in pairs(WHudGold.horses) do
        if slot.health <= now and slot.stamina <= now then WHudGold.horses[handle] = nil end
    end

    local slot  = WHudGold.horses[ped] or { health = 0, stamina = 0 }
    local key   = (core == CORE_HEALTH) and 'health' or 'stamina'
    local until_ = now + math.floor(math.min(seconds, 3600) * 1000)

    -- the longer wins, as for the player's gilding
    if until_ > slot[key] then slot[key] = until_ end
    WHudGold.horses[ped] = slot
end)

--- What the HUD payload carries. nil while nothing is gilded, so the fingerprint stays quiet.
---@param mount number|nil the horse being ridden, if any: its boosters ride along
---@return table|nil
function WHudGold.snapshot(mount)
    local now = GetGameTimer()
    local h, s = WHudGold.health, WHudGold.stamina
    local horse = mount and mount ~= 0 and WHudGold.horses[mount] or nil
    local dev = WHudGold.horseDev

    local out = {
        healthRing   = h.ring > now,
        healthIcon   = h.icon > now,
        staminaRing  = s.ring > now,
        staminaIcon  = s.icon > now,
        horseHealth  = (horse ~= nil and horse.health > now) or dev.health > now,
        horseStamina = (horse ~= nil and horse.stamina > now) or dev.stamina > now,
    }

    if out.healthRing or out.healthIcon or out.staminaRing or out.staminaIcon
        or out.horseHealth or out.horseStamina then
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
        -- نسبة ما بقي (تُرسَل مع الحالة؛ الواجهة تكتفي بتلوين دائرة الصحة).
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
        SetEntityHealth(cache.ped, math.min(GetEntityMaxHealth(cache.ped), h), 0)
    end

    -- The stamina ring is the ped's stamina, not the core above: without this a tonic filled
    -- the icon and left the bar you sprint on where it was. outerStamina = percent of the bar.
    -- ! Of the bar's own ceiling (WHudStamina, client/func.lua), not _GET_PED_MAX_STAMINA: that
    --   one adds the core's fixed 22.4 to the bar (33.6 on a fresh character whose bar is 11.2),
    --   so a 25% coffee poured in three quarters of the bar and any tonic of 34% or more filled it.
    if entry.outerStamina and entry.outerStamina ~= 0 then
        local _, _, ceiling = WHudStamina.barPercent()
        Citizen.InvokeNative(0xC3D4B754C0E86B9E, cache.ped, ceiling * entry.outerStamina / 100.0) -- _CHANGE_PED_STAMINA (a delta)
    end

    gild(CORE_HEALTH,  entry.goldHealthOuter,  entry.goldHealthInner)
    gild(CORE_STAMINA, entry.goldStaminaOuter, entry.goldStaminaInner)
    if entry.focus and Config.Focus.Enabled then
        addCore(2, entry.focus)
        Citizen.InvokeNative(0x51345AE20F22C261, PlayerId(), entry.focus + 0.0, 0, 0, 1)
    end
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
exports.w_lib:FwOnCharacterLoaded(clearFx) -- and so does a new character


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

local function cleanupAction()
    WHudAnimalClient.cleanup()
    for prop in pairs(props) do pcall(dropProp, prop) end
    props = {}
    for dict in pairs(dictionaries) do RemoveAnimDict(dict) end
    dictionaries = {}
    if active and active.stage == 'select' then pcall(w.closeInputDialog) end
    if active and active.stage ~= 'select' then ClearPedTasks(cache.ped) end
end
-- ★ The client's own bound on a use. The server answers each stage within Config.Use.Timeout and
--   a commit within Config.Use.CommitTimeout; an answer lost past that (plus a margin) used to leave
--   hudConsuming up for good -- w_stables' E-mount and care rows and w_pets' follow refuse while it
--   is. Every server message for the use restarts it; the watchdog at the end enforces it.
local ANSWER_MARGIN = 15000
local function stageDeadline() return GetGameTimer() + Config.Use.Timeout + ANSWER_MARGIN end
local function commitDeadline() return GetGameTimer() + (Config.Use.CommitTimeout or 60000) + ANSWER_MARGIN end
local function release()
    if active then active.cancelled = true end
    -- ! pcall: release is the only way hudConsuming comes down, and a cleanup that threw skipped it
    local cleaned, problem = pcall(cleanupAction)
    active, busy = nil, false
    LocalPlayer.state:set('hudConsuming', false, false)
    if not cleaned then w.print.error(('consumable cleanup failed: %s'):format(tostring(problem))) end
end

-- Ask the engine to run the actual inventory item's interaction and create its prop.
-- A missing native interaction falls back to an authored category animation.
local function playNative(item)
    local asset = Config.ItemPresentation[item]
    if not asset or not asset.nativeHash or not asset.interaction then return nil end
    local state = joaat(asset.interaction)
    if not Citizen.InvokeNative(0x2D19BC4DF626CBE7, cache.ped, asset.nativeHash, state, 0) then return nil end
    Citizen.InvokeNative(0xAE72E7DF013AAA61, cache.ped, asset.nativeHash, state, 1, 0, 0.0)
    local start = GetGameTimer()
    while GetGameTimer() - start < 1500 do
        if Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) then break end
        actionWait(50)
    end
    if not Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) then return nil end
    start = GetGameTimer()
    while Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) do
        if GetGameTimer() - start > 14000 then return false end
        actionWait(50)
    end
    return GetGameTimer() - start >= 700
end

local function playScenario(name)
    local hash = joaat(name)
    Citizen.InvokeNative(0x524B54361229154F, cache.ped, hash, -1, true, 0, 0.0, false)
    local deadline = GetGameTimer() + 1500
    while GetGameTimer() < deadline and not Citizen.InvokeNative(0x34D6AC1157C8226C, cache.ped, hash) do actionWait(50) end
    if not Citizen.InvokeNative(0x34D6AC1157C8226C, cache.ped, hash) then
        ClearPedTasks(cache.ped)
        return false
    end
    actionWait(6500)
    -- a BOOL native answers 1, never true: `== true` read every finished scenario as a failure,
    -- and the item's fallback animation played again on top of it
    return Citizen.InvokeNative(0x34D6AC1157C8226C, cache.ped, hash) and true or false
end

Anims.unpack = function(_, item)
    local hash = Config.ItemPresentation[item].nativeHash
    local state = joaat('RECTANGLE@L11_W6-7_H2-5_InspectZ_HOLD')
    if not Citizen.InvokeNative(0x2D19BC4DF626CBE7, cache.ped, hash, state, 0) then return false end
    Citizen.InvokeNative(0xAE72E7DF013AAA61, cache.ped, hash, state, 1, 0, 0.0)
    actionWait(700)
    if not Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) then return false end
    actionWait(2300)
    return true
end

RegisterNetEvent('w_hud:client:prepareUse', function(item, token, forcedAnimal)
    if source ~= 65535 then return end
    -- ★ The server holds one use per player and offers a new one only after it answered the last:
    --   a use still active under another token is one whose answer never landed. Released here,
    --   instead of refusing every use after it with hudConsuming up.
    if active and active.token ~= token then
        w.print.warn(('consumable token %s was never answered: released'):format(tostring(active.token)))
        release()
    end
    if busy or LocalPlayer.state.stableCaring or IsEntityDead(cache.ped) or not Config.Consumables[item] then
        return TriggerServerEvent('w_hud:server:selectUse', token, false)
    end
    busy, active = true, { item = item, token = token, stage = 'select', deadline = stageDeadline() }
    LocalPlayer.state:set('hudConsuming', true, false)
    -- Let the inventory bridge close its own NUI before the target chooser takes focus.
    Wait(100)
    if not active or active.token ~= token then return end
    local ok, result = pcall(function()
        if forcedAnimal then return {'animal:' .. tostring(forcedAnimal)} end
        local options = WHudAnimalClient.choices(item)
        if #options == 1 then return { 'player' } end
        return w.inputDialog(WHudLocale.itemLabel(item), {
            { type = 'select', label = locale('needs.chooseTarget'), required = true, default = 'player', options = options },
        })
    end)
    if not active or active.token ~= token then return end
    local selected = ok and result and result[1]
    local target, netId
    if selected == 'player' then target = 'player'
    elseif type(selected) == 'string' then target, netId = selected:match('^(%a+):(%d+)$') end
    active.stage = 'waiting'
    TriggerServerEvent('w_hud:server:selectUse', token, target or false, tonumber(netId))
end)

RegisterNetEvent('w_hud:client:playUse', function(item, token, target, netId)
    if source ~= 65535 or not active or active.token ~= token or active.stage ~= 'waiting' then return end
    active.stage, active.target, active.netId = 'animate', target, netId
    active.deadline = stageDeadline()
    active.coroutine = coroutine.running()
    local operation = active
    local ok, done = xpcall(function()
        if target ~= 'player' then
            if not netId or not NetworkDoesEntityExistWithNetworkId(netId) then return false end
            local animal = NetToPed(netId)
            if not DoesEntityExist(animal) or IsEntityDead(animal) or IsPedOnMount(cache.ped) then return false end
            if target == 'animal' or Config.HorseItems[item].kind == 'water' then
                return WHudAnimalClient.play(animal, item, actionWait, makeProp)
            end
            if #(GetEntityCoords(cache.ped) - GetEntityCoords(animal)) > 3.5 then return false end
            local asset = Config.ItemPresentation[item]
            Citizen.InvokeNative(0xCD181A959CFDD7F4, cache.ped, animal, joaat('Interaction_Food'),
                asset and joaat(asset.model) or 0, true)
            actionWait(300)
            if not Citizen.InvokeNative(0x7FC84E85D98F063D, cache.ped) then return false end
            actionWait((Config.HorseCare.FeedTime or 5000) - 300)
            return DoesEntityExist(animal) and not IsEntityDead(animal) and
                #(GetEntityCoords(cache.ped) - GetEntityCoords(animal)) <= 3.5
        end
        local entry = Config.Consumables[item]
        if entry.scenario and playScenario(entry.scenario) then return true end
        local native = not entry.pack and playNative(item)
        if native ~= nil and not entry.pack then return native end
        local play = Anims[entry.anim]
        if not play then return false end
        w.print.debug(('consumable %s uses authored %s animation'):format(item, entry.anim))
        return play(entry.prop, item) == true
    end, debug.traceback)
    if active ~= operation then return end
    -- ! pcall: a cleanup that threw here never sent completeUse
    local cleaned, problem = pcall(cleanupAction)
    if not cleaned then w.print.error(('consumable cleanup failed: %s'):format(tostring(problem))) end
    if active ~= operation then return end
    active.stage, active.deadline = 'commit', commitDeadline()
    if not ok then w.print.debug(tostring(done)) end
    TriggerServerEvent('w_hud:server:completeUse', token, ok and done == true)
end)

RegisterNetEvent('w_hud:client:useFinished', function(token, item, target)
    if source ~= 65535 or not active or active.token ~= token then return end
    local netId = active.netId
    release()
    if not item or IsEntityDead(cache.ped) then return end
    local entry = Config.Consumables[item]
    if not entry then return end
    if target == 'animal' then
        WHudAnimalClient.apply(netId, item)
    elseif target == 'player' and not entry.pack then
        applyCores(entry)
        screenFx(entry.fx, entry.fxTime)
        if entry.curesPoison then WHudPoison.cure() end
        if entry.poison then WHudPoison.apply(entry.poison) end
        if entry.heal then TriggerEvent('w_hud:client:healed', item) end
    end
    PlaySoundFrontend('Core_Fill_Up', 'Consumption_Sounds', true, 0)
    local notice = entry.pack and 'needs.packOpened' or target == 'horse' and 'needs.horseFed'
        or target == 'animal' and 'needs.animalFed' or 'needs.consumed'
    WHudLocale.notify(notice, WHudLocale.PAPER, 'mp_anim_eat', 4000, { WHudLocale.itemLabel(item) })
end)

function IsConsumeBusy() return busy end
function SetConsumeBusy(value) if not active then busy = value == true end end
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then release() end
end)
AddEventHandler('playerSpawned', release)
exports.w_lib:FwOnCharacterLoaded(release)


-- ════════════════════════════════════════════════════════════════════════════
-- ★ The safety net for hudConsuming
--
--   The server answers every use: a result, a failure, a timeout, or a reset for a token it no
--   longer holds. Should that answer still not land, the use is released here once its deadline
--   passes; and the flag left up with no use behind it (the last instance of this resource, a stop
--   that failed) comes down. Its readers: w_stables (E-mount, care rows), w_pets (follow).
-- ════════════════════════════════════════════════════════════════════════════
if LocalPlayer.state.hudConsuming then LocalPlayer.state:set('hudConsuming', false, false) end
CreateThread(function()
    while true do
        Wait(1000)
        local ok, problem = pcall(function()
            if active then
                if active.deadline and GetGameTimer() > active.deadline then
                    w.print.warn(('consumable %s (token %s, stage %s) got no answer from the server: released')
                        :format(tostring(active.item), tostring(active.token), tostring(active.stage)))
                    release()
                end
            elseif LocalPlayer.state.hudConsuming then
                LocalPlayer.state:set('hudConsuming', false, false)
            end
        end)
        if not ok then w.print.error(('consumable watchdog: %s'):format(tostring(problem))) end
    end
end)
