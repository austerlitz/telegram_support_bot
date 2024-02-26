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


## Development

- Run `bin/setup` to install dependencies.
- Use `rake spec` for tests and `bin/console` for an interactive prompt.
- To install locally, use `bundle exec rake install`.
- For releases, update `version.rb`, and run `bundle exec rake release`.

## Contributing

Contributions are welcome via GitHub, adhering to
the [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).

## License

Available under the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Follow the
project's [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).
