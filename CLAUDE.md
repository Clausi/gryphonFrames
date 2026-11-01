# GryphonFrames

World of Warcraft addon that improves the default Blizzard frames.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This file only adds
what is specific to GryphonFrames.

## Target clients

- **Forever** (16001, `forever` branch of wow-ui-source, Mainline UI), **Classic Era** (11509,
  `classic_era`) and **Anniversary** (20506, `classic_anniversary`), all in one `.toc`
  (`## Interface: 16001, 11509, 20506`). Other clients (Retail, MoP Classic) are not supported.
  Forever differs from Retail in many places.
- Every client difference goes through `ns.Compat` (`Core/Compat.lua`). Read the Blizzard source of
  all three branches before hooking a frame: Classic Era and Anniversary use the Classic UI
  (`Blizzard_UnitFrame/Classic/...`), Forever the Mainline UI.
- All three clients have Blizzard's Edit Mode, so LibEditMode is used on all of them.
- Features are usually one module per Blizzard frame.

## Testing

`.tools/deploy.cmd forever|era|anniversary|all` copies the addon into the AddOns folder of that
client (default `all` installed clients; run `.tools/fetch-libs.cmd` once before).
`.tools/deploy-forever.cmd` is a shortcut for `deploy.cmd forever`.

## Libraries

- `.tools/fetch-libs.cmd` fetches the same library versions as the `externals` in `.pkgmeta`.
  luacheck skips `Libs/`.
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
