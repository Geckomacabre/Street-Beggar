-- ============================================================================
-- um_hobos — English locale
-- ============================================================================

Lang = {
    -- Job
    duty_on             = 'You hit the streets. Stay sharp out there.',
    duty_off            = 'You slip away from the streets for a while.',
    duty_location       = 'Hobo Camp',
    not_on_job          = 'You need to be a hobo to do that.',
    not_on_duty         = 'You need to be on duty first.',

    -- Rank up
    rank_up             = 'You\'ve been promoted to ~g~%s~s~ (Rank %d)!',
    skill_up            = '%s skill improved to level %d!',

    -- Needs
    hunger_warn         = '~o~You\'re getting hungry...',
    hunger_crit         = '~r~You\'re starving!',
    thirst_warn         = '~o~You\'re thirsty...',
    thirst_crit         = '~r~You\'re desperately thirsty!',
    hygiene_warn        = '~o~People are noticing the smell...',
    hygiene_crit        = '~r~You smell absolutely terrible.',
    energy_warn         = '~o~You\'re starting to drag...',
    energy_crit         = '~r~You\'re exhausted.',
    morale_warn         = '~o~Things aren\'t looking great.',
    morale_crit         = '~r~You\'re barely keeping it together.',

    -- Scavenging
    scavenge_start      = 'Rummaging through the trash...',
    scavenge_empty      = 'Nothing useful here.',
    scavenge_cooldown   = 'You already checked this spot recently.',
    scavenge_found      = 'You found something!',

    -- Shelter
    shelter_placed      = 'You set up camp here.',
    shelter_removed     = 'You packed up your shelter.',
    shelter_already     = 'You already have a shelter placed somewhere.',
    shelter_too_far     = 'Your shelter is too far away.',
    shelter_sleep       = 'Catching some Z\'s...',
    shelter_woke        = 'You feel a bit more rested.',
    shelter_needs_items = 'You need a ~y~shelter_frame~s~ and a ~y~tarp~s~ to build a shelter.',
    shelter_pickup_e    = '[E] Dismantle Shelter',
    shelter_sleep_e     = '[E] Sleep',
    shelter_stash_e     = '[E] Stash',

    -- Crafting
    craft_title         = 'Hobo Crafting',
    craft_success       = 'You made: %s',
    craft_no_materials  = 'Not enough materials.',

    -- Menu
    menu_title          = 'Hobo Life',
    menu_status         = 'Status',
    menu_craft          = 'Craft',
    menu_clothing       = 'Change Outfit',
    menu_duty           = 'Clock Off',
    menu_rank           = 'Rank: %s (Rank %d)',
    menu_xp             = 'XP: %d / %d',
    menu_skills         = 'Skills',
}

-- ============================================================================
-- Subtitle lines — loaded from locales/en.json
-- Access via SubtitleLines['category'] anywhere in client/server scripts.
-- ============================================================================
do
    local raw = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    SubtitleLines = (raw and json.decode(raw)) or {}
end
