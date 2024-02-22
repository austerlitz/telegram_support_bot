# frozen_string_literal: true

module TelegramSupportBot
  class Configuration
    attr_accessor :adapter, :adapter_options

    def initialize
      @adapter         = :telegram_bot # Default adapter
      @adapter_options = {} # Hash to store additional options
    end
  end
end
