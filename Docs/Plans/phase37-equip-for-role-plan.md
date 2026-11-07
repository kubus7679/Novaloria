# Phase 37: EquipForRole Action MVP

## Objective

Enable players to equip units with roles (Missionary, Pioneer, Scout, etc.) during gameplay.

## Implementation Summary

- [x] Generated `EquipForRoleMessage` from Java protocol source via `codegen.py`
- [x] Implemented `equipSelectedUnitForRole(roleId:count:)` action in `GameState`
- [x] Added `canEquipSelectedUnitForRole` guard property
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] Verified message registry includes new message type

## Technical Details

### Protocol Message

**Tag:** `equipForRole`

**Attributes:**
- `unit` (String): Unit ID to equip
- `role` (String): Role ID (e.g., `model.role.missionary`)
- `count` (String): Role count (e.g., "1")

### GameState Changes

Added two new methods:
1. `equipSelectedUnitForRole(_ roleId: String, count: Int)` — sends the action to server
2. `canEquipSelectedUnitForRole: Bool` — guard property for UI availability

### Testing

- Unit test validates message encoding/decoding with multiple role scenarios
- Integration test confirms client sends correct attributes to mock server
- All 73 CLI tests pass (including new equipForRole tests)
- All 11 unit tests pass

## Validation Status

✅ `swift build --target Novaloria` — Success
✅ `swift run FreeColProtocolCLI` — 73 passed, 0 failed  
✅ `swift test` — 11 tests, 0 failures

## Next Steps

1. Add UI controls in GameView or unit detail panel for role selection (Phase 37-UI, optional enhancement)
2. Implement server-side role application handling in Game model (when server sends role update via Update message)
3. Test against real Java server with actual role mechanics validation

## Notes

- The message format follows the standard AttributeMessage pattern with three key-value pairs
- Role IDs are validated server-side; client accepts any role string
- Role count is also server-validated (must be 0-3 depending on role type)
- Game model updates will be applied via Update messages from server, not directly in client logic
