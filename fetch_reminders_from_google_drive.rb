# frozen_string_literal: true

SpreadsheetReminder = Struct.new(:index, :date_time, :username, :message, :sent, :discord_id)

class FetchRemindersFromGoogleDrive
  attr_reader :worksheet, :reminders

  def initialize(config_file_path, spreadsheet_id)
    @session = GoogleDrive::Session.from_service_account_key(config_file_path)
    @spreadsheet_id = spreadsheet_id
    @worksheet = @session.spreadsheet_by_key(@spreadsheet_id).worksheets[0]
    @reminders = @worksheet.rows[1...].map.with_index { |row, index| create_reminder(row, index) }
  end

  def reload
    @worksheet.reload
    @reminders = @worksheet.rows[1...].map.with_index { |row, index| create_reminder(row, index) }
  end

  def reminders_as_values
    @reminders.map do |r|
      [r.index, r.date_time, r.username, r.message, r.sent]
    end
  end

  private

  def create_reminder(csv_row, index)
    index_in_spreadsheet = index.to_i + 2
    date_time = parse_reminder_date(csv_row[0], csv_row[1])
    username = csv_row[2]
    message = csv_row[3]
    sent = csv_row[4] == '1'
    SpreadsheetReminder.new(index_in_spreadsheet, date_time, username, message, sent)
  end

  def parse_reminder_date(date, time)
    DateTime.parse("#{date}T#{time}+02:00")
  end
end
