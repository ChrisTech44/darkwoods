# Friends playtest follow-up — 20 October 2026

The reported problems led to implemented John/reconnect/marker fixes. Max now
uses the names-only wheel described in the [maintained character design](four_survivor_overhaul.md).
The [new monster plan](new_monster_plan.md) records seven implemented additions.
The Max economy/UI alternatives and four monster pitches below are historical,
superseded proposals; source descriptions there describe the old baseline.

## Max: confirmed problem and interface choices

[SamplePresentation.detail](../scripts/world/sample_presentation.gd) always returns
three lines for an idle Max, and [HUD.update_ability](../scripts/ui/hud.gd) shows
that detail panel whenever the notebook is closed. The panel occupies a substantial
part of a 384×216 screen. [Actual teammate capture](evidence/playtest_recovery/max_help_baseline.png)
shows it alongside Alex's now-shared marker; this is a staged multiplayer fixture,
frozen enemies, normal lighting, normal route selection and no microphones.

| Choice | Idle display | While holding X | Tradeoff |
| --- | --- | --- | --- |
| **A — compact wallet (recommended)** | Wallet icon, `$6 · X $4`; complete rules in Tab | One short row: `BUY $4` then `GAMBLE $4 · 45% BUST`; a small stake meter shows $4/$8/$12 | Retains current controls, removes the permanent paragraph, keeps the risk visible before committing |
| B — contextual card | Wallet icon and cash only | Small two-line card appears only while X is held; disappears on release/cancel | More explanation at the moment of use, but still covers some world space |
| C — purchase selection | Wallet icon and cash only | X opens a bounded supply selector; gambling is a separate explicit choice | Greater control, but requires a control/gameplay redesign and a mouse/keyboard/online audit |

Choose A first. Keep H GIVE on the existing control guide; do not repeat full
instructions beside the wallet. Never reduce font size to fit more text. Capture
idle, buy, gamble, unaffordable and notebook states at the original viewport before
calling the replacement accepted. No proposed UI change is implemented here.

## Max: why money feels scarce and alternatives

Current source: starts with $6; a safe supply costs $4; optional searches pay $4;
first stolen-loot recovery pays $3. Ordinary movement, finding required parts and
team objective progress do not pay. The search award goes to the actor who
performs it: if another camper consumes the stash first, Max misses that chance.
Hits spill one third of cash. A gamble has a 45% bust rate. That makes replenishment
sporadic and dependent on detours/encounters, even when the team is making progress.
A safe purchase consumes two thirds of the starting wallet.

Suggested economy prototypes, independently selectable from the interface:

| Alternative | First tuning proposal | Benefit / limit |
| --- | --- | --- |
| **Team finder's fee (recommended)** | Each unique optional stash pays each Max $4 once, regardless of who opens it; keep the existing shared supply loot finite | Removes the race against friends. Host receipts must include stable survivor identity and stash ID; reconnecting cannot re-award it |
| Small, visible loose change | Put finite $1–$2 coin pickups at a bounded subset of normal optional search locations; show only discovered coins | More frequent feedback without required detours to rare thieves. Each coin has one authoritative claim; do not reveal unexplored caches |
| New-step dividends | Pay $2 for a genuinely new installed/prepared escape step, with an $8 per-Max round cap | Pays useful teamwork. May make Max feel too similar to John's progress passive; no credit for repeated removal/installation or mere carrying |
| Low-wallet allowance | Earn $1 per 90s of active round time only below $4, capped at $4 between spends | Prevents permanent lockout; less exploration identity and can encourage waiting. No lobby/menu/offline catch-up income |
| Sell an ordinary supply | Sell for $1 versus the $4 purchase cost; forbid objectives/tools/cash payouts | Converts unwanted gear, but can tempt Max to sell team resources; adds UI and needs explicit team agreement |

Recommended first experiment: compact-wallet A plus team finder's fees; measure
income, purchases, time below $4 and money recovered after hits before changing
prices or odds. Start a second experiment with finite loose change only if Max
still goes long stretches without an action. Do not ship all income sources at once.
Keep the same initial cash/prices for that first comparison to isolate the change.
The current gamble's average payout is 1.1 supplies per $4 versus 1 for a purchase;
its high variance, rather than lower mean value, makes scarce cash feel punishing.

## Disconnect investigation and implemented recovery

The supplied log has two `server_peer_left` events, followed by a status record
with two fewer participants. The authority did detect those departures. It does
not record transport reason, client timeout or network conditions, so it cannot
establish why the original links dropped or when each client stopped receiving.

Source-backed faults and corrections:

- Client liveness previously refreshed only after a complete world snapshot.
  Ten seconds without one ended the session, even with healthy motion packets.
  Valid 30Hz motion now refreshes liveness too. A real-process regression withholds
  complete world state for eleven seconds while retaining motion.
- The assembler previously discarded an incomplete sequence as soon as the next
  sequence began. It now bounds four interleaved sequences, applies only complete
  newer states, and bounds each piece/count/decompressed payload as before.
- Running rounds rejected every registration. A random 256-bit reconnect token now
  reserves the same authoritative survivor for **five minutes** after an unexpected
  departure. The token stays in the running client process, is tied to its endpoint,
  and is never logged. Name/role alone cannot reclaim a slot. New players still
  cannot join a running round. Update server and clients together to `lnac-net-30`.
