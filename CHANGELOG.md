# Changelog

## Unreleased

- Added a low-durability warning glow on the equipped shield icon, reusing
  Blizzard's own action-bar "spell activation alert" effect (the gold
  pulsing/ants glow used for proc alerts) rather than building one from
  scratch - traced its XML in `~/ws/wow-ui-source` first, and overrode one
  handler (the fade-out animation's `OnFinished`) since it's hardwired to
  return the frame to Blizzard's shared action-bar overlay pool, which
  would risk a real action button stealing our custom overlay later.
  Threshold is a new 0-10% slider under a "Warnings" section in options
  (default 5%). Bag spares never glow, only the equipped shield.
- Added "Demo mode" (checkbox in Settings): swaps the grid to 4 synthetic
  shields (equipped at 5% with the low-durability glow on, three bagged at
  0/50/100%) to preview layout/warnings without needing real shields in
  that state. `Core/Scan.lua:ScanShields()` substitutes this data
  entirely when `SW.opt.demoMode` is set, so every downstream consumer
  (sort, layout, glow, `/shs dump`) works unchanged - the demo entries
  just carry a `demo = true` flag that suppresses the real-item-only
  parts (equip attribute, `SetBagItem`/`SetInventoryItem` tooltip).

## 0.1.4 - 2026-08-27

- Changed: bag shields sort alphabetically by name now, not by durability.
  (First pass just fixed the tiebreak - durability primary, name for ties -
  but ties were the common case anyway since bag items don't take damage,
  so per feedback the whole ordering is simpler as name-first.) Durability
  still shows on each icon, it just doesn't drive order anymore. guid still
  tiebreaks two genuinely identical shields (same name) so that pair
  doesn't flip-flop between refreshes; itemID is the last-resort fallback
  if guid is unavailable.

## 0.1.3 - 2026-08-27

- Reworked combat handling and the whole equipped-shield display after the
  guid-tracking fix below turned out not to fully resolve the combat
  swap-position bug (diagnosed via matched dump+screenshot pairs: a single
  equip fires several events in quick succession as WoW's bag-cascade
  settles - confirmed via `/shs dump`, three items moved from one equip in
  testing - and patching cosmetics in place on every one of those risked
  painting a partially-settled intermediate state). Reassigning which
  shield is on which icon now has exactly one path - it requires secure
  attribute changes and repositioning, both blocked by
  `InCombatLockdown()`, so it only happens out of combat and freezes
  otherwise, catching up the instant combat ends. Durability numbers still
  update live in combat, just via something much simpler than the earlier
  guid-tracking attempt: reading/displaying data was never the protected
  part (a tooltip hover shows live durability in combat with zero special
  handling), so each icon just re-reads whatever's actually in its
  already-assigned bag/slot right now - no identity tracking across a
  location change, so no swap-position bug to have. The equipped shield no
  longer needs the gold highlight box to mark it either - it's now always
  the first icon, with a visual gap before the bag grid, so position alone
  tells you which one is equipped.
- Fixed: right-click-to-equip via `type="item"` couldn't reliably target a
  specific shield when you owned two genuinely identical ones (same
  itemID) - `SECURE_ACTIONS.item` (traced in `~/ws/wow-ui-source`) always
  calls `C_Item.EquipItemByName(name)` using just the item's link for an
  equippable/unworn item, discarding bag/slot entirely. Two duplicates
  have byte-identical links (no uniqueID component), so it couldn't tell
  them apart and grabbed whichever instance it found, regardless of which
  icon was clicked. Switched to `type="macro"` with `/use <bag> <slot>`,
  which targets the container slot directly through WoW's real
  macro-command interpreter - unambiguous even for exact duplicates.
- Fixed: 0.1.2's initial secure-button attempt didn't survive combat
  after all - traced the actual dispatch chain in
  `SecureTemplates.lua` and switched equip to right-click specifically
  (`type2`/`macrotext2`) with `useOnKeyDown` set explicitly, so it can't
  race the left-click drag-to-move gesture.
- Only loads for Warrior/Paladin/Shaman now - the only classes that can
  equip a shield in Classic Era/SoD.
- The grid only shows once you own 2+ shields total (worn + bagged) -
  nothing to display with 0 or 1.
- Fixed: equipping a shield in combat made icons appear to swap places
  while the gold box stayed put. The combat-time cosmetic refresh matched
  buttons back to fresh shield data by kind+location (bag/slot or
  invSlot), but equipping moves an item from a bag slot to the equip slot
  and moves whatever was worn into a bag slot (often the exact slot just
  vacated) - so the button that used to be "the equipped slot" picked up
  whichever item is equipped now, and the button that vacated its bag slot
  picked up whatever landed there. Now matches by each shield's guid (the
  same stable per-physical-item identity used for sorting), which doesn't
  change when an item moves between a bag and the equip slot - every
  button keeps showing the same physical shield throughout combat, and
  only the gold box (recomputed from whichever guid is currently equipped)
  moves.

## 0.1.2 - 2026-08-27

- Fixed: clicking an icon to equip it while in combat picked the item up
  onto the cursor instead of equipping it. A plain (insecure) button
  calling `UseContainerItem()` can't complete a protected equip action
  during combat lockdown, so the game silently falls back to a pickup -
  the same reason action bars use secure buttons. Icons are now real
  secure action buttons (`type="item"`), same mechanism action bars use,
  so the click itself is protected and survives combat.

  Tradeoff: secure attributes and repositioning can't be changed by
  insecure code while in combat, so the grid now freezes (which shield is
  on which icon) for the duration of combat and only reassigns once combat
  ends (`PLAYER_REGEN_ENABLED`). Durability numbers/colors still update
  live in combat - those are plain cosmetic changes, not attribute or
  structural ones, so they're unaffected.

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
