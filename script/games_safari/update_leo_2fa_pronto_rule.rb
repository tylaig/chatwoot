# frozen_string_literal: true

# One-shot ops patch for Games Safari Leo assistants.
# Appends an anti-loop rule for repeated "Pronto" during Microsoft/Xbox 2FA.
#
# Usage (on the VPS container):
#   bundle exec rails runner script/games_safari/update_leo_2fa_pronto_rule.rb

MARKER = 'REGRA PRONTO REPETIDO (ANTI-LOOP)'
RULE = <<~RULE.strip
  #{MARKER}:
  - Quando o cliente responder "Pronto" (ou "já cliquei" / "enviei") depois que você pediu para avisar, chame buscar_codigo_acesso imediatamente.
  - Se a 1ª consulta vier vazia/expirada e o cliente mandar "Pronto" de novo na mesma tentativa, NÃO peça outro "aguarde 1 minuto": consulte buscar_codigo_acesso de novo na hora.
  - Se a 2ª consulta consecutiva ainda vier vazia/expirada, diga claramente que o código ainda não chegou no e-mail de segurança e ofereça: (a) clicar em Reenviar código na tela e avisar de novo, ou (b) atendimento humano via captain--tools--handoff.
  - Na 3ª falha consecutiva da mesma tentativa, faça handoff humano sem novo loop de espera.
RULE

updated = 0
Captain::Assistant.find_each do |assistant|
  guidelines = Array(assistant.response_guidelines)
  next if guidelines.any? { |g| g.to_s.include?(MARKER) }

  # description has a 500-char validation; behavioral rules live in response_guidelines.
  assistant.update_columns(
    response_guidelines: guidelines + [RULE],
    updated_at: Time.current
  )
  updated += 1
  puts "updated assistant id=#{assistant.id} name=#{assistant.name}"
end

puts "done updated=#{updated}"
