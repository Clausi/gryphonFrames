# GryphonFrames

**Better default frames for World of Warcraft: Forever.**

GryphonFrames improves Blizzard's own frames instead of replacing them. Everything stays where you know it.

## Features

### Movable target cast bar
- Move the cast bar of your target anywhere in **Edit Mode**, like the other frames
- Saved separately for each Edit Mode layout
- **Lock to Target Frame** or **Reset Position** puts it back below the target frame

### Five second rule
- After a spell that costs mana, a red line runs from right to left across the mana bar for 5
  seconds: the time without mana regeneration
- Turn it on in the addon options or with `/gryphonframes mana on`, per character

### IDs in tooltips
- Spells, buffs, debuffs, items and NPCs show their ID in the tooltip
- Spell IDs, item IDs and NPC IDs are turned on separately, in the addon options or with
  `/gryphonframes spellids on`, `/gryphonframes itemids on` and `/gryphonframes npcids on`, per
  character
- Equippable items can also show their item level (`/gryphonframes itemlevel on`, per character)

## Options

Options > AddOns > GryphonFrames, or `/gryphonframes options`. Unit frame options are under
GryphonFrames > Unit Frames, tooltip options under GryphonFrames > Tooltips.

## Slash commands

- `/gryphonframes` – help
- `/gryphonframes options` – open the addon options
- `/gryphonframes chat on|off` – automatic chat messages
- `/gryphonframes mana on|off` – five second rule on the player frame
- `/gryphonframes spellids on|off` – spell IDs in tooltips
- `/gryphonframes itemids on|off` – item IDs in tooltips
- `/gryphonframes itemlevel on|off` – item level in tooltips
- `/gryphonframes npcids on|off` – NPC IDs in tooltips
