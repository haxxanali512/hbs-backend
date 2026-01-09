/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/views/**/*.pdf.erb',
    './app/views/**/*.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/assets/tailwind/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      fontFamily: {
        'sans': ['Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', 'Apple Color Emoji', 'Segoe UI Emoji'],
        'inter': ['Inter', 'sans-serif'],
      },
      colors: {
        'primary-blue': '#173D6C',
        'primary-blue-50': '#173D6C80',
        'primary-green': '#2FAD6F',
        'primary-green-50': '#2FAD6F80',
        // Override Tailwind's blue and indigo to use our primary colors
        'blue': {
          50: '#E6EDF5',
          100: '#CCDBEB',
          200: '#99B7D7',
          300: '#6693C3',
          400: '#336FAF',
          500: '#173D6C',
          600: '#173D6C',
          700: '#173D6C80', // Half opacity for hover
          800: '#0A1D33',
          900: '#05101D',
        },
        'indigo': {
          50: '#E6EDF5',
          100: '#CCDBEB',
          200: '#99B7D7',
          300: '#6693C3',
          400: '#336FAF',
          500: '#173D6C',
          600: '#173D6C',
          700: '#173D6C80', // Half opacity for hover
          800: '#0A1D33',
          900: '#05101D',
        },
      },
    },
  },
  plugins: [],
}
