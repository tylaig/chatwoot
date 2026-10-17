class Shopify::ShopDomain
  FORMAT = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.myshopify\.(?:com|io)\z/

  def self.normalize(value)
    cleaned = value.to_s.strip.downcase
    return '' if cleaned.blank?

    cleaned = cleaned.sub(%r{\Ahttps?://}, '').sub(%r{/.*\z}, '')
    return cleaned if cleaned.match?(FORMAT)

    slug = cleaned
           .sub(/\.(com\.br|com|net|org|io|store|shop)\z/, '')
           .gsub(/[^a-z0-9-]+/, '-')
           .gsub(/\A-+|-+\z/, '')
    slug.present? ? "#{slug}.myshopify.com" : cleaned
  end

  def self.valid?(value)
    normalize(value).match?(FORMAT)
  end
end
