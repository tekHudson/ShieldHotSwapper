# Changelog

## Unreleased

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
