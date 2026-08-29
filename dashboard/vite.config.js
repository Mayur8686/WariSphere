import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const apiProxy = {
  '/lost-person': { target: 'http://127.0.0.1:8000', changeOrigin: true },
  '/uploads': { target: 'http://127.0.0.1:8000', changeOrigin: true },
  '/sos': { target: 'http://127.0.0.1:8000', changeOrigin: true },
  '/health': { target: 'http://127.0.0.1:8000', changeOrigin: true },
  '/firebase-health': { target: 'http://127.0.0.1:8000', changeOrigin: true },
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: true,
    proxy: apiProxy,
  },
  preview: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: true,
    proxy: apiProxy,
  },
})
