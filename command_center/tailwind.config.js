/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./public/**/*.html', './server.js'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        buoy: {
          bg: '#0f172a',
          card: '#1e293b',
          accent: '#38bdf8',
          accentA11y: '#7dd3fc', /* sky-300, ~6:1 on dark for WCAG AA */
          muted: '#64748b',
          mutedA11y: '#94a3b8', /* slate-400, ~4.9:1 on dark */
        },
      },
    },
  },
  plugins: [],
};
