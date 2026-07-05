class_name Palette
extends RefCounted
## Curated 32-color palette for dungeon caretaker.
## ALL colors in the game must come from this palette. No arbitrary RGB.

# --- Deep darks (backgrounds, shadows) ---
const VOID       := Color(0.07, 0.05, 0.10)  # deepest black-purple
const DARK       := Color(0.12, 0.10, 0.16)  # dungeon dark
const STONE      := Color(0.18, 0.16, 0.22)  # wall stone
const STONE_LT   := Color(0.26, 0.24, 0.32)  # wall highlight
const STONE_DK   := Color(0.10, 0.08, 0.14)  # wall shadow

# --- Floors ---
const FLOOR      := Color(0.15, 0.13, 0.19)  # base floor
const FLOOR_DK   := Color(0.10, 0.08, 0.14)  # floor shadow
const FLOOR_LT   := Color(0.20, 0.18, 0.26)  # floor highlight
const GRIME      := Color(0.08, 0.06, 0.10)  # grout lines

# --- Wood / Leather ---
const WOOD       := Color(0.40, 0.25, 0.15)  # wood base
const WOOD_DK    := Color(0.25, 0.15, 0.08)  # wood shadow
const WOOD_LT    := Color(0.55, 0.35, 0.22)  # wood highlight
const LEATHER    := Color(0.35, 0.20, 0.12)  # leather

# --- Metal ---
const STEEL      := Color(0.60, 0.65, 0.72)  # steel base
const STEEL_DK   := Color(0.35, 0.40, 0.48)  # steel shadow
const STEEL_LT   := Color(0.85, 0.88, 0.95)  # steel highlight
const IRON       := Color(0.30, 0.30, 0.35)  # dark iron

# --- Ghost / Magic ---
const GHOST      := Color(0.80, 0.85, 0.95, 0.88)  # ghost body
const GHOST_DK   := Color(0.50, 0.55, 0.70, 0.60)  # ghost shadow
const GLOW_BLUE  := Color(0.45, 0.75, 0.95)  # magic blue glow
const GLOW_PURP  := Color(0.65, 0.40, 0.85)  # magic purple glow

# --- Fire / Warmth ---
const FIRE_CORE  := Color(1.00, 0.85, 0.40)  # fire bright
const FIRE       := Color(0.95, 0.55, 0.20)  # fire mid
const FIRE_DK    := Color(0.85, 0.30, 0.10)  # fire deep
const GOLD       := Color(0.95, 0.80, 0.30)  # gold trim

# --- Nature / Danger ---
const SLIME      := Color(0.45, 0.80, 0.45)  # slime green
const BLOOD      := Color(0.55, 0.12, 0.12)  # blood red
const BONE       := Color(0.88, 0.82, 0.68)  # bone white
const RUST       := Color(0.70, 0.40, 0.20)  # rust orange

# --- Text / UI ---
const TEXT       := Color(0.90, 0.88, 0.92)  # body text
const TEXT_DIM   := Color(0.55, 0.52, 0.60)  # dim text
const TEXT_GOLD  := Color(0.95, 0.85, 0.40)  # gold text (headers)
const TEXT_GREEN := Color(0.55, 0.95, 0.55)  # positive text
const TEXT_RED   := Color(0.95, 0.40, 0.40)  # negative text
const TEXT_BLUE  := Color(0.65, 0.85, 0.95)  # info text

# --- State colors (for weapon states) ---
const STATE_PRISTINE := Color(0.55, 0.95, 0.55)
const STATE_BLOODIED := Color(0.85, 0.45, 0.45)
const STATE_RUSTED   := Color(0.75, 0.55, 0.30)
const STATE_HAUNTED  := Color(0.55, 0.75, 0.95)
const STATE_CURSED   := Color(0.65, 0.40, 0.85)
const STATE_SHATTERED := Color(0.45, 0.45, 0.45)

# --- Wear state colors ---
const WEAR_PRISTINE := Color(0.55, 0.95, 0.55)
const WEAR_WORN     := Color(0.95, 0.85, 0.40)
const WEAR_DAMAGED  := Color(0.95, 0.55, 0.30)
const WEAR_BROKEN   := Color(0.55, 0.30, 0.30)
