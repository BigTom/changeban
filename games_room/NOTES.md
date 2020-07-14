# Tailwind setup
#### add required packages to assets directory
```
cd assets
npx tailwindcss init
yarn add -D tailwindcss
yarn add -D postcss-loader
yarn add -D postcss-import
yarn add -D @fullhuman/postcss-purgecss
yarn add -D autoprefixer
```

#### Update webpack.config.js
In: ```module.exports/module/rules/2 (MiniCssExtractPlugin.loader)```
```javascript
use: [
  MiniCssExtractPlugin.loader,
  'css-loader',
  'postcss-loader',
],
```

#### Add postcss.config.js
```javascript
const purgecss = require("@fullhuman/postcss-purgecss")({
  content: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/views/**/*.ex",
    "./js/**/*.js"
  ],
  defaultExtractor: content => content.match(/[\w-/:]+(?<!:)/g) || []
});

module.exports = {
  plugins: [
    require('postcss-import'),
    require('tailwindcss'),
    require('autoprefixer'),
    ...(process.env.NODE_ENV === 'production' ? [purgecss] : [])
  ]
}
```
(the last line is to ensure purgecss only purges in production)

#### Update app.css
Rename app.scss to app.css

Replace all content with:
```css
/* Cannot use @tailwind to import because we want postcss-import so we can use @apply inside included files */

@import "tailwindcss/base";
@import "tailwindcss/component";
@import "tailwindcss/utilities"
```
You can delete ```phoenix.css``` as it won't be used

https://javisperez.github.io/tailwindcolorshades/#/ is a site to define additional colors

They can be added to tailwind in the ```theme/extend``` section of ```tailwind.config.js```