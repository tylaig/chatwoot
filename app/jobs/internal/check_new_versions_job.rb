class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless Rails.env.production?

    ::Redis::Alfred.set(::Redis::Alfred::LATEST_CHATWOOT_VERSION, Chatwoot.config[:version])
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
