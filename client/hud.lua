-- client/hud.lua
-- Hobo HUD removed — hunger/thirst/stress are shown by um_hud via qbx state bags.
-- Rank/XP overlay removed per user request (separate HUD system handles it).
-- NUI page is still loaded for the pickpocket minigame only.
RegisterNUICallback('nuiReady', function(_, cb) cb('ok') end)
