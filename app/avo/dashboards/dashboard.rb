class Dashboard < Avo::Dashboards::BaseDashboard
  self.id = "dashboard"
  self.name = "Dashboard"
  self.grid_cols = 4

  divider label: "原曲紐付け済み楽曲"
  card SongsCount,
       label: '総楽曲数',
       options: {
         touhou: true
       }
  card SongsCount,
       label: 'DAM楽曲数',
       options: {
         touhou: true,
         dam: true
       }
  card SongsCount,
       label: 'JOYSOUND楽曲数',
       options: {
         touhou: true,
         joysound: true
       }
  card SongsCount,
       label: 'JOYSOUND MUSIC POST楽曲数',
       options: {
         touhou: true,
         music_post: true
       }

  divider label: "原曲未紐付け楽曲"
  card SongsCount,
       label: '総楽曲数',
       options: {
         missing_original_songs: true
       }

  divider label: "JOYSOUND MUSIC POST"
  card SongsCount,
       label: '原曲紐付け済み楽曲数(Songs)',
       options: {
         touhou: true,
         music_post: true
       }
  card SongsCount,
       label: '全楽曲数(Songs)',
       options: {
         music_post: true
       }
  card JoysoundMusicPostCount, label: '楽曲数(JOYSOUND MUSIC POST)'
end
