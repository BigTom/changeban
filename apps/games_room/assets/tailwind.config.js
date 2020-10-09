module.exports = {
  purge: [],
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

  }

  },
  variants: {},
  plugins: [
    require('@tailwindcss/typography')
  ],
}
