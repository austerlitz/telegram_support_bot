# lib/telegram_support_bot/adapter_factory.rb
module TelegramSupportBot
  module AdapterFactory
    ADAPTERS = {
      telegram_bot: 'TelegramSupportBot::Adapters::TelegramBotAdapter',
      telegram_bot_ruby: 'TelegramSupportBot::Adapters::TelegramBotRubyAdapter'
      # Add more predefined adapters here
    }.freeze

    def self.build(adapter_specification, adapter_options = {})
      case adapter_specification
      when Symbol
        adapter_class = ADAPTERS[adapter_specification].constantize
        adapter_class.new(adapter_options)
      when Class
        adapter_specification.new(adapter_options)
      else
        raise ArgumentError, "Unsupported adapter specification: #{adapter_specification}"
      end
    end
  end
end
