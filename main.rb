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

bot = Discordrb::Bot.new(token: PRZYPOMINACZ_TOKEN, fancy_log: true)
bot.register_application_command(:create_section, 'Tworzy rolę, kategorię i kanały dla strefy',
                                 server_id: SERVER_ID) do |cmd|
  cmd.string('section_name', 'Nazwa strefy', required: true)
end
bot.application_command(:create_section) do |event|
  event.respond(content: 'On it sir!', ephemeral: true)

  section_name = event.options['section_name']
  server = event.channel.server

  LOGGER.info "Creating role #{section_name}"
  role = server.create_role(name: section_name)

  allow_role_to_communicate = Discordrb::Permissions.new %i[read_messages send_messages connect speak]
  add_role_to_category = Discordrb::Overwrite.new(role, allow: allow_role_to_communicate)

  deny_everyone = Discordrb::Permissions.new %i[read_messages connect]
  private_category = Discordrb::Overwrite.new(SERVER_ID, type: 'role', deny: deny_everyone)

  LOGGER.info "Creating category #{section_name}"
  category = server.create_channel(section_name, 4, permission_overwrites: [private_category, add_role_to_category])

  text_channels = %w[ogłoszenia-org ogólny]
  text_channels.each do |channel_name|
    LOGGER.info "Creating text channel #{channel_name}"
    server.create_channel(channel_name, parent: category)
  end

  voice_channels = %w[voice]
  voice_channels.each do |channel_name|
    LOGGER.info "Creating voice channel #{channel_name}"
    server.create_channel(channel_name, 2, parent: category)
  end
end
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
