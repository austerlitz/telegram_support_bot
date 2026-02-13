# lib/telegram_support_bot/adapter_factory.rb
module TelegramSupportBot
  module AdapterFactory
    ADAPTERS = {
      telegram_bot: 'TelegramSupportBot::Adapters::TelegramBot',
      telegram_bot_ruby: 'TelegramSupportBot::Adapters::TelegramBotRuby'
      # Add more predefined adapters here
    }.freeze

    def self.build(adapter_specification, adapter_options = {})
      adapter_options ||= {}
      case adapter_specification
      when Symbol
        class_name = ADAPTERS[adapter_specification]
        raise ArgumentError, "Unsupported adapter specification: #{adapter_specification}" unless class_name

        adapter_class = constantize(class_name)
        adapter_class.new(**adapter_options)
      when Class
        adapter_specification.new(**adapter_options)
      else
        raise ArgumentError, "Unsupported adapter specification: #{adapter_specification}"
      end
    end

    def self.constantize(class_name)
      class_name.split('::').reject(&:empty?).inject(Object) { |namespace, constant| namespace.const_get(constant) }
    end
    private_class_method :constantize
  end
end
