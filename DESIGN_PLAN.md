# DUNGEON CARETAKER: V2 FULL IMPLEMENTATION PLAN
## For GLM — Build in This Order

## What We're Building

A ghost bound to a dungeon guides disposable adventurers through it. They die. You salvage their gear, repair it, upgrade it, assign it to the next batch. The weapons persist — their history IS your progress. Each stage is a management puzzle: how efficiently can you run the operation? Death is expected, not failure — total collapse is the only loss.

The roguelike layer (combat variance, hazard RNG, salvage rolls) stays genuinely unpredictable. The management layer (repair quality, shard economy, weapon investment) is legible and optimizable. An incremental-style reward curve bridges them: push harder for more reward, but the marginal cost rises faster than the reward.

## BUILD STATUS

- [x] **Priority 1 — Movement feel + Phase verb** — DONE (commit e986b47). Ghost now has tighter accel/friction, velocity-driven camera bob, ghost trail, footstep SFX, and the unified Phase verb (SPACE) working across salvage/workshop/planning/battle.
- [ ] Priority 2 — Salvage overhaul (density, QTE variety, push-your-luck)
- [ ] Priority 3 — Repair minigame overhaul (visible transform, live stats, triage, system-changing upgrades)
- [ ] Priority 4 — Battle drama (speed, sparks, boss waves)
- [ ] Priority 5 — Ghost personality + tone
- [ ] Priority 6 — Diegetic upgrade shop + incremental reward curve
- [ ] Priority 7 — Polish pass

## THE 7 PRIORITIES (IN BUILD ORDER)

---

### 1. MOVEMENT FEEL + GHOST PHASE VERB  ✅ DONE

**Why first:** Everything sits on top of the base verb. If movement doesn't feel good, nothing else matters. This is the UFO 50 / Mina lesson — obsessively tune the action/feedback loop before touching systems.

**Current problem:** Ghost has one verb (walk) with momentum acceleration, no sound, no trail, no feedback. It's a cursor. Movement is slippery — the ghost overshoots stations and corpses.

**What to build:**

**A) Fix the walk:**
- Reduce acceleration, increase friction so the ghost stops when you release keys
- Add velocity-driven camera bob (not fixed sine wave)
- Add a soft "whoosh" footfall sound tied to velocity (use existing SFX system — generate a low-pitched blip at intervals scaled to speed)
- Add a faint ghost trail: 3-4 fading afterimages at 0.3s intervals, drawn as semi-transparent ghost sprites at previous positions
- The ghost should feel **floaty but precise** — it's a ghost, not a tank

**B) Add the Phase verb (the "hollowing"):**
- Press SPACE (or right-click) to phase: ghost becomes semi-transparent, moves 2x faster, passes through hazards for 1.5 seconds
- 4-second cooldown, shown as a shrinking ring around the ghost
- **Does NOT bypass:** pits (you still fall), cursed bells (they still ring)
- **DOES bypass:** fire, spikes, skeleton attacks in battle
- This is the ghost's identity verb — it shows up in EVERY phase:
  - **Salvage:** phase through fire/spikes to grab corpses faster
  - **Battle:** phase to reposition near enemies for Haunt ability (replaces the current "1" key haunt — phasing NEAR enemies slows them)
  - **Workshop/Planning:** phase to move between stations faster (quality of life)
- Resource cost: each phase costs 1 soul shard (ties to economy)
- The verb and the character concept are the same fact: a ghost that goes incorporeal

**C) Test in an empty room first:**
- Per UFO 50's process: build the movement + phase in a bare room with nothing else. Don't touch hazards/corridors until moving is fun on its own.

**Files to touch:** `salvage.gd`, `workshop.gd`, `planning.gd`, `battle.gd`, `juice.gd` (trail), `sfx.gd` (phase sound), new `phase_cooldown` UI

---

### 2. SALVAGE OVERHAUL — DENSITY, VARIETY, CHOICE

**Why second:** Salvage is the most empty phase. Long corridor, few interactions, same QTE every time. It needs to be dense, varied, and offer real choices.

**Current problem:** 60-tile corridor with 2-3 corpses and 6+ hazards spaced 6 tiles apart. QTE is a single timing bar with different verb labels. No variety, no comedy, no surprise. Walking for 10+ seconds between interactions.

**What to build:**

**A) Shorten and densify:**
- Cut corridor from 60 tiles to 30 tiles
- Pack corpses and hazards closer together — 2-3 tiles between interactions, not 6-10
- Every screen should have something to interact with

