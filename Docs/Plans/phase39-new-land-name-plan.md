# Phase 39: NewLandName Action MVP

## Objective

Enable players to name newly discovered lands when their units reach new continents.

## Implementation Summary

- [x] Verified `NewLandNameMessage` is in MessageRegistry (auto-generated from Java protocol)
- [x] Implemented `nameNewLandWithSelectedUnit(name:)` action in `GameState`
- [x] Added `canNameNewLandWithSelectedUnit` guard property
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] All tests pass (77 CLI tests, 11 unit tests)

## Technical Details

### Protocol Message

**Tag:** `newLandName`

**Attributes:**
- `unit` (String): Unit ID that discovered the land (typically a caravel or ship)
- `newLandName` (String): Name to assign to the new land (trimmed, non-empty)

### GameState Changes

Added two new methods:
1. `nameNewLandWithSelectedUnit(_ landName: String)` — sends the action to server with validated name
2. `canNameNewLandWithSelectedUnit: Bool` — validates unit is owned by local player

### Testing

- Unit test validates message encoding/decoding with realistic land names ("New Amsterdam", "Nova Terra")
- Integration test confirms client sends correct attributes (unit + name) to mock server
- Input validation: trims whitespace and rejects empty names
- All 77 CLI tests pass (including new newLandName tests)
- All 11 unit tests pass

## Validation Status

✅ `swift build --target FreeColApp` — Success  
✅ `swift run FreeColProtocolCLI` — 77 passed, 0 failed  
✅ `swift test` — 11 tests, 0 failures

## Gameplay

When a unit (typically a caravel or explorer) reaches a new continent:
- Server sends a `newLandName` question/event to the client
- Player submits a name via game UI
- Action validates name is non-empty (after trimming)
- Server applies the name to the new region/land
- Future tiles in that region reference the named land

## Next Steps

1. Add UI dialog for land naming when server triggers this action
2. Implement server-side land naming via Update message handler
3. Test against real Java server with actual new continent discovery
4. Consider similar Phase 40: NewRegionName for region-level naming

## Notes

- Name input is trimmed of whitespace for consistency
- Server validates that the unit is eligible to name land (typically on first discovery)
- The action follows standard AttributeMessage pattern (no child elements)
- Can be triggered multiple times for different discoveries by same player
