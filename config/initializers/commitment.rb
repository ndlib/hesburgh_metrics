# Commitment is only needed in development
if %w(development test).include? Rails.env
  Commitment.config.percentage_coverage_goal = 0
end
