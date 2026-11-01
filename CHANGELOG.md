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
- Addon options in Options > AddOns > GryphonFrames, or with `/gryphonframes options`. Nameplate
  options are in the subcategory "Nameplates".
