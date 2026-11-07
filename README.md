# GryphonFrames

A World of Warcraft addon that improves the default Blizzard frames.

## Supported clients

| Client  | Interface | Status    |
| ------- | --------- | --------- |
| Forever | 16001     | Supported |

Other clients are not supported.

## Installation

Copy (or symlink) the `GryphonFrames` folder into the AddOns folder of the client:

```
World of Warcraft\_forever_\Interface\AddOns\GryphonFrames
```

## Structure

```
GryphonFrames.toc      Addon metadata and load order
Locales/enUS.lua       Base locale (every key), fallback for all languages
Locales/deDE.lua       German translation
Core/Init.lua          Namespace, saved variable defaults, module, command and event registry
Core/Util.lua          Chat output, debug and memory helpers, defaults merging
Core/Main.lua          Bootstrap: saved variables, module lifecycle, slash commands
Modules/TargetCastBar.lua  Makes the target cast bar movable in Edit Mode
Modules/NameplateComboPoints.lua  Shows combo points on the target's nameplate as well
Modules/PlayerPowerTicks.lua  Shows the five second rule on the player frame
Modules/TooltipIds.lua  Shows spell, item and NPC IDs in tooltips
Modules/Options.lua    Options page in the game settings ("/gryphonframes options")
Libs/                  Embedded libraries, not in the repo (fetched by the packager)
```

## Libraries

The packager embeds these libraries from the externals in `.pkgmeta`:

- [LibStub](https://www.wowace.com/projects/libstub) (public domain)
- [LibEditMode](https://github.com/p3lim-wow/LibEditMode) by p3lim: adds own frames to the Edit
  Mode. Its license allows embedding it unmodified into an addon; it stays under its own license
  (`Libs/LibEditMode/LICENSE.txt`), not under the MIT license of GryphonFrames.

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` to a new version section and bump
   `## Version` in `GryphonFrames.toc`, then merge that into `main`.
2. Tag the merged commit on `main` and push the tag:

   ```
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

The release workflow (`.github/workflows/release.yml`) builds the package with the BigWigs
packager and uploads it as a GitHub release, and to CurseForge once `## X-Curse-Project-ID` is set
in the TOC and the `CF_API_KEY` secret exists.

## Localization

All strings live in `Locales/`. Add new keys to `enUS.lua` first; other locales
only override what they translate. Missing keys fall back to English.

## Development

Lint with [luacheck](https://github.com/lunarmodules/luacheck). Place `luacheck.exe` in `.tools/`
(ignored by git) and run from the repo root:

```
./.tools/luacheck.exe .
```

## Slash commands

- `/gryphonframes` – help
- `/gryphonframes options` – open the addon options (also in Options > AddOns > GryphonFrames)
- `/gryphonframes version` – show version
- `/gryphonframes chat on|off` – automatic chat messages (login, hints) of the current character,
  default on
- `/gryphonframes combo on|off` – also show combo points on the target's nameplate for the current
  character, default off (position, size and gap in the options)
- `/gryphonframes mana on|off` – show the five second rule on the player frame for the current
  character, default off
- `/gryphonframes spellids on|off` – show spell IDs in tooltips (spells, buffs, debuffs) for the
  current character, default off
- `/gryphonframes itemids on|off` – show item IDs in tooltips for the current character, default
  off
- `/gryphonframes npcids on|off` – show NPC IDs in tooltips for the current character, default off
- `/gryphonframes debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.

## Options

All options live in `Modules/Options.lua` (Esc > Options > AddOns > GryphonFrames), loaded after
the other modules. General options are on the main page; everything on unit frames goes into the
"Unit Frames" subcategory, everything on nameplates into "Nameplates" and everything on tooltips
into "Tooltips", one section per feature.
Proxy settings read and write `ns.db` and `ns.charDb` through the getters and setters of the
modules (e.g. `NameplateComboPoints:SetScale`), so a change takes effect right away.
Opening the page by command is blocked in combat.

## License

[MIT](LICENSE)
