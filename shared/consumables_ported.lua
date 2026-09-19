-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · shared/consumables_ported.lua
-- The consumables carried over from bln_hud
--
-- ═══ Why a second file and not a rewrite of the first ═══
--
--   shared/consumables.lua is a curated dozen: six pairs, each with a job, and
--   its comments explain every number. Pouring a hundred and sixty rows into it
--   would drown that. So the curated table stays the reference, and this file
--   adds to it -- Config.Consumables[k] is only filled where it is still empty,
--   which is what keeps the tuned `water` and `whisky` in that file winning over
--   the ported ones here.
--
--   Delete this file and the load line in fxmanifest.lua, and w_hud is back to
--   its curated dozen with nothing else touched.
--
-- ═══ Where it came from ═══
--
--   [bln]/bln_hud/config/usables.cfg.lua -- Usables.items, 170 entries.
--   Checked against the live `items` table: 168 of them are real rows a player
--   can hold, which is the whole point of carrying them over rather than
--   letting the shops sell what nothing could then consume.
--
-- ═══ The conversion ═══
--
--   name                  -> locales/{ar,en}.json item.<name> (en from bln, ar from the `items` table)
--                            so the notification matches the satchel
--   hunger · thirst       -> unchanged, both are 0-100
--   player.staminaCore    -> stamina        (0-100, the inner core)
--   player.staminaOuter   -> stamina        only where no core value was given
--   player.healthOuter    -> outerHealth    × 6: bln keeps a percentage of the
--                            outer ring, w_hud keeps the RDR 0-600 scale
--   player.boostHealth    -> goldHealthInner / goldHealthOuter
--   player.boostStamina   -> goldStaminaInner / goldStaminaOuter
--                            (bln stores a duration, w_hud a flag per ring; the
--                             duration itself lives in Config.Gold.Duration)
--   effects.animationName -> anim, mapped onto the seven w_hud implements
--   effects.screenFx      -> fx
--   horse{}               -> Config.HorseItems, a separate path entirely
--
-- ⚠️ Dropped on the way, because w_hud has no counterpart and inventing one
--    would be worse than saying so: stress, urine, tempModifier, drunk levels,
--    cooldown, requiredItems. bln_hud is stopped in server.cfg, so nothing owns
--    them any more - that was the decision, not an oversight.
-- ════════════════════════════════════════════════════════════════════════════

Config.Consumables = Config.Consumables or {}
Config.HorseItems  = Config.HorseItems or {}

--- ! Never an overwrite. A key already in shared/consumables.lua was put there
---   deliberately and tuned; this file only fills what is missing.
---@param target table
---@param rows table
local function addMissing(target, rows)
    for key, row in pairs(rows) do
        if target[key] == nil then target[key] = row end
    end
end

