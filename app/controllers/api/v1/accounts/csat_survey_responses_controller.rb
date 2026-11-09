class Api::V1::Accounts::CsatSurveyResponsesController < Api::V1::Accounts::BaseController
  include Sift
  include DateRangeHelper

  RESULTS_PER_PAGE = 25

  before_action :check_authorization
  before_action :set_csat_survey_responses, only: [:index, :metrics, :download]
  before_action :set_current_page, only: [:index]
  before_action :set_current_page_surveys, only: [:index]
  before_action :set_total_sent_messages_count, only: [:metrics]

  sort_on :created_at, type: :datetime

  def index; end

  def metrics
    @total_count = @csat_survey_responses.count
    @ratings_count = @csat_survey_responses.group(:rating).count
    build_agent_leaderboard
  end

  def download
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = 'attachment; filename=csat_report.csv'
    render layout: false, template: 'api/v1/accounts/csat_survey_responses/download', formats: [:csv]
  end

  private

  def set_total_sent_messages_count
    @csat_messages = Current.account.messages.input_csat
    @csat_messages = @csat_messages.where(created_at: range) if range.present?
    @total_sent_messages_count = @csat_messages.count
  end

  def set_csat_survey_responses
    base_query = Current.account.csat_survey_responses.includes([{ conversation: [:inbox, :ai_assignee] }, :assigned_agent, :contact])
    @csat_survey_responses = filtrate(base_query).filter_by_created_at(range)
                                                 .filter_by_assigned_agent_id(params[:user_ids])
                                                 .filter_by_inbox_id(params[:inbox_id])
                                                 .filter_by_team_id(params[:team_id])
                                                 .filter_by_rating(params[:rating])
  end

  def build_agent_leaderboard
    grouped = @csat_survey_responses.unscope(:order, :includes).group(:assigned_agent_id, :rating).count
    agent_ids = grouped.keys.map(&:first).compact.uniq
    users_by_id = Current.account.users.where(id: agent_ids).index_by(&:id)

    stats = Hash.new { |h, k| h[k] = { ratings: { 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, total: 0, weighted_sum: 0 } }
    grouped.each do |(agent_id, rating), count|
      key = agent_id || 'ai'
      stats[key][:ratings][rating] = count
      stats[key][:total] += count
      stats[key][:weighted_sum] += (rating * count)
    end

    @ai_responses_count = stats['ai'][:total]
    @human_responses_count = @total_count - @ai_responses_count

    @agent_leaderboard = stats.map do |key, data|
      next if data[:total].zero?

      is_ai = key == 'ai'
      user = is_ai ? nil : users_by_id[key]
      positive = data[:ratings][4].to_i + data[:ratings][5].to_i
      {
        id: is_ai ? 'ai' : key,
        is_ai: is_ai,
        name: is_ai ? '🤖 Assistente IA (Leo)' : (user&.name || "Agente ##{key}"),
        thumbnail: is_ai ? nil : user&.avatar_url,
        total_count: data[:total],
        average_rating: (data[:weighted_sum].to_f / data[:total]).round(2),
        satisfaction_score: ((positive.to_f * 100) / data[:total]).round(1),
        ratings_count: data[:ratings]
      }
    end.compact.sort_by { |row| [-row[:average_rating], -row[:total_count]] }
  end

  def set_current_page_surveys
    @csat_survey_responses = @csat_survey_responses.page(@current_page).per(RESULTS_PER_PAGE)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end

Api::V1::Accounts::CsatSurveyResponsesController.prepend_mod_with('Api::V1::Accounts::CsatSurveyResponsesController')
