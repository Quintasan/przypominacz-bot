# frozen_string_literal: true

class FetchDiscordUserMap
  def initialize(bot, server_id)
    @bot = bot
    @server_id = server_id
  end

  def call
    fetch_all_discord_users(@bot, @server_id)
      .then { |userlist| build_values(userlist) }
  end

  private

  def fetch_all_discord_users(bot, server_id)
    bot.server(server_id).users
  end

  def build_values(user_list)
    user_list.map { |user| [user.id, user.username] }
  end
end
