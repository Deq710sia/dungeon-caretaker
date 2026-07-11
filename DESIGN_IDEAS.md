# Game Ideas — Player-Proposed Concepts Not Yet Implemented

This file tracks ideas the player specifically proposed during development that were never coded, were cut for scope, or were put on the backburner for polish. These are the player's ideas — not AI-generated suggestions.

---

## 1. Physical Delivery Gauntlet (from original V1/V2 design)

**Status:** Cut — replaced by diegetic planning room assignment.

The player originally wanted the "equipment running" to be done by the player physically, not off-screen. After repairing weapons, you'd carry them to adventurers through a hazard-filled gauntlet — a *Dumb Ways to Die*-style QTE cutscene sequence on the way back. Slip on slime, catch a falling sword, dodge a swinging blade, don't touch the cursed bell. 3-5 microgames per delivery, failure = gear takes damage (not run-ending).

The delivery gauntlet was deleted when the planning room became diegetic (walk to adventurer, press E). The QTE cutscene concept survives in salvage hazards, but the "delivery" framing is gone. Could return as a set-piece between stages or as a mini-mode when assigning legendary gear.

---

## 2. Salvage from Previous Party's Actual Gear (original core fantasy)

**Status:** Implemented in V2 — but was the #1 missing feature for 7 versions.

The player's original vision: "you're rarely making new gear, you're reusing and revitalizing the gear from the dead party from before." This was NOT implemented until V2 — salvage generated random weapons from random NPC corpses. The fix (battle.gd stores fallen_gear, salvage.gd reads it) was the single highest-leverage change in the project.

The player also wanted multiple sources for fresh gear when the salvage pit runs dry:
- **Bare-Knuckle Run:** Send party in with nothing, they die fast, you keep whatever drops. (Partially implemented — party can go unequipped.)
- **Hire Mercenary Martyrs:** Pay shards for a disposable party whose job is to die and leave gear. (Implemented as recruit shrine.)
- **Wandering Haunt-Merchant:** A spectral peddler with rotating stock. (NOT built.)
- **Dungeon Scavenging Runs:** Send ghost solo into a shallow level to grab loose gear. (NOT built.)
- **Grateful Survivor Gifts:** Survivors return bearing pristine gear as thanks. (NOT built.)
- **Cursed Lottery:** Gamble 100 shards for a chance at Overcharged or Shattered. (NOT built.)

---

## 3. Ghost Phase / Incorporeal Verb (from Mina the Hollower discussion)

**Status:** Implemented (v0.17+) but NOT FUN YET — Priority 1 in DESIGN_PLAN.md, PARTIAL.

The player identified Mina the Hollower's "hollow tunnel" as the reference for how to make top-down movement feel good. The lesson: give the ghost ONE signature verb that touches everything — a phase/incorporeal ability that lets the ghost briefly pass through hazards, move faster, and slow enemies in battle. The verb and the character concept are the same fact: a ghost that goes incorporeal.

Also informed by UFO 50's design philosophy: "give the old genre skeleton exactly one new verb, and let it touch everything."

**Current state:** The phase verb (SPACE) works, plus a tap pulse (SHIFT) for momentum burst. But the 4-state momentum system (FLOAT/PHASE/DIVE/COAST) has design tension: it rewards staying fast in a game that rewards stopping precisely. Phase auto-fires DIVE on natural expiry, costing ~2.5s of reduced control after using your hazard tool. Needs playtest-driven tuning. See DESIGN_PLAN.md Priority 1 for details.

---

## 4. Stage-as-Puzzle: Efficiency Management (from Desktop Dungeons / incremental discussion)

**Status:** Not implemented — Priority 6 in DESIGN_PLAN.md.

The player wanted each stage to be "a bit of a puzzle in how you successfully manage the dungeon to make it efficient enough to pass." Not puzzle-vs-management, but puzzle-AS-management. There's a guaranteed floor (clear the wave) and an open-ended reward curve above it for exceeding expectations (more corpses, better repairs, tighter triage). The marginal cost rises faster than the reward, so pushing further is always tempting but never a no-brainer.

The player explicitly clarified: "I'm not saying the direction of the game is as an incremental, but that incremental elements are showing that can be a direction to give rewards while keeping it roguelike+management which seem to be at odds."

---

