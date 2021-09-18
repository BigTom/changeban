module.exports = {
  mode: "jit",
  purge: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
  theme: {
    extend: {
      border: {
        '1': '1px'
      },
      gridTemplateColumns: {
        // Simple 8 row grid
        'cb': '4fr 4fr 4fr 4fr 1fr 1fr 1fr 1fr',
      },
      gridTemplateRows: {
        // Simple 8 row grid
        'cb': '1fr 1fr 1fr 2fr 1fr 1fr 2fr',
      },
      gridColumnStart: {
        '13': '13',
        '14': '14',
        '15': '15',
        '16': '16',
        '17': '17',
        '18': '18',
        '19': '19',
        '20': '20'
      },
      gridColumnEnd: {
        '13': '13',
        '14': '14',
        '15': '15',
        '16': '16',
        '17': '17',
        '18': '18',
        '19': '19',
        '20': '20'
      },
      gridRowStart: {
        '8': '8',
        '9': '9',
        '10': '10',
        '11': '11'
      },
      gridRowEnd: {
        '8': '8',
        '9': '9',
        '10': '10',
        '11': '11'
      }
    },
    keyframes: {
      arrive: {
        '0%, 20%, 40%, 60%, 80%, 100%': { transform: 'translate(0px, 0px)' },
        '10%': { transform: 'translate(0px, -10px)' },
        '30%': { transform: 'translate(0px, -8px)' },
        '50%': { transform: 'translate(0px, -6px)' },
        '70%': { transform: 'translate(0px, -4px)' },
        '90%': { transform: 'translate(0px, -2px)' },
      }
    },
    animation: {
      arrive: 'arrive 1s ease-in-out'
    }
  },
  variants: {},
  plugins: [
    require('@tailwindcss/typography')
  ],
}
