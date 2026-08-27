# ShieldHotSwapper

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
  Works in combat too - the icons are secure action buttons, so equipping
  survives combat lockdown the same way action bars do.
- Hold-click anywhere on the group (an icon or the background gap) to drag
  the whole thing. Lock the frame in options to stop accidental drags.
- Two sliders under Display set the grid size: rows (1-6), columns (1-10).
- The grid freezes (which shield is on which icon) while you're in combat -
  durability numbers still update live, but reassigning icons has to wait
  until combat ends, since that's a secure/protected action. Anything that
  was already on the grid before combat started stays clickable throughout.
- `/shs` opens options. `/shs lock`, `/shs unlock`, `/shs reset` also
  work. `/shs dump` opens a copyable text dump of everything read off
  each shield (itemID, link, durability, etc.) - a diagnostic tool, not a
  normal feature.

## Icon art

`Icons/Icon.tga` (64x64) is the in-game/TOC icon, referenced by
`ShieldHotSwapper.toc`'s `IconTexture`. `Icons/Icon_source.png` is the larger
source version (not shipped - see `.pkgmeta`), useful for the CurseForge
project thumbnail.
