import {defineConfig} from 'vite'
import vue from '@vitejs/plugin-vue'
import vueJsx from '@vitejs/plugin-vue-jsx'
import vueDevTools from 'vite-plugin-vue-devtools'
import {fileURLToPath, URL} from 'node:url'

export default defineConfig({
  plugins: [vue(), vueJsx(), vueDevTools()],

  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },

  server: {
    port: 5173,
    strictPort: true,
    host: '0.0.0.0', // 监听所有网络接口，支持外网访问
    allowedHosts: ['james521.gnway.cc', 'localhost'], // 允许的域名

    // ✅ 关键：开发代理
    proxy: {
      '/api': {
        target: 'http://localhost:8080', // Gin 后端
        changeOrigin: true,
        ws: true, // 支持 WebSocket 代理（终端等功能需要）
      },
    },
  },
})