**B) QTE variety (the Dumb Ways to Die lesson):**
- Each hazard type gets a DIFFERENT minigame, not just a different verb label:
  - **Pit:** Timing tap (hit the green zone on a sweeping bar) — 2.5s window
  - **Fire:** Hold to fill (keep a meter in the green zone, like oil_grindstone) — 3s
  - **Spikes:** Swipe direction (drag in the shown arrow direction) — 2s
  - **Falling debris:** Do nothing (don't click the glowing bell — reverse QTE) — 3s
- Failure = -1 ghost HP + weapon durability damage
- Success = hazard disarmed, can walk past
- Phase verb bypasses fire and spikes entirely (but costs a shard)

**C) Push-your-luck (the incremental reward curve):**
- The exit is always visible and reachable — you can leave anytime
- But there are OPTIONAL deeper corridors with better gear (cursed/legendary weapons from named fallen heroes)
- Going deeper = more hazards = more risk = more reward
- This is the "exceed expectations" curve: the floor (reach exit) is guaranteed, the ceiling (collect everything) costs real risk

**D) Corpse identity:**
- Corpses from YOUR dead party members show their name, class, and death cause floating above them
- Bonus corpses (random NPCs) show just a name — less emotional weight, useful for filling gear gaps
- The visual difference should be immediate: your fallen have a blue soul-glow, random corpses don't

**Files to touch:** `salvage.gd` (major rewrite of `_build_level`, `_draw_qte_bar` → multiple QTE types, push-your-luck branching), new QTE minigame scripts

---

### 3. REPAIR MINIGAME OVERHAUL — TACTILE, TRANSFORMATIVE, TRIAGE

**Why third:** The repair phase is where the player invests emotionally in weapons. Currently it's the most tedious part — same static minigame, no visible transformation, no decision-making.

**Current problem:** Only reforge_furnace shows the weapon transforming. Polish/oil_grind/exorcise draw the weapon statically. All minigames are the same 7-12 second task repeated forever with no exit. No per-weapon upgrade decisions.

**What to build:**

**A) Visible weapon transformation:**
- **Polish:** Blood cells wipe away as you drag, revealing the clean weapon sprite underneath. The weapon art should visibly change from BLOODIED-tinted to clean as coverage increases. At 50% coverage, half the blood is gone. At 100%, the weapon is pristine.
- **Oil_grindstone:** Weapon rotates on the wheel (use `draw_set_transform` + rotation). Sparks fly when oil hits the sweet spot. Rust flakes visibly fall off as quality increases.
- **Exorcise:** Ghostly wisps around the weapon fade as you trace the sigil. At 50% traced, half the wisps are gone. At 100%, the weapon is clear.
- **Reforge:** Already works — keep it.

**B) Live authoring feedback:**
- During each minigame, show the fingerprint stat being improved in real-time: "Sharpness: 45% → 62%" as a small counter in the corner
- This makes the investment visible DURING the action, not just after

**C) Triage decision-making (the Satisfactory lesson done right):**
- The bell timer creates time scarcity — you can't repair everything perfectly
- Add a "quick repair" option at each station: press Q instead of E to do a fast auto-repair at 40% quality (no minigame). This is the "automation" — it doesn't delete the task, it creates a CHOICE: "Do I spend 10 seconds getting this sword to 80%, or quick-repair it at 40% and use those 10 seconds on the staff instead?"
- The triage decision is: which weapons deserve manual attention (for max quality) vs. which can be quick-repaired (baseline functional)?
- This decision gets harder every wave as the arsenal grows and the bell timer shrinks
- Meta-upgrade "Twin Wipe" (unlock at upgrade shop): quick-repair quality rises from 40% to 55%. This is the "system-changing upgrade" — it doesn't remove the decision, it shifts the math.

**D) System-changing repair upgrades (the friction-has-a-destination lesson):**
- **Cannibalize (Reforge Furnace):** Destroy one weapon to fully repair another. Costs the destroyed weapon permanently. This is the "weapons are capital" decision — do you sacrifice a legendary with 40 kills to save a pristine blade for the boss wave?
- **Cold Oil (Oil_grindstone):** Oil stays in the sweet spot 50% longer. Changes the minigame feel, not the rules.
- **Read the Sigil (Exorcise Altar):** Show the next 2 waypoints in advance. Reduces skill floor without removing the trace.
- Each is bought at the upgrade shop (replaces the current flat-stat upgrades for those slots) and permanently changes how that station plays.

