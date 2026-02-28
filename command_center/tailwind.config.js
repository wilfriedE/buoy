/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./public/**/*.html', './server.js'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        buoy: { bg: '#0f172a', card: '#1e293b', accent: '#38bdf8', muted: '#64748b' },
      },
    },
  },
  plugins: [],
};
