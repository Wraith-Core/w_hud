-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · shared/satchels.lua
-- Satchels -- items that permanently raise how much the player can carry
--
-- ═══ How it works ═══
--
--   The inventory's base capacity is the convar `inventory:weight` (30000 = 30kg by
--   default). We never touch that. We store a **bonus** per character and set
--
--       maxWeight = base + bonus
--
--   through exports.w_inventory:SetMaxWeight on every login and after every upgrade.
--
-- ★ Reading the base from the convar rather than writing 30000 here: change the convar
--   in server.cfg and every satchel stays correct on its own. A copied constant would
--   quietly desync the day someone edits one and not the other.
--
-- ⚠️ Tiers, not stacks. Each satchel is a rank: buying the large one replaces the small
--   one's bonus rather than adding to it, exactly as in RDR2. Otherwise a player buys
--   ten small satchels and carries a wagon.
--
--   And a tier already owned refuses politely and is NOT consumed -- losing an item to
--   a no-op is the kind of thing players remember.
-- ════════════════════════════════════════════════════════════════════════════

--- Bonus in grams. 1000 = 1kg. The display name of each tier is locale('item.<name>')
--- from locales/{ar,en}.json.
---
--- ★ `rank` is what makes them tiers: a satchel is only accepted if its rank is higher
---   than what the character already owns.
Config.Satchels = {
    ['satchel_small'] = {
        rank  = 1,
        bonus = 10000, -- +10kg  => 40kg total by default
    },

    ['satchel_medium'] = {
        rank  = 2,
        bonus = 25000, -- +25kg  => 55kg
    },

    ['satchel_large'] = {
        rank  = 3,
        bonus = 45000, -- +45kg  => 75kg
    },

    ['satchel_legendary'] = {
        rank  = 4,
        bonus = 70000, -- +70kg  => 100kg
    },
}
