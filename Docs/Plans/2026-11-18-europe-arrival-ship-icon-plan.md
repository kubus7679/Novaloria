# Europe Arrival Ship Icon Plan

## Goal
Show the arriving ship's unit graphic for `model.unit.arriveInEurope` event messages instead of the generic colonist icon.

## Change
- Resolve the event message's source unit through the current game model.
- Load its graphic through `TileImageCache.unitImage(forUnitType:)`.
- Leave image selection for other event messages unchanged.

## Verification
- Build the `Novaloria` target with `swift build --target Novaloria`.