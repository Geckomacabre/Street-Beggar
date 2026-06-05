-- ============================================================================
-- client/needs.lua
-- Custom drain system REMOVED — hunger, thirst, and stress are owned by
-- um_hud / qbx_consumables via qbx state bags:
--   LocalPlayer.state.hunger  (0-100)
--   LocalPlayer.state.thirst  (0-100)
--   LocalPlayer.state.stress  (0-100)
--
-- Hobo activities (campfire, shelter sleep) that previously restored internal
-- "morale/energy" now trigger server events that write to those state bags.
-- ============================================================================

-- Stub so other scripts that call these functions don't error
function GetNeed(name) return 100.0 end
function GetNeedsBeggingModifiers() return { give = 0, yell = 0 } end

-- Morale bump → reduce stress via server event
AddEventHandler('um_hobos:moraleBump', function(amount)
    TriggerServerEvent('um_hobos:adjustStress', -(amount or 5))
end)

-- Energy bump → restore hunger/thirst slightly via server event
AddEventHandler('um_hobos:energyBump', function(amount)
    TriggerServerEvent('um_hobos:adjustHunger', (amount or 5))
end)
