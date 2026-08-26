# ShieldWatch

Shows your currently-equipped shield plus every shield sitting in your bags
as a small icon grid, with live durability, so spare/resistance shields (and
the one you're actually wearing) don't quietly go unrepaired.

- All icons are always visible: one icon per shield you own, worn or in a
  bag, sorted most-damaged first. Equipping a shield doesn't reshuffle the
  icons - the gold outline box just moves to whichever icon is now worn.
  The worn shield is never crowded out by bag shields filling the grid.
- Click a bag icon to equip that shield (swaps whatever's currently worn
  back into the bag), same as double-clicking it in your bags. Clicking the
  worn shield's own icon does nothing - there's nothing to swap it with.
- Hold-click anywhere on the group (an icon or the background gap) to drag
  the whole thing. Lock the frame in options to stop accidental drags.
- Two sliders under Display set the grid size: rows (1-6), columns (1-10).
- `/sw` opens options. `/sw lock`, `/sw unlock`, `/sw reset` also work.

## Icon art

`Icons/Icon.tga` (64x64) is the in-game/TOC icon, referenced by
`ShieldWatch.toc`'s `IconTexture`. `Icons/Icon_source.png` is the larger
source version (not shipped - see `.pkgmeta`), useful for the CurseForge
project thumbnail.
