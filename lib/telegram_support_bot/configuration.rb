# frozen_string_literal: true

module TelegramSupportBot
  class Configuration
    attr_accessor :adapter, :adapter_options, :support_chat_id, :welcome_message,
                  :auto_away_message, :auto_away_interval, :ignore_unknown_commands

    def initialize
      @adapter                 = :telegram_bot
      @adapter_options         = {}
      @welcome_message         = 'Welcome! How can we help you?'
      @ignore_unknown_commands = true
      @auto_away_interval      = 10 # seconds
      @auto_away_message       = 'We are sorry, all operators are busy at the moment. Please wait'
    end
  end
end
