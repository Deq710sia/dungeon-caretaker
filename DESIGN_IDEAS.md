# Design Ideas — cut, half-built, or teased-but-not-delivered

This file exists so that good ideas found lying around in old/dead code or
implied-but-unbuilt UI don't just vanish during cleanup. Nothing here is
required reading to run the game — it's a backlog.

## 1. "Dumb Ways to Die" cinematic QTE cutscene (recovered from `scripts/delivery/qte_cutscene.gd`)

The current salvage phase uses small, diegetic QTE bars drawn right at the
hazard's position in the world (see `salvage.gd::_draw_qte_bar`). There used
to be a second, fancier system: a full-screen, multi-beat cutscene — 3-5
quick "beats" of a single verb (TAP / DODGE / JUMP...), each beat's timing
window shrinking as you go, judged pass/fail by majority. It played as a big
centered overlay with its own timing bar, separate from the world.

That file was dead code (nothing called it) and has been removed, but the
concept is worth keeping for later: it would make a great **escalation** for
boss waves or a rare "big hazard" — something with more weight and comedy
than the everyday in-world QTE, without replacing it. If revisited:
- Reuse the diegetic QTE's input/scoring logic rather than the old file's
  copy (which duplicated timing-bar code that now lives in `salvage.gd`).
- Keep it rare — it was designed to be a set-piece, not the default.

## 2. Boss waves are teased but not built

`planning.gd`'s map view labels the last wave of each stage "STAGE BOSS" in
red, and the README's wave table implies bosses exist. Right now
`battle.gd::_spawn_enemies()` treats every wave identically — same enemy mix,
just scaled HP/ATK/count. There's no actual boss unit, no different fight
shape, nothing that reads as "this one is special" beyond a bigger number.

A real fix would add a distinct boss dictionary (bigger sprite scale, unique
attack pattern/telegraph, a name) spawned only on `wave == WAVES_PER_STAGE`,
replacing or supplementing the normal spawn. Left undone here because it
touches combat pacing and deserves its own pass rather than being bolted on.

## 3. Haunted/Cursed states could have distinct combat behavior, not just a stat multiplier

The README describes Haunted as "-10% + jitter" and Cursed as "-40% +
debuff," but in code both just reduce `stat_multiplier()` — there's no
separate "jitter" (e.g. occasional wasted attacks / erratic movement) or
"debuff" (e.g. a status effect applied to the wielder) beyond the flat
percentage. Worth a follow-up pass if you want Haunted/Cursed to *feel*
different in a fight, not just weaker.

## 4. Fallen adventurers currently get a counter, not individual memorials

The new recruiting shrine (`planning.gd`) shows "Fallen: N" as a simple
count. A nicer version: keep a small list of `{name, class, stage, wave,
cause}` for each death and let the shrine (or the win/lose chronicle) show
individual epitaphs — "Here lies Wren the mage, Stage 3 Wave 2." This is a
natural extension of the persistent-party system now in place; skipped for
now to keep the recruiting feature itself scoped and testable.

## 5. "Famous pairing" bonus for long-term wielder/weapon combos

Now that weapons track `wielder` and adventurers persist across a whole run,
there's room for a small bonus (flavor text, or a minor stat nudge) when the
same adventurer keeps the same weapon across several consecutive waves —
rewarding *not* constantly reshuffling gear. Not implemented; flagged as a
cheap, high-flavor addition for later.

## 6. Authoring fingerprints (sharpness/balance/power/mystic) now have a blurb, could go further

`Weapon.authoring_blurb()` (new) turns the four crafting-minigame scores into
a one-line description shown in the dossier detail view. A further step
would be surfacing individual fingerprint values directly in the repair
minigames themselves (e.g. showing "Sharpness: 62%" live during the polish
minigame instead of only after the fact), so players can see the number
they're actually building toward while playing.
