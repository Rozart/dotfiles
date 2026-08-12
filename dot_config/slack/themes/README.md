# Slack sidebar themes

Slack's sidebar theme is a **server-side account preference**, not a local
file. `~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application
Support/Slack/storage/root-state.json` holds only `userTheme: light|dark` and
per-team titlebar colours. Writing it from `theme` would mean lifting the
`xoxc` session token and `xoxd` cookie out of the running client and calling an
internal endpoint — it breaks on every token rotation, so `theme` copies the
string to the clipboard instead.

Paste into **Preferences → Themes → Create a custom theme**, into the box below
the swatches.

Each file is one comma-separated line, in Slack's slot order. Colour roles are
nvim's `config/palettes.lua` names.

| # | Slack slot       | Role   |
|---|------------------|--------|
| 1 | Column BG        | bg1    |
| 2 | Menu BG Hover    | bg2    |
| 3 | Active Item      | accent |
| 4 | Active Item Text | bg0    |
| 5 | Hover Item       | bg2    |
| 6 | Text Color       | fg     |
| 7 | Active Presence  | green  |
| 8 | Mention Badge    | red    |
| 9 | Top Nav BG       | bg0    |
|10 | Top Nav Text     | fg     |

Slots 9 and 10 only exist on newer desktop builds. Older ones take the first
eight and ignore the rest.

Contrast caveat: slot 4 on slot 3 clears AA on every theme except
everforest-light, where `#fdf6e3` on `#3a94c5` lands at about 3.4:1. Darken
`--th-accent` there if it bothers you.
