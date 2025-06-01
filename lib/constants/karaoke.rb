module Constants
  module Karaoke
    # 東方関連の許可された作曲者リスト
    PERMITTED_COMPOSERS = %w[
      ZUN
      ZUN(上海アリス幻樂団)
      ZUN[上海アリス幻樂団]
      ZUN，あきやまうに
      あきやまうに
      U2
    ].freeze

    # 特別に許可するJOYSOUND楽曲のURL
    # これらは作曲者が許可リストに含まれていなくても登録される
    JOYSOUND_ALLOWLIST = [
      "https://www.joysound.com/web/search/song/115474", # ひれ伏せ愚民どもっ! 作曲:ARM
      "https://www.joysound.com/web/search/song/225460", # Once in a blue moon feat. らっぷびと 作曲:Coro
      "https://www.joysound.com/web/search/song/225456", # Crazy speed Hight 作曲:龍5150
      "https://www.joysound.com/web/search/song/225449"  # 愛き夜道 feat. ランコ(豚乙女)、雨天決行／魂音泉 作曲:U2，Coro
    ].freeze

    # DAM関連のURL設定
    module Dam
      BASE_URL = "https://www.clubdam.com/karaokesearch/".freeze
      SONG_URL = "https://www.clubdam.com/karaokesearch/songleaf.html?requestNo=".freeze
      SEARCH_URL = "https://www.clubdam.com/karaokesearch/?keyword=%E6%9D%B1%E6%96%B9%E3%83%97%E3%83%AD%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88&type=keyword&contentsCode=&serviceCode=&serialNo=AT00001&sort=1&pageNo=".freeze
      OPTION_PATH = "&contentsCode=&serviceCode=&serialNo=AT00001&filterTitle=&sort=3".freeze

      # 除外対象のURL
      EXCEPTION_URLS = %w[
        https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=43477
      ].freeze

      # 除外対象のキーワード
      EXCEPTION_WORDS = %w[
        アニメ
        ゲーム
        映画
        Windows
        PlayStation
        PS
        Xbox
        ニンテンドーDS
      ].freeze
    end

    # JOYSOUND関連のURL設定
    module Joysound
      BASE_URL = "https://www.joysound.com/web/".freeze
      SEARCH_URL = "https://www.joysound.com/web/search/song".freeze
      TOUHOU_GENRE_URL = "https://www.joysound.com/web/search/song?searchType=3&genreCd=22800001&sortOrder=new&orderBy=asc&startIndex=0#songlist".freeze

      # MusicPost関連
      MUSIC_POST_BASE_URL = "https://musicpost.joysound.com/".freeze
      MUSIC_POST_LIST_URL = "https://musicpost.joysound.com/musicList/page:1".freeze
      MUSIC_POST_ZUN_URL = "#{MUSIC_POST_LIST_URL}?target=5&method=1&keyword=ZUN&detail_show_flg=false&original=on&cover=on&sort=1".freeze
      MUSIC_POST_AKIYAMA_URL = "#{MUSIC_POST_LIST_URL}?target=5&method=1&keyword=%E3%81%82%E3%81%8D%E3%82%84%E3%81%BE%E3%81%86%E3%81%AB&detail_show_flg=false&original=on&cover=on&sort=1".freeze
    end
  end
end
