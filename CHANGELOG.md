# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.10] - 2026-02-25

### Added
- Multi-bot runtime support in one process with keyed configuration and processing:
  `configure(:bot_key)` and `process_update(update, bot: :bot_key)`.
- Bot-scoped adapter/state-store/scheduler instances to isolate mappings, reactions, and user profiles per bot key.
- Redis state namespace isolation for non-default bot keys.
- Multi-bot isolation test coverage for message mappings, support chat routing, contact profiles, and Redis namespaces.

### Changed
- Backward compatibility preserved: no-arg `configure` and `process_update` continue using `:default`.
- Development dependency resolution now has Ruby-version-aware constraints for older runtimes.

## [0.1.09] - 2026-02-13

### Added
- Configurable support-chat non-command behavior:
  `ignore_non_command_messages` (default `true`) and
  `non_command_message_response` for optional acknowledgement text.

## [0.1.08] - 2026-02-13

### Added
- Optional one-time contact sharing flow for user identification:
  `request_contact_on_start`, `require_contact_for_support`, custom contact messages, and
  `on_contact_received` callback.
- In-memory user profile storage and lookup via `TelegramSupportBot.user_profile(chat_id)`.
- Configurable state-store backend with Redis support for multi-pod deployments
  (`state_store`, `state_store_options`, and state TTL settings).

### Changed
- Support reply routing now uses internal message mapping first, with `forward_from` as fallback.
  This removes the dependency on user forwarding privacy settings for normal reply flows.
- Message processing no longer relies on shared `@message_chat_id`, reducing thread-safety risks.

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