- All carried supplies, tools and objectives drop immediately
  through the existing authoritative drop path. The reserved body has empty gear;
  reconnect and expiry cannot duplicate what teammates recovered. The wheel
  has replaced Max's wallet; no current cash recovery is needed.
- Reliable departure messages remove the body and release tethers even without
  a complete world snapshot. Snapshots captured before that departure are rejected,
  so delayed packets cannot resurrect the character or its broken tether.
- The disconnected body leaves the scene tree and simulation. Grabs, both tether
  ends, copied holds/casts, creature target/rider references and incomplete vaults
  are cleared. A cancelled vault returns to its safe starting side before drops.
  Health, life state, remaining resources, cooldowns, samples/forms and unexpired
  Alex marker state remain on the reserved body. Timers freeze while reserved.
- A server watchdog detects fifteen seconds without accepted input packets. Idle
  clients still transmit zero-direction input continuously; standing still or
  opening a menu does not count as disconnection. Scene loading has its separate
  90s allowance, and readiness resets the input watchdog before play starts.
- Clients retry automatically every two seconds. A valid ticket can reclaim a
  connection before the server's native timeout has fired; the old transport is
  retired first. Other clients recreate the returning actor from authority data.
  Existing player map pins migrate to the new transport ID; replicated membership
  updates identity consumers, including opt-in voice.
- New diagnostics distinguish client connection loss, server input silence,
  resumed peers and expired reservations. Server status includes reservation and
  resuming counts. No token or microphone content is logged.

In the supplied four-player logs, roughly 7KB snapshots at 20Hz imply roughly
560KB/s of authority world-payload upload across four clients, before overhead,
movement or voice. That is a calculation from source cadence and the supplied
sizes, not a measured Internet bandwidth diagnosis. A congested uplink, NAT/VPN,
engine stall or lost link remains possible; do not claim these fixes cure all loss.

If every dedicated client disconnects, the authority pauses the empty round until
someone returns or the final reservation expires. With teammates still present,
the night continues. A finished/reset round ends its reservations. Deliberate Leave
relinquishes the ticket; restarting the app or authority loses this in-memory
recovery state. There is no host migration, crash persistence or encrypted identity
service. Automatic recovery can only return to a still-running matching authority.

## John and Alex

John's accepted hit damage is multiplied by 0.5 during the six-second Push Through
window before entering his deferred ledger. Continuous numeric drain during the
window follows the same reduction/defer rule. Normal grace, wards and once-only
settlement remain. Outside the window, damage is unchanged. Forced downs are life
state transitions; the ability still does not grant grab/execution immunity.

Alex's marker kit was already replicated, but world drawing explicitly required
`actor == level.player`. Markers now draw for teammates too and identify the owner.
This does not discover caches or enemies. The marker is a shared ability beacon;
world sight occlusion and the notebook's exploration rules remain in place.

[Execution evidence and limits](evidence/playtest_recovery/README.md).

## Mechanically distinct monster proposals

The existing roster already includes gaze locks, light parasites, tethers,
teleporting carriers, rewinds, resource theft, fake teammates and lost-map effects.
These concepts aim at different player decisions. They need prototypes, readable
muted equivalents and a defined Christian sample before entering the full roster.

| Concept | Mechanism and encounter | Counter / solo and team play | Main prototype risk |
| --- | --- | --- | --- |
| **The Unfinished Guest** | A half-assembled dinner guest watches one survivor's interactions. During a clearly marked encounter, abandoning a held action leaves a visible unfinished place setting. Three settings assemble the Guest into one telegraphed attack | Finish one safe eligible action to dismiss its settings, or leave its bounded territory to let them decay. Teammates can finish a marked shared task; solo players get a short, optional nearby action. No punishment for grabs, downing, disconnection or server cancellation | Must not pressure people into unavoidable damage, reset completed objectives or create infinite interactions for rewards |
| **The Metronome** | A tall figure conducts short measures. Crossing its ring during a red beat triggers a visible ground strike on the next beat; crossing during a rest is safe. It never chases you | Watch the swinging pendulum and ground segments; step through the gaps or take the longer path. A teammate may briefly hold a damping lever; solo timing always works. Sound teaches rhythm but is optional | Network timing needs server-scheduled beats, generous windows and latency tolerance; never judge client audio output or microphones |
| **The Chalk Eater** | It eats paths rather than people: your recent visible footsteps become chalk vertices. If you cross your own chalk line, the resulting closed polygon starts filling inward, with a clear countdown before the interior bursts | Avoid self-intersections; open the traced boundary at a visibly marked eraser stone or leave before it fills. One team's drawing cannot silently count as another's. Each actor has a short bounded trace; no objective site can become permanently enclosed | Collision, trace readability and interactions with generated roads need testing. Distinct from Seamstress: no link between bodies or pulling/tether status |
| **The Fold** | A creature physically folds a short trail segment into a continuous loop: passing the same split tree brings you back along the same stretch while the rest of the world keeps moving. Both seams are visibly creased | Exit through the side of the fold, or hold its two visible corners apart; one player can prop the first corner with a supplied temporary peg. Teammates see the same altered passage and can guide each other | Highest implementation cost: authoritative spatial continuity, safe exits, camera/collision and carried objectives. It cannot falsify map knowledge or loop the only escape path indefinitely |

Prototype the Unfinished Guest first for a low-content encounter focused on
commitment under pressure. The Metronome is the next strong candidate once online
timing is measured. The Fold is an ambitious later experiment, not a small AI patch.
