# frozen_string_literal: true
require 'spec_helper'
RSpec.describe TelegramSupportBot do
  it "has a version number" do
    expect(TelegramSupportBot::VERSION).not_to be nil
  end

  it "can be configured" do
    expect(TelegramSupportBot).to respond_to(:configure)
  end
end
