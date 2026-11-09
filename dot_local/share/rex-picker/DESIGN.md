---
name: Rex Picker
subject: Native fuzzy navigation for Rex
audience: Keyboard-driven Rex users
job: Select a machine, session, or tab without navigating a tree
type:
  body: macOS system font
  utility: macOS small system font
palette:
  surface: Rex selected theme background
  ink: Rex selected theme foreground
  muted: Rex foreground blended over background
  selection: Rex selected theme selectionBackground
  selectionInk: Rex selected theme selectionForeground
signature: One flat list with machine and session context on every result
---

## Direction

The user selected the Spotlight-style flat list over grouped sections and a two-column navigator. Spotlight is the stated interaction reference, not a pixel-matched reproduction. Use AppKit search, table selection, and system typography. Read Rex’s current custom theme and appearance from its preferences on each opening. Use its background, foreground, and selection palette throughout both picker modes; use system colors only when the active theme cannot be resolved. No web reference exploration was performed because the selected direction is a native system utility.

## Component decisions

A floating, resizable utility panel opens near the top-center of the active screen. Search stays focused while arrow keys move selection. Each row shows a title and its type and destination context. Enter activates, Escape dismisses, and double-click activates. Selected rows use Rex’s selection background and foreground rather than the macOS accent. The menu bar provides Open, Refresh, and Quit. Ctrl+A then F opens fuzzy search. Ctrl+A then apostrophe opens the same panel in numbered-tab mode: a flat list with visible number badges and machine/session context. Digits 1–9 activate immediately. Arrows, name search, double-click, and Enter reach any tab. Numbers derive from local-first configured host/session/tab order and do not change while the panel is open; numbering waits for discovery to finish.

## Edge states

Cached results appear immediately on reopening. Refresh runs away from the main thread and streams hosts independently. Offline hosts remain visible with their error. Hosts without this Mac's Rex connection are unavailable rather than targeting another device. Empty searches explain whether nothing matched or no destinations exist. Activation errors keep the picker open. Rex’s appearance preference selects its light or dark palette independently of the macOS appearance. Failed host discovery is reported; numbered mode refuses to present a partial list as complete.

## Anti-references

No browser shell, gradients, cards, unrelated macOS accent colors, decorative glass, or dashboard layout.
