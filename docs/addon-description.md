# GryphonFrames

**Better default frames for World of Warcraft: Forever, Classic Era and Classic Anniversary.**

GryphonFrames improves Blizzard's own frames instead of replacing them. Everything stays where you know it.

## Features

### Movable target cast bar
- Move the cast bar of your target anywhere in **Edit Mode**, like the other frames
- Saved separately for each Edit Mode layout
- **Lock to Target Frame** or **Reset Position** puts it back below the target frame

### Combo points on the nameplate
- Rogues and cat druids also see their combo points on the target's nameplate
- The combo points at the target frame stay where they are
- Modern style like the modern unit frames, or classic style
- Above the name or below the nameplate, with adjustable size, gap and left/right position
- Turn it on in the addon options or with `/gryphonframes combo on`, per character

### Energy ticks on the player frame
- A spark runs across the energy bar of the player frame and shows when the next energy tick comes
- For rogues and cat druids, keeps running at full energy
- Turn it on in the addon options or with `/gryphonframes energy on`, per character

### Mana ticks and five second rule
- After you spend mana, a red spark runs from right to left across the mana bar for 5 seconds: the
  time without mana regeneration
- Then a spark shows when the next mana tick comes; hidden at full mana
- Turn it on in the addon options or with `/gryphonframes mana on`, per character

### Own buffs at the player frame
- Shows the buffs you cast at the player frame, with stacks, remaining time and tooltip
- Below the power bar, or anywhere in **Edit Mode**, with icon size and icons per row per layout
- Hide long buffs with a maximum duration, and buffs without a duration (forms, auras, aspects);
  whitelist and blacklist by spell ID or aura name, or show only the whitelist
- Turn it on in the addon options or with `/gryphonframes buffs on`, per character

### IDs in tooltips
- Spells, buffs, debuffs, items and NPCs show their ID in the tooltip, handy for the buff whitelist
- Spell IDs, item IDs and NPC IDs are turned on separately, in the addon options or with
  `/gryphonframes spellids on`, `/gryphonframes itemids on` and `/gryphonframes npcids on`, per
  character

## Options

Options > AddOns > GryphonFrames, or `/gryphonframes options`. Unit frame options are under
GryphonFrames > Unit Frames, nameplate options under GryphonFrames > Nameplates, tooltip options
under GryphonFrames > Tooltips.

## Slash commands

- `/gryphonframes` – help
- `/gryphonframes options` – open the addon options
- `/gryphonframes chat on|off` – automatic chat messages
- `/gryphonframes combo on|off` – combo points on the target's nameplate
- `/gryphonframes energy on|off` – energy ticks on the player frame
- `/gryphonframes mana on|off` – mana ticks and five second rule on the player frame
- `/gryphonframes buffs on|off` – own buffs at the player frame
- `/gryphonframes spellids on|off` – spell IDs in tooltips
- `/gryphonframes itemids on|off` – item IDs in tooltips
- `/gryphonframes npcids on|off` – NPC IDs in tooltips
