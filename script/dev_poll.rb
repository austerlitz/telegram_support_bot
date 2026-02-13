#!/usr/bin/env ruby
# frozen_string_literal: true

require 'telegram_support_bot'
require 'telegram/bot'
require 'json'

token = ENV.fetch('TELEGRAM_BOT_TOKEN')
support_chat_id = Integer(ENV.fetch('SUPPORT_CHAT_ID'))
adapter = ENV.fetch('TSB_ADAPTER', 'telegram_bot')
username = ENV['TELEGRAM_BOT_USERNAME']

adapter_options = { token: token }
adapter_options[:username] = username if username && !username.empty?

TelegramSupportBot.configure do |config|
  config.adapter = adapter.to_sym
  config.adapter_options = adapter_options
  config.support_chat_id = support_chat_id
  config.request_contact_on_start = true
  # config.require_contact_for_support = true
  config.welcome_message = 'Hi! How can we help you?'
  config.on_contact_received = lambda do |profile|
    puts '[TSB CONTACT] Contact received profile:'
    puts JSON.pretty_generate(profile)
  end
end

client = Telegram::Bot::Client.new(token)
offset = 0

puts "TelegramSupportBot dev poller started (adapter=#{adapter}, support_chat_id=#{support_chat_id})."
puts 'Press Ctrl+C to stop.'

def extract_result(payload)
  return payload['result'] if payload.is_a?(Hash) && payload.key?('result')
  return payload[:result] if payload.is_a?(Hash) && payload.key?(:result)

  payload
end

def verify_reaction_update_prerequisites(client:, support_chat_id:)
  me_response = client.get_me
  me_result = extract_result(me_response)
  bot_user_id = me_result['id'] || me_result[:id]
  return puts('Warning: could not verify bot identity via getMe.') unless bot_user_id

  member_response = client.get_chat_member(chat_id: support_chat_id, user_id: bot_user_id)
  member_result = extract_result(member_response)
  status = member_result['status'] || member_result[:status]

  unless %w[administrator creator].include?(status)
    puts "Warning: bot status in support chat is #{status.inspect}. message_reaction/message_reaction_count updates require bot admin rights."
  end
rescue StandardError => e
  puts "Warning: failed to verify reaction prerequisites: #{e.class}: #{e.message}"
end

verify_reaction_update_prerequisites(client: client, support_chat_id: support_chat_id)

def debug_update_summary(update)
  return unless ENV['TSB_DEBUG'] == '1'

  if update['message_reaction']
    chat_id = update.dig('message_reaction', 'chat', 'id')
    message_id = update.dig('message_reaction', 'message_id')
    puts "[TSB POLL DEBUG] update=message_reaction chat_id=#{chat_id.inspect} message_id=#{message_id.inspect}"
  elsif update['message_reaction_count']
    chat_id = update.dig('message_reaction_count', 'chat', 'id')
    message_id = update.dig('message_reaction_count', 'message_id')
    puts "[TSB POLL DEBUG] update=message_reaction_count chat_id=#{chat_id.inspect} message_id=#{message_id.inspect}"
  elsif update['message']
    chat_id = update.dig('message', 'chat', 'id')
    message_id = update.dig('message', 'message_id')
    puts "[TSB POLL DEBUG] update=message chat_id=#{chat_id.inspect} message_id=#{message_id.inspect}"
  elsif update['my_chat_member']
    chat_id = update.dig('my_chat_member', 'chat', 'id')
    puts "[TSB POLL DEBUG] update=my_chat_member chat_id=#{chat_id.inspect}"
  else
    puts "[TSB POLL DEBUG] update=other keys=#{update.keys.inspect}"
  end
end

loop do
  params = {
    offset: offset,
    timeout: 25,
    allowed_updates: %w[message message_reaction message_reaction_count my_chat_member]
  }
  response =
    if client.respond_to?(:get_updates)
      client.get_updates(**params)
    elsif client.respond_to?(:api) && client.api.respond_to?(:get_updates)
      client.api.get_updates(**params)
    elsif client.respond_to?(:api) && client.api.respond_to?(:getUpdates)
      client.api.getUpdates(**params)
    else
      raise 'Unsupported Telegram client API for polling'
    end
  updates = response['result'] || response[:result] || []

  updates.each do |update|
    normalized = update.respond_to?(:to_h) ? update.to_h : update
    debug_update_summary(normalized)
    TelegramSupportBot.process_update(normalized)
    update_id = normalized['update_id'] || normalized[:update_id]
    offset = update_id + 1 if update_id
  end
end
