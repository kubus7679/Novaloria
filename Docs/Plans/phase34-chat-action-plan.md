# Phase 34: Chat Action MVP Plan

## Goal

Close another lightweight action/UI gap by adding support for sending `chat` messages from the Swift client.

## Scope

- [x] Add `sendChatMessage(message:privateRecipientId:)` action in `GameState` to send `chat` with `sender`, `message`, and optional `private`.
- [x] Expose in-game UI affordances in `GameView` for chat text and optional private recipient id.
- [x] Add CLI integration regression to verify outgoing `chat` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`
