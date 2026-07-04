if Rails.env.local?
  Prosopite.rails_logger = true
  Prosopite.raise = Rails.env.test?
end
