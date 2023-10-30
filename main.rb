#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default, :development)

LOGGER = TTY::Logger.new
PRZYPOMINACZ_TOKEN = ENV.fetch('PRZYPOMINACZ_TOKEN')
CONFIG_PATH = ENV.fetch('GOOGLE_CREDENTIALS_PATH')
SPREADSHEET_ID = ENV.fetch('SPREADSHEET_ID')
SERVER_ID = ENV.fetch('SERVER_ID')
CHANNEL_ID = ENV.fetch('CHANNEL_ID')

require_relative('setup_database')
DB = SetupDatabase.call
DB.sql_log_level = :debug
DB.loggers << LOGGER
require_relative('models')

bot = Discordrb::Bot.new(token: PRZYPOMINACZ_TOKEN)
bot.run(:async)

require_relative('fetch_discord_user_map')
require_relative('save_discord_user_map')
SaveDiscordUserMap.call(
  DiscordUser.dataset,
  FetchDiscordUserMap.new(bot, SERVER_ID).call
)

require_relative('fetch_reminders_from_google_drive')
require_relative('save_reminders')
worksheet = FetchRemindersFromGoogleDrive.new(CONFIG_PATH, SPREADSHEET_ID)
SaveReminders.call(
  Reminder.dataset,
  worksheet.reminders_as_values
)

loop do
  LOGGER.info 'Scheduling new reminders'
  Reminder.where(scheduled: false, sent: false).each do |reminder|
    LOGGER.info { "Scheduling reminder for #{reminder.username} at #{reminder.date_time}" }
    reminder.update(scheduled: true)
    Rufus::Scheduler.s(discard_past: false).schedule_at(reminder.date_time.to_s) do
      reminder.post_to_discord(bot, CHANNEL_ID)
      reminder.update_google_sheet(worksheet.worksheet)
    end
  end

  LOGGER.info 'Sleeping 55 seconds...'
  sleep 55

  LOGGER.info 'Refreshing spreadsheet'
  worksheet.reload
  SaveReminders.call(
    Reminder.dataset,
    worksheet.reminders_as_values
  )
end
