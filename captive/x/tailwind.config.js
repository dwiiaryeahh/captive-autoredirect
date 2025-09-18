/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './views/**/*.ejs',
  ],
  theme: {
    extend: {
      colors: {
        'twitter-blue': '#1d9bf0',
        'twitter-black': '#000000',
        'twitter-dark': '#242d35',
        'twitter-gray': '#71767b',
        'twitter-border': '#333639',
      }
    },
  },
  plugins: [],
};
