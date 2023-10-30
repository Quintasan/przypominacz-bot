# frozen_string_literal: true

class SetupDatabase
  class << self
    def call
      database_path = ENV.fetch('DATABASE_PATH', '.reminders.db')
      @db = Sequel.connect("sqlite://#{database_path}")
      create_discord_users
      create_reminders
      @db
    end

    private

    def create_discord_users
      @db.create_table?(:discord_users) do
        Integer :id, primary_key: true
        String :username, null: false
      end
    end

    def create_reminders
      @db.create_table?(:reminders) do
        primary_key :id
        DateTime :date_time, null: false
        String :username, null: false
        String :message, null: false
        TrueClass :scheduled, null: false, default: false
        TrueClass :sent, null: false, default: false
        Integer :spreadsheet_row, null: false

        unique %i[date_time username message], name: 'reminder_must_be_unique'
      end
    end
  end
end
