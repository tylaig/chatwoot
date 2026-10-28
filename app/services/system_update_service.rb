require 'net/http'
require 'json'
require 'uri'

class SystemUpdateService
  GITHUB_REPO = ENV.fetch('CHATWOOT_UPDATE_REPO', 'tylaig/chatwoot')
  TARGET_BRANCH = ENV.fetch('CHATWOOT_UPDATE_BRANCH', 'meusuperchat')
  STATE_DIR = Rails.root.join('storage', 'system_updates')
  REQUEST_FILE = STATE_DIR.join('update_request.json')
  STATUS_FILE = STATE_DIR.join('update_status.json')

  def self.current_sha
    sha = if File.exist?(Rails.root.join('.git_sha'))
            File.read(Rails.root.join('.git_sha')).strip
          elsif defined?(GIT_HASH) && GIT_HASH.present? && GIT_HASH != 'unknown'
            GIT_HASH
          else
            ''
          end
    sha.present? ? sha : 'unknown'
  end

  def self.brasilia_time
    Time.current.in_time_zone('America/Sao_Paulo')
  end

  def self.within_support_hours?
    hour = brasilia_time.hour
    hour >= 11 && hour < 22
  end

  def self.check_updates(force_refresh: false)
    cache_key = "system_update_check:#{GITHUB_REPO}:#{TARGET_BRANCH}:#{current_sha[0..6]}"
    Rails.cache.delete(cache_key) if force_refresh

    comparison = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      fetch_github_comparison
    end

    comparison.merge(
      current_sha: current_sha,
      current_short_sha: current_sha[0..6],
      target_branch: TARGET_BRANCH,
      repo: GITHUB_REPO,
      within_support_hours: within_support_hours?,
      brasilia_time: brasilia_time.strftime('%d/%m/%Y %H:%M:%S BRT'),
      auto_deploy_schedule: 'Automático fora do horário de atendimento (22:00 às 10:59 BRT)',
      deploy_status: read_deploy_status
    )
  end

  def self.trigger_update!(user:, target_sha:, force_window: false)
    if within_support_hours? && !ActiveModel::Type::Boolean.new.cast(force_window)
      return {
        ok: false,
        error: 'Estamos no horário de atendimento (11h às 22h BRT). Marque a confirmação de forçar atualização de emergência para prosseguir agora.'
      }
    end

    FileUtils.mkdir_p(STATE_DIR)

    payload = {
      requested_at: Time.current.iso8601,
      requested_at_brt: brasilia_time.strftime('%d/%m/%Y %H:%M:%S BRT'),
      requested_by_id: user&.id,
      requested_by_name: user&.name || user&.email || 'SuperAdmin',
      from_sha: current_sha,
      target_sha: target_sha.presence || TARGET_BRANCH,
      branch: TARGET_BRANCH,
      force_window: ActiveModel::Type::Boolean.new.cast(force_window),
      state: 'queued'
    }

    status_payload = {
      state: 'running',
      step: 'queued',
      message: 'Solicitação de atualização recebida! O servidor está baixando as alterações e preparando os contêineres...',
      started_at: Time.current.iso8601,
      updated_at: Time.current.iso8601,
      target_sha: payload[:target_sha],
      from_sha: current_sha,
      requested_by: payload[:requested_by_name]
    }

    File.write(STATUS_FILE, JSON.pretty_generate(status_payload))
    File.write(REQUEST_FILE, JSON.pretty_generate(payload))

    {
      ok: true,
      message: 'Atualização iniciada com sucesso!',
      deploy_status: status_payload
    }
  end

  def self.read_deploy_status
    return { state: 'idle' } unless File.exist?(STATUS_FILE)

    data = JSON.parse(File.read(STATUS_FILE)).with_indifferent_access
    if data[:state] == 'running' && data[:target_sha].present? &&
       current_sha.start_with?(data[:target_sha].to_s[0..6])
      data[:state] = 'completed'
      data[:message] = "Sistema atualizado com sucesso para a versão #{current_sha[0..6]}!"
    end
    data
  rescue StandardError
    { state: 'idle' }
  end

  def self.fetch_github_comparison
    base = current_sha == 'unknown' ? 'HEAD~1' : current_sha[0..11]
    encoded_branch = URI.encode_www_form_component(TARGET_BRANCH)
    url = URI("https://api.github.com/repos/#{GITHUB_REPO}/compare/#{base}...#{encoded_branch}")

    req = Net::HTTP::Get.new(url)
    req['Accept'] = 'application/vnd.github.v3+json'
    req['User-Agent'] = 'MeuSuperChat-Elite-Updater'
    req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN'].present?

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: true, open_timeout: 6, read_timeout: 10) do |http|
      http.request(req)
    end

    unless res.is_a?(Net::HTTPSuccess)
      return fetch_branch_head_fallback("GitHub API status #{res.code}")
    end

    json = JSON.parse(res.body)
    commits = Array(json['commits']).reverse.map do |c|
      full_msg = c.dig('commit', 'message').to_s
      lines = full_msg.lines.map(&:strip).reject(&:empty?)
      {
        sha: c['sha'].to_s[0..6],
        full_sha: c['sha'].to_s,
        title: lines.first || 'Atualização',
        description: lines.drop(1).join("\n"),
        author: c.dig('commit', 'author', 'name') || c.dig('author', 'login') || 'Sistema',
        date: c.dig('commit', 'author', 'date'),
        html_url: c['html_url']
      }
    end

    files = Array(json['files']).first(50).map do |f|
      {
        filename: f['filename'],
        status: f['status'],
        additions: f['additions'].to_i,
        deletions: f['deletions'].to_i,
        changes: f['changes'].to_i,
        patch: f['patch'].to_s.lines.first(40).join
      }
    end

    latest_sha = commits.first&.dig(:full_sha) || json.dig('base_commit', 'sha') || current_sha
    ahead_by = json['ahead_by'].to_i

    {
      has_updates: ahead_by.positive? && latest_sha[0..6] != current_sha[0..6],
      status: json['status'] || 'identical',
      ahead_by: ahead_by,
      behind_by: json['behind_by'].to_i,
      latest_sha: latest_sha,
      latest_short_sha: latest_sha.to_s[0..6],
      total_commits: json['total_commits'].to_i,
      commits: commits,
      files_count: Array(json['files']).size,
      total_additions: Array(json['files']).sum { |f| f['additions'].to_i },
      total_deletions: Array(json['files']).sum { |f| f['deletions'].to_i },
      files: files
    }
  rescue StandardError => e
    fetch_branch_head_fallback(e.message)
  end

  def self.fetch_branch_head_fallback(error_msg = nil)
    encoded_branch = URI.encode_www_form_component(TARGET_BRANCH)
    url = URI("https://api.github.com/repos/#{GITHUB_REPO}/commits/#{encoded_branch}")
    req = Net::HTTP::Get.new(url)
    req['Accept'] = 'application/vnd.github.v3+json'
    req['User-Agent'] = 'MeuSuperChat-Elite-Updater'

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: true, open_timeout: 5, read_timeout: 8) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      c = JSON.parse(res.body)
      latest_sha = c['sha'].to_s
      has_upd = latest_sha.present? && latest_sha[0..6] != current_sha[0..6]
      return {
        has_updates: has_upd,
        status: has_upd ? 'ahead' : 'identical',
        ahead_by: has_upd ? 1 : 0,
        behind_by: 0,
        latest_sha: latest_sha,
        latest_short_sha: latest_sha[0..6],
        total_commits: has_upd ? 1 : 0,
        commits: [
          {
            sha: latest_sha[0..6],
            full_sha: latest_sha,
            title: c.dig('commit', 'message').to_s.lines.first.to_s.strip,
            description: '',
            author: c.dig('commit', 'author', 'name') || 'Sistema',
            date: c.dig('commit', 'author', 'date'),
            html_url: c['html_url']
          }
        ],
        files_count: Array(c['files']).size,
        total_additions: 0,
        total_deletions: 0,
        files: [],
        warning: error_msg
      }
    end

    {
      has_updates: false,
      status: 'error',
      ahead_by: 0,
      behind_by: 0,
      latest_sha: current_sha,
      latest_short_sha: current_sha[0..6],
      total_commits: 0,
      commits: [],
      files_count: 0,
      total_additions: 0,
      total_deletions: 0,
      files: [],
      error: error_msg
    }
  rescue StandardError => e
    {
      has_updates: false,
      status: 'error',
      ahead_by: 0,
      latest_sha: current_sha,
      latest_short_sha: current_sha[0..6],
      commits: [],
      files: [],
      error: e.message
    }
  end
end
