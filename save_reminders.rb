# frozen_string_literal: true

class SaveReminders
  class << self
    def call(dataset, values)
      persist_reminders(dataset, values)
    end

    private

    def persist_reminders(dataset, values)
      dataset.insert_conflict.import(
        %i[spreadsheet_row date_time username message sent],
        values
      )
    end
  end
end
