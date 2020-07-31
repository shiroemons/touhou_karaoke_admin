module Admin
  module JoysoundSongs
    class FetchJoysoundSongsController < ApplicationController
      def index
        RunFetchJoysoundSongWorker.perform_async
        render status: :ok
      end
    end
  end
end