## 5. System-Changing Repair Upgrades (from Satisfactory / camwing discussion)

**Status:** Not implemented — Priority 3 in DESIGN_PLAN.md.

The player wanted upgrades that "slightly change the gameplay and repair systems" during the repair phase. Inspired by Satisfactory's automation-unlock pattern: friction (manual repair) has a destination (upgrades that change HOW you repair, not just make it faster).

The player explicitly pushed back on simple auto-repair: "if you use automation to solve tedium it just becomes its own tedium. The fundamental problem with incremental games is that they allow automation but not enough management mechanics to make managing the automation its own fun."

Concrete concepts discussed:
- **Cannibalize (Reforge):** Destroy one weapon to fully repair another.
- **Cold Oil (Grindstone):** Oil stays in sweet spot 50% longer.
- **Read the Sigil (Altar):** Show next 2 waypoints in advance.
- **Twin Wipe (Polish):** Quick-repair quality rises from 40% to 55%.
- **Quick Repair:** Fast auto-repair at 40% quality (no minigame) — creates a triage decision, doesn't delete the task.

---

## 6. Weapon Visibility in Minigames + Visible Transformation

**Status:** Partially implemented — only reforge_furnace transforms the weapon.

The player wanted: "you make the weapons visible in the minigames and interesting enough for upgrades in gameplay and visuals that this is what the player becomes most invested in." Weapons should visibly change during repair — blood wipes off, rust flakes away, ghostly aura fades. The player should SEE their work happening, not just get a quality score at the end.

Also wanted: live authoring feedback during minigames (show "Sharpness: 62%" updating in real-time, not just after).

---

## 7. Durability Tension Across Waves

**Status:** Partially implemented — durability exists but tension isn't felt.

The player wanted: "ensuring you build and repair them so their durability lasts enough between rounds to clear a stage. It should take multiple rounds of adventurers dying before you get your weapons good enough."

The game should make the player FEEL the tension of "will this weapon last 3 more waves?" — visible cracking, pre-break warnings at 25% durability, the decision to push a weapon or swap it mid-battle.

---

## 8. Boss Waves with Named Bosses

**Status:** Teased in UI, not built — Priority 4 in DESIGN_PLAN.md.

The player's original design doc included boss waves. The planning map labels wave 3 "STAGE BOSS" but battle.gd spawns identical enemies every wave. The player wanted named bosses with unique attack patterns and guaranteed weapon drops.

---

## 9. Diegetic Upgrade Shop (from "everything should be tactile" directive)

**Status:** Not implemented — Priority 6 in DESIGN_PLAN.md.

The player said: "everything should be animated, tactile, and stylistic." The upgrade shop is the one menu screen — a scrollable list with buy buttons. The player wanted it to be diegetic: walk to trinkets mounted on a wall, press E to buy. Current level shows as physical wear/notches on the plaque.

---

## 10. Ghost Personality / Voice

**Status:** Not implemented — Priority 5 in DESIGN_PLAN.md.

The player wanted: "I need to see more personality and creative visual design." The ghost has zero dialogue, zero reactions. The player wanted 1-line reactions to key events: death, weapon shatter, repair, recruit, run end.

---

## 11. Aftermath Scene Showing Previous Crew Dying

**Status:** Partially implemented — aftermath shows names, not the death scene.

The player wanted: "it should be like something visually showing the previous adventurer crew dying in the halls." The aftermath scene shows fallen names and "fell here" text, but doesn't show the death happening. The gate scene shows graves. Neither shows the actual death moment.

---

## 12. Camera Follows Party Through Dungeon (original battle vision)

**Status:** Partially implemented — camera follows, but battle is slow and undramatic.

The player wanted: "the camera follows the adventurer team as they go through and fun animations play while they get to the end and either die or beat the dungeon." The camera does follow, but movement is slow (25px/sec), there are no "fun animations," and the battle takes 30+ seconds of watching dots walk.

---

## 13. New Weapon Types Beyond Sword/Staff/Helm/Robe

**Status:** Not implemented.

The player mentioned wanting "new weapons" in the V2 directive. Currently only 4 gear types exist (sword, staff, helm, robe). The original design doc mentioned bows, shields, accessories. More weapon types would expand the triage and assignment decisions.

---

## 14. Cursed Weapon Effects Beyond Stat Penalties

