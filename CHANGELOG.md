# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.15] - 2026-02-26

### Added
- Optional `forward_start_to_support` configuration to forward the first user `/start`
  message to support chat, so the team can proactively start the conversation.
- Update-level deduplication by Telegram `update_id` to prevent repeated replies/forwards
  when webhook deliveries are retried.

### Fixed
- Initial `/start` forwarding is now fail-safe: errors in forwarding/persisting first-message
  marker no longer crash update processing and block subsequent updates.
- Redis-backed marker storage for update/start dedup now writes JSON objects (not scalar booleans),
  fixing `JSON::GeneratorError: only generation of JSON objects or arrays allowed` on stricter runtimes.

## [0.1.12] - 2026-02-26

### Fixed
- `my_chat_member` onboarding message with support chat ID is no longer sent for private chats.
- Support-chat onboarding message is now emitted only when the bot is newly added to a non-private chat.

## [0.1.11] - 2026-02-25

### Added
- Optional host callback `on_user_command` for user-chat commands other than `/start`.
  Return `true` to mark a command as handled and skip forwarding to support chat.

### Fixed
- User-chat `/start` detection now recognizes deep-link command forms and bot mentions:
  `/start`, `/start <payload>`, `/start@botname`, `/start@botname <payload>`.
- Start commands in user chats continue to run welcome/contact onboarding and are not forwarded to the support chat.

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
