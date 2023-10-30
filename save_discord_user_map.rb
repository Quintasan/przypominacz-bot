# frozen_string_literal: true

class SaveDiscordUserMap
  class << self
    def call(dataset, values)
      persist_discord_user_maps(dataset, values)
    end

    private

    def persist_discord_user_maps(dataset, values)
      dataset.insert_conflict(
        target: :id,
        update: { username: Sequel[:excluded][:username] }
      ).import(
        %i[id username], values
      )
    end
  end
end
