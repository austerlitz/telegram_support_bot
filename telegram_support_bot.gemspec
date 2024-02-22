# frozen_string_literal: true

require_relative 'lib/telegram_support_bot/version'

Gem::Specification.new do |spec|
  spec.name = 'telegram-support-bot'
  spec.version = TelegramSupportBot::VERSION
  spec.authors = ['Max Buslaev']
  spec.email = ['max@buslaev.net']

  spec.summary = 'A Rails gem for integrating a Telegram bot into your application for seamless
support desk functionality.'
  spec.description = 'The telegram_support_bot gem provides Rails applications with an
easy-to-integrate Telegram bot, designed to enhance customer support services.
By leveraging this gem, developers can swiftly add a Telegram-based support desk to their
application, enabling direct communication between users and support agents through Telegram.
Features include automatic message forwarding to a designated secret chat for support agents,
the ability to reply directly from the secret chat to users, and customizable responses
for common queries. This gem simplifies the process of setting up a robust support channel on one of
the most popular messaging platforms, making it an ideal solution for businesses looking to improve
their customer service experience.'
  spec.homepage = 'https://github.com/austerlitz/telegram_support_bot'
  spec.license = 'MIT'
  # spec.required_ruby_version = '>= 2.6.0'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

end
