# eM Client theming

eM Client is the one app in the switch that cannot be driven from a file alone.
It keeps its settings in a SQLite database (`~/Library/Application Support/eM
Client/settings.dat`), reads them once at launch, and rewrites the whole file on
exit — so a theme written while it runs is discarded. It has no AppleScript
support for appearance either: `MailClient.sdef` exposes only `activate`,
`go to`, `mailto`, `start backup` and `subscribe`.

What it *does* have is `ThemeStyle=file` plus a `ThemePath` pointing at an
`.emtheme` on disk, and it re-reads that file on every launch. So the switch
writes the file and restarts the app, and never touches the database.

## One-time setup

`ThemeStyle` and `ThemePath` live in that database, so they have to be set once
through the UI. `theme` does the rest from then on.

1. Run `theme <any-slug>` once, so `~/.config/emclient/active.emtheme` exists.
2. eM Client → Settings → Appearance → Themes → **Import**, pick
   `~/.config/emclient/active.emtheme`, select the imported **System** theme,
   **Apply**, then **Save & Close**.
3. Confirm it took:

   ```sh
   sqlite3 ~/Library/Application\ Support/eM\ Client/settings.dat \
     "select key, value from GeneralSettings where key like 'Theme%'"
   ```

   Expect `ThemeStyle|file` and a `ThemePath`. If `ThemePath` is *not*
   `~/.config/emclient/active.emtheme`, eM Client copied the theme into its own
   store on import — point `$emclient_theme` in `theme.fish` at whatever path it
   reports instead.

## How a theme is built

`theme.emtheme.template` is one file with `{{role}}` placeholders;
`render-theme.py` substitutes a palette from `~/.config/beeper/palettes/` into
it. Every rendered theme is named `System`, so eM Client sees a single stable
theme whose colours change underneath it, rather than accumulating one entry per
slug.

The template carries 499 colour slots drawn from 16 palette roles, plus two
polarity-driven values that are not colours at all:

- `IsDarkTheme`, which eM Client uses to pick its own derived shades.
- 62 `*Invert*` flags. Toolbar and menu glyphs are monochrome images that get
  inverted to sit on a dark surface. Left at `True` under a light palette, the
  entire toolbar renders white on white.

`red` maps only to `AccountWarning`. It is the single genuine failure state in
the schema — everything else eM Client calls a "warning" is an unread-count
nudge, which takes `orange`.

## Provenance

The template's structure — which element controls which surface — was derived
from the [Dracula theme for eM Client](https://github.com/dracula/em-client),
MIT licensed, Copyright (c) 2021 Dracula Theme. Every colour in it has been
replaced by a palette role and its embedded 210 KB preview bitmap dropped; what
remains of that file is the element tree, which is dictated by eM Client's own
serializer.
