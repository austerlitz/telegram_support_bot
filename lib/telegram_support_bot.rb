# frozen_string_literal: true

require_relative "telegram_support_bot/version"
require_relative 'telegram_support_bot/configuration'
require_relative 'telegram_support_bot/auto_away_scheduler'
require_relative 'telegram_support_bot/adapter_factory'
require_relative 'telegram_support_bot/state_store'
require_relative 'telegram_support_bot/adapters/base'
require_relative 'telegram_support_bot/adapters/telegram_bot'
require_relative 'telegram_support_bot/adapters/telegram_bot_ruby'

module TelegramSupportBot
  DEFAULT_BOT_KEY = :default
  BOT_CONTEXT_THREAD_KEY = :telegram_support_bot_current_bot_key

  class << self
    # Provides a method to configure the gem.
    def configure(bot_key = DEFAULT_BOT_KEY)
      key = normalize_bot_key(bot_key)
      config = configuration(key)
      yield(config) if block_given?
      config
    end

    def configuration(bot_key = nil)
      key = bot_key.nil? ? current_bot_key : normalize_bot_key(bot_key)
      configurations[key] ||= Configuration.new
    end

    def configuration=(config)
      configurations[DEFAULT_BOT_KEY] = config
    end

    # Lazily builds and returns the adapter based on the current configuration.
    # This method initializes the adapter when it's first called.
    def adapter(bot_key = nil)
      key = bot_key.nil? ? current_bot_key : normalize_bot_key(bot_key)
      adapters[key] ||= AdapterFactory.build(configuration(key).adapter, configuration(key).adapter_options)
    end

    def state_store(bot_key = nil)
      key = bot_key.nil? ? current_bot_key : normalize_bot_key(bot_key)
      state_stores[key] ||= StateStore.build(configuration(key), bot_key: key)
    end

    def message_map(bot_key = nil)
      state_store(bot_key).message_map
    end

    def reverse_message_map(bot_key = nil)
      state_store(bot_key).reverse_message_map
    end

    def reaction_count_state(bot_key = nil)
      state_store(bot_key).reaction_count_state
    end

    def user_profiles(bot_key = nil)
      state_store(bot_key).user_profiles
    end

    def user_profile(chat_id, bot: nil)
      profiles = user_profiles(bot)
      profiles[chat_id] || profiles[chat_id.to_s] || profiles[chat_id.to_i]
    end

    def scheduler(bot_key = nil)
      key = bot_key.nil? ? current_bot_key : normalize_bot_key(bot_key)
      schedulers[key] ||= AutoAwayScheduler.new(adapter(key), configuration(key))
    end

    def process_update(update, bot: DEFAULT_BOT_KEY)
      with_bot_context(bot) do
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
    end

    # Reset the adapter instance (useful for testing or reconfiguration).
    def reset_adapter!(bot_key = nil)
      reset_registry!(adapters, bot_key)
    end

    def reset_state_store!(bot_key = nil)
      reset_registry!(state_stores, bot_key)
    end

    def reset_scheduler!(bot_key = nil)
      reset_registry!(schedulers, bot_key)
    end

    def reset_configuration!(bot_key = nil)
      reset_registry!(configurations, bot_key)
    end

    def reset!(bot_key = nil)
      reset_adapter!(bot_key)
      reset_state_store!(bot_key)
      reset_scheduler!(bot_key)
      reset_configuration!(bot_key)
    end

    private

    def configurations
      @configurations ||= {}
    end

    def adapters
      @adapters ||= {}
    end

    def state_stores
      @state_stores ||= {}
    end

    def schedulers
      @schedulers ||= {}
    end

    def current_bot_key
      Thread.current[BOT_CONTEXT_THREAD_KEY] || DEFAULT_BOT_KEY
    end

    def with_bot_context(bot_key)
      normalized_bot_key = normalize_bot_key(bot_key)
      previous_bot_key = Thread.current[BOT_CONTEXT_THREAD_KEY]
      Thread.current[BOT_CONTEXT_THREAD_KEY] = normalized_bot_key
      yield
    ensure
      Thread.current[BOT_CONTEXT_THREAD_KEY] = previous_bot_key
    end

    def normalize_bot_key(bot_key)
      (bot_key || DEFAULT_BOT_KEY).to_sym
    end

    def reset_registry!(registry, bot_key)
      if bot_key.nil?
        registry.clear
      else
        registry.delete(normalize_bot_key(bot_key))
      end
    end

    def process_message(message)
      chat_id = message.dig('chat', 'id')

      if same_chat_id?(chat_id, configuration.support_chat_id)
        process_support_chat_message(message, chat_id: chat_id)
      else
        process_user_chat_message(message, chat_id: chat_id)
      end
    end

    def process_user_chat_message(message, chat_id:)
      if message.key?('contact')
        process_user_contact(message, chat_id: chat_id)
        return
      end

      command_data = parse_command(message['text'])

      if command_data && command_data[:command] == '/start'
        adapter.send_message(chat_id: chat_id, text: configuration.welcome_message)
        request_contact_from_user(chat_id: chat_id) if should_request_contact?(chat_id)
        return
      end

      if command_data && handle_user_command(command_data: command_data, message: message, chat_id: chat_id)
        return
      end

      if configuration.require_contact_for_support && !contact_known_for_user?(chat_id)
        request_contact_from_user(chat_id: chat_id)
        return
      end

      forward_message_to_support_chat(message, chat_id: chat_id)
    end

    def process_user_contact(message, chat_id:)
      contact = message['contact'] || {}

      unless valid_contact_for_chat?(contact: contact, chat_id: chat_id)
        request_contact_from_user(chat_id: chat_id, text: configuration.contact_invalid_message)
        return
      end

      profile = build_contact_profile(chat_id: chat_id, message: message, contact: contact)
      store_user_profile(chat_id: chat_id, profile: profile)
      notify_contact_received(profile)

      adapter.send_message(
        chat_id: chat_id,
        text: configuration.contact_received_message,
        reply_markup: remove_keyboard_markup
      )
    end

    def process_support_chat_message(message, chat_id:)
      if message.key?('reply_to_message')
        # It's a reply in the support chat
        process_reply_in_support_chat(message)
      elsif message['text']&.start_with?('/')
        process_command(message, chat_id: chat_id)
      else
        acknowledge_non_command_message(message, chat_id: chat_id) unless configuration.ignore_non_command_messages
      end
    end

    def acknowledge_non_command_message(message, chat_id:)
      adapter.send_message(
        chat_id:             chat_id,
        text:                configuration.non_command_message_response,
        reply_to_message_id: message['message_id']
      )
    end

    def process_command(message, chat_id:)
      command_data = parse_command(message['text'])
      command = command_data && command_data[:command]
      return unless command

      case command
      when '/start'
        send_welcome_message(chat_id: chat_id)
      else
        # Respond to unknown commands
        unless configuration.ignore_unknown_commands
          unknown_command_response = "I don't know the command #{command}. Please use /start to begin or check the available commands."
          adapter.send_message(chat_id: chat_id, text: unknown_command_response)
        end
      end
    end

    def handle_user_command(command_data:, message:, chat_id:)
      callback = configuration.on_user_command
      return false unless callback.respond_to?(:call)
      return false if command_data[:command] == '/start'

      callback.call(
        command: command_data[:command],
        bot_username: command_data[:bot_username],
        args: command_data[:args],
        message: message,
        chat_id: chat_id
      )
    rescue StandardError => error
      warn "Failed to run on_user_command callback: #{error.class}: #{error.message}"
      false
    end

    def parse_command(text)
      return nil unless text.is_a?(String)

      token, args = text.strip.split(/\s+/, 2)
      return nil unless token&.start_with?('/')

      command, bot_username = token.split('@', 2)
      return nil if command.nil? || command.empty?

      { command: command.downcase, bot_username: bot_username, args: args&.strip }
    end

    def process_reply_in_support_chat(message)
      reply_to_message = message['reply_to_message']
      reply_to_message_id = reply_to_message['message_id']
      mapping = find_message_mapping(reply_to_message_id)

      original_user_id = mapping && mapping[:chat_id]
      original_user_id ||= reply_to_message.dig('forward_from', 'id')
      return unless original_user_id

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

    def forward_message_to_support_chat(message, chat_id:)
      message_id = message['message_id']
      result = adapter.forward_message(
        from_chat_id: chat_id,
        message_id:   message_id,
        chat_id:      configuration.support_chat_id)

      if result
        support_message_id = extract_message_id(result)
        if support_message_id
          store_message_mapping(
            support_message_id: support_message_id,
            user_chat_id:       chat_id,
            user_message_id:    message_id
          )
        end
      end
      # scheduler.schedule_auto_away_message(message_id, message_chat_id)
    end

    def handle_my_chat_member_update(update)
      new_status = update.dig('new_chat_member', 'status')
      old_status = update.dig('old_chat_member', 'status')
      return unless %w[member administrator].include?(new_status)
      return if %w[member administrator].include?(old_status)

      chat = update['chat'] || {}
      return if chat['type'] == 'private'

      chat_id = chat['id']
      return if chat_id.nil?

      send_welcome_message(chat_id: chat_id)
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

    def request_contact_from_user(chat_id:, text: configuration.contact_request_message)
      adapter.send_message(chat_id: chat_id, text: text, reply_markup: contact_request_keyboard)
    end

    def contact_request_keyboard
      {
        keyboard: [[{ text: 'Share phone number', request_contact: true }]],
        resize_keyboard: true,
        one_time_keyboard: true
      }
    end

    def remove_keyboard_markup
      { remove_keyboard: true }
    end

    def should_request_contact?(chat_id)
      configuration.request_contact_on_start && !contact_known_for_user?(chat_id)
    end

    def contact_known_for_user?(chat_id)
      !user_profile(chat_id).nil?
    end

    def valid_contact_for_chat?(contact:, chat_id:)
      contact_user_id = contact['user_id'] || contact[:user_id]
      return false if contact_user_id.nil?

      same_chat_id?(contact_user_id, chat_id)
    end

    def build_contact_profile(chat_id:, message:, contact:)
      sender = message['from'] || {}
      {
        chat_id: chat_id,
        user_id: contact['user_id'] || contact[:user_id],
        phone_number: contact['phone_number'] || contact[:phone_number],
        first_name: contact['first_name'] || contact[:first_name] || sender['first_name'],
        last_name: contact['last_name'] || contact[:last_name] || sender['last_name'],
        username: sender['username'],
        language_code: sender['language_code']
      }
    end

    def store_user_profile(chat_id:, profile:)
      user_profiles[chat_id] = profile
      user_profiles[chat_id.to_s] = profile
    end

    def notify_contact_received(profile)
      return unless configuration.on_contact_received.respond_to?(:call)

      configuration.on_contact_received.call(profile)
    rescue StandardError => error
      warn "Failed to run on_contact_received callback: #{error.class}: #{error.message}"
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

end
