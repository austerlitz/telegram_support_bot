# frozen_string_literal: true

require_relative "telegram_support_bot/version"
require_relative 'telegram_support_bot/configuration'
require_relative 'telegram_support_bot/adapter_factory'
require_relative 'telegram_support_bot/adapters/base_adapter'
require_relative 'telegram_support_bot/adapters/telegram_bot_adapter'
require_relative 'telegram_support_bot/adapters/telegram_bot_ruby_adapter'

module TelegramSupportBot
  class << self
    attr_accessor :configuration

    # Provides a method to configure the gem.
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    # Lazily builds and returns the adapter based on the current configuration.
    # This method initializes the adapter when it's first called.
    def adapter
      @adapter ||= AdapterFactory.build(configuration.adapter, configuration.adapter_options)
    end

    def process_update(update, &block)
      # Shared processing logic here
      puts "Processing update:"
      ap update

      message         = update['message']
      message_chat_id = message['chat']['id']
      message_text    = message['text']

      if message_chat_id == configuration.support_chat_id.to_i

        adapter.send_message(chat_id: message_chat_id, text: 'Test OK')
        if message.key?('reply_to_message')
          # It's a reply in the support chat
          reply_to_message = message['reply_to_message']

          if reply_to_message.key?('forward_from')
            # The reply is to a forwarded message
            original_user_id = reply_to_message['forward_from']['id']
            reply_text       = "Support says: #{message_text}"

            # Send a message back to the original user
            adapter.send_message(chat_id: original_user_id, text: reply_text)
          else
            # It's a reply but not to a forwarded message; handle accordingly
          end
        end

      else
        # Message is from an individual user, forward it to the support chat
        adapter.forward_message(
          from_chat_id: message_chat_id,
          message_id:   update['message']['message_id'],
          chat_id:      configuration.support_chat_id
        )
      end
      # If a block is given, yield to it for customization
      yield(update) if block_given?

      # Delegate to the adapter for any specific handling
      # adapter.process_specific_update(update)
    end
  end

  # Reset the adapter instance (useful for testing or reconfiguration).
  def self.reset_adapter!
    @adapter = nil
  end
end

