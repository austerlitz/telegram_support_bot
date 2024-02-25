module TelegramSupportBot
  class AutoAwayScheduler
    def initialize(adapter, configuration)
      @adapter = adapter
      @configuration = configuration
      @scheduled_tasks = {}
    end

    def schedule_auto_away_message(user_message_id, chat_id)
      # Cancel any existing scheduled task for this message to avoid duplicate messages
      cancel_scheduled_task(user_message_id)

      # Only proceed if auto-away is configured
      auto_away_interval = @configuration.auto_away_interval || 60

      # Immediately store the thread object in the hash to mark this message ID as scheduled
      @scheduled_tasks[user_message_id] = Thread.new do
        sleep(auto_away_interval) # Wait for the specified interval

        # After waking up, check if the task is still relevant
        if @scheduled_tasks[user_message_id]
          send_auto_away_message(chat_id)
          notify_support_chat

          # Once the auto-away message has been sent, remove this task from the schedule
          @scheduled_tasks.delete(user_message_id)
        end
      end
    end


    def cancel_scheduled_task(user_message_id)
      if task = @scheduled_tasks[user_message_id]
        task.kill # Terminate the scheduled thread
        @scheduled_tasks.delete(user_message_id)
      end
    end

    private

    def send_auto_away_message(chat_id)
      auto_away_message = @configuration.auto_away_message
      @adapter.send_message(chat_id: chat_id, text: auto_away_message)
    end

    def notify_support_chat
      @adapter.send_message(
        chat_id: @configuration.support_chat_id,
        text: 'Auto-away message has been sent to user: "'+@configuration.auto_away_message+'"',
      )

    end
  end
end
