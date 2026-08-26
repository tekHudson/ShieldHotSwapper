# ShieldWatch

Shows every shield sitting in your bags as a small icon grid, with live
durability, so spare/resistance shields don't quietly go unrepaired.

- Icons sort most-damaged shield first.
- Hold-click anywhere on the group (an icon or the background gap) to drag
  the whole thing.
- Hover the group to reveal the icons (toggleable in options); lock the
  frame to stop accidental drags.
- Two sliders under Display set the grid size: rows (1-6), columns (1-10).
- `/sw` opens options. `/sw lock`, `/sw unlock`, `/sw reset` also work.

## Icon art

`Icons/Icon.tga` (64x64) is the in-game/TOC icon, referenced by
`ShieldWatch.toc`'s `IconTexture`. `Icons/Icon_source.png` is the larger
source version (not shipped - see `.pkgmeta`), useful for the CurseForge
project thumbnail.
