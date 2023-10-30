# frozen_string_literal: true

class DiscordUser < Sequel::Model; end

class Reminder < Sequel::Model
  def post_to_discord(bot, channel_id)
    return if sent

    user_id = DiscordUser.find(username:)&.id

    bot.send_message(
      channel_id,
      format_message(user_id)
    )

    update(sent: true)
  end

  def update_google_sheet(spreadsheet)
    spreadsheet[spreadsheet_row, 5] = 1
    spreadsheet.save
  end

  def format_message(user_id)
    "<@#{user_id}> #{message}"
  end
end