**Files to touch:** `polish_bench.gd`, `oil_grindstone.gd`, `exorcise_altar.gd` (add visible transformation + live stats), `workshop.gd` (add quick-repair option, add Cannibalize branch), `game_state.gd` (add new meta-upgrade defs)

---

### 4. BATTLE DRAMA — SPEED, SPARKS, STAKES

**Why fourth:** Battle is a 30-second spectator phase with no drama. It needs to be fast, legible, and tense.

**Current problem:** Party walks at 25px/sec toward enemies 600px away. 24 seconds of walking before combat. Weapons degrade silently. No way to tell why a weapon failed. Ghost ability is a separate button that doesn't connect to the phase verb.

**What to build:**

**A) Speed up everything:**
- Party movement: 25 → 60 px/sec
- Enemy movement: 15 → 40 px/sec
- Attack cooldown: 1.5s → 0.8s (party), 2.5s → 1.5s (enemies)
- Battle should resolve in 15-20 seconds, not 30-45

**B) Visual combat feedback:**
- Weapon sparks on hit: small yellow particle burst at the impact point, directional (not uniform ring)
- Weapon durability bar under each unit visibly cracks at 25% (red flash + "CRACK" text)
- Damage numbers float and fade faster (0.5s instead of 0.7s)
- Screen shake scales with damage dealt (bigger hit = bigger shake)

**C) Phase verb integration:**
- Replace the "1" key Haunt ability with the Phase verb
- Phasing near enemies slows them (same effect, unified verb)
- Phasing costs 1 shard per use (economy tie-in)
- The ghost can phase to reposition near a struggling ally or to slow a cluster of enemies

**D) Boss waves:**
- Wave 3 of each stage spawns 1 boss + 2 regular enemies (instead of 5 regulars)
- Boss: 3x sprite scale, 3x HP, unique name ("Gorok the Slime King"), unique attack pattern (telegraphed AoE every 5 seconds — red square on the ground for 1s, then damage)
- Boss drops a guaranteed pristine weapon on death (named, with boss kill in history)
- The map table in planning already says "STAGE BOSS" — make it true

**Files to touch:** `battle.gd` (speed, sparks, boss spawn, phase integration), `sprites.gd` (boss sprite scaling), `game_state.gd` (boss definitions)

---

### 5. GHOST PERSONALITY + TONE

**Why fifth:** The ghost is the player's avatar but has zero voice. The tone is wrong — death reads as failure, not expected ecology.

**What to build:**

**A) Ghost reaction lines (10-15 total):**
- On adventurer death: "Not again..." / "Rest now. Your blade remains."
- On weapon shatter: "Hold together, old friend." / "No — not this one."
- On successful repair: "Better than new. Almost." / "They'll not recognize you."
- On recruit: "You'll do." / "Another soul for the grind."
- On stage clear: "One floor closer to freedom." / "The dungeon remembers us."
- On run end (win): "Free at last. The weapons can rest now."
- On run end (lose): "The dungeon keeps its caretaker..."
- Display as a brief text bubble above the ghost, 2 seconds, fade out
- Don't repeat the same line twice in a row

**B) Aftermath tone rewrite:**
- Current: "S1 W1 - THE FALLEN" / "Mira fell here" / "The rest retreated, carrying what they could."
- New: "Mira fell — as expected. The operation continues." / "Mira's gear awaits salvage."
- The tone should be **professional, not mournful**. Death is the job. The ghost is a caretaker, not a grieving friend.
- On full wipe: "The operation has failed. The dungeon wins this round." (not "THE DUNGEON WINS...")

**C) Run log as chronicle:**
- The win/lose screen already shows the full run_log. Make the entries more narrative:
  - "Stage 1, Wave 1 — Cael fell to the slimes. His sword survives."
  - "Stage 1, Wave 2 — Mira retreated, wounded but alive. The Whispering Staff shattered."
  - "Stage 1, Wave 3 — Victory. The slime king is dead. Gorok's Fang claimed."

**Files to touch:** new `ghost_dialogue.gd` (dialogue lines + trigger system), `battle.gd` (trigger on death/shatter), `workshop.gd` (trigger on repair), `planning.gd` (trigger on recruit), `aftermath.gd` (tone rewrite), `win_lose.gd` (tone rewrite), `game_state.gd` (narrative run_log entries)

---

### 6. DIEGETIC UPGRADE SHOP + INCREMENTAL REWARD CURVE

**Why sixth:** The upgrade shop is the one menu screen. It breaks the diegetic language. And the upgrades are all flat stat bumps — no system-changing choices.

