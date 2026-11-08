# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Addon skeleton: saved variables, module system and the slash commands
  `/gryphonframes version`, `/gryphonframes chat on|off` and `/gryphonframes debug`.
- The cast bar of the target frame can be moved in Edit Mode, separately for each layout. "Lock to
  Target Frame" or "Reset Position" puts it back below the target frame.
- Combo points of rogues and cat druids can also be shown on the target's nameplate
  (`/gryphonframes combo on|off`, per character, off by default). Size, position (above the name
  or below the nameplate), gap and left/right position can be changed in the options.
- Nameplate combo points: new style option "Modern" (like the combo points of the modern unit
  frames) or "Classic", with an animation when a point fills.
- Five second rule on the player frame: after a spell that costs mana, also a free one
  (Clearcasting), a red line runs from right to left for the 5 seconds without mana regeneration
  (`/gryphonframes mana on|off`, per character, off by default).
- IDs in tooltips: spells, buffs and debuffs show their spell ID
  (`/gryphonframes spellids on|off`), items their item ID (`/gryphonframes itemids on|off`) and
  NPCs their NPC ID (`/gryphonframes npcids on|off`), each per character and off by default.
- Loot rolls: a panel next to each roll frame shows who chose need, greed or pass
  (`/gryphonframes rolls on|off`), and a small scrolling window keeps finished rolls grouped by item
  (`/gryphonframes rollresults on|off`), both per character and on by default. The window can
  be moved and sized with the mouse, also in combat, or in Edit Mode, and can close by itself after a set time.
  Edit Mode also sets padding, opacity, background, text size, item icons and class colors, per
  layout, and shows a sample while the window is empty.
- Addon options in Options > AddOns > GryphonFrames, or with `/gryphonframes options`. Nameplate
  options are in the subcategory "Nameplates", tooltip options in "Tooltips", unit frame options
  in "Unit Frames", loot roll options in "Loot Rolls".