local Ported = {
    ['adrenaline'] = {
        kind = 'medical',
        stamina = 100,
        anim = 'syringe', prop = 'mp007_p_mp_syringe01x_1',
    },
    ['antipoison'] = {
        kind = 'medical',
        thirst = 20, stamina = 5, outerHealth = 6,
        curesPoison = true,
        anim = 'tonic', prop = 's_inv_antidote01x',
    },
    ['antipoison2'] = {
        kind = 'medical',
        thirst = 20, stamina = 5, outerHealth = 6,
        curesPoison = true,
        anim = 'tonic', prop = 's_inv_antidote01x',
    },
    ['asiaspower'] = {
        kind = 'drink',
        hunger = 50, thirst = 50,
        fx = 'PlayerOverpower', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine02x',
    },
    -- 'bandage': no resource registers it (w_ambulancejob does not exist on this server); it is
    -- a self-use medical item in shared/consumables_orphans.lua since 2026-09-18.
    ['beer'] = {
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        anim = 'bottle_small', prop = 'p_bottlebeer01a',
    },
    ['bidaouipower'] = {
        kind = 'drink',
        hunger = 50, thirst = 50,
        fx = 'PlayerOverpower', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine04x',
    },
    ['bread6'] = {
        kind = 'food',
        hunger = 20,
        anim = 'bite', prop = 'p_bread06x',
    },
    ['bread_pita'] = {
        kind = 'food',
        hunger = 20,
        anim = 'bite', prop = 'p_bread_14_ab_s_a',
    },
    ['chili'] = {
        kind = 'food',
        hunger = 5, thirst = -70,
        anim = 'bite', prop = 'p_pepper02x',
    },
    ['cobbler_strawberry'] = {
        kind = 'food',
        hunger = 47, thirst = 20,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['coffeesugar'] = {
        kind = 'drink',
        thirst = 32,
        anim = 'mug', prop = 'p_mugcoffee01x',
    },
    ['consumable_alcohol_candycane_cocktail'] = {
        kind = 'alcohol',
        thirst = 40,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_alcohol_cranberry_mimosa'] = {
        kind = 'alcohol',
        thirst = 40,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_alcohol_eggnog'] = {
        kind = 'alcohol',
        thirst = 40,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_applejuice'] = {
        kind = 'drink',
        thirst = 40,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_biscuits'] = {
        kind = 'food',
        hunger = 37,
        anim = 'bite', prop = 's_biscuits01x',
    },
    ['consumable_boiledegg'] = {
        kind = 'food',
        hunger = 45,
        anim = 'bite', prop = 'p_egg01x',
    },
    ['consumable_bread4'] = {
        kind = 'food',
        hunger = 25,
        anim = 'bite', prop = 'p_bread04x',
    },
    ['consumable_bread5'] = {
        kind = 'food',
        hunger = 15, thirst = 5,
        anim = 'bite', prop = 'p_bread05x',
    },
    ['consumable_bread7'] = {
        kind = 'food',
        hunger = 25,
        anim = 'bite', prop = 'p_bread07x',
    },
    ['consumable_breakfast'] = {
        kind = 'food',
        hunger = 25,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_can_peaches'] = {
        kind = 'food',
        hunger = 45, thirst = 20,
        anim = 'can', prop = 's_canrigpeaches01x',
    },
    ['consumable_canned_carrots'] = {
        kind = 'food',
        hunger = 45, thirst = 20,
        anim = 'can', prop = 'p_can01x',
    },
    ['consumable_canned_chicken'] = {
        kind = 'food',
        hunger = 45, thirst = 30,
        anim = 'can', prop = 's_canrigbeef01x',
    },
    ['consumable_canned_corn'] = {
        kind = 'food',
        hunger = 45, thirst = 10,
        anim = 'can', prop = 's_canrigcorn01x',
    },
    ['consumable_canned_vegetables'] = {
        kind = 'food',
        hunger = 35,
        anim = 'can', prop = 's_canrigpeas01x',
    },
    ['consumable_caramel'] = {
        kind = 'food',
        hunger = 34, thirst = 10, stamina = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_cheesecake'] = {
        kind = 'food',
        hunger = 36, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_chef_bacon_sandwich'] = {
        kind = 'food',
        hunger = 43, thirst = 10,
        anim = 'bite', prop = 'p_hamsandwich01x',
    },
    ['consumable_chef_butter'] = {
        kind = 'food',
        hunger = 30,
        anim = 'bite', prop = 's_bit_cheesewedge1x',
    },
    ['consumable_chef_cheedar_cheese'] = {
        kind = 'food',
        hunger = 30, thirst = 10,
        anim = 'bite', prop = 's_bit_cheesewedge1x',
    },
    ['consumable_chef_groundbeef'] = {
        kind = 'food',
        hunger = 40, thirst = 20, stamina = 15,
        anim = 'stew', prop = 'p_cs_meatbowl01x',
    },
    ['consumable_chickenpie'] = {
        kind = 'food',
        hunger = 40, thirst = 20, stamina = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_chipsnsalsa'] = {
        kind = 'food',
        hunger = 55, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_chocolate'] = {
        kind = 'food',
        hunger = 25, stamina = 15,
        anim = 'bite', prop = 's_chocolatebar01x',
    },
    ['consumable_cinnamonbuns'] = {
        kind = 'food',
        hunger = 37, thirst = 20, stamina = 15,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_coffee'] = {
        kind = 'drink',
        thirst = 30, stamina = 30,
        anim = 'mug', prop = 'p_mugcoffee01x',
    },
    ['consumable_coffeecake'] = {
        kind = 'food',
        hunger = 43, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_cookie_christmas'] = {
        kind = 'food',
        hunger = 40, thirst = 20,
        anim = 'bite', prop = 's_biscuits01x',
    },
    ['consumable_crumbcake'] = {
        kind = 'food',
        hunger = 47, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_cupcake_blueberry'] = {
        kind = 'food',
        hunger = 44, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_cupcake_buttercream'] = {
        kind = 'food',
        hunger = 42, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_cupcake_cherry_chocolate'] = {
        kind = 'food',
        hunger = 37, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_cupcake_chocolate'] = {
        kind = 'food',
        hunger = 37, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_donut'] = {
        kind = 'food',
        hunger = 47, thirst = 20, stamina = 5,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_donut2'] = {
        kind = 'food',
        hunger = 42, thirst = 10,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_donut3'] = {
        kind = 'food',
        hunger = 40, thirst = 10,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_donut4'] = {
        kind = 'food',
        hunger = 38, thirst = 10,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_donut5'] = {
        kind = 'food',
        hunger = 42, thirst = 10,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_donut6'] = {
        kind = 'food',
        hunger = 41, thirst = 10,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_donut7'] = {
        kind = 'food',
        hunger = 50, thirst = 10,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['consumable_fishnchips'] = {
        kind = 'food',
        hunger = 40, thirst = 20, stamina = 5,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_fried_bluegill'] = {
        kind = 'food',
        hunger = 33, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_friedtater'] = {
        kind = 'food',
        hunger = 37, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_frog_legs'] = {
        kind = 'food',
        hunger = 40, thirst = 10,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_grits'] = {
        kind = 'food',
        hunger = 42, thirst = 20,
        anim = 'stew', prop = 'p_bowl04x_stew',
    },
    ['consumable_herb_tomato'] = {
        kind = 'food',
        hunger = 10, thirst = 10,
        anim = 'bite', prop = 's_tomato01x',
    },
    ['consumable_herbal_medicine'] = {
        kind = 'drink',
        thirst = 30, stamina = 50, outerHealth = 48,
        anim = 'tonic', prop = 'p_bottlemedicine09x',
    },
    ['consumable_honeycomb_candy'] = {
        kind = 'food',
        hunger = 39,
        anim = 'bite', prop = 'p_candybrittle01x',
    },
    ['consumable_horchata'] = {
        kind = 'drink',
        thirst = 40,
        anim = 'mug', prop = 'p_mug01x',
    },
    ['consumable_huevos_rancheros'] = {
        kind = 'food',
        hunger = 45, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_iced_coffee_sugar'] = {
        kind = 'drink',
        thirst = 45,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_iguana_bits_cooked'] = {
        kind = 'food',
        hunger = 37,
        anim = 'bite', prop = 's_meatbit_chunck_small01x',
    },
    ['consumable_jello_blueberry'] = {
        kind = 'drink',
        thirst = 32,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_kidneybeans_can'] = {
        kind = 'food',
        hunger = 40, thirst = 20, stamina = 5,
        anim = 'can', prop = 's_canrigkidney01x',
    },
    ['consumable_lemonade_raspberry'] = {
        kind = 'drink',
        thirst = 40,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_lemoncake'] = {
        kind = 'food',
        hunger = 39, thirst = 37, stamina = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_lemondrops'] = {
        kind = 'food',
        hunger = 20, thirst = 20, stamina = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_meat_mutton_cooked'] = {
        kind = 'food',
        hunger = 48, thirst = 10,
        anim = 'bite', prop = 's_meatbit_rib_medium01x',
    },
    ['consumable_meat_plump_bird_oregano_cooked'] = {
        kind = 'food',
        hunger = 42, thirst = 10,
        anim = 'bite', prop = 'p_chickenhalf01x',
    },
    ['consumable_meat_prime_beef_cooked'] = {
        kind = 'food',
        hunger = 40,
        anim = 'bite', prop = 'p_cs_steakslice01x',
    },
    ['consumable_meat_snake_cooked'] = {
        kind = 'food',
        hunger = 50,
        anim = 'bite', prop = 'p_meatchunk_sm01x',
    },
    ['consumable_med_special'] = {
        kind = 'drink',
        hunger = 10, thirst = 10, stamina = 30, outerHealth = 30,
        anim = 'tonic', prop = 's_inv_supertonic01x',
    },
    ['consumable_medicine'] = {
        kind = 'drink',
        thirst = 15, stamina = 25, outerHealth = 60,
        anim = 'tonic', prop = 's_inv_medicine01x',
    },
    ['consumable_milkshake_blueberry'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_milkshake_chocolate'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_milkshake_chocolate_mint'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_milkshake_strawberry'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_milkshake_vanilla'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_peachjelly'] = {
        kind = 'drink',
        hunger = 40, thirst = 20,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_pie_banana_cream'] = {
        kind = 'food',
        hunger = 37, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_pie_key_lime'] = {
        kind = 'food',
        hunger = 39, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_pie_peach'] = {
        kind = 'food',
        hunger = 45,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_platter_lobster'] = {
        kind = 'food',
        hunger = 43, thirst = 20,
        anim = 'stew', prop = 'p_lobster_bisque01x',
    },
    ['consumable_poundcake'] = {
        kind = 'food',
        hunger = 40, thirst = 20, stamina = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_pretzel'] = {
        kind = 'food',
        hunger = 40, thirst = 10, stamina = 5,
        anim = 'bite', prop = 's_bit_bread06',
    },
    ['consumable_raspberrywater'] = {
        kind = 'drink',
        hunger = 35, thirst = 30,
        anim = 'bottle_small', prop = 'p_water01x',
    },
    ['consumable_salmon_can'] = {
        kind = 'food',
        hunger = 45, thirst = 37, stamina = 5,
        anim = 'can', prop = 's_canrigbeef01x',
    },
    ['consumable_seafood_platter'] = {
        kind = 'food',
        hunger = 45, thirst = 20,
        anim = 'stew', prop = 'p_crab_plate',
    },
    ['consumable_smores'] = {
        kind = 'food',
        hunger = 42,
        anim = 'bite', prop = 's_crackers01x',
    },
    ['consumable_soborno'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'bottle_small', prop = 'p_bottlebeer01a',
    },
    ['consumable_soup_chickenveg2'] = {
        kind = 'food',
        hunger = 55, thirst = 20,
        anim = 'stew', prop = 'p_bowl04x_stew',
    },
    ['consumable_soup_duck'] = {
        kind = 'food',
        hunger = 35,
        anim = 'stew', prop = 'p_bowl03x_stew',
    },
    ['consumable_spongecake'] = {
        kind = 'food',
        hunger = 37, thirst = 10, stamina = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_steak_veg'] = {
        kind = 'food',
        hunger = 42, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_taco'] = {
        kind = 'food',
        hunger = 45, thirst = 10,
        anim = 'bite', prop = 'p_bread_14_ab_s_a',
    },
    ['consumable_tanka_me_a_lo'] = {
        kind = 'food',
        hunger = 40, thirst = 20,
        anim = 'stew', prop = 'p_cs_meatstew01x',
    },
    ['consumable_tea_mint'] = {
        kind = 'drink',
        thirst = 35,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['consumable_tea_sage'] = {
        kind = 'drink',
        thirst = 35,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['consumable_tea_wild_berry'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['consumable_tea_yaupon'] = {
        kind = 'drink',
        thirst = 45,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['consumable_tonic'] = {
        kind = 'alcohol',
        thirst = 50,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['consumable_toulouse_style_cassoulet'] = {
        kind = 'food',
        hunger = 35,
        anim = 'stew', prop = 'p_bowl04x_stew',
    },
    ['consumable_tres_leches'] = {
        kind = 'food',
        hunger = 33,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_veggies'] = {
        kind = 'food',
        hunger = 43, thirst = 30, stamina = 5,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_vodka'] = {
        kind = 'alcohol',
        thirst = 50,
        anim = 'bottle', prop = 'p_bottle01x',
    },
    ['consumable_waffles'] = {
        kind = 'food',
        hunger = 40,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['cookedbluegil'] = {
        kind = 'food',
        hunger = 42, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['coolpeace'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['fairypower'] = {
        kind = 'drink',
        hunger = 50, thirst = 50,
        fx = 'PlayerOverpower', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine05x',
    },
    ['fullcanteen'] = {
        kind = 'drink',
        thirst = 25,
        anim = 'canteen', prop = 'p_canteen01x',
    },
    ['gin'] = {
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'bottle', prop = 's_inv_gin01x',
    },
    ['honeywhisky'] = {
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        fx = 'PlayerDrunkAberdeen', fxTime = 1,
        anim = 'bottle', prop = 'p_glenswhisky01x',
    },
    ['jelalipower'] = {
        kind = 'drink',
        hunger = 100, thirst = 100, stamina = 100, outerHealth = 600,
        fx = 'PlayerOverpower', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine06x',
    },
    ['large_beer'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'glass', prop = 'p_beermugglass01x',
    },
    ['liquor'] = {
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'bottle', prop = 'p_bottlejd01x',
    },
    ['marijuana_joint1'] = {
        kind = 'drug',
        stamina = 100, outerHealth = 102,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_1'] = {
        kind = 'drug',
        outerHealth = 198,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_2'] = {
        kind = 'drug',
        outerHealth = 300,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_3'] = {
        kind = 'drug',
        outerHealth = 402,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_4'] = {
        kind = 'alcohol',
        outerHealth = 450,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_5'] = {
        kind = 'alcohol',
        outerHealth = 498,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_6'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint1_7'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_1'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_2'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_3'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_4'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_5'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_6'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint2_7'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_1'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_2'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_3'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_4'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_5'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_6'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint3_7'] = {
        kind = 'drug',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint_double1'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint_double2'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['marijuana_joint_double3'] = {
        kind = 'alcohol',
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['omertapower'] = {
        kind = 'drink',
        fx = 'PlayerOverpower', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine07x',
    },
    ['pie_blueberry2'] = {
        kind = 'food',
        hunger = 37, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['potato'] = {
        kind = 'food',
        hunger = 20, thirst = 10,
        anim = 'bite', prop = 'p_potato01x',
    },
    ['powerpacino'] = {
        kind = 'drink',
        hunger = 50, thirst = 50, stamina = 30, outerHealth = 30,
        anim = 'tonic', prop = 'p_bottlemedicine08x',
    },
    ['powerpatata'] = {
        kind = 'drink',
        hunger = 100, thirst = 100, stamina = 100, outerHealth = 600,
        fx = 'PlayerOverpower', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine10x',
    },
    ['sumac_lemonade'] = {
        kind = 'drink',
        thirst = 37,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['unique_beef_stew'] = {
        kind = 'food',
        hunger = 70, thirst = 20,
        anim = 'stew', prop = 'p_beefstew01x',
    },
    ['unique_cajun_gumbo'] = {
        kind = 'food',
        hunger = 70, thirst = 20,
        anim = 'stew', prop = 'p_bowl04x_stew',
    },
    ['unique_colt46'] = {
        kind = 'drink',
        thirst = 33,
        anim = 'bottle_small', prop = 'p_bottlebeer01a',
    },
    ['unique_elote'] = {
        kind = 'food',
        hunger = 30,
        anim = 'bite', prop = 'p_corn01x',
    },
    ['unique_ginger_ale'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'bottle_small', prop = 'p_bottlebeer01a',
    },
    ['unique_helper'] = {
        kind = 'drink',
        thirst = 20, stamina = 5, outerHealth = 6,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['unique_mooncake'] = {
        kind = 'food',
        hunger = 45, thirst = 20,
        anim = 'bite', prop = 'p_oatcake01x',
    },
    ['unique_peach_tea'] = {
        kind = 'drink',
        hunger = 10, thirst = 45,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['unique_pineapple_cocktail'] = {
        kind = 'drink',
        thirst = 38,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['water'] = {
        kind = 'drink',
        thirst = 30,
        anim = 'bottle_small', prop = 'p_water01x',
    },
    ['watermelon'] = {
        kind = 'food',
        hunger = 20, thirst = 20,
        anim = 'bite', prop = 'proc_watermeloneaten01x',
    },
    ['whisky'] = {
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        fx = 'PlayerDrunkAberdeen', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['wine'] = {
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'bottle', prop = 'p_bottlewine01x',
    },
}

local PortedHorse = {
    ['apple'] = {
        kind = 'stamina', amount = 25, distance = 3.0,
    },
    ['consumable_haycube'] = {
        kind = 'stamina', amount = 25, distance = 3.0,
    },
    ['corn'] = {
        kind = 'stamina', amount = 25, distance = 3.0,
    },
    ['horseadrenaline'] = {
        kind = 'stamina', amount = 100, distance = 3.0,
    },
    ['horsebrush'] = {
        kind = 'brush', amount = 0, distance = 3.0,
        consume = false, -- a tool: brushing must not eat the brush
    },
}

addMissing(Config.Consumables, Ported)
addMissing(Config.HorseItems, PortedHorse)
