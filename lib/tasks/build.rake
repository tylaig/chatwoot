# ref: https://github.com/rails/rails/issues/43906#issuecomment-1094380699
# https://github.com/rails/rails/issues/43906#issuecomment-1099992310
task before_assets_precompile: :environment do
  unless ENV['NODE_OPTIONS'].to_s.include?('--max-old-space-size')
    ENV['NODE_OPTIONS'] = [ENV['NODE_OPTIONS'], '--max-old-space-size=4096'].compact.join(' ').strip
  end
  # run a command which starts your packaging
  system('pnpm install')
  system('echo "-------------- Bulding SDK for Production --------------"')
  system('pnpm run build:sdk')
  system('echo "-------------- Bulding App for Production --------------"')
end

# every time you execute 'rake assets:precompile'
# run 'before_assets_precompile' first
Rake::Task['assets:precompile'].enhance %w[before_assets_precompile]
