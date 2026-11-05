# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Addon skeleton for WoW Forever: saved variables, module system and the slash commands
  `/gryphonframes version`, `/gryphonframes chat on|off` and `/gryphonframes debug`.
- The cast bar of the target frame can be moved in Edit Mode, separately for each layout. "Lock to
  Target Frame" or "Reset Position" puts it back below the target frame.
- Support for WoW Classic Era and Classic Anniversary.
- Combo points of rogues and cat druids can also be shown on the target's nameplate
  (`/gryphonframes combo on|off`, per character, off by default). Size, position (above the name
  or below the nameplate), gap and left/right position can be changed in the options.
- Nameplate combo points: new style option "Modern" (like the combo points of the modern unit
  frames, drawn on Classic Era and Anniversary) or "Classic", with an animation when a point fills.
- Energy ticks on the player frame: a spark runs across the energy bar and shows when the next
  energy tick comes, for rogues and cat druids (`/gryphonframes energy on|off`, per character, off
  by default).
- Mana ticks and the five second rule on the player frame: after a mana spend, a red spark runs
  from right to left for the 5 seconds without mana regeneration, then the spark shows the mana
  ticks (`/gryphonframes mana on|off`, per character, off by default). Energy and mana ticks are
  only available on Classic Era and Anniversary for now: WoW Forever hides power values from addons
  in combat. On WoW Forever, the five second rule is shown on its own and starts with every cast of
  a spell that costs mana, also a free one (Clearcasting).
- Own buffs at the player frame: all buffs you cast, with stacks, remaining time and tooltip
  (`/gryphonframes buffs on|off`, per character, off by default). Below the power bar of the
  player frame, or anywhere in Edit Mode, with icon size, icons per row, alignment (left to right,
  centered or right to left) and sort order (default, remaining time, full duration, name or
  whitelist order, optionally reversed) per layout. Only available on Classic Era and Anniversary
  for now: WoW Forever hides auras from addons in combat.
- Own buffs: a maximum duration hides long buffs, an option hides buffs without a duration
  (forms, auras, aspects), a whitelist always shows buffs and a blacklist hides them, by spell ID
  or aura name, and an option shows only the whitelist (per character, in the options).
- IDs in tooltips: spells, buffs and debuffs show their spell ID
  (`/gryphonframes spellids on|off`), items their item ID (`/gryphonframes itemids on|off`) and
  NPCs their NPC ID (`/gryphonframes npcids on|off`), each per character and off by default.
- Addon options in Options > AddOns > GryphonFrames, or with `/gryphonframes options`. Nameplate
  options are in the subcategory "Nameplates", tooltip options in "Tooltips", unit frame options
  in "Unit Frames".
