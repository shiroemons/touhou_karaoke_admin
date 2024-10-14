class FetchDamSong < Avo::BaseAction
  self.name = "URLからDAMの楽曲を取得"
  self.standalone = true
  self.visible = -> { view == :index }

  field :dam_song_url, as: :text, placeholder: "https://www.clubdam.com/karaokesearch/songleaf.html?requestNo="

  def handle(args)
    field = args.values_at(:fields).first
    fail('DAMの楽曲URLではありません。') unless field['dam_song_url'].start_with?("https://www.clubdam.com/karaokesearch/songleaf.html?requestNo=")

    DamSong.fetch_dam_song(field['dam_song_url'])
    succeed 'Done!'
    reload
  end
end
