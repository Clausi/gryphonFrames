# GryphonFrames

World of Warcraft addon that improves the default Blizzard frames.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
compatibility, changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This
file only adds what is specific to GryphonFrames.

## Target clients

- **Forever** only (16001, `forever` branch of wow-ui-source, Mainline UI). Other clients are not
  supported, and Forever differs from Retail in many places.
- A single client needs no `ns.Compat`: no client checks, and `issecretvalue` and `canaccesstable`
  are called directly.
- Features are usually one module per Blizzard frame.
- `Core/Names.lua` does not exist yet. When a feature needs names, take over `Core/Names.lua` from
  GryphonMail, without `Compat.HasRealmNames()`.

## Libraries

- `.tools/fetch-libs.cmd` fetches the same library versions as the `externals` in `.pkgmeta`
  (LibStub, LibEditMode) into `Libs/`. luacheck skips `Libs/`.
- LibEditMode's license only allows embedding it unmodified.
- LibEditMode (`LibStub("LibEditMode")`) adds own frames to Blizzard's Edit Mode: use it for every
  frame that should be movable or configurable there. API docs: the comments in
  `Libs/LibEditMode/LibEditMode.lua` and https://github.com/p3lim-wow/LibEditMode/wiki.
- Edit Mode positions are saved per layout name in `ns.db`, and the module handles LibEditMode's
  `create`, `rename` and `delete` callbacks (see `Modules/TargetCastBar.lua`).

## Locales

`enUS` (base), `deDE`.

## Saved variables

`GryphonFramesDB` (account-wide) and `GryphonFramesCharDB` (per character).

## Commit scopes

`loot-rolls`, `nameplate-combo-points`, `player-power-ticks`, `target-cast-bar`, `tooltip-ids`,
`options`, `core`, `locales`, `toc`.
