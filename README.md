# um_beg / um_hobos — Hobo Tough Life

Street survival resource for **Qbox / QBX** servers. Combines a full begging system with an optional hobo job layer — progression, scavenging, pickpocketing, campfire, odd jobs, fence, and more.

---

## Table of Contents

1. [Dependencies](#dependencies)
2. [Installation](#installation)
3. [Items Required](#items-required)
4. [Job Setup](#job-setup)
5. [Feature Checklist & Test Guide](#feature-checklist--test-guide)
   - [Hobo Job — Duty](#1-hobo-job--duty)
   - [Begging (Auto Mode)](#2-begging--auto-mode)
   - [Begging (Manual Mode — /autobeg)](#3-begging--manual-mode)
   - [Begging Box](#4-begging-box)
   - [Busking / Guitar](#5-busking--guitar)
   - [Rare Events](#6-rare-events)
   - [Cardboard Sign Crafting](#7-cardboard-sign-crafting)
   - [Hobo Crafting Menu](#8-hobo-crafting-menu)
   - [Scavenging](#9-scavenging)
   - [Shelter](#10-shelter)
   - [Pickpocket Minigame](#11-pickpocket-minigame)
   - [Windshield Washing](#12-windshield-washing)
   - [Can & Bottle Collecting](#13-can--bottle-collecting)
   - [Odd Jobs Board](#14-odd-jobs-board)
   - [Campfire](#15-campfire)
   - [Stolen Goods Fence](#16-stolen-goods-fence)
   - [Progression — Rank & XP](#17-progression--rank--xp)
6. [Commands](#commands)
7. [Configuration Reference](#configuration-reference)

---

## Dependencies

| Resource | Required | Notes |
|---|---|---|
| `ox_lib` | ✅ | Notifications, progress bars, zones, menus |
| `ox_inventory` | ✅ | Item use, crafting, giving items |
| `ox_target` | ✅ | All world interactions |
| `oxmysql` | ✅ | Hobo progression database |
| `qbx_core` | ✅ | Player, money, job functions |
| `rcore_prison` | Optional | Jail handoff on hostile cop arrest |

---

## Installation

1. Drop the `um_beg` folder into your `resources` directory.
2. Add to `server.cfg`:
   ```
   ensure um_beg
   ```
3. Add items to `ox_inventory/data/items.lua` — see [Items Required](#items-required).
4. The `hobo` job must exist in `qbx_core/shared/jobs.lua` — see [Job Setup](#job-setup).
5. Run the server once; `oxmysql` will auto-create the `hobo_progression` table.

---

## Items Required

Add to `ox_inventory/data/items.lua`:

```lua
-- Begging
['cardboard_sign'] = {
    label = 'Cardboard Sign', weight = 200, stack = true, close = true,
    client = { event = 'um_beg:useSign' },
},
['cardboard_box'] = {
    label = 'Cardboard Box', weight = 300, stack = true,
},
['marker'] = {
    label = 'Marker', weight = 50, stack = true,
},
['begging_box'] = {
    label = 'Begging Box', weight = 400, stack = false, close = true,
    client = { event = 'um_beg:placeBox' },
},
['begging_guitar'] = {
    label = 'Busking Guitar', weight = 1500, stack = false, close = true,
    client = { event = 'um_beg:startBusking' },
},

-- Hobo job
['campfire_kit'] = {
    label = 'Campfire Kit', weight = 500, stack = true, close = true,
    client = { event = 'um_beg:useCampfireKit' },
},
['junk_wood']   = { label = 'Junk Wood',    weight = 200, stack = true },
['junk_metal']  = { label = 'Junk Metal',   weight = 300, stack = true },
['junk_cloth']  = { label = 'Junk Cloth',   weight = 100, stack = true },
['junk_glass']  = { label = 'Junk Glass',   weight = 150, stack = true },
['junk_food']   = { label = 'Food Scraps',  weight = 100, stack = true },
['junk_water']  = { label = 'Dirty Water',  weight = 200, stack = true },
['shelter_frame'] = { label = 'Shelter Frame', weight = 800, stack = false },
['tarp']          = { label = 'Tarp',          weight = 400, stack = false },
['hobo_knife']    = { label = 'Hobo Knife',    weight = 200, stack = false },

-- Collecting (recycling center)
['empty_can']    = { label = 'Aluminum Can',  weight = 20,  stack = true },
['empty_bottle'] = { label = 'Glass Bottle',  weight = 50,  stack = true },
```

> Item images go in `ox_inventory/web/images/` — filename must match item name exactly (e.g. `cardboard_sign.png`).

---

## Job Setup

The `hobo` job must be defined in `qbx_core/shared/jobs.lua`. Add:

```lua
['hobo'] = {
    label       = 'Hobo',
    defaultDuty = false,
    offDutyPay  = false,
    grades      = {
        ['0'] = { label = 'Street Rat',   payment = 0 },
        ['1'] = { label = 'Drifter',      payment = 0 },
        ['2'] = { label = 'Vagrant',      payment = 0 },
        ['3'] = { label = 'Panhandler',   payment = 0 },
        ['4'] = { label = 'Grifter',      payment = 0 },
        ['5'] = { label = 'Hobo',         payment = 0 },
    },
},
```

Give yourself the job in-game:
```
/setjob [id] hobo 0
```

---

## Feature Checklist & Test Guide

> **Before testing anything:** give yourself the `hobo` job. All hobo-system features are gated behind `isOnHoboJob()`.

---

### 1. Hobo Job — Duty

The resource automatically detects your job from the qbx state bags. No manual duty toggle needed.

- [ ] Give yourself the `hobo` job — all features should become active immediately
- [ ] Remove the job (`/setjob [id] unemployed 0`) — features should deactivate
- [ ] Blips for **Job Board**, **Recycling Center**, and **Fence** should appear on the map while on duty

---

### 2. Begging — Auto Mode

Default mode. Stand near traffic and the script auto-scans for stopped cars.

- [ ] Give yourself a `cardboard_sign`, use it or type `/beg`
- [ ] Sit down animation plays, prop attaches to hand
- [ ] Cars at red lights trigger outcomes (give / yell / ignore / cop) every 4–9 seconds
- [ ] On **give** — car honks, blip appears, player auto-walks to car, cash received, player walks back
- [ ] On **yell** — horn blast + speech
- [ ] On **ignore** — subtitle appears
- [ ] On **cop** — police cruiser spawns, drives over (see [Rare Events](#6-rare-events))
- [ ] Press `/beg` again or `X` to stop
- [ ] **Zone modifier test** — beg in Rockford Hills (nice) vs Davis (bad) and compare give rates

---

### 3. Begging — Manual Mode

- [ ] While begging, type `/autobeg` — notification confirms **Auto-beg OFF**
- [ ] Auto-scanning stops; `[E] Beg` prompt appears when within 5 m of a stopped car or walking ped
- [ ] Press E on a car — outcome rolls for that specific target
- [ ] Press E on a ped — same outcome system, including mugging chance
- [ ] Type `/autobeg` again to re-enable auto mode

---

### 4. Begging Box

- [ ] Give yourself a `begging_box`, use it from inventory
- [ ] Ghost prop appears in front of player — press **[E]** to confirm placement, **[Backspace]** to cancel
- [ ] Box spawns; progress bar animation plays during placement
- [ ] Without begging: NPCs walk over every ~20 seconds and drop small cash (box_only tier)
- [ ] While begging nearby: payout tier upgrades to `sign_and_box` (higher payouts)
- [ ] Walk back to the box — `[E]` prompt appears — press to pick it up

---

### 5. Busking — Guitar

Requires a `begging_box` placed within 10 m.

- [ ] Give yourself a `begging_guitar`, use it from inventory
- [ ] If no box nearby — error notification
- [ ] Guitar attaches to hand, animation plays, player is **frozen in place**
- [ ] NPCs periodically walk up to the box and drop money (box_and_guitar tier — highest payouts)
- [ ] Use the guitar item again to stop busking
- [ ] Player unfreezes and guitar prop is removed

---

### 6. Rare Events

#### Cop Encounter
- [ ] **Nice cop (50%)** — cruiser arrives, cop exits, tips you $100, leaves
- [ ] **Mean cop (50%)** — arrest dialog appears: choose **Run** (wanted level 2) or **Surrender** (busted screen + jail via rcore_prison)
- [ ] Cop car and ped despawn cleanly after the encounter

#### Limo Encounter
- [ ] Beg for at least **2 minutes** continuously
- [ ] Limo spawns from a road node (not from on top of you)
- [ ] Subtitle announces the approaching limo
- [ ] Limo pulls up, player auto-walks over, generous payout received ($75–$250)
- [ ] Limo drives away naturally and despawns when 80 m away

#### Mugging
- [ ] Occasionally a ped rolls "give" but is actually a mugger
- [ ] They wave, walk toward you, subtitle warns you
- [ ] On arrival: they steal cash and flee
- [ ] Mugger ped despawns after fleeing

#### Drive-by Toss
- [ ] Occasionally a moving car throws coins as it passes (not enabled by default — set `Config.DriveByToss.enabled = true` to test)

---

### 7. Cardboard Sign Crafting

- [ ] Give yourself `cardboard_box` x1 and `marker` x1
- [ ] Walk to any crafting bench location (Skid Row, Olympic Freeway, Vespucci Beach)
- [ ] `[E] Craft Cardboard Sign` prompt appears via ox_target
- [ ] Progress bar plays; `cardboard_sign` added to inventory

---

### 8. Hobo Crafting Menu

- [ ] Type `/hobo` and select **Craft**
- [ ] Recipes shown: Dirty Water, Food Scraps, Shelter Frame, Tarp, Hobo Knife
- [ ] Test a recipe you have materials for — items consumed, result added to inventory
- [ ] Test a recipe without materials — error message shown

---

### 9. Scavenging

- [ ] Walk up to any dumpster or trash bin in the world
- [ ] ox_target radial shows **Scavenge**
- [ ] Progress bar plays; loot item added to inventory (or "nothing useful here")
- [ ] Same dumpster can't be searched again until cooldown expires (5 minutes)
- [ ] Higher scavenging skill unlocks better loot tiers

---

### 10. Shelter

- [ ] Give yourself `shelter_frame` x1 and `tarp` x1
- [ ] Type `/hobo` → **Shelter** → **Place Shelter**
- [ ] Ghost preview appears; press **[E]** to confirm, **[Backspace]** to cancel
- [ ] Shelter prop spawns; ox_target shows: **Sleep**, **Stash**, **Remove**
- [ ] **Sleep** — progress bar plays; energy restored (if needs enabled) or stress reduced
- [ ] **Stash** — opens a personal ox_inventory stash (15 slots)
- [ ] **Remove** — shelter despawns
- [ ] Shelter location is saved to DB and restored on next login

---

### 11. Pickpocket Minigame

- [ ] Walk up to any ambient NPC (not a shop clerk or script ped)
- [ ] ox_target radial shows **Pickpocket**
- [ ] Select it — approach animation plays, grid minigame appears (5 slots, 2–3 filled)
- [ ] Cursor sweeps left/right; press **[Space]** when it's over a filled slot
- [ ] **Success** — item/cash added, ped wanders away (never looks at you)
- [ ] **Fail — flees** (40%) — ped shouts and runs
- [ ] **Fail — angry** (30%) — ped confronts and throws punches for ~10 seconds
- [ ] **Fail — nervous** (30%) — ped shouts and walks away
- [ ] **Cop call** — 8% chance on any failure (independent of ped reaction)
- [ ] Walk up to loaf_storerobbery shop clerk — **Pickpocket** option should NOT appear
- [ ] Walk up to the fence NPC — **Pickpocket** option should NOT appear
- [ ] Per-ped 5-minute cooldown — try same NPC twice quickly

---

### 12. Windshield Washing

- [ ] Walk up to a stopped car (at a red light or parked)
- [ ] ox_target radial shows **Wash Windshield**
- [ ] **Refuse (25%)** — driver waves you off, short cooldown
- [ ] **Yell (15%)** — driver honks and insults you, full cooldown
- [ ] **Pay** — progress bar plays; cash received ($3–$35)
- [ ] Same driver can't be washed again for 3 minutes

---

### 13. Can & Bottle Collecting

- [ ] Walk around the map near hobo camp locations — `prop_beer_can_01` props appear on the ground
- [ ] Walk within 2.5 m — prop disappears, `empty_can` or `empty_bottle` added to inventory, sound plays
- [ ] Props respawn at that location after 5 minutes
- [ ] Walk to the **Recycling Center** blip (near Olympic Freeway)
- [ ] ox_target on the bin — **Sell Cans & Bottles**
- [ ] Cans sell for $1 each, bottles for $2 each — total shown in notification

---

### 14. Odd Jobs Board

- [ ] Walk to the **Job Board** blip at the Skid Row hobo camp
- [ ] ox_target on the corkboard — **Check Job Board**
- [ ] Menu opens showing 3 available jobs (rotate hourly)
- [ ] **Collect job** — accept it, trash pile props (`prop_rub_binbag_01`) appear in the zone, waypoint set
  - [ ] Walk near each pile — auto-collected, counter shown
  - [ ] Collect all piles — complete job event fires, cash + XP rewarded
- [ ] **Delivery job** — accept it, package prop appears at pickup location
  - [ ] Walk to package — it attaches to your hand, waypoint changes to dropoff
  - [ ] Walk to dropoff — job completes, cash + XP rewarded
- [ ] Time limit enforced — abandon mid-job and wait; "ran out of time" notification fires

---

### 15. Campfire

- [ ] Give yourself `campfire_kit` x1 and `junk_wood` x2
- [ ] Use the `campfire_kit` from inventory
- [ ] If missing fuel — error message
- [ ] Ghost preview appears; press **[E]** to place, **[Backspace]** to cancel
- [ ] `prop_firebarrel` spawns; `core/ent_amb_barrel_fire` particle plays on top
- [ ] ox_target on the fire — **Cook / Manage Fire** radial option
- [ ] Menu shows: cooking recipes, Add Fuel, Extinguish
- [ ] **Cook** — select a recipe you have ingredients for; progress bar plays; output item received
- [ ] **Add Fuel** — requires 1x `junk_wood`; burn time extended 15 minutes
- [ ] **Extinguish** — fire and particles removed
- [ ] Standing near the fire restores stress every 30 seconds (visible in um_hud stress bar)

---

### 16. Stolen Goods Fence

- [ ] The **Shady Dealer** blip should be visible on the map while on duty
- [ ] Walk to the fence NPC location — `a_m_m_skidrow_01` ped standing idle
- [ ] Walk within 2.5 m — ox_target radial shows **Sell Stolen Goods**
- [ ] Select it — if you have no fenceable items: *"You don't have anything worth fencing"*
- [ ] Give yourself `phone`, `cheap_watch`, or `lockpick` and try again
- [ ] Menu lists only items you actually have, with count and price
- [ ] Select an item — items removed from inventory, cash received
- [ ] **Busted (8% chance)** — 1-star wanted level after a short delay
- [ ] 60-second cooldown between sales
- [ ] Charisma skill increases prices (+5% per level)

---

### 17. Progression — Rank & XP

- [ ] Perform any hobo activity — check F8 console for `gainXP` server events
- [ ] `/hobostatus` — prints current rank, total XP, and all four skill levels to chat
- [ ] `/hobo` — opens the hobo menu (status, craft, shelter, clothing, duty toggle)
- [ ] Rank-up is saved to the `hobo_progression` database table
- [ ] Logout and back in — rank/XP/skills should persist

**Skills and what levels them:**
| Skill | XP Source |
|---|---|
| Begging | Every successful beg payout |
| Scavenging | Every successful dumpster scavenge |
| Charisma | Generous beg, limo payout, pickpocket success |
| Survival | Crafting, shelter sleep |

---

## Commands

| Command | Description |
|---|---|
| `/beg` | Toggle sign begging |
| `/autobeg` | Toggle auto-beg (cars approach you) vs manual ([E] to beg) |
| `/hobo` | Open hobo life menu |
| `/hobostatus` | Print rank / XP / skills to chat |
| `/hoboduty` | Fallback duty toggle (not normally needed) |

---

## Configuration Reference

All settings are in `config.lua`. Key sections:

| Section | What it controls |
|---|---|
| `Config.BegVariants` | Beg animation dict/clip/prop |
| `Config.Outcomes` | Base % weights: give / yell / ignore / cop |
| `Config.AreaModifiers` | Per-zone outcome adjustments |
| `Config.Payout` / `Config.PayoutTiers` | Cash ranges per tier |
| `Config.CopEncounter` | Cop models, payout, wanted level, jail time |
| `Config.LimoEncounter` | Limo models, payout range, trigger conditions |
| `Config.Mug` | Mugging chance, steal range |
| `Config.DriveByToss` | Enable/disable, chance, payout |
| `Config.BeggingBox` | Box model, placement offset, audience interval |
| `Config.Guitar` | Guitar model/bone/anim |
| `Config.CraftingBenches` | Cardboard sign crafting spots |
| `Config.ZoneAreas` | Zone name → nice/normal/bad mapping |
| `Config.JobName` | Job name (`'hobo'`) |
| `Config.HoboCamps` | Hobo camp locations, blips, and zone radii |
| `Config.RankXP` / `Config.RankNames` | 20-rank progression thresholds and titles |
| `Config.Pickpocket` | Slot count, slider speeds, loot pool, blocked models |
| `Config.Washing` | Payout range, refuse/yell chance, animation |
| `Config.Collecting` | Spawn locations, prices, respawn timer |
| `Config.OddJobs` | Job pool, payout, time limits |
| `Config.Campfire` | Prop, particle, fuel item, cooking recipes |
| `Config.Fence` | Location, ped model, item prices, cop risk |

---

## Notes

- **Subtitle lines** are in `locales/en.json` — edit freely without touching `config.lua`
- **Hunger / thirst / stress** are read directly from qbx state bags by `um_hud` — the hobo script does not maintain its own needs system
- **Pickpocket blocked models** — only add models that are exclusively script peds; ambient peds using the same model will also be blocked
- The fence NPC and other locally-spawned peds are automatically blocked from pickpocketing via the `NetworkGetEntityIsNetworked` check — no model listing needed

---

## Credits

- **Upstate Mafia** — resource development
