# Phase 40: NewRegionName Action MVP

## Objective

Enable players to name newly discovered regions when their units explore new areas.

## Implementation Summary

- [x] Verified `NewRegionNameMessage` is in MessageRegistry (auto-generated from Java protocol)
- [x] Implemented `nameNewRegionWithSelectedUnit(regionId:tileId:regionName:)` action in `GameState`
- [x] Added `canNameNewRegionWithSelectedUnit` guard property
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] All tests pass (79 CLI tests, 11 unit tests)

## Technical Details

### Protocol Message

**Tag:** `newRegionName`

**Attributes:**
- `unit` (String): Unit ID discovering the region
- `region` (String): Region ID being named
- `tile` (String): Tile ID where the region is discovered
- `newRegionName` (String): Name to assign to the new region (trimmed, non-empty)

### GameState Changes

Added two new methods:
1. `nameNewRegionWithSelectedUnit(regionId:tileId:regionName:)` — sends the action with validation
2. `canNameNewRegionWithSelectedUnit: Bool` — validates unit is owned by local player

### Testing

- Unit test validates message encoding/decoding with realistic region names and IDs
- Integration test confirms client sends all 4 attributes (unit + region + tile + name) to mock server
- Input validation: trims whitespace, rejects empty names
- Validates region and tile IDs are non-empty
- All 79 CLI tests pass (including new newRegionName tests)
- All 11 unit tests pass

## Validation Status

✅ `swift build --target Novaloria` — Success
✅ `swift run FreeColProtocolCLI` — 79 passed, 0 failed  
✅ `swift test` — 11 tests, 0 failures

## Gameplay

When a unit discovers a new region during exploration:
- Server sends a `newRegionName` question/event to the client
- Player submits a name via game UI dialog
- Action validates all parameters:
  - Name is non-empty (after trimming)
  - Region ID is provided
  - Tile ID is provided
- Server applies the name to the region
- Future discoveries in that region reference the named region

## Key Differences from Phase 39 (NewLandName)

- **NewLandName** → Names entire **lands/continents** (broader geographic feature)
- **NewRegionName** → Names specific **regions** within a land (more granular, requires region + tile IDs)
- NewRegionName has 2 additional required attributes (region + tile)

## Next Steps

1. Add UI dialog for region naming when server triggers this action
2. Implement server-side region naming via Update message handler
3. Test against real Java server with actual region discovery mechanics
4. Consider diplo/trade route UI enhancements that reference region names

## Notes

- Both region ID and tile ID are validated as non-empty
- Name input is trimmed of whitespace for consistency
- Server validates that the unit is eligible to name the region
- The action follows standard AttributeMessage pattern (no child elements)
