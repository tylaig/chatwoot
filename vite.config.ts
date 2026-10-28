import v8 from 'node:v8';
import { spawnSync } from 'node:child_process';
import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { aliases, vueOptions } from './vite.shared';
import yaml from '@rollup/plugin-yaml';

if (
  process.argv.includes('build') &&
  !process.env.VITEST &&
  !process.env.CW_VITE_HEAP_BOOSTED &&
  v8.getHeapStatistics().heap_size_limit < 3_500_000_000
) {
  const existingNodeOptions = (process.env.NODE_OPTIONS || '')
    .replace(/--max-old-space-size=\d+/g, '')
    .trim();
  const result = spawnSync(
    process.execPath,
    ['--max-old-space-size=4096', ...process.execArgv, ...process.argv.slice(1)],
    {
      stdio: 'inherit',
      env: {
        ...process.env,
        CW_VITE_HEAP_BOOSTED: '1',
        NODE_OPTIONS: `${existingNodeOptions} --max-old-space-size=4096`.trim(),
      },
    }
  );
  process.exit(result.status ?? 1);
}

export default defineConfig({
  plugins: [ruby(), vue(vueOptions), yaml()],
  build: {
    sourcemap: false,
    reportCompressedSize: false,
  },
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
  resolve: { alias: aliases },
});
