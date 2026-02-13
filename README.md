# TelegramSupportBot

## Introduction

`TelegramSupportBot` is a Ruby gem designed to enhance customer support through Telegram, allowing
for the management of queries directly from a designated chat while ensuring privacy and
confidentiality.

## Features

- Forward messages between users and a support chat
- Supports various message types (text, images, videos, documents, audio, stickers)
- Auto-away messages for off-hours
- Simple configuration and deployment

## Installation

Add to your Gemfile:

```ruby
gem 'telegram-support-bot'
```

## Usage

### Creating and Configuring Your Bot

1. **Create Your Bot** via BotFather on Telegram to get your bot token.
2. **Deploy Your Application** and set up a controller action for webhook callbacks, directing them
   to `TelegramSupportBot.process_update`.
3. **Set the Webhook URL** using the Telegram Bot API to your controller action.

### Setting Up Your Telegram Bot

1. **Add Your Bot to a Support Chat** and obtain the `support_chat_id` by sending the `/start`
   command to the bot inside the support chat.
2. **Configure Your Bot** in your Ruby application with the token and `support_chat_id`, and set a
   welcome message.

```ruby
TelegramSupportBot.configure do |config|
  config.adapter         = :telegram_bot
  config.adapter_options = { token: 'YOUR_TELEGRAM_BOT_TOKEN' }
  config.support_chat_id = 'YOUR_SUPPORT_CHAT_ID'
  config.welcome_message = 'Hi! How can we help you?'
  # Optional: ask users to share their phone once for account lookup.
  config.request_contact_on_start = true
  # Optional: block forwarding until contact is shared.
  config.require_contact_for_support = false
  # Optional callback to persist/lookup user profile in your app.
  config.on_contact_received = ->(profile) { YourUserMatcher.sync_from_telegram(profile) }
  # Recommended in Kubernetes/multi-pod setup:
  # config.state_store = :redis
  # config.state_store_options = { url: ENV.fetch('REDIS_URL'), namespace: 'telegram_support_bot' }
end
```

3. **Interact with Users**: Messages to your bot will be forwarded to the support chat, and replies
   in the chat will be sent back to the users.

## Adapters

`TelegramSupportBot` supports integration through adapters. Currently, `telegram-bot`
and `telegram-bot-ruby` are supported.

Configuration is pretty much the same for both gems:

```ruby
TelegramSupportBot.configure do |config|
  config.adapter         = :telegram_bot
  config.adapter_options = { token: 'YOUR_TELEGRAM_BOT_TOKEN' }
end
```

```ruby
TelegramSupportBot.configure do |config|
  config.adapter         = :telegram_bot_ruby
  config.adapter_options = { token: 'YOUR_TELEGRAM_BOT_TOKEN' }
end
```

## Examples

**Basically, just make sure you call `TelegramSupportBot.process_update` somewhere in you workflow
cycle and pass it a parsed json update received from Telegram servers.**

### Using `telegram-bot` Gem with a Webhook Controller

If you're using the `telegram-bot` gem, set up a Rails controller to handle incoming webhook
requests. Here's an example of how you might implement such a controller:

```ruby

class TelegramWebhooksController < ApplicationController

  def webhook
    update = JSON.parse(request.body.read)
    TelegramSupportBot.process_update(update)
    head :ok
  end
end
```

Make sure to configure your routes to direct webhook callbacks to this controller action.

### Using `telegram-bot-ruby` Gem with bot.listen

For those utilizing telegram-bot-ruby, you can set up a simple listener loop to process incoming
messages. This approach is more suited for polling rather than webhooks:
require 'telegram/bot'

```ruby
token = 'YOUR_TELEGRAM_BOT_TOKEN'

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    TelegramSupportBot.process_update(update.to_h)
  end
end
```

## Custom Adapter Implementation

Implement custom adapters by inheriting from `TelegramSupportBot::Adapter::Base` and defining
message sending and forwarding methods.

## User Identification With Phone Sharing

If you want support agents to identify users quickly in your CRM, you can request phone sharing once:

```ruby
TelegramSupportBot.configure do |config|
  config.request_contact_on_start = true
  config.require_contact_for_support = false
  config.contact_request_message = 'Please share your phone number so we can identify your account.'
  config.contact_received_message = 'Thanks! We have saved your phone number.'
  config.on_contact_received = ->(profile) do
    # profile keys:
    # :chat_id, :user_id, :phone_number, :first_name, :last_name, :username, :language_code
    UserIdentitySync.call(profile)
  end
end
```

If you set `require_contact_for_support = true`, the bot will ask for contact and will not forward
other user messages until contact is shared.

Support replies are routed by internal message mapping, so users do not need to change Telegram
forwarding privacy settings to receive replies.

## State Storage (Single Pod vs Multi-Pod)

By default, runtime state is stored in-memory (`state_store = :memory`). This is fine for local
development or a single process.

For Kubernetes / multiple pods, configure Redis so message mappings, reaction state, and user
profiles are shared:

```ruby
TelegramSupportBot.configure do |config|
  config.state_store = :redis
  config.state_store_options = {
    url: ENV.fetch('REDIS_URL'),
    namespace: 'telegram_support_bot'
  }
  # Optional TTL tuning:
  # config.mapping_ttl_seconds = 30 * 24 * 60 * 60
  # config.reaction_count_ttl_seconds = 7 * 24 * 60 * 60
  # config.user_profile_ttl_seconds = nil
end
```

## Development

- Run `bin/setup` to install dependencies.
- Use `rake spec` for tests and `bin/console` for an interactive prompt.
- To install locally, use `bundle exec rake install`.
- For releases, update `lib/telegram_support_bot/version.rb` and `CHANGELOG.md`, then run `bundle exec rake release`.

### Local Testing Without Rails (Polling)

You can run the bot locally without a Rails app by using the included script:

Prerequisites:
- Add the bot as an **administrator** in the support chat if you want support-side reactions to be delivered as updates.
- Bots can set only one reaction per message via Bot API, so only one mirrored reaction is applied when multiple are present.

1. Export required environment variables:

```bash
export TELEGRAM_BOT_TOKEN=your_bot_token
export SUPPORT_CHAT_ID=your_support_chat_id
# optional; defaults to telegram_bot
export TSB_ADAPTER=telegram_bot
# optional; used by telegram_bot adapter
export TELEGRAM_BOT_USERNAME=your_bot_username
```

2. Disable webhook mode for that bot token (polling and webhooks cannot be used together):

```bash
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/deleteWebhook" > /dev/null
```

3. Start the local poller:

```bash
bundle exec ruby script/dev_poll.rb
```

4. In Telegram, verify:
- user message is forwarded to support chat
- support reply is sent back to user
- reactions are mirrored in both directions

If you want to test with `telegram_bot_ruby` adapter, set `TSB_ADAPTER=telegram_bot_ruby` and add
the `telegram-bot-ruby` gem in your environment.

### Switch Back To Webhook Mode

After polling tests, set your webhook again:

```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://YOUR_PUBLIC_HOST/telegram/webhook","allowed_updates":["message","message_reaction","message_reaction_count","my_chat_member"]}'
```

## Contributing

Contributions are welcome via GitHub, adhering to
the [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).

## License

Available under the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Follow the
project's [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).
