# frozen_string_literal: true

require_relative "telegram_support_bot/version"
require_relative 'telegram_support_bot/configuration'
require_relative 'telegram_support_bot/auto_away_scheduler'
require_relative 'telegram_support_bot/adapter_factory'
require_relative 'telegram_support_bot/adapters/base'
require_relative 'telegram_support_bot/adapters/telegram_bot'
require_relative 'telegram_support_bot/adapters/telegram_bot_ruby'

module TelegramSupportBot
  class << self
    attr_accessor :configuration
    attr_reader :message_chat_id

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

    def scheduler
      @scheduler ||= AutoAwayScheduler.new(adapter, configuration)
    end

    def process_update(update)
      # Handle different types of updates
      if update['message']
        # Process standard messages
        process_message(update['message'])
      elsif update['my_chat_member']
        # Handle the bot being added to or removed from a chat
        handle_my_chat_member_update(update['my_chat_member'])
        # Add other update types as needed
      else
        # Log or handle unknown update types
        puts "Received an unknown type of update: #{update}"
      end
    end

    private

    def process_message(message)
      @message_chat_id = message['chat']['id']
      ap message

      if message_chat_id == configuration.support_chat_id
        process_support_chat_message(message)
      else
        # Message is from an individual user, forward it to the support chat
        if message['text'] == '/start'
          # Send welcome message to the user
          adapter.send_message(chat_id: message_chat_id, text: configuration.welcome_message)
        else
          forward_message_to_support_chat(message)
        end
      end
    end

    def process_support_chat_message(message)
      if message.key?('reply_to_message')
        # It's a reply in the support chat
        process_reply_in_support_chat(message)
      elsif message['text']&.start_with?('/')
        process_command(message)
      else
        # For non-command messages, you might want to handle differently or just ignore
        # For now, let's just acknowledge the message
        acknowledge_non_command_message(message)
      end
    end

    def acknowledge_non_command_message(message)
      reply_message = 'I received your message, but I only respond to commands. Please use /start to get started.'
      adapter.send_message(
        chat_id:             message_chat_id,
        text:                reply_message,
        reply_to_message_id: message['message_id']
      )
    end

    def process_command(message)
      command = message['text'].split(/[ \@]/).first.downcase # Extract the command, normalize to lowercase

      case command
      when '/start'
        send_welcome_message(chat_id: message_chat_id)
      else
        # Respond to unknown commands
        unknown_command_response = "I don't know the command #{command}. Please use /start to begin or check the available commands."
        adapter.send_message(chat_id: message_chat_id, text: unknown_command_response)
      end
    end

    def process_reply_in_support_chat(message)
      reply_to_message = message['reply_to_message']

      if reply_to_message.key?('forward_from')
        # The reply is to a forwarded message
        original_user_id = reply_to_message['forward_from']['id']
        caption          = message['caption'] if message.key?('caption')

        # Determine the type of media and prepare the content and options
        type, media, options = extract_media_info(message)
        options[:caption]    = caption if caption

        message_id = message['message_id']
        if :unknown == type
          # Handle other types of messages or default case
          warning_message = "Warning: The message type received from the user is not supported by the bot. Please assist the user directly."
          adapter.send_message(
            chat_id:             configuration.support_chat_id,
            text:                warning_message,
            reply_to_message_id: message_id
          )
        else
          adapter.send_media(chat_id: original_user_id, type: type, media: media, **options)
          # scheduler.cancel_scheduled_task(message_id)
        end
      end
    end

    def extract_media_info(message)
      if message.key?('text')
        [:text, message['text'], { entities: message.fetch('entities', []) }]
      elsif message.key?('photo')
        photo = message['photo'].last # Assuming you want to send the highest quality photo
        [:photo, photo['file_id'], {}]
      elsif message.key?('video')
        [:video, message['video']['file_id'], {}]
      elsif message.key?('video_note')
        [:video, message['video_note']['file_id'], {}]
      elsif message.key?('document')
        [:document, message['document']['file_id'], {}]
      elsif message.key?('audio')
        [:audio, message['audio']['file_id'], {
          duration:  message['audio'].fetch('duration', 0),
          performer: message['audio'].fetch('performer', ''),
          title:     message['audio'].fetch('title', '')
        }]
      elsif message.key?('voice')
        [:voice, message['voice']['file_id'], {}]
      elsif message.key?('sticker')
        [:sticker, message['sticker']['file_id'], {}]
      else
        [:unknown, "This type of message is not supported.", {}]
      end
    end

    def forward_message_to_support_chat(message)
      message_id = message['message_id']
      adapter.forward_message(
        from_chat_id: message_chat_id,
        message_id:   message_id,
        chat_id:      configuration.support_chat_id)
      # scheduler.schedule_auto_away_message(message_id, message_chat_id)
    end

    def handle_my_chat_member_update(update)
      # Check if the bot has been added to the chat
      if update['new_chat_member']
        chat_id = update['chat']['id']
        send_welcome_message(chat_id: chat_id)
      end
    end

    def send_welcome_message(chat_id:)
      welcome_text = "Hello! Thank you for adding me to your chat. To configure your system, please use the following support chat ID: <code>#{chat_id}</code>."
      adapter.send_message(chat_id: chat_id, text: welcome_text, parse_mode: 'HTML')
    end

  end

  # Reset the adapter instance (useful for testing or reconfiguration).
  def self.reset_adapter!
    @adapter = nil
  end
end

