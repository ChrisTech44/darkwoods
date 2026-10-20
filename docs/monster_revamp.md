# Monster revamp: one verb per creature

Status: **implemented** (user request, 17 October 2026). Every creature below,
the stalker's traits and the items are in the game and covered by
`tests/integration/monster_revamp.gd`. The development log records how it was
verified. Where the build differs from the first draft:
- **The Conductor roams the woods** (he can't send you to the Rail Yard if he
  lives there); the **Trash Jackals** (a pair) guard the Rail Yard instead.
- **The Vampire doesn't heal.** Its gaze lasts at most 4 s before it must look
  away for 6 s. Breaking its pull or escaping its bite also starts that cooldown;
  a flare breaks it, and a sprint outruns the pull.
- **The werewolf still fears flares** when transformed.
- **Bigfoot fur** is scored when picked up (+300 each).
- **The grip** (user follow-up): struggle drains while you aren't pressing
  (0.1/s for creatures, 0.06/s for the stalker); each grab by the same kind of
  creature adds 2 presses, capped at +4 above its base; the stalker jolts his captive
  every 3 s (−10% progress); tearing free of him leaves you tripped (1 s) and
  drops what you held. Teammates' flashes, flares and the air horn free you
  instantly and cleanly.
- **Blood Moon** brings the moon out about twice as often and speeds up the
  Stalker. Following the 19 October full-roster request, every creature type
  remains present; pranksters are no longer replaced by werewolves.

Code map:
- **Creatures:** `scripts/ai/brains/<id>.gd` (one CreatureBrain each) on
  the shared body `scripts/ai/cryptid.gd`.
- **The stalker:** `scripts/ai/stalker_traits.gd` and `scripts/ai/camp_song.gd`;
  bear traps live in `scripts/world/snares.gd`.
- **Player effects:** `CampPlayer.effects`, plus `grab`, `wriggle` and `shove`.
- **Overlays:** `scripts/ui/effects_overlay.gd`.
- **Voice:** helium and frog pitch buses, and the Mimic's replay, in
  `scripts/network/voice_chat.gd`.

## Goals (from the request)

1. Revamp the monsters and add fun new ones.
2. Not every monster is lethal or simply charges you. Some create funny,
   memorable moments: stealing items, carrying a player away, raising the pitch
   of someone's voice.
3. Every monster is drastically different. Slight stat variations are out:
   each creature has its **own verb**, its **own tell** and its **own counter**.
   Several counters are items (garlic for the vampire, and so on).
4. The same mix of novelty, punishment and fun as R.E.P.O.'s monsters.
5. The **stalker is the centre of the game**, with characteristics nothing
   else has.

## Design rules

- **One verb each.** Before adding a creature, write its verb in one line.
  If another creature already does it, change one of them.
- **Readable.** Every dangerous action has a tell (sound, pose, shadow or
  marker) at least a second before it lands.
