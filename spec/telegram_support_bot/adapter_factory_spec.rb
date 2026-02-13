# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot::AdapterFactory do
  describe '.build' do
    let(:fake_adapter_class) do
      Class.new do
        attr_reader :options

        def initialize(**options)
          @options = options
        end
      end
    end

    before do
      stub_const('TelegramSupportBot::Adapters::FakeAdapter', fake_adapter_class)
      stub_const('TelegramSupportBot::AdapterFactory::ADAPTERS', {
        fake: 'TelegramSupportBot::Adapters::FakeAdapter'
      }.freeze)
    end

    it 'builds an adapter from symbol with keyword options' do
      adapter = described_class.build(:fake, token: 'abc')
      expect(adapter).to be_a(fake_adapter_class)
      expect(adapter.options).to eq(token: 'abc')
    end

    it 'builds an adapter from class with keyword options' do
      adapter = described_class.build(fake_adapter_class, token: 'abc')
      expect(adapter.options).to eq(token: 'abc')
    end

    it 'raises for unknown adapter symbols' do
      expect { described_class.build(:missing) }.to raise_error(ArgumentError, /Unsupported adapter specification/)
    end
  end
end
