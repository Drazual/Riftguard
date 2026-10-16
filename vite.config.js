import { defineConfig } from 'vite';
import { readFileSync } from 'fs';

// The build's version (CI sets the patch number before building) is shown on the main menu.
const { version } = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

export default defineConfig({
  base: './',
  build: { chunkSizeWarningLimit: 2000 },
  define: { __APP_VERSION__: JSON.stringify(version) },
});
