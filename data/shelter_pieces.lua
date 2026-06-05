-- ============================================================================
-- Shelter blueprints
-- ============================================================================

ShelterPieces = {
    {
        id       = 'cardboard_fort',
        label    = 'Cardboard Fort',
        model    = 'v_ind_cs_box01',
        requires = {},   -- no materials needed (freebie)
        desc     = 'A pile of boxes taped together. Better than nothing.',
        scale    = 1.0,
    },
    {
        id       = 'tarp_tent',
        label    = 'Tarp Tent',
        model    = 'prop_cablereels_01',   -- placeholder — swap for custom if streamed
        requires = { { item = 'tarp', count = 1 }, { item = 'junk_wood', count = 2 } },
        desc     = 'A waterproof tarp stretched over sticks. Keeps the rain off.',
        scale    = 1.2,
    },
    {
        id       = 'pallet_fort',
        label    = 'Pallet Shelter',
        model    = 'prop_pallet_01',
        requires = { { item = 'junk_wood', count = 4 }, { item = 'junk_metal', count = 2 } },
        desc     = 'Stacked pallets with a corrugated roof. Almost cozy.',
        scale    = 1.0,
    },
    {
        id       = 'proper_camp',
        label    = 'Proper Camp',
        model    = 'prop_skid_tent_01',
        requires = {
            { item = 'shelter_frame', count = 1 },
            { item = 'tarp',          count = 1 },
            { item = 'junk_cloth',    count = 2 },
        },
        desc     = 'A real tent. Warm, dry, with a zip. You\'re living the dream.',
        scale    = 1.0,
    },
}