**Status:** Not implemented — cursed is just a flat multiplier.

The player's original design doc described cursed weapons with "negative effect on wearer" and haunted weapons with "random stat jitter." Currently both are just percentage reductions. The player wanted them to FEEL different — cursed weapons could cause missed attacks, haunted weapons could cause erratic movement, etc.

---

## 15. Narrative Emergence from Weapon History

**Status:** Infrastructure exists, surfacing doesn't.

The player wanted the game to generate stories through systems, not scripted narrative. Weapon history (kill logs, death causes, repair records) exists and is readable in the dossier, but it's hidden behind a click. The player wanted these stories surfaced more prominently — mid-battle callouts, gate-screen memorials of legendary weapons, run-log chronicles that read like obituaries.

---

## 16. Multiple Waves Per Stage with Gear Persistence

**Status:** Implemented.

The player wanted "multiple waves of adventurers to beat a stage" with gear persisting between waves. This is now the core loop: 3 waves per stage, weapons carry forward, dead party members' gear goes to salvage.

---

## 17. The Ghost's Freedom (original narrative goal)

**Status:** Not implemented — mentioned in flavor text only.

The player's original premise: "you're a ghost haunting a dungeon, you want to be freed or something so you guide adventurers through it." The freedom motivation exists in the design doc but not in the game. No dialogue, no progression toward freedom, no ending that references it. The win screen says "VICTORY!" not "Free at last."

---

## 19. Salvage Crossroads Needs to Be a Real Choice (v0.25 player feedback)

**Status:** Implemented but BROKEN — Priority 2 in DESIGN_PLAN.md, PARTIAL / NOT FUN YET.

The push-your-luck branching in salvage is technically implemented (main corridor + optional deeper section, `committed_deeper` flag) but the "crossroads" doesn't feel like a choice. Current state: it's just a body + text that says "deeper," then the exit disappears and you get an easy pickup. No visual bend, no risk/reward tension — it's a no-brainer.

**What it should be:**
- A visual fork in the corridor (not just text) — the player SEES the two paths diverging
- The deeper path should have MORE hazards, tighter corridors, and require real commitment (no turning back)
- The reward should be meaningfully better (cursed/legendary weapons, not just another easy corpse)
- The exit should remain visible but require backtracking THROUGH the hazards to reach — not just disappear
- Difficulty is inconsistent: sometimes the salvage feels good, sometimes too easy. Needs tuning so the deeper path consistently feels risky.

**Design principle:** The "exceed expectations" curve only works if the floor (reach exit) is guaranteed and the ceiling (deeper path) costs real risk. Right now the deeper path is free reward.

---

## 20. Music Theme Still Needs Work (v0.25 player feedback)

**Status:** Implemented but user says "sounds bad" — Priority 7 in DESIGN_PLAN.md, PARTIAL.

The procedural main theme has been through 9+ iterations (v0.14-v0.22). Current state: speder2-style chord palette, 8 layers, stereo, Schroeder reverb, melody. But user feedback is still "sounds kinda bad." The melody was added in v0.22 but the overall mix/arrangement needs more iteration. User asked for a mute button (added v0.23, M key) while the theme is being fixed.

**Known issues to address:**
- The mix may still be too dense (8 layers all playing)
- The melody needs to be more singable / prominent
- The chord voicings were fixed in v0.21 but may still clash in places
- Needs A/B testing against actual speder2 reference tracks

---

## 21. Code Quality Issues (v0.25 Claude review)

**Status:** Partially addressed — see VERSION_LOG v0.23-v0.25.

Claude (Sonnet 5) reviewed the codebase and found:
- **Fixed:** Salvage HUD lying about controls, gate.gd stale constants, wall collision velocity bug, pulse_charge dead code (v0.23), music disk cache (v0.24), documentation overhaul (v0.25)
- **Not fixed:** Repair folder duplication (4 files share ~120 lines of scaffolding, could be RepairMinigame base class), get_speed() circularity (investigated, self-stabilizing), stale "Sidestep" comments, ghost_movement state-update functions share 80% structure (could parameterize)

A full refactoring review (v0.25) identified ~400 lines of potential savings across the codebase. Top opportunities: RepairMinigame base class (~120 lines), MELODY motif extraction (~150 lines), sine-chord timbre helper (~50 lines). See AGENT.md for the full refactoring checklist.
