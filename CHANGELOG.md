# Changelog

All notable changes to this project will be documented in this file.

## [0.1.07] - 2026-02-13

### Added
- Mirroring of `message_reaction` updates between support chat and user chats.
- Message mapping storage (`message_map` and `reverse_message_map`) to correlate forwarded/replied messages for reaction sync.
- Adapter API method `set_message_reaction` with implementations for both supported adapters.
- Test coverage for reaction handling and adapter reaction calls.
- Local polling helper script for development testing without Rails (`script/dev_poll.rb`).
- README documentation for local development testing workflow.

### Fixed
- Local polling script now uses the proper polling call for `telegram-bot` gem (`get_updates`) and supports multiple client styles.
- Reaction mapping now correctly handles wrapped Telegram API responses (`{ "ok": true, "result": ... }`).
- Reaction mirroring now gracefully handles `REACTIONS_TOO_MANY` by retrying with a single reaction instead of crashing.
- Reaction mapping lookup now tolerates chat/message ID type mismatches (string vs integer).
- Added optional reaction-flow debug logs via `TSB_DEBUG=1`.
- Support-chat reaction mirroring now also handles `message_reaction_count` updates (anonymous reaction counts).
