# Phase 38: LearnSkill Action MVP

## Objective

Enable units to learn skills from Native Settlements by moving adjacent and initiating the learn action.

## Implementation Summary

- [x] Verified `LearnSkillMessage` is in MessageRegistry (auto-generated from Java protocol)
- [x] Implemented `learnSkillAtSelectedUnit(direction:)` action in `GameState`
- [x] Added `canLearnSkillAtSelectedUnit` guard property
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] All tests pass (75 CLI tests, 11 unit tests)

## Technical Details

### Protocol Message

**Tag:** `learnSkill`

**Attributes:**
- `unit` (String): Unit ID learning the skill
- `direction` (String): Direction to the Native Settlement (N, NE, E, SE, S, SW, W, NW)

### GameState Changes

Added two new methods:
1. `learnSkillAtSelectedUnit(direction: String)` — sends the action to server
2. `canLearnSkillAtSelectedUnit: Bool` — validates unit is active with moves remaining

### Testing

- Unit test validates message encoding/decoding with multiple direction scenarios (NE, S)
- Integration test confirms client sends correct attributes (unit + direction) to mock server
- All 75 CLI tests pass (including new learnSkill tests)
- All 11 unit tests pass

## Validation Status

✅ `swift build --target Novaloria` — Success
✅ `swift run FreeColProtocolCLI` — 75 passed, 0 failed  
✅ `swift test` — 11 tests, 0 failures

## Gameplay

Units (especially Colonists) can now learn skills from adjacent Native Settlements:
- Requires unit to be **active** with **moves left > 0**
- Direction must be one of the 8 cardinal directions
- Server validates that direction points to a settlement and that learning is possible
- Skills improve unit productivity (e.g., expert farmer, expert builder)

## Next Steps

1. Add UI affordances in GameView for direction selection when learning skills
2. Implement server-side skill application via Update message handler
3. Test against real Java server with actual Native Settlement interactions

## Notes

- Direction calculation uses the same hex-based direction mapping as movement/combat
- Game model updates for learned skills will be applied via Update messages from server
- The action follows standard AttributeMessage pattern (no child elements)
