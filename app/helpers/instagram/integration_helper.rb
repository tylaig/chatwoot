module Instagram::IntegrationHelper
  REQUIRED_SCOPES = %w[instagram_business_basic instagram_business_manage_messages].freeze
  OAUTH_STATE_JTI_REDIS_KEY = 'OAUTH_STATE_JTI::instagram::%<jti>s'.freeze
  OAUTH_STATE_TTL = 15.minutes.to_i

  # Generates a signed JWT token for Instagram integration
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @param return_to [String, nil] Optional onboarding return hint
  # @param user_id [Integer, nil] Optional initiating administrator user ID
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_instagram_token(account_id, return_to = nil, user_id: nil)
    return if client_secret.blank?

    payload = token_payload(account_id, return_to, user_id: user_id)
    store_oauth_state_jti(payload[:jti], account_id) if payload[:jti].present?
    JWT.encode(payload, client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Instagram token: #{e.message}")
    nil
  end

  def token_payload(account_id, return_to = nil, user_id: nil)
    now = Time.current.to_i
    resolved_user_id = user_id || (defined?(Current) ? Current.user&.id : nil)
    payload = {
      sub: account_id,
      iat: now,
      exp: now + OAUTH_STATE_TTL,
      jti: SecureRandom.hex(16)
    }
    payload[:user_id] = resolved_user_id if resolved_user_id.present?
    payload[:return_to] = return_to if return_to.present?
    payload
  end

  # Verifies and decodes a Instagram JWT token (consumes one-time jti when present)
  #
  # @param token [String] The JWT token to verify
  # @return [Integer, nil] The account ID from the token or nil if invalid
  def verify_instagram_token(token)
    return if token.blank? || client_secret.blank?

    decoded = decode_token(token, client_secret)
    return if decoded.blank?
    return unless consume_oauth_state_jti!(decoded['jti'])

    decoded['sub']
  end

  # Reads the onboarding return hint from a Instagram JWT token, if present.
  def instagram_token_return_to(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)&.dig('return_to')
  end

  private

  def store_oauth_state_jti(jti, account_id)
    key = format(OAUTH_STATE_JTI_REDIS_KEY, jti: jti)
    ::Redis::Alfred.set(key, account_id.to_s, ex: OAUTH_STATE_TTL + 60)
  rescue StandardError => e
    Rails.logger.warn("Failed to store Instagram OAuth JTI in Redis: #{e.message}")
  end

  def consume_oauth_state_jti!(jti)
    return true if jti.blank?

    @consumed_instagram_jtis ||= {}
    return true if @consumed_instagram_jtis[jti]

    key = format(OAUTH_STATE_JTI_REDIS_KEY, jti: jti)
    stored = ::Redis::Alfred.get(key)
    return false if stored.blank?

    ::Redis::Alfred.delete(key)
    @consumed_instagram_jtis[jti] = true
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('INSTAGRAM_APP_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, {
                 algorithm: 'HS256',
                 verify_expiration: true,
                 exp_leeway: 30
               }).first
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Instagram token: #{e.message}")
    nil
  end
end
