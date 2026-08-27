# ShieldHotSwapper

Shows your currently-equipped shield plus every shield sitting in your bags
as a small icon grid, with durability, so spare/resistance shields (and the
one you're actually wearing) don't quietly go unrepaired.

- Only loads for Warrior/Paladin/Shaman - the only classes that can equip a
  shield in Classic Era/SoD. Prints a one-line "disabled" message and does
  nothing else on any other class.
- The grid itself only shows once you own 2+ shields total (worn + bagged
  combined) - with 0 or 1, there's no "which one is worn" question to
  answer yet, so there's nothing worth displaying.
- Layout is `<equipped> gap <bag shields...>`: the shield you're wearing
  is always the first icon, with a visual gap before the grid of spares
  from your bags. Position alone tells you which one is equipped - no
  highlight to track. Bag shields sort most-damaged first, then
  alphabetically by name for ties (the common case - shields don't take
  damage sitting in a bag).
- Right-click a bag icon to equip that shield (swaps whatever's currently
  worn back into the bag), same as double-clicking it in your bags.
  Right-clicking the worn shield's own icon does nothing - there's nothing
  to swap it with. Works in combat too - the icons are secure action
  buttons, so equipping survives combat lockdown the same way action bars
  do. It's right-click and not left specifically so it doesn't conflict
  with left-click-and-hold, which drags the group.
- Hold-click (left) anywhere on the group (an icon or the background gap)
  to drag the whole thing. Lock the frame in options to stop accidental
  drags.
- Two sliders under Display set the bag grid's size: rows (1-6), columns
  (1-10). The equipped icon is separate and doesn't count against this.
- Durability numbers keep updating live in combat. Which shield is on
  which icon freezes during combat, though, and only catches up once
  combat ends - reassigning icons requires secure/protected changes that
  can't happen mid-fight. If you equip a shield mid-combat, the icons
  whose bag slots shuffle as a result may briefly show a different
  shield's numbers than expected on that icon, until combat ends and
  everything re-syncs.
- `/shs` opens options. `/shs lock`, `/shs unlock`, `/shs reset` also
  work. `/shs dump` opens a copyable text dump of everything read off
  each shield (itemID, link, durability, etc.) - a diagnostic tool, not a
  normal feature.

## Icon art

`Icons/Icon.tga` (64x64) is the in-game/TOC icon, referenced by
`ShieldHotSwapper.toc`'s `IconTexture`. `Icons/Icon_source.png` is the larger
source version (not shipped - see `.pkgmeta`), useful for the CurseForge
project thumbnail.
