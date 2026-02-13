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

    def message_map
      @message_map ||= {}
    end

    def reverse_message_map
      @reverse_message_map ||= {}
    end

    def reaction_count_state
      @reaction_count_state ||= {}
    end

    def scheduler
      @scheduler ||= AutoAwayScheduler.new(adapter, configuration)
    end

    def process_update(update)
      # Handle different types of updates
      if update['message']
        # Process standard messages
        process_message(update['message'])
      elsif update['message_reaction']
        process_message_reaction(update['message_reaction'])
      elsif update['message_reaction_count']
        process_message_reaction_count(update['message_reaction_count'])
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
        unless configuration.ignore_unknown_commands
          unknown_command_response = "I don't know the command #{command}. Please use /start to begin or check the available commands."
          adapter.send_message(chat_id: message_chat_id, text: unknown_command_response)
        end
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
          result = adapter.send_media(chat_id: original_user_id, type: type, media: media, **options)
          if result
            user_message_id = extract_message_id(result)
            if user_message_id
              support_message_id = message['message_id']
              store_message_mapping(
                support_message_id: support_message_id,
                user_chat_id:       original_user_id,
                user_message_id:    user_message_id
              )
            end
          end
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
      result = adapter.forward_message(
        from_chat_id: message_chat_id,
        message_id:   message_id,
        chat_id:      configuration.support_chat_id)

      if result
        support_message_id = extract_message_id(result)
        if support_message_id
          store_message_mapping(
            support_message_id: support_message_id,
            user_chat_id:       message_chat_id,
            user_message_id:    message_id
          )
        end
      end
      # scheduler.schedule_auto_away_message(message_id, message_chat_id)
    end

    def handle_my_chat_member_update(update)
      # Check if the bot has been added to the chat
      if update['new_chat_member']
        chat_id = update['chat']['id']
        send_welcome_message(chat_id: chat_id)
      end
    end

    def process_message_reaction(message_reaction)
      chat_id = message_reaction['chat']['id']
      message_id = message_reaction['message_id']
      new_reaction = message_reaction['new_reaction']

      if same_chat_id?(chat_id, configuration.support_chat_id)
        # Reaction in support chat, forward to user
        if (mapping = find_message_mapping(message_id))
          debug_log("Support->user mapping hit: support_message_id=#{message_id.inspect} => user_chat_id=#{mapping[:chat_id].inspect}, user_message_id=#{mapping[:message_id].inspect}")
          mirror_reaction(
            chat_id:    mapping[:chat_id],
            message_id: mapping[:message_id],
            reaction:   new_reaction
          )
        else
          debug_log("Missing support->user mapping for support_message_id=#{message_id.inspect}; known_mappings=#{message_map.size}")
        end
      else
        # Reaction in user chat, forward to support chat
        if (support_message_id = reverse_message_map[reverse_mapping_key(chat_id, message_id)])
          debug_log("User->support mapping hit: key=#{reverse_mapping_key(chat_id, message_id)} => support_message_id=#{support_message_id.inspect}")
          mirror_reaction(
            chat_id:    configuration.support_chat_id,
            message_id: support_message_id,
            reaction:   new_reaction
          )
        else
          debug_log("Missing user->support mapping for key=#{reverse_mapping_key(chat_id, message_id)}; known_reverse_mappings=#{reverse_message_map.size}")
        end
      end
    end

    def process_message_reaction_count(message_reaction_count)
      chat_id = message_reaction_count.dig('chat', 'id')
      message_id = message_reaction_count['message_id']

      unless same_chat_id?(chat_id, configuration.support_chat_id)
        debug_log("Ignoring message_reaction_count outside support chat: chat_id=#{chat_id.inspect}")
        return
      end

      mapping = find_message_mapping(message_id)
      unless mapping
        debug_log("Missing support->user mapping for message_reaction_count support_message_id=#{message_id.inspect}; known_mappings=#{message_map.size}")
        return
      end

      state_key = reverse_mapping_key(chat_id, message_id)
      previous_counts = reaction_count_state[state_key] || {}
      current_counts, reaction_types = extract_reaction_counts(message_reaction_count['reactions'])
      reaction_to_mirror = infer_reaction_from_count_diff(
        previous_counts: previous_counts,
        current_counts:  current_counts,
        reaction_types:   reaction_types
      )
      reaction_count_state[state_key] = current_counts

      if reaction_to_mirror.nil?
        debug_log("No actionable reaction diff in message_reaction_count for support_message_id=#{message_id.inspect}")
        return
      end

      debug_log("Support->user inferred reaction from count update: support_message_id=#{message_id.inspect} payload=#{reaction_to_mirror.inspect}")
      mirror_reaction(
        chat_id:    mapping[:chat_id],
        message_id: mapping[:message_id],
        reaction:   reaction_to_mirror
      )
    end

    def mirror_reaction(chat_id:, message_id:, reaction:)
      normalized_reaction = normalize_reaction_payload(reaction)
      debug_log("Mirroring reaction to chat_id=#{chat_id.inspect} message_id=#{message_id.inspect} payload=#{normalized_reaction.inspect}")
      adapter.set_message_reaction(chat_id: chat_id, message_id: message_id, reaction: normalized_reaction)
      debug_log("Reaction mirrored to chat_id=#{chat_id.inspect} message_id=#{message_id.inspect}")
    rescue StandardError => error
      if reaction_too_many_error?(error) && normalized_reaction.size > 1
        begin
          adapter.set_message_reaction(chat_id: chat_id, message_id: message_id, reaction: [normalized_reaction.first])
          debug_log("Reaction mirrored after fallback to single reaction for chat_id=#{chat_id.inspect} message_id=#{message_id.inspect}")
        rescue StandardError => retry_error
          warn_reaction_forwarding_failure(chat_id: chat_id, message_id: message_id, error: retry_error)
        end
      else
        warn_reaction_forwarding_failure(chat_id: chat_id, message_id: message_id, error: error)
      end
    end

    def normalize_reaction_payload(reaction)
      return [] if reaction.nil?
      return reaction if reaction.is_a?(Array)

      [reaction]
    end

    def reaction_too_many_error?(error)
      error.message.to_s.upcase.include?('REACTIONS_TOO_MANY')
    end

    def warn_reaction_forwarding_failure(chat_id:, message_id:, error:)
      warn "Failed to mirror reaction to chat_id=#{chat_id} message_id=#{message_id}: #{error.class}: #{error.message}"
    end

    def extract_reaction_counts(reactions)
      counts = {}
      reaction_types = {}

      Array(reactions).each do |reaction|
        reaction_type = reaction['type'] || reaction[:type]
        next unless reaction_type

        key = reaction_type_key(reaction_type)
        next if key.nil?

        counts[key] = (reaction['total_count'] || reaction[:total_count] || 0).to_i
        reaction_types[key] = reaction_type
      end

      [counts, reaction_types]
    end

    def infer_reaction_from_count_diff(previous_counts:, current_counts:, reaction_types:)
      increments = []
      current_counts.each do |key, current_value|
        previous_value = previous_counts.fetch(key, 0)
        diff = current_value - previous_value
        increments << [key, diff, current_value] if diff.positive?
      end

      if increments.any?
        selected_key = increments.max_by { |(_, diff, current_value)| [diff, current_value] }[0]
        return [reaction_types.fetch(selected_key)]
      end

      removed_all = previous_counts.values.any?(&:positive?) && current_counts.values.all?(&:zero?)
      return [] if removed_all

      nil
    end

    def reaction_type_key(reaction_type)
      type = reaction_type['type'] || reaction_type[:type]

      case type
      when 'emoji', :emoji
        "emoji:#{reaction_type['emoji'] || reaction_type[:emoji]}"
      when 'custom_emoji', :custom_emoji
        "custom_emoji:#{reaction_type['custom_emoji_id'] || reaction_type[:custom_emoji_id]}"
      when 'paid', :paid
        'paid'
      else
        nil
      end
    end

    def store_message_mapping(support_message_id:, user_chat_id:, user_message_id:)
      mapping = { chat_id: user_chat_id, message_id: user_message_id }
      message_map[support_message_id] = mapping
      message_map[support_message_id.to_s] = mapping
      reverse_message_map[reverse_mapping_key(user_chat_id, user_message_id)] = support_message_id
    end

    def find_message_mapping(support_message_id)
      message_map[support_message_id] ||
        message_map[support_message_id.to_s] ||
        message_map[support_message_id.to_i]
    end

    def reverse_mapping_key(chat_id, message_id)
      "#{chat_id}:#{message_id}"
    end

    def same_chat_id?(left, right)
      left == right || left.to_s == right.to_s
    end

    def debug_log(message)
      return unless ENV['TSB_DEBUG'] == '1'

      puts "[TelegramSupportBot DEBUG] #{message}"
    end

    def extract_message_id(result)
      if result.is_a?(Hash)
        return result['message_id'] || result[:message_id] ||
               result.dig('result', 'message_id') || result.dig(:result, :message_id) ||
               result.dig('result', :message_id) || result.dig(:result, 'message_id')
      end

      return result.message_id if result.respond_to?(:message_id)

      nil
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
