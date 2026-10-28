# Sidekiq Web is a separate Rack application, outside the Administrate layout.
# Inject only scoped presentation CSS; do not change jobs, routes or CSP.
require 'sidekiq/web'

class MscSidekiqResponsive
  STYLE = <<~HTML.freeze
    <style id="msc-sidekiq-responsive">
      *, *::before, *::after { box-sizing: border-box; }
      html, body { width: 100%; max-width: 100vw; margin: 0; overflow-x: hidden !important; }
      #page, #page .container { max-width: 100%; min-width: 0; }
      .navbar { max-width: 100vw; overflow-x: hidden; }
      .navbar .container { max-width: 100%; }
      .navbar-nav { display: flex; flex-wrap: wrap; }
      .navbar-nav > li { float: none; }
      .table-responsive { max-width: 100%; overflow-x: auto; }
      canvas, svg, img { max-width: 100%; }
      footer { display: flex; flex-wrap: wrap; gap: 8px; max-width: 100%; }
      footer > * { max-width: 100%; overflow-wrap: anywhere; }
      @media(max-width: 991px) {
        .container { width: auto !important; margin-left: 0; margin-right: 0; padding-left: 15px; padding-right: 15px; }
        .navbar-header, .navbar-nav { float: none !important; }
        .navbar-nav { margin: 0; }
        .summary_bar { max-width: 100%; overflow-x: auto; }
        .summary_bar > * { max-width: 100%; }
        .pull-right { max-width: 100%; }
        .content { max-width: 100vw; overflow-x: hidden; }
      }
      @media(prefers-color-scheme:dark) {
        body, #page { background:#04090D !important; color:#CBD5E1 !important; }
        a { color:#10B981; }
        .navbar, .summary { background:#081218 !important; border-color:#132631 !important; }
      }
    </style>
  HTML

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [status, headers, body] unless headers['content-type'].to_s.include?('text/html')

    html = +''
    body.each { |part| html << part }
    body.close if body.respond_to?(:close)
    html.sub!('</head>', "#{STYLE}</head>")
    headers = headers.dup
    headers.delete('content-length')
    headers['content-length'] = html.bytesize.to_s
    [status, headers, [html]]
  end
end

Sidekiq::Web.use MscSidekiqResponsive
