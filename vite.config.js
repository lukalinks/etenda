import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  
  return {
    define: {
      'process.env.VITE_WALLETCONNECT_PROJECT_ID': JSON.stringify(env.VITE_WALLETCONNECT_PROJECT_ID),
      'process.env.VITE_ALCHEMY_API_KEY': JSON.stringify(env.VITE_ALCHEMY_API_KEY),
      'process.env.VITE_CONTRACT_ADDRESS': JSON.stringify(env.VITE_CONTRACT_ADDRESS),
    },
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    build: {
      outDir: 'dist',
      assetsDir: 'assets',
      rollupOptions: {
        external: [
          'wagmi',
          'viem'
        ],
        output: {
          globals: {
            'wagmi': 'wagmi',
            'viem': 'viem'
          }
        }
      },
      commonjsOptions: {
        include: [/node_modules/],
        transformMixedEsModules: true
      },
      chunkSizeWarningLimit: 1600
    },
    optimizeDeps: {
      include: [
        'react',
        'react-dom',
        'react-router-dom',
        '@rainbow-me/rainbowkit',
        '@tanstack/react-query',
        'wagmi',
        'viem',
        'framer-motion'
      ]
    }
  }
})