**What to build:**

**A) Diegetic upgrade wall:**
- Replace the scrollable list with a physical wall in the workshop (or a new small room between workshop and planning)
- Each upgrade is a trinket/charm mounted on the wall with a plaque
- Walk to it, press E to buy. Current level shows as carved notches on the plaque
- Fleet Shade → a ghost charm / lantern-wick trinket
- Master Forge → a smith's sigil branded into wood
- Sturdy Grip → a wrapped leather grip mounted like a trophy
- Adventurer Training → a small worn training dummy figure
- Salvage Expert → a cracked lantern
- Ghost Resilience → a spectral heart charm
- System-changing upgrades (Cannibalize, Cold Oil, etc.) → unique mounted objects

**B) Incremental reward curve (the puzzle-as-management reframe):**
- **Efficiency Score:** After each wave, calculate an efficiency rating based on: survivors, weapon durability remaining, time left on bell timer, corpses collected, shards earned
- Display as a star rating (1-3 stars) on the results screen
- 3 stars = bonus shards + faster legendary weapon progress
- This is the "exceed expectations" curve — the floor (1 star, clear the wave) is guaranteed. The ceiling (3 stars, perfect efficiency) costs real skill and risk.
- The player decides how hard to push: spend extra time in salvage for more corpses (risk ghost HP), spend extra time in workshop for perfect repairs (risk bell timer), assign gear perfectly (risk sending someone undergeared)

**C) Meta-upgrade restructure:**
- Keep the 5 existing stat upgrades (they're fine as baseline progression)
- ADD the 4 system-changing repair upgrades from Priority 3 (Cannibalize, Cold Oil, Read the Sigil, Twin Wipe)
- These are the "automation that creates new decisions" — they change how you play, not just how strong you are

**Files to touch:** new `upgrade_wall.gd` (replaces `upgrade_shop.gd`), `results.gd` (add efficiency score), `game_state.gd` (efficiency calculation, new upgrade defs)

---

### 7. POLISH PASS — EVERY SCREEN, EVERY TRANSITION

**Why last:** Polish only matters once the systems are right. But it matters a LOT.

**What to build:**

**A) Screen transitions:**
- The fade system exists but may still be buggy. Verify it works: 0.12s fade-to-black between every phase
- Add a brief whoosh sound on transition

**B) Sprite animation:**
- 2-frame walk cycles for ghost, knight, mage, enemies (shift leg pixels on odd frames)
- Use `Sprites.get_sprite_frame(name, frame)` pattern (already sketched in research)

**C) Ambient lighting:**
- Torch glow already exists in salvage/battle. Add to workshop (furnace glow, altar glow) and planning (bell glow)
- Make the ghost emit a faint blue glow that illuminates nearby tiles

**D) Sound bed:**
- Add procedural ambient music: a slow, low-pitched drone that changes pitch per phase (lower for battle, higher for workshop)
- Use the Music autoload pattern from the research (two AudioStreamPlayers, crossfade)
- Generate the drone as a long AudioStreamWAV with loop=true

**E) UI consistency:**
- Verify every screen at 4x upscale with vision model
- Every text element at font size 8 or 16
- No overlaps, no cut-offs, no off-screen elements
- Bottom hints on every walkable screen: "WASD:move E:interact SPACE:phase [[]/]:cycle"

**Files to touch:** `main.gd` (transitions), `sprites.gd` (walk frames), `sfx.gd` (ambient bed), all phase files (lighting, UI), `game_font.gd` (verify sizes)

---

## BUILD RULES

1. **Test movement in an empty room before touching anything else.** If moving the ghost isn't fun, stop and fix it before proceeding.
2. **Commit to the debug-tools branch for playtest harness.** Keep main clean.
3. **Playtest after every priority.** Capture screenshots at 4x upscale, vision-verify, check for overlaps/crashes.
4. **Don't add new systems until existing ones feel good.** The design theory is sound — the execution needs to catch up.
5. **The phase verb is the ghost's identity.** It should work in every phase, cost a shard, and feel like the same action everywhere.
6. **Death is expected, not failure.** Tone should be professional, not mournful. Only total party collapse is a failure.
7. **Weapons are the save file.** Their history, kills, and wear IS the player's progress. Every system should serve making weapons feel like invested capital.
8. **Friction needs a destination.** Every tedious action should have an upgrade path that changes HOW you deal with it, not just makes it faster. The destination is new decision-making, not automation that deletes the task.
