class FetchJoysoundDetail < Avo::BaseAction
  self.name = "Fetch joysound detail"
  self.standalone = true
  self.visible = -> { view == :index }

  field :joysound_url, as: :text

  def handle(**args)
    field = args.values_at(:fields).first

    url = field['joysound_url'].to_s
    fail('not joysound url') unless url.start_with?("https://www.joysound.com/web/search/song/")

    JoysoundSong.fetch_joysound_song_direct(url:)
    succeed 'Done!'
    reload
  end
end
