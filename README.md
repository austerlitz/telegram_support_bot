# TelegramSupportBot

## Introduction
`TelegramSupportBot` is a Ruby gem designed to facilitate customer support through Telegram. It allows businesses and support teams to manage customer queries directly from a designated Telegram chat, forwarding messages to and from users anonymously to maintain privacy and confidentiality.

## Features
- Forward messages from users to a support chat
- Reply to users directly from the support chat
- Supports text, images, videos, documents, audio, and stickers
- Auto-away messages for when support is not immediately available
- Easy to configure and deploy

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'telegram_support_bot'
```



# TelegramSupportBot

TODO: Delete this and the text below, and describe your gem

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/telegram_support_bot`. To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

### Setting Up Your Telegram Bot

1. **Creating Your Bot:**
  - Start a chat with [BotFather](https://t.me/botfather) on Telegram.
  - Use the `/newbot` command and follow the instructions to create your bot. You will receive a token to access the Telegram Bot API.
  - Take note of your new bot's username.

2. **Adding Your Bot to a Support Chat:**
  - Create a new group chat on Telegram. This will serve as your support chat.
  - Add your bot to this group chat by searching for the bot's username and inviting it to the group.

3. **Obtaining the `support_chat_id`:**
  - Send a message to the support chat.
  - Use the `getUpdates` method from the Telegram Bot API to retrieve details about new messages. You can do this by visiting the following URL in your web browser: `https://api.telegram.org/bot<YourBotToken>/getUpdates`
  - Look for the `chat` object in the response. The `id` field within this object is your `support_chat_id`. Note that chat IDs for groups are negative and usually start with a `-`.

4. **Publishing Your Bot to Users:**
  - Share your bot's username or a direct link (e.g., `https://t.me/your_bot_username`) with your users. This allows them to start chatting with your bot.
  - Optionally, you can use the `/setdescription` and `/setuserpic` commands in BotFather to improve your bot's profile with a description and an avatar, making it more appealing to users.

5. **Configuring Your Bot:**
  - In your Ruby application, configure the bot with the token and `support_chat_id` obtained in the previous steps:

```ruby
TelegramSupportBot.configure do |config|
  config.token = 'YOUR_TELEGRAM_BOT_TOKEN'
  config.support_chat_id = 'YOUR_SUPPORT_CHAT_ID' # You'll get this after adding the bot to your support chat
  config.welcome_message = 'Hi! How can we help you?'
end
```
6. **Receiving and Replying to Messages:**
- When a user sends a message to your bot, it will automatically be forwarded to the support chat.
-  To reply to a user, a support agent simply needs to reply to the forwarded message within the support chat. The bot will handle sending this reply back to the user, creating a seamless support experience.

## Adapters

The `TelegramSupportBot` is designed with flexibility in mind, allowing for the integration of various messaging platforms through the use of adapters. While the primary focus is on Telegram, the architecture supports the addition of adapters for other platforms such as Slack, Discord, or custom APIs.

### Implementing Custom Adapters

To implement a custom adapter, follow these steps:

1. **Define Your Adapter Class:**
   Create a new class that inherits from `TelegramSupportBot::Adapter::Base`. This base class provides the necessary groundwork for integrating new messaging platforms.

```ruby
module TelegramSupportBot
  module Adapter
    class YourCustomAdapter < Base
      def send_message(chat_id, text)
        # Implementation for sending a message via your platform
      end

      def forward_message(from_chat_id, message_id, to_chat_id)
        # Implementation for forwarding a message via your platform
      end

      # Add additional methods as required by your platform
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/austerlitz/telegram_support_bot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TelegramSupportBot project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/austerlitz/telegram_support_bot/blob/main/CODE_OF_CONDUCT.md).
