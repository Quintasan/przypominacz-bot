#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default, :development)

LOGGER = TTY::Logger.new
DISCORD_BOT_TOKEN = ENV.fetch('DISCORD_BOT_TOKEN')
SERVER_ID = ENV.fetch('SERVER_ID')
ORG_ROLE_ID = 1060291697214500926

bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN, fancy_log: true)
#bot.register_application_command(:create_section, 'Tworzy rolę, kategorię i kanały dla strefy',
#                                 server_id: SERVER_ID) do |cmd|
#  cmd.string('section_name', 'Nazwa strefy', required: true)
#end
bot.application_command(:create_section) do |event|
  unless event.user.roles.map(&:id).include?(ORG_ROLE_ID)
    LOGGER.warn(
      "unauthorized usage attempt",
      slash_command: "create_section",
      user_id: event.user.id,
      username: event.user.username,
      timestamp: Time.now.iso8601
    )
    event.respond(content: 'Unauthorized', ephemeral: true)
    next
  end

  event.respond(content: 'On it sir!', ephemeral: true)

  section_name = event.options['section_name']
  server = event.channel.server

  LOGGER.info("creating role", role_name: section_name)
  role = server.create_role(name: section_name)

  allow_role_to_communicate = Discordrb::Permissions.new %i[read_messages send_messages connect speak]
  add_role_to_category = Discordrb::Overwrite.new(role, allow: allow_role_to_communicate)

  deny_everyone = Discordrb::Permissions.new %i[read_messages connect]
  private_category = Discordrb::Overwrite.new(SERVER_ID, type: 'role', deny: deny_everyone)

  LOGGER.info("creating category", category_name: section_name)
  category = server.create_channel(section_name, 4, permission_overwrites: [private_category, add_role_to_category])

  text_channels = %w[ogłoszenia-org ogólny]
  text_channels.each do |channel_name|
    LOGGER.info("creating text channel", channel_name: channel_name)
    server.create_channel(channel_name, parent: category)
  end

  voice_channels = %w[voice]
  voice_channels.each do |channel_name|
    LOGGER.info("creating voice channel", channel_name: channel_name)
    server.create_channel(channel_name, 2, parent: category)
  end
end

bot.run
