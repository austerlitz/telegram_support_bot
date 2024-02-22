# frozen_string_literal: true

require_relative "telegram_support_bot/version"
require_relative 'telegram_support_bot/configuration'
require_relative 'telegram_support_bot/adapters/base_adapter'
require_relative 'telegram_support_bot/adapters/telegram_bot_adapter'
require_relative 'telegram_support_bot/adapters/telegram_bot_ruby_adapter'

module TelegramSupportBot

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.create_adapter
    adapter_class = resolve_adapter_class(configuration.adapter)
    adapter_class.new(**configuration.adapter_options)
  end

  private

  def self.resolve_adapter_class(adapter)
    # Logic to resolve adapter symbol to class, e.g., :telegram_bot to TelegramBotAdapter
  end
  # Your code goes here...
end
