# frozen_string_literal: true

module TelegramSupportBot
  class Configuration
    attr_accessor :adapter, :adapter_options, :support_chat_id, :welcome_message,
                  :auto_away_message, :auto_away_interval, :ignore_unknown_commands,
                  :ignore_non_command_messages, :non_command_message_response,
                  :request_contact_on_start, :require_contact_for_support, :contact_request_message,
                  :contact_received_message, :contact_invalid_message, :on_contact_received,
                  :on_user_command,
                  :state_store, :state_store_options, :mapping_ttl_seconds,
                  :reaction_count_ttl_seconds, :user_profile_ttl_seconds

    def initialize
      @adapter                 = :telegram_bot
      @adapter_options         = {}
      @welcome_message         = 'Welcome! How can we help you?'
      @ignore_unknown_commands = true
      @ignore_non_command_messages = true
      @non_command_message_response = 'I received your message, but I only respond to commands. Please use /start to get started.'
      @auto_away_interval      = 10 # seconds
      @auto_away_message       = 'We are sorry, all operators are busy at the moment. Please wait'
      @request_contact_on_start = false
      @require_contact_for_support = false
      @contact_request_message = 'Please share your phone number so we can quickly identify your account.'
      @contact_received_message = 'Thanks! We have saved your phone number.'
      @contact_invalid_message = 'Please use the button below to share your own phone number.'
      @on_contact_received = nil
      @on_user_command = nil
      @state_store = :memory
      @state_store_options = {}
      @mapping_ttl_seconds = 30 * 24 * 60 * 60
      @reaction_count_ttl_seconds = 7 * 24 * 60 * 60
      @user_profile_ttl_seconds = nil
    end
  end
end
