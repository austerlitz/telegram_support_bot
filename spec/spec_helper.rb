# frozen_string_literal: true

require "telegram_support_bot"

# Require all files in the spec/support directory
Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.before do
    TelegramSupportBot.reset_adapter!
    TelegramSupportBot.reset_state_store! if TelegramSupportBot.respond_to?(:reset_state_store!)
  end

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
