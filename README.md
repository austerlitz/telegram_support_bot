# TelegramSupportBot

## Introduction
`TelegramSupportBot` is a Ruby gem designed to enhance customer support through Telegram, allowing for the management of queries directly from a designated chat while ensuring privacy and confidentiality.

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
### Webhook Integration

#### Creating and Configuring Your Bot
1. **Create Your Bot** via BotFather on Telegram to get your bot token.
2. **Deploy Your Application** and set up a controller action for webhook callbacks, directing them to `TelegramSupportBot.process_update`.
3. **Set the Webhook URL** using the Telegram Bot API to your controller action.

#### Setting Up Your Telegram Bot
1. **Add Your Bot to a Support Chat** and obtain the `support_chat_id` by sending the `/start` command to the bot inside the support chat.
2. **Configure Your Bot** in your Ruby application with the token and `support_chat_id`, and set a welcome message.

```ruby
TelegramSupportBot.configure do |config|
  config.adapter = :telegram_bot
  config.adapter_options = { token: 'YOUR_TELEGRAM_BOT_TOKEN' }
  config.support_chat_id = 'YOUR_SUPPORT_CHAT_ID'
  config.welcome_message = 'Hi! How can we help you?'
end
```

3. **Interact with Users**: Messages to your bot will be forwarded to the support chat, and replies in the chat will be sent back to the users.

### Adapters
`TelegramSupportBot` supports integration through adapters. Currently, `telegram-bot` is supported with plans to add `telegram-bot-ruby`.

#### Custom Adapter Implementation
Implement custom adapters by inheriting from `TelegramSupportBot::Adapter::Base` and defining message sending and forwarding methods.

## Development
- Run `bin/setup` to install dependencies.
- Use `rake spec` for tests and `bin/console` for an interactive prompt.
- To install locally, use `bundle exec rake install`.
- For releases, update `version.rb`, and run `bundle exec rake release`.

## Contributing
Contributions are welcome via GitHub, adhering to the [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).

## License
Available under the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct
Follow the project's [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).
