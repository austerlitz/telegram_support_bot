RSpec.shared_examples "a Telegram bot adapter" do
  let(:chat_id) { '123456' }
  let(:text) { 'Hello, world!' }
  let(:message_id) { '123' }

  it "implements #on_message" do
    expect(adapter).to respond_to(:on_message).with(0).arguments
  end
  it "calls #send_message with correct arguments" do
    adapter.send_message(chat_id: chat_id, text: text)
    expect(telegram_mock).to have_received(:send_message).with(chat_id: chat_id, text: text)
  end

  it "calls #forward_message with correct arguments" do
    adapter.forward_message(from_chat_id: chat_id, message_id: message_id, chat_id: chat_id)
    expect(telegram_mock).to have_received(:forward_message).with(chat_id: chat_id, from_chat_id: chat_id, message_id: message_id)
  end

end
