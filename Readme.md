<img width="938" height="572" alt="beggar" src="https://github.com/user-attachments/assets/82bbb8eb-ad58-4959-b3db-9f30481ab589" />

### FiveM Street Begging Made By Geckomacabre

A fully-featured street begging & busking resource for **Qbox / QBX** servers.  
Beg at car windows, place a donation box, or busk with a guitar — each setup unlocks a higher payout tier. Rare events (limo encounter, cop encounter, mugging, drive-by toss) fire on top of normal gameplay.

---

## Features

- **Sign begging** — use a `cardboard_sign` to sit on the curb and beg at stopped cars and pedestrians
- **Begging box** — place a `begging_box` on the street; NPCs passively walk over and drop money
- **Guitar busking** — use a `begging_guitar` near your box for a 2-minute progress bar with a big lump-sum payout
- **Payout tiers** — four setups each earning more than the last (box → sign → sign+box → box+guitar)
- **3-D box preview** — ghost prop with a ground marker before confirming placement
- **Cardboard sign crafting** — craft a sign from a `cardboard_box` + `marker` at configurable street locations
- **Zone-based modifiers** — wealthy areas give more, rough areas yell more and call fewer cops
- **Rare events**
  - 🚔 Cop encounter — nice cop tips you, mean cop can arrest or give a wanted level
  - 🚗 Drive-by toss — moving cars randomly throw coins without stopping
  - 🚕 Limo encounter — rare, always generous, fires after 2+ min of begging; can also give bonus items
  - 🔪 Mugging — an NPC pretends to give money then robs you
- **ox_inventory** item use support — use items straight from the hotbar or inventory
- **rcore_prison** jail handoff for hostile cop arrest
- **Fully configurable** — tiers, outcomes, areas, cooldowns, models, everything in `config.lua`

---

## Dependencies

