# Changelog

## Unreleased

## 0.1.1 - 2026-08-26

- Renamed the addon from ShieldWatch to ShieldHotSwapper (CurseForge
  already had a project named ShieldWatch). Set up CurseForge publishing
  (project ID 1669376) and the GitHub Actions release workflow
  (BigWigsMods/packager on tag push).

## 0.1.0 - 2026-08-26

- Initial version: icon grid of every shield in your bags, with live
  durability (color-coded ring + percent text, full tooltip on hover).
  Hold-and-drag to move the group; group only reveals its icons on hover
  (toggleable). Rows/columns sliders size the grid.
- Click an icon to equip that shield (swaps whatever's currently worn back
  into the bag), same as double-clicking it in your bags.
- Fixed: the frame no longer reserves space for the full rows x columns
  grid regardless of how many shields you actually have - it now sizes to
  fit only what's currently shown.
- The currently-equipped shield now shows in the grid too, not just ones
  sitting in bags - its durability actually changes from combat, so it's
  the one most worth watching. Rescans on `PLAYER_EQUIPMENT_CHANGED` and
  `UPDATE_INVENTORY_DURABILITY` in addition to bag updates.
- Changed the equipped-shield marker from a small "W" corner tag (too easy
  to miss) to a gold outline box around the whole icon.
- Fixed: "only show icons on hover" had no effect while the frame was
  unlocked (the default state) - a boolean bug in `Frame.lua:ApplyReveal`
  meant icons were always shown regardless of the setting unless you'd
  also locked the frame.
- Removed hover-to-reveal entirely (setting and functionality both gone,
  per feedback: an empty box when not hovering looked bad, and hovering
  over one icon hid the rest of the group). All icons are always visible
  now, same as EasyMount/PallySquire.
- The equipped shield is always visible - it never gets clipped out by the
  rows/columns capacity, even if bag shields fill the rest of the grid.
- Changed how the equipped shield is represented: instead of pinning it as
  a separate first icon (which reshuffled the rest of the grid every time
  you equipped something - the previously-worn shield would jump into the
  bag-sorted list and the newly-worn one would jump to the front), it's
  now just one shield in the same sorted pool as everything else. Since
  durability doesn't change the instant you equip something, its position
  doesn't move either - only the gold outline box jumps to mark whichever
  icon is currently worn.
- Fixed: icons were still visibly swapping positions on equip even after
  the above change, because `table.sort` isn't stable and every shield
  usually ties at 100% durability - Lua is free to reorder equal-valued
  items differently depending on their input order, and equipping changes
  that input order (the newly-worn item leaves the bag scan, the
  previously-worn one re-enters it at some bag slot). Added itemID as a
  tiebreaker so equal-durability shields sort the same way every time.
- Fixed: owning two genuinely identical shields (same itemID, same
  durability) could still flip which of the two slots showed the gold
  box, since itemID alone doesn't distinguish them. Confirmed (via the new
  `/shs dump`, live in-game data) that `C_Item.GetItemGUID` works on this
  client and gives each physical item a distinct, stable ID that stays the
  same across an equip/unequip location change. Sorting now uses that as
  the tiebreaker, so the grid's order genuinely never changes just because
  something got equipped - only the gold box moves - even for duplicates.
- Added `/shs dump`: a copyable text dump of everything read off each
  shield (itemID, link, durability, item GUID), for diagnosing edge cases
  like the above.
