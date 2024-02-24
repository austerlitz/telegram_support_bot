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

    def process_update(update)
      message         = update['message']
      message_chat_id = message['chat']['id']
      ap update

      if message_chat_id == configuration.support_chat_id && message.key?('reply_to_message')
        # It's a reply in the support chat
        reply_to_message = message['reply_to_message']

        if reply_to_message.key?('forward_from')
          # The reply is to a forwarded message
          original_user_id = reply_to_message['forward_from']['id']

          # Determine the type of message and act accordingly
          case
          when message.key?('text')
            # Support replied with text
            adapter.send_message(chat_id: original_user_id, text: message['text'], entities: message['entities'])

          when message.key?('photo')
            # Support replied with a photo
            photo   = message['photo'].last # Assuming you want to send the highest quality photo
            caption = message['caption'] if message.key?('caption')
            adapter.send_photo(chat_id: original_user_id, photo: photo['file_id'], caption: caption)

          when message.key?('video')
            # Support replied with a video
            video   = message['video']
            caption = message['caption'] if message.key?('caption')
            adapter.send_video(chat_id: original_user_id, video: video['file_id'], caption: caption)

          when message.key?('document')
            # Support replied with a document
            document = message['document']
            caption  = message['caption'] if message.key?('caption')
            adapter.send_document(
              chat_id: original_user_id, document: document['file_id'], caption: caption
            )

            # Add more cases as necessary for other media types

          else
            # Handle other types of messages or default case
            warning_message = "Warning: The message type received from the user is not supported by the bot. Please assist the user directly."
            adapter.send_message(
              chat_id:             configuration.support_chat_id,
              text:                warning_message,
              reply_to_message_id: message['message_id'] # Reply to the specific message in the support chat
            )
          end
        end
      elsif message_chat_id != configuration.support_chat_id
        # Message is from an individual user, forward it to the support chat
        adapter.forward_message(
          from_chat_id: message_chat_id,
          message_id:   message['message_id'],
          chat_id:      configuration.support_chat_id)
      end
    end

  end

  # Reset the adapter instance (useful for testing or reconfiguration).
  def self.reset_adapter!
    @adapter = nil
  end
end

