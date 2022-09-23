# For more information regarding these settings check out our docs https://docs.avohq.io
Avo.configure do |config|
  ## == Routing ==
  config.root_path = '/'

  # Where should the user be redirected when visting the `/avo` url
  # config.home_path = nil

  ## == Licensing ==
  config.license = 'pro' # change this to 'pro' when you add the license key
  # config.license_key = ENV['AVO_LICENSE_KEY']

  ## == Set the context ==
  config.set_context do
    # Return a context object that gets evaluated in Avo::ApplicationController
  end

  ## == Authentication ==
  user = Struct.new(:name)

  config.current_user_method do
    user.new({ name: 'Anonymous user' })
  end
  # config.authenticate_with = {}

  ## == Authorization ==
  # config.authorization_methods = {
  #   index: 'index?',
  #   show: 'show?',
  #   edit: 'edit?',
  #   new: 'new?',
  #   update: 'update?',
  #   create: 'create?',
  #   destroy: 'destroy?',
  # }
  # config.raise_error_on_missing_policy = false

  ## == Localization ==
  # config.locale = 'en-US'
  config.locale = :ja

  ## == Resource options ==
  # config.resource_controls = :right
  # config.model_resource_mapping = {}
  # config.default_view_type = :table
  # config.per_page = 24
  # config.per_page_steps = [12, 24, 48, 72]
  # config.via_per_page = 8
  # config.id_links_to_resource = false
  # config.cache_resources_on_index_view = true

  ## == Customization ==
  config.app_name = '東方カラオケ管理画面'
  # config.timezone = 'UTC'
  # config.currency = 'USD'
  # config.hide_layout_when_printing = false
  # config.full_width_container = false
  # config.full_width_index_view = false
  # config.search_debounce = 300
  # config.view_component_path = "app/components"
  # config.display_license_request_timeout_error = true
  # config.disabled_features = []
  # config.resource_controls = :right
  # config.tabs_style = :tabs # can be :tabs or :pills
  # config.buttons_on_form_footers = true

  ## == Branding ==
  # config.branding = {
  #   colors: {
  #     background: "248 246 242",
  #     100 => "#CEE7F8",
  #     400 => "#399EE5",
  #     500 => "#0886DE",
  #     600 => "#066BB2",
  #   },
  #   chart_colors: ["#0B8AE2", "#34C683", "#2AB1EE", "#34C6A8"],
  #   logo: "/avo-assets/logo.png",
  #   logomark: "/avo-assets/logomark.png"
  # }

  ## == Breadcrumbs ==
  # config.display_breadcrumbs = true
  # config.set_initial_breadcrumbs do
  #   add_breadcrumb "Home", '/avo'
  # end

  config.resource_controls_placement = :left

  ## == Menus ==
  config.main_menu = lambda {
    section "Dashboards", icon: "dashboards" do
      all_dashboards
    end

    section('Master data', icon: 'resources') do
      resource(:original)
      resource(:original_song)
      resource(:karaoke_delivery_model)
      resource(:circle)
    end

    section "Resource", icon: "resources" do
      resource(:song)
      resource(:display_artist)
    end

    section "DAM", icon: "resources" do
      resource(:dam_song)
      resource(:dam_artist_url)
    end

    section "JOYSOUND", icon: "resources" do
      resource(:joysound_song)
      resource(:joysound_music_post)
    end

    #   section "Tools", icon: "tools" do
    #     all_tools
    #   end
  }

  # config.profile_menu = -> {
  #   link "Profile", path: "/avo/profile", icon: "user-circle"
  # }
end
