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
- The currently-equipped shield now shows in the grid too (marked with a
  "W" tag), not just ones sitting in bags - its durability actually changes
  from combat, so it's the one most worth watching. Rescans on
  `PLAYER_EQUIPMENT_CHANGED` and `UPDATE_INVENTORY_DURABILITY` in addition
  to bag updates.