| Resource | Notes |
|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | Notifications, progress bars, zones, alert dialogs |
| [ox_inventory](https://github.com/overextended/ox_inventory) | Item handling, crafting hooks |
| [qbx_core](https://github.com/Qbox-project/qbx_core) | Player / money functions (fallback to `qb-core`) |
| [rcore_prison](https://github.com/rcoreteam/rcore_prison) *(optional)* | Jail handoff on hostile cop arrest |

---

## Installation

1. Drop `um_beg` into your resources folder and add `ensure um_beg` to `server.cfg`.
2. Add the items to `ox_inventory/data/items.lua` (see [Items](#items) below).
3. Add item images to `ox_inventory/web/images/` (see [Images](#images)).
4. Restart or start the resource — no SQL needed.

---

## Items

Add these entries to `ox_inventory/data/items.lua`:

```lua
['cardboard_sign'] = {
    label = 'Cardboard Sign', weight = 200, stack = true, close = true,
    client = { event = 'um_beg:useSign' },
},
['cardboard_box'] = {
    label = 'Cardboard Box', weight = 300, stack = true, close = true,
},
['marker'] = {
    label = 'Marker', weight = 50, stack = true, close = true,
},
['begging_box'] = {
    label = 'Begging Box', weight = 400, stack = false, close = true,
    client = { event = 'um_beg:placeBox' },
},
['begging_guitar'] = {
    label = 'Busking Guitar', weight = 1500, stack = false, close = true,
    client = { event = 'um_beg:startBusking' },
},
```

---

## Images

Place `.png` files in `ox_inventory/web/images/`.  
File names must match the item names exactly:

| File | Item |
|---|---|
| `cardboard_sign.png` | Cardboard Sign |
| `cardboard_box.png` | Cardboard Box (copy from `box.png` if needed) |
| `marker.png` | Marker |
| `begging_box.png` | Begging Box |
| `begging_guitar.png` | Busking Guitar |

---

## Crafting a Cardboard Sign

Walk to any configured crafting location (default: Skid Row, Olympic Freeway underpass, Vespucci Beach) and press **[E]**.  
A progress bar plays while you write on the cardboard.

**Recipe:** `1× cardboard_box` + `1× marker` → `1× cardboard_sign`

Locations are fully configurable in `Config.CraftingBenches`.  
Fallback command: `/craftbegbox` (works anywhere, no bench required).

---

## Gameplay

### Sign Begging (`cardboard_sign`)
Use the sign from inventory or run `/beg` to toggle begging.  
Sit on the curb — stopped cars and nearby pedestrians roll a random outcome every few seconds:

| Outcome | Effect |
|---|---|
| Give | Driver/ped waves you over, auto-walk, collect cash |
| Yell | Horn blast, insults |
| Ignore | They pretend you don't exist |
| Cop | Police cruiser spawns and approaches |

### Begging Box (`begging_box`)
Use the item to enter 3-D placement mode.  
- Ghost prop + green circle shows where it will land
- **[E]** to confirm, **[Backspace]** to cancel
- After placing, stand nearby — NPCs will walk over and drop money every ~20 seconds
- Walk back to the box and press **[E]** to pick it up

Having the box placed within 8 m while sign-begging upgrades the payout tier automatically.

### Busking (`begging_guitar`)
Requires a box placed within 10 m.  
Use the guitar — it attaches to your hands and a **2-minute progress bar** begins.  
Completing the full bar pays the highest regular payout. Cancelling early gives nothing.

---

## Payout Tiers

| Setup | Base Range | Generous Range | Generous Chance |
|---|---|---|---|
| Box only | $1 – $6 | $8 – $18 | 2% |
| Sign only | $1 – $15 | $25 – $75 | 5% |
| Sign + Box | $8 – $28 | $40 – $100 | 8% |
| Box + Guitar | $30 – $90 | $80 – $200 | 15% |
| Limo encounter | $75 – $250 | — | 100% (always generous) |

All values are configurable in `Config.Payout`, `Config.PayoutTiers`, and `Config.LimoEncounter`.

---

## Rare Events

### 🚔 Cop Encounter (5% roll chance)
A police cruiser spawns and drives to you.
- **Nice cop (50%)** — tips you $100 and leaves
- **Mean cop (50%)** — you choose: surrender (busted screen → jail) or run (wanted level 2)

### 🚗 Drive-by Toss (4% per roll)
A moving car throws coins from the window — no stopping required.

### 🚕 Limo Encounter (rare, time-gated)
Unlocks after 2 minutes of begging. 4% chance per roll interval with a 5-minute cooldown.  
Always generous ($75–$250). Can also drop configurable bonus items.

### 🔪 Mugging (15% of ped-give rolls)
An NPC waves you over, walks up, steals $10–$40, then flees.

---

## Zone Modifiers

Payout odds shift based on what GTA zone the player is begging in:

| Area Type | Effect |
|---|---|
| **Nice** (Rockford Hills, Vinewood, etc.) | +25% give chance, -10% yell, +5% cop |
| **Normal** | No change |
| **Bad** (Davis, Chamberlain, Rancho, etc.) | -15% give, +15% yell, -3% cop |

Zones are mapped in `Config.ZoneAreas`. Any unlisted zone defaults to `normal`.

---

## Commands

| Command | Description |
|---|---|
| `/beg` | Toggle sign begging (also works via item use) |
| `/craftbegbox` | Craft a cardboard sign anywhere (fallback, no bench needed) |

---

## Configuration Reference

All settings live in `config.lua`. Key sections:

```
Config.BegVariants          Animation variants for the sign begging emote
Config.ScanRange            How far away cars/peds can be targeted (metres)
Config.ConeAngleDegrees     Forward scan cone width (degrees)
Config.Outcomes             Base % weights for give/yell/ignore/cop
Config.AreaModifiers        Per-zone adjustments to outcome weights
Config.PersonalityModifiers Per-ped-type adjustments
Config.Offer                Auto-walk speed, claim radius, timeout
Config.CopEncounter         Cop models, payout, wanted level, jail time
Config.LimoEncounter        Limo models, payout range, trigger conditions, bonus items
Config.Mug                  Mugging chance, steal range, timing
Config.DriveByToss          Enable, range, chance, payout range
Config.Payout               Base sign-only payout (min/max/generous)
Config.PayoutTiers          Overrides for box_only / sign_and_box / box_and_guitar
Config.BeggingBox           Box model, placement distance, audience interval
Config.Guitar               Guitar model/bone/anim, busking duration
Config.CraftingBenches      List of { label, coords, radius } crafting spots
Config.ZoneAreas            GetNameOfZone() → 'nice'|'normal'|'bad' mapping
Config.RequireItem          true = cardboard_sign required to beg
Config.BegItem              Item name for the sign (default: 'cardboard_sign')
Config.Craft                Recipe items for the crafting bench
Config.UseOxInventory       true = ox_inventory payments, false = qbx_core fallback
Config.OxMoneyItem          Money item name in ox_inventory (default: 'money')
Config.MaxBegPerSession     Cap on payouts per beg session (0 = unlimited)
Config.RewardCooldownMs     Minimum ms between server-side reward events
```

---

## Credits

- **Upstate Mafia** — core resource
- Guitar animation & busking mechanic inspired by [Kael-Street-Beggar](https://github.com/abdullasadi/Kale-Street-Beggar) (GPL-3.0)


## Join With Us
- [Discord](tba)
- [Tebex](tba)

