---
name: wow-lua
description: Rules for World of Warcraft addon development in Lua - Lua 5.1 limits, luacheck, locales, addon structure (ns, modules, saved variables, TOC), Blizzard UI hooking and taint, combat lockdown, secret values, character names per client, client compatibility via ns.Compat, changelog and releases. Use before reading, writing or reviewing code in any WoW addon (a repo with a .toc file and .lua files).
---

# WoW addon development (Lua)

These rules apply to every WoW addon project. The project's `CLAUDE.md` names the target clients,
locales, libraries and module-specific rules, and wins where it differs.

## Lua and luacheck

- Lua 5.1 (WoW flavor): no `goto`, `//`, bitwise operators, `require`, `io` or `os`.
- **luacheck must be green (0 warnings / 0 errors) after every change.** Run it from the repo root:

  ```
  ./.tools/luacheck.exe .
  ```

- Fix warnings in the code. Only change `.luacheckrc` when the warning is a false positive, e.g. a new
  WoW API global (add it to `read_globals`) or an intentional write to a Blizzard frame field.
  Never silence warnings globally or with inline `-- luacheck: ignore` without a reason in a comment.
- luacheck also runs in CI (`.github/workflows/luacheck.yml`) on pull requests and on `main`.
- Code cannot be tested in-game from here. After a change, tell the user what to verify in-game.

## Language and text

- Code, identifiers, comments and docs are in **English**.
- Never hardcode user-facing text. Every string goes through `L["KEY"]`:
  1. Add the key to `Locales/enUS.lua` (base locale, must contain every key).
  2. Add the translations to every other locale file the project has (listed in its `CLAUDE.md`).
  Missing translations fall back to English.
- `|` starts an escape sequence in WoW text (`|n` newline, `|c` color, `|H` hyperlink, ...). Write a
  literal pipe as `||` in user-facing strings. Never cut or rewrite text (e.g. chat messages, item
  links) in the middle of an escape sequence.

## Addon structure

- All files share the addon namespace via `local addonName, ns = ...`. Do not create new globals;
  the only allowed globals are the ones listed under `globals` in `.luacheckrc`.
- Features live in `Modules/` and register with `ns:RegisterModule("Name")`:
  - `OnInitialize()` runs on `ADDON_LOADED` (saved variables are available).
  - `OnEnable()` runs on `PLAYER_LOGIN`.
  - Frames of load-on-demand Blizzard addons (e.g. `Blizzard_InspectUI`) do not exist yet at
    login. Hook them when `ADDON_LOADED` fires for that addon, or right away if
    `C_AddOns.IsAddOnLoaded` says it is already loaded.
- Use the helpers from `Core/` (`ns:RegisterEvent`, `ns:Print`, `ns:Debug`, `ns:Notify` where it
  exists) instead of own event frames or `print`.
- Slash subcommands are registered with `ns:RegisterCommand(name, handler, helpLines)`, never by
  extending the handler in `Core/Main.lua`.
- Saved variables (defaults in `Core/Init.lua`):
  - `<Addon>DB` / `ns.db` (account-wide, `ns.defaults`): settings and data shared by all characters.
  - `<Addon>CharDB` / `ns.charDb` (per character, `ns.charDefaults`): data only the logged-in
    character needs. Prefer this for growing per-character data, so a login does not load the data
    of all characters.
- Every new file must be added to the `.toc`. Libraries first, then locales, `Core\Main.lua` last.
- Libraries live in `Libs/`, are not in the repo (`.gitignore`) and are fetched from the
  `externals` in `.pkgmeta`. Never modify a library.

## Working with the Blizzard UI

- Reference for Blizzard UI code: https://github.com/Gethe/wow-ui-source, branch per client:
  `forever` (Forever), `live` (Retail), `classic_era` (Classic Era), `classic_anniversary`
  (Anniversary), `classic` (MoP Classic). Read the actual Blizzard source of every target client
  before hooking or mirroring Blizzard behavior instead of relying on memory; clients differ in many
  places.
- Verify interface numbers in-game with `/dump select(4, GetBuildInfo())`.
- Improve Blizzard frames, do not replace them. Prefer `hooksecurefunc`, `HookScript` and (for chat)
  `ChatFrame_AddMessageEventFilter` over replacing Blizzard functions, methods or scripts (e.g. a
  chat frame's `AddMessage`), to avoid taint.
- Keep writes to Blizzard frames minimal and document why, in the code and in `.luacheckrc`.
- Many frames are protected or secure (unit frames, action bars, ...). Do not move, show, hide or
  resize them in combat (`InCombatLockdown()`); defer such changes to `PLAYER_REGEN_ENABLED`.
- Own frames must not go through Blizzard's panel manager (`ShowUIPanel`, `HideUIPanel`,
  `HideParentPanel`, the scripts of `UIPanelCloseButton`): from addon code it is blocked in combat
  ("Interface action failed because of an AddOn"). Use `UIPanelCloseButtonNoScripts` with an own
  `OnClick` that calls `frame:Hide()`.
- Values returned by the API and event arguments may be secret values (Forever, Retail), e.g. unit
  health in combat or chat messages during encounters. Guard string or number operations on them
  with `issecretvalue` and pass secret values through unchanged.

## Clients and compatibility

Interface numbers: Forever 16001, Retail 120105, Classic Era 11509, Anniversary 20506,
MoP Classic 50504. Forever and Retail use the Mainline UI and API; Classic Era, Anniversary and
MoP Classic use the Classic UI.

- Supported clients are exactly the ones in `## Interface:` of the `.toc` (see the project's
  `CLAUDE.md`). Do not add code for other clients.
- In a multi-client addon, every client difference goes through `ns.Compat` (`Core/Compat.lua`).
  Detect APIs, methods or frame fields that exist instead of comparing version numbers, and do not
  branch on clients anywhere else. Put Blizzard UI access that is likely to differ (frame internals,
  sending chat messages via `C_ChatInfo.SendChatMessage` or `SendChatMessage`, secret values) behind
  `ns.Compat` from the start.
- A single-client addon has no compatibility layer and no client checks.

## Character names

Names differ per client. When a feature builds, compares or shows names, use `ns.Names`
(`Core/Names.lua`, with `ns.Compat.HasRealmNames()`; the reference implementation is in GryphonMail,
https://github.com/Clausi/gryphonMail). Never use `Ambiguate`.

- **Forever:** names are "First Surname" (separator from
  `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR`, a space) and carry no
  realm suffix. `UnitName(unit)` returns first name and **surname**, not name and realm. Each
  ruleset (PvE, PvP, RP) is its own realm, e.g. `GetRealmName()` = "Classic Beta PvE". A full name
  is unique across rulesets.
- **Classic Era, Anniversary, MoP Classic, Retail:** names are "Name-Realm" with the realm from
  `GetNormalizedRealmName()` (no spaces). Chat events usually include the sender's realm; other APIs
  leave it out for the own realm. `Names.Normalize` fills in the own realm for comparing;
  `Names.ToDisplay` gives the short name for the own realm.

## Housekeeping

- Record every user-visible change in `CHANGELOG.md` under `[Unreleased]`
  ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format: Added, Changed, Fixed, Removed).
- On a release, move the entries to a new version section and bump `## Version` in the `.toc`.
  After that is merged, a pushed tag `vX.Y.Z` on `main` builds and uploads the release (see
  "Releasing" in `README.md`). Only tag when asked.
- Keep the structure section in `README.md` up to date when files are added or removed.
- Commit scopes are usually the module name in kebab-case, or `core`, `locales`, `toc`.