- **Counterable.** Each creature has a way to deal with it: an item, a
  behaviour (look, don't look, keep moving, stand still, stay together) or
  teamwork.
- **Funny is allowed to hurt.** Being yeeted, frogged, stitched to a friend or
  carried off costs time, position or items. Health damage is reserved for the
  real hunters.
- **Co-op first.** Many effects are fixed fastest by a teammate (flash the
  hugger, cut the thread, pull you out of the mud), so splitting up is
  dangerous and sticking together is rewarded, except against the Seamstress.

## The stalker: the reason this game exists

The stalker is the camp's old counselor in a canvas mask. Everything below is
his alone, and since 18 October he is the killer every night. (The
Groundskeeper used to be an alternative headliner sharing these traits; he is
now a woods creature with a ride-on mower; see "18 October additions" below.)

| Trait | What happens | Counter |
| --- | --- | --- |
| **The camp song** | He whistles the camp song (synthesised in game; a real recording is on the audio wish list). Its direction and volume tell you where he is; the tune quickens when he is hunting you. | Listen. |
| **Shadowing** | He picks a *favourite* survivor and follows them at the edge of their light. Catch him in your beam and he steps back into the dark, reappearing behind you later. | Keep your light moving; stay with the team. |
| **The grab** | A wounded survivor (50 health or less) isn't hit: he throws them over his shoulder and walks to **his hook**. The carried player mashes **E** to wriggle free; a teammate's flash, flare or air horn makes him drop them. | Teamwork, the air horn. |
| **The hook** | Reaching the hook (a seeded clearing in the woods, pinned on everyone's map) leaves the survivor hooked and downed there, far from the team. Teammates must go and get them. | A rescue run. |
| **He remembers** | Hiding spots you have used are remembered. Searching nearby, he checks those first and drags you out. | Don't reuse a spot. |
| **Bear traps** | Through the night he sets bear traps on the trail cells you walk most (up to four): a loud snap, 4 s stuck and 15 damage. They glint in a flashlight; **E** disarms one in 2 s. | Vary routes; watch the ground. |
| **Calling cards** | He scrawls survivors' names and "I SEE YOU" on the ground where they have been. | Purely to scare you. |
| **Rage** | Every time a target slips away (a door, a stun, a hiding spot, a freed captive) his rage grows. At three he **frenzies** for 12 s, then a 40 s rage rest: faster (capped at 90 px/s), doors burst instantly, the whistle becomes a scream. | Don't humiliate him too often. |
| **Air horn** | A new camp item: a blast stuns him for 5 s and makes him drop anyone he carries, but every creature in the woods hears it. | — |

## Creatures

Ids keep their existing art names (for example `lens_eater` is drawn as the
Peeper). Display names are what players see.

| Id | Name | Verb | Lethal? | Tell | Counter |
| --- | --- | --- | --- | --- | --- |
| `vampire` | **The Vampire** | **Hypnotises**: in its sight (and not in your beam) you're drawn toward it. When it reaches you it **latches on and drains** health (6/s) until you mash E free or a teammate flashes it. | Yes | Its eyes glow; your HUD says DRAWN. | **Garlic** (60 s: it won't come near or hypnotise you); your beam slows it. |
| `werewolf` | **The Werewolf** | **Moon-bound**: most of the night it's a lost **hiker**, harmless and friendly. When the **moon** comes out (every few minutes, shown on the HUD) it transforms and **rampages**: pounces knock you flying (35 damage) and it smashes doors, fences and knock-overs in its path. | During the moon | Howl and moon icon. | **Wolfsbane** (thrown): it turns back and flees; or hide until the clouds return. |
| `bigfoot` | **Bigfoot** | **Shy yeeter**: never chases. Startle it up close without light on it and it grabs you and **throws you** 220–300 px (10 damage; you may drop what you hold). Light it from a distance and it flees, dropping a **tuft of fur** worth +300 score. | Barely | Grunts when you get close. | Light it from far away. |
| `witch` | **The Witch** | **Curses**: her hex bolt applies a random curse: **Frog** (12 s: a tiny hopping frog that can't carry parts or use items; deep ribbit voice), **Backwards** (10 s of inverted controls), **Swap** (you swap places with a random teammate) or **Float** (8 s drifting like a balloon). | No | Cackle and a wind-up circle. | **Salt ward** reflects the curse onto her. |
| `lantern_moth` | **The Lantern Moth** | **Face-hugger moth**: flies to the brightest light and **lands on your face**; a moth fills most of your screen and drinks 3 light per second. | No | Fluttering and a looming shadow. | Swat it with **Space** (flash), or a teammate does it; **bug spray**; light off. |
| `ration_moth` | **The Puffball** | **Spore puffs**: anyone in a puff gets **helium voice** for 60 s (everyone hears you squeak) and **sneezes** loudly every few seconds for 30 s. | No | A swelling pale cloud. | Walk around it; hold your breath (stand still). |
| `briar_revenant` | **The Scarecrow** | **Only moves when nobody is looking**: frozen while any survivor's light is on it or it's in their view. Unwatched, it's very fast; its touch deals 60. | Yes | Rustling straw when it moves. | Keep watching it; teammates take turns. |
| `switchback_hound` | **Buster, the stalker's hound** | **Tracker and alarm**: follows blood and scent trails; on seeing you it **barks**, calling the stalker straight to it. Drags downed survivors toward the hook. | Indirectly | Sniffing, then barking. | **Rations as bait**: he eats and becomes your friend for 60 s, growling at nearby creatures. |
| `relay_jackal` | **Trash Jackals** (a pair, Rail Yard guardians) | **Thieves**: dart in, snatch a belt item (or rarely a carried part) and run to their **den**, pinned on the map, where they drop it. | No | Yipping and a dash. | Flash or chase them; throw rations to distract. |
| `lens_eater` | **The Peeper** | **Staring contest**: if it's in your beam or you face it closely, you're **locked**: you can't move and slowly lose health until something breaks the gaze. | Slowly | An unblinking eye in the treeline. | Don't look at it; a teammate steps between you or flashes it. |
| `shutter_wraith` | **The Paparazzo** | **Flash photography**: its camera whites out everyone in view for 3 s and **sends the photo to the stalker**, who learns where you are. | Indirectly | A shutter whine before the flash. | Turn away; break line of sight. |
| `last_car_conductor` | **The Conductor** | **"Tickets please"**: grabs you; without a ticket you're **whisked away to the Rail Yard**. With a **train ticket** he punches it and gives you a **free ride back to camp**. | No | A lantern swing and a bell. | **Train ticket** (turns him into a taxi). |
| `stoneback_ram` | **The Ram** | **Bowling**: a telegraphed charge that **launches** everyone in its path (30 damage) and smashes doors and fences. | Yes | The existing CHARGE tell. | Step aside. |
| `candle_grazer` | **The Snuffer** | **Eats light**: walks in a bubble of darkness: flashlights cut out, flares die and lamps dim around it. Harmless itself; everything else sees you better. | No | Candles gutter; the light flickers. | **Glow moss** (can't be snuffed). |
| `bramble_seamstress` | **The Seamstress** | **Sews survivors together**: a thread tethers the target to the nearest teammate (or a tree, solo) for 25 s; you can't get more than 80 px apart and you drag each other. | No | Thread-whip sound. | **Scissors** cut it. |
| `boiler_saint` | **The Lullaby Saint** | **Sings you to sleep**: within its song you slow and your screen dims; stand still for two seconds and you **fall asleep** for 6 s (and snore). | Indirectly | A hymn. | **Coffee** (90 s immunity and full stamina); keep moving. |
| `mimic` *(new)* | **The Mimic** | **Pretends to be a teammate**: wears a survivor's look and a teammate's name, waves, and **replays a teammate's recent voice** from where it stands. Up close it reveals itself and grabs (25 damage and a 2 s stun). | Yes | No flashlight cone; a wrong shadow. | Check the map: real teammates are pinned. |
| `owl` *(new)* | **The Night Owl** | **Carry-off**: circles overhead; dives at a survivor with no teammate within 150 px and **carries them 700 px away** to a random clearing (10 damage). | Barely | A hoot and a growing shadow on the ground. | Stay together; a flare makes it veer off. |
| `bog_hands` *(new)* | **The Bog Hands** | **Ankle-grabber**: waits in mud puddles on trails. Step in and you're held; after 6 s you're **dragged under** (downed). | Yes | A bubbling puddle. | Mash E or a teammate pulls you out; walk around puddles; a flare in the puddle scares it. |
| `imps` *(new)* | **The Toadstool Imps** | **Mischief**: untie your shoelaces (you trip and drop what you hold), then **carry dropped items away** and hide them. | No | Giggling. | Flash poofs them; **bug spray**. |
| `teddy` *(new)* | **Bear Hug** | **Relentless hugger**: a giant camp teddy that never stops following you once it has seen you. When it catches you, it **hugs**: you're held and squeezed (5 damage per second) until you mash E 15 times or a teammate flashes it. | Yes, slowly | Squeaky footsteps. | Teamwork; outpace it. |

The six region guardians stay in their regions: Lullaby Saint (Flooded Mill),
Seamstress (Orchard), Paparazzo (Observatory), Trash Jackals (Rail Yard), Ram
(Quarry) and Snuffer (Chapel). The vampire and witch keep their homes. The
roaming slots draw from all the other creatures, so a night has a mix of
hunters and pranksters.

## New items

| Item | Where | Use (V) |
| --- | --- | --- |
| **Garlic** | Woods loot, the Vampire's region | 60 s of vampire immunity. |
| **Wolfsbane** | Woods loot | Thrown: a transformed werewolf turns back and flees for 90 s. |
| **Bug spray** | Camp and woods | 45 s: moths and imps keep away. |
| **Scissors** | Camp | Cut a seamstress thread (yours or a teammate's beside you). |
| **Train ticket** | Woods loot | Carried: the Conductor gives you a free ride to camp. |
| **Air horn** | Maintenance (1–2 per night) | Stuns the stalker 5 s and makes him drop a captive. Loud. |
| **Coffee** | Mess hall | 90 s of lullaby immunity and full stamina. |
| **Bigfoot fur** | Dropped by a fleeing Bigfoot | Trophy: +300 score. |
| *Rations* (existing) | — | Also bait for Buster and the jackals. |
| *Salt ward* (existing) | — | Also reflects witch curses. |
| *Glow moss* (existing) | — | Also keeps your light on near the Snuffer. |

## Voice effects

- **Helium (Puffball):** everyone hears your voice chat pitched up
  (pitch-shift bus) for the duration.
- **Frog (Witch):** pitched down.
- **Mimic replay:** each client keeps only the last few seconds of received
  voice in memory (never saved or sent anywhere new) so the Mimic can replay a
  teammate's words from its own position. It works without voice too: it just
  waves and calls.

## Implementation plan

1. **Framework:**
   - a creature brain per species (`scripts/ai/brains/`), so behaviours stop
     being `if species ==` chains;
   - timed player effects (frog, helium, held, carried, asleep, …) with
     knockback, struggling (mash E) and network sync;
   - HUD overlays for those effects.
2. **The stalker:** whistle, shadowing, grab and hook, memory, bear traps,
   calling cards, rage and the air horn.
3. **Revamped creatures:** the sixteen existing ids above.
4. **New creatures:** Mimic, Owl, Bog Hands, Imps and Bear Hug (new
   SpriteCook sheet).
5. **Items:** loot tables and icons (new SpriteCook sheet), the journal and
   tips.
6. **Tests, docs, screenshots and clips.**

## 18 October additions

The Stalker is the only headline killer. Nine new creatures, each with a verb
nothing else has (brains in `scripts/ai/brains/`, art from SpriteCook sheets F and
G, tests in `tests/integration/new_creatures.gd`):

| Id | Name | Verb | Counter |
| --- | --- | --- | --- |
| `groundskeeper` | The Groundskeeper | Ride-on mower: momentum steering, headlight-cone sight, runs you over (35 + launch); on foot he rakes hiding spots. | Sidestep late, trees, cabins; pull the parked mower's spark plug (hold E 3 s: 90 s on foot). |
| `cuckoo` | The Cuckoo | Three calls while you're in sight, then you're rewound to where you stood 8 s ago. | Break line of sight; flash it. |
| `banshee` | The Banshee | Inhale ring, then a scream: deafened 25 s (muffled local audio). | Leave the ring or get behind cover. |
| `slug` | The Slug | Slime trails make you skate; touch coats you 8 s. | Walk around; salt ward shrivels it and dissolves slime. |
| `surveyor` | The Surveyor | Touch makes you LOST 40 s (map, skyline, signposts, location hidden). | A teammate beside you 3 s, or a ranger note. |
| `hitchhiker` | The Hitchhiker | Rides your back: slow, no sprint, switches your light off. | Walk into a teammate (TAG) or wait 45 s. |
| `tollkeeper` | The Tollkeeper | Blocks a trail; shoves back anyone unpaid. | E pays one supply (or 15 health) for a minute's passage. |
| `echo` | The Echo | Whistles the stalker's camp song from the wrong place. | Your light bursts it up close. |
| `fortune_teller` | The Fortune Teller | Forced tarot card: 3 boons, 4 banes. | Walk away. |
