module Admin
  module JoysoundMusicPosts
    class FetchJoysoundMusicPostsController < ApplicationController
      def index
        RunFetchJoysoundMusicPostWorker.perform_async
        render status: :ok
      end
    end
  end
end
