module Admin
  module Operations
    class KaraokeCandidateOperation < BaseOperation
      def initialize(params:)
        super()
        @params = params
      end

      def fetch_dam_song(progress: nil)
        url = @params.dig(:operation_fields, :dam_song_url).to_s
        raise OperationRunner::InputError, 'DAMの楽曲URLではありません。' unless url.start_with?(Constants::Karaoke::Dam::SONG_URL)

        progress&.call(percentage: 25, status: 'DAM候補追加中', label: '指定URLからDAM候補を取得しています', detail: nil)
        DamSong.fetch_dam_song(url)
        progress&.call(percentage: 96, status: 'DAM候補追加中', label: 'DAM候補の保存が完了しました', detail: nil)
        message('DAM候補を追加しました。')
      end

      def fetch_joysound_detail(progress: nil)
        url = @params.dig(:operation_fields, :joysound_url).to_s
        raise OperationRunner::InputError, 'JOYSOUNDの楽曲URLではありません。' unless url.start_with?("#{Constants::Karaoke::Joysound::SEARCH_URL}/")

        progress&.call(percentage: 25, status: 'JOYSOUND候補追加中', label: '指定URLからJOYSOUND候補を取得しています', detail: nil)
        JoysoundSong.fetch_joysound_song_direct(url:)
        progress&.call(percentage: 96, status: 'JOYSOUND候補追加中', label: 'JOYSOUND候補の保存が完了しました', detail: nil)
        message('JOYSOUND候補を追加しました。')
      end
    end
  end
end
