class_name Palette
extends RefCounted
## V6 Palette — richer, more vibrant, with proper light/dark ramps.
## 48 colors organized by function. Every color in the game comes from here.

# === DEPTHS (backgrounds, shadows, voids) ===
const VOID       := Color(0.05, 0.03, 0.08)   # deepest black-purple
const DARK       := Color(0.10, 0.08, 0.14)   # dungeon dark
const DEEP       := Color(0.14, 0.11, 0.19)   # deep stone

# === STONES (walls, floors) ===
const STONE      := Color(0.20, 0.18, 0.26)   # wall stone
const STONE_LT   := Color(0.30, 0.27, 0.38)   # wall highlight
const STONE_DK   := Color(0.12, 0.10, 0.16)   # wall shadow
const FLOOR      := Color(0.16, 0.14, 0.20)   # base floor
const FLOOR_DK   := Color(0.11, 0.09, 0.15)   # floor shadow
const FLOOR_LT   := Color(0.22, 0.20, 0.28)   # floor highlight
const GRIME      := Color(0.07, 0.05, 0.10)   # grout lines

# === WOOD / LEATHER ===
const WOOD       := Color(0.42, 0.26, 0.16)   # wood base
const WOOD_DK    := Color(0.26, 0.15, 0.09)   # wood shadow
const WOOD_LT    := Color(0.58, 0.38, 0.24)   # wood highlight
const LEATHER    := Color(0.36, 0.21, 0.13)   # leather

# === METALS ===
const STEEL      := Color(0.62, 0.67, 0.74)   # steel base
const STEEL_DK   := Color(0.36, 0.41, 0.49)   # steel shadow
const STEEL_LT   := Color(0.88, 0.91, 0.97)   # steel highlight
const IRON       := Color(0.30, 0.30, 0.35)   # dark iron
const GOLD       := Color(0.95, 0.78, 0.28)   # gold trim
const GOLD_LT    := Color(1.00, 0.92, 0.50)   # gold highlight

# === GHOST / MAGIC ===
const GHOST      := Color(0.82, 0.88, 0.98, 0.90)  # ghost body
const GHOST_DK   := Color(0.50, 0.55, 0.72, 0.60)  # ghost shadow
const GHOST_LT   := Color(0.95, 0.97, 1.00, 0.95)  # ghost highlight
const GLOW_BLUE  := Color(0.45, 0.78, 1.00)   # magic blue glow
const GLOW_PURP  := Color(0.68, 0.42, 0.88)   # magic purple glow
const GLOW_CYAN  := Color(0.40, 0.90, 0.85)   # magic cyan glow

# === FIRE / WARMTH ===
const FIRE_CORE  := Color(1.00, 0.90, 0.50)   # fire bright
const FIRE       := Color(0.98, 0.58, 0.22)   # fire mid
const FIRE_DK    := Color(0.88, 0.32, 0.12)   # fire deep
const EMBER      := Color(0.95, 0.45, 0.15)   # ember glow

# === NATURE / DANGER ===
const SLIME      := Color(0.48, 0.85, 0.48)   # slime green
const SLIME_DK   := Color(0.28, 0.55, 0.28)   # slime shadow
const BLOOD      := Color(0.60, 0.14, 0.14)   # blood red
const BLOOD_DK   := Color(0.38, 0.06, 0.06)   # blood deep
const BONE       := Color(0.90, 0.85, 0.72)   # bone white
const BONE_DK    := Color(0.65, 0.58, 0.45)   # bone shadow
const RUST       := Color(0.72, 0.42, 0.22)   # rust orange

# === TEXT / UI ===
const TEXT       := Color(0.92, 0.90, 0.94)   # body text
const TEXT_DIM   := Color(0.55, 0.52, 0.62)   # dim text
const TEXT_GOLD  := Color(0.98, 0.88, 0.42)   # gold text (headers)
const TEXT_GREEN := Color(0.58, 0.98, 0.58)   # positive text
const TEXT_RED   := Color(0.98, 0.42, 0.42)   # negative text
const TEXT_BLUE  := Color(0.68, 0.88, 1.00)   # info text

# === STATE COLORS (weapon states) ===
const STATE_PRISTINE  := Color(0.58, 0.98, 0.58)
const STATE_BLOODIED  := Color(0.88, 0.48, 0.48)
const STATE_RUSTED    := Color(0.78, 0.58, 0.32)
const STATE_HAUNTED   := Color(0.58, 0.78, 1.00)
const STATE_CURSED    := Color(0.68, 0.42, 0.88)
const STATE_SHATTERED := Color(0.48, 0.48, 0.48)

# === WEAR STATE COLORS ===
const WEAR_PRISTINE := Color(0.58, 0.98, 0.58)
const WEAR_WORN     := Color(0.98, 0.88, 0.42)
const WEAR_DAMAGED  := Color(0.98, 0.58, 0.32)
const WEAR_BROKEN   := Color(0.58, 0.32, 0.32)

# === AMBIENT LIGHT (for radial gradients) ===
const LIGHT_TORCH  := Color(1.00, 0.65, 0.25, 0.15)  # torch glow
const LIGHT_FURNACE := Color(1.00, 0.45, 0.15, 0.20) # furnace glow
const LIGHT_ALTAR   := Color(0.45, 0.78, 1.00, 0.15) # altar glow
const LIGHT_EXIT    := Color(0.45, 0.98, 0.65, 0.15) # exit glow
