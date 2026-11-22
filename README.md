# w_hud

Player HUD, server-authoritative needs (hunger & thirst), satchel weight bonus, voice proximity indicator, and server-wide announcements for **Wraith Framework RedM**.

## Key Features

- **Clean RedM HUD:** Health, stamina, hunger, thirst, money balances, and voice proximity level.
- **Server-Authoritative Needs:** Hunger and thirst tracked and saved server-side (`w_hud_needs`).
- **Player Customization:** Per-player HUD settings panel (`/hudsettings`, saved in `w_hud_settings`).
- **Server Announcements:** Top-center announcement banner via `exports.w_hud:Announce(...)`.

## Installation

1. Place `w_hud` in `resources/[wraith]/w_hud`.
2. Import the SQL files in `sql/` (also auto-created on startup).
3. Add `ensure w_hud` to `server.cfg` after `w_lib` and `w_core`.

## Key Exports

```lua
-- Server-wide announcement
exports.w_hud:Announce('Server restart in 5 minutes.', 15, { title = 'Announcement', target = -1 })

-- Needs management (Server)
exports.w_hud:AddNeed(source, 'hunger', 25)
exports.w_hud:SetNeed(source, 'thirst', 100)
exports.w_hud:ResetNeeds(source)

-- Client HUD toggle
exports.w_hud:SetDisplay(true)
exports.w_hud:OpenHudSettings()
```

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/interface-world
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe
