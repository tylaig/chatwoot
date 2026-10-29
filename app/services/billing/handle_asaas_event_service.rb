# frozen_string_literal: true

class Billing::HandleAsaasEventService
  PAYMENT_CONFIRMED_EVENTS = %w[
    PAYMENT_CONFIRMED
    PAYMENT_RECEIVED
    PAYMENT_DUNNING_RECEIVED
  ].freeze

  PAYMENT_OVERDUE_EVENTS = %w[
    PAYMENT_OVERDUE
  ].freeze

  CANCELED_EVENTS = %w[
    PAYMENT_REFUNDED
    PAYMENT_DELETED
    SUBSCRIPTION_DELETED
    SUBSCRIPTION_INACTIVATED
  ].freeze

  SUBSCRIPTION_ACTIVE_EVENTS = %w[
    SUBSCRIPTION_CREATED
    SUBSCRIPTION_UPDATED
  ].freeze

  def initialize(payload:)
    @payload = (payload || {}).with_indifferent_access
  end

  def perform
    event_type = @payload[:event].to_s.strip.upcase
    return { status: 'ignored', reason: 'missing_event' } if event_type.blank?
    return { status: 'duplicate', event_id: event_id } unless acquire_idempotency_lock

    result = dispatch_event(event_type)
    mark_event_processed
    result
  rescue StandardError => e
    release_idempotency_lock
    raise e
  end

  private

  def event_id
    @event_id ||= @payload[:id].presence ||
                  "#{@payload[:event]}_#{payment_data[:id] || subscription_data[:id]}_#{@payload[:dateCreated]}"
  end

  def idempotency_key
    "msc:billing:asaas:event:#{event_id}"
  end

  def acquire_idempotency_lock
    return true if event_id.blank? || !defined?(::Redis::Alfred)

    @lock_acquired = ::Redis::Alfred.set(idempotency_key, 'processing', nx: true, ex: 1.day.to_i)
    @lock_acquired.present?
  rescue StandardError
    true
  end

  def mark_event_processed
    return if event_id.blank? || !defined?(::Redis::Alfred)

    ::Redis::Alfred.set(idempotency_key, 'processed', ex: 7.days.to_i)
  rescue StandardError
    nil
  end

  def release_idempotency_lock
    return unless @lock_acquired && event_id.present? && defined?(::Redis::Alfred)

    ::Redis::Alfred.delete(idempotency_key)
  rescue StandardError
    nil
  end

  def dispatch_event(event_type)
    account = resolve_account
    return { status: 'ignored', reason: 'account_not_found', event: event_type } if account.blank?

    if PAYMENT_CONFIRMED_EVENTS.include?(event_type) || SUBSCRIPTION_ACTIVE_EVENTS.include?(event_type)
      activate_or_upgrade_account!(account, event_type)
    elsif PAYMENT_OVERDUE_EVENTS.include?(event_type)
      mark_account_past_due!(account, event_type)
    elsif CANCELED_EVENTS.include?(event_type)
      downgrade_or_cancel_account!(account, event_type)
    else
      { status: 'ignored', reason: 'unhandled_event', event: event_type, account_id: account.id }
    end
  end

  def activate_or_upgrade_account!(account, event_type)
    tier_key = resolve_tier_key(account)
    seats = extract_seats
    custom_limits = seats.positive? ? { agents: seats } : {}

    account.with_lock do
      custom_attrs = (account.custom_attributes || {}).dup
      custom_attrs['billing_provider'] = 'asaas'
      custom_attrs['asaas_customer_id'] = customer_id if customer_id.present?
      custom_attrs['asaas_subscription_id'] = subscription_id if subscription_id.present?
      custom_attrs['asaas_payment_id'] = payment_data[:id] if payment_data[:id].present?
      custom_attrs['subscription_status'] = 'active'
      custom_attrs['subscription_ends_on'] = next_due_date if next_due_date.present?
      custom_attrs['subscription_cancels_on'] = nil
      custom_attrs['last_billing_event'] = event_type
      custom_attrs['last_billing_at'] = Time.current.iso8601
      account.update!(custom_attributes: custom_attrs)

      EliteLicenseEngine.apply_tier_to_account!(
        account,
        tier_key,
        custom_limits: custom_limits,
        sync_sidebar: false
      )
    end

    { status: 'processed', action: 'activated', account_id: account.id, tier: tier_key }
  end

  def mark_account_past_due!(account, event_type)
    custom_attrs = (account.custom_attributes || {}).dup
    custom_attrs['billing_provider'] = 'asaas'
    custom_attrs['asaas_customer_id'] = customer_id if customer_id.present?
    custom_attrs['subscription_status'] = 'past_due'
    custom_attrs['last_billing_event'] = event_type
    custom_attrs['last_billing_at'] = Time.current.iso8601
    account.update!(custom_attributes: custom_attrs)

    { status: 'processed', action: 'past_due', account_id: account.id }
  end

  def downgrade_or_cancel_account!(account, event_type)
    account.with_lock do
      custom_attrs = (account.custom_attributes || {}).dup
      custom_attrs['billing_provider'] = 'asaas'
      custom_attrs['subscription_status'] = 'canceled'
      custom_attrs['subscription_cancels_on'] = Time.current.iso8601
      custom_attrs['last_billing_event'] = event_type
      custom_attrs['last_billing_at'] = Time.current.iso8601
      account.update!(custom_attributes: custom_attrs)

      EliteLicenseEngine.apply_tier_to_account!(
        account,
        'starter',
        sync_sidebar: false
      )
    end

    { status: 'processed', action: 'downgraded_to_starter', account_id: account.id }
  end

  def payment_data
    @payment_data ||= (@payload[:payment] || {}).with_indifferent_access
  end

  def subscription_data
    @subscription_data ||= (@payload[:subscription] || {}).with_indifferent_access
  end

  def external_reference
    @external_reference ||= (
      payment_data[:externalReference].presence ||
      subscription_data[:externalReference].presence ||
      @payload[:externalReference].presence
    ).to_s.strip
  end

  def parsed_reference
    @parsed_reference ||= begin
      ref = {}
      if external_reference.present?
        if external_reference.start_with?('{')
          ref = JSON.parse(external_reference).with_indifferent_access rescue {}
        else
          acct_match = external_reference.match(/(?:account|acc|acct)[_:\-](\d+)/i)
          tier_match = external_reference.match(/(?:tier|plan)[_:\-]([a-z_]+)/i)
          seats_match = external_reference.match(/(?:seats|agents)[_:\-](\d+)/i)
          ref[:account_id] = acct_match[1].to_i if acct_match
          ref[:account_id] ||= external_reference.to_i if external_reference.match?(/\A\d+\z/)
          ref[:tier] = tier_match[1] if tier_match
          ref[:seats] = seats_match[1].to_i if seats_match
        end
      end
      ref.with_indifferent_access
    end
  end

  def customer_id
    payment_data[:customer].presence || subscription_data[:customer].presence || @payload[:customer].presence
  end

  def subscription_id
    payment_data[:subscription].presence || subscription_data[:id].presence
  end

  def next_due_date
    raw_date = payment_data[:dueDate].presence || subscription_data[:nextDueDate].presence
    return nil if raw_date.blank?

    Time.zone.parse(raw_date.to_s)&.as_json
  rescue StandardError
    nil
  end

  def resolve_account
    acct_id = @payload[:account_id].presence ||
              payment_data.dig(:metadata, :account_id).presence ||
              subscription_data.dig(:metadata, :account_id).presence ||
              parsed_reference[:account_id].presence

    if acct_id.present?
      found = Account.find_by(id: acct_id)
      return found if found
    end

    if customer_id.present?
      found = Account.where("custom_attributes->>'asaas_customer_id' = ?", customer_id.to_s).first
      return found if found
    end

    if subscription_id.present?
      found = Account.where("custom_attributes->>'asaas_subscription_id' = ?", subscription_id.to_s).first
      return found if found
    end

    email = payment_data[:customerEmail].presence ||
            subscription_data[:customerEmail].presence ||
            @payload[:email].presence ||
            parsed_reference[:email].presence
    if email.present?
      user = User.find_by(email: email.to_s.strip.downcase)
      return user.accounts.order(:id).first if user&.accounts&.any?
    end

    nil
  end

  def resolve_tier_key(account)
    raw = @payload[:plan_tier].presence ||
          @payload[:tier].presence ||
          payment_data.dig(:metadata, :plan_tier).presence ||
          subscription_data.dig(:metadata, :plan_tier).presence ||
          parsed_reference[:tier].presence ||
          payment_data[:description].presence ||
          subscription_data[:description].presence

    EliteLicenseEngine.resolve_billing_tier_key(raw) ||
      infer_tier_from_value(payment_data[:value] || subscription_data[:value]) ||
      EliteLicenseEngine.account_tier_key(account)
  end

  def infer_tier_from_value(amount)
    val = amount.to_f
    return nil if val <= 0

    if val >= 900
      'business'
    elsif val >= 400
      'pro'
    else
      'starter'
    end
  end

  def extract_seats
    (
      @payload[:seats].presence ||
      payment_data.dig(:metadata, :seats).presence ||
      subscription_data.dig(:metadata, :seats).presence ||
      parsed_reference[:seats].presence ||
      0
    ).to_i
  end
end
