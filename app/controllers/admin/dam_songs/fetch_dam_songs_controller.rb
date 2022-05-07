module Admin
  module DamSongs
    class FetchDamSongsController < ApplicationController
      def index
        RunFetchDamSongWorker.perform_async
        render status: :ok
      end
    end
  end
end
