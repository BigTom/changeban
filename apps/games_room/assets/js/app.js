// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import {Socket} from "phoenix"
import NProgress from "nprogress"
import { LiveSocket } from "phoenix_live_view"
import Chart from "chart.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")


var makeChart = (ctx) => new Chart(ctx, {
  type: 'line', // The type of chart we want to create
  data: {
    labels: 0, // The data for our dataset
    datasets: [
      {
        label: 'Complete',
        backgroundColor: '#666666',
        borderColor: '#666666',
        data: [0],
        lineTension: 0,
        fill: 'origin'
      },
      {
        label: 'Verify Performance',
        backgroundColor: '#888888',
        borderColor: '#888888',
        data: [0],
        lineTension: 0,
        fill: 'origin'
      },
      {
        label: 'Validate Adoption',
        backgroundColor: '#aaaaaa',
        borderColor: '#aaaaaa',
        data: [0],
        lineTension: 0,
        fill: 'origin'
      },
      {
      label: 'Negotiate Change',
      backgroundColor: '#cccccc',
      borderColor: '#cccccc',
      data: [0],
      lineTension: 0,
      fill: 'origin'
      }
    ]
  },
  options: { // Configuration options go here
    scales: {
      yAxes: [{
        stacked: true,
        ticks: {
          max: 16,
          min: 0,
          stepSize: 1
        }
      }]
    },
    elements: {
      point:{
          radius: 0
      }
  }
  }
});

let hooks = {}
hooks.chart = {
  mounted() {
    var ctx = this.el.getContext('2d');
    var chart = makeChart(ctx);

    this.handleEvent("line_cfd", ({
      x
    }) => {
      chart.data.datasets[0].data = x.data[3]
      chart.data.datasets[1].data = x.data[2]
      chart.data.datasets[2].data = x.data[1]
      chart.data.datasets[3].data = x.data[0]
      chart.data.labels = x.headers
      chart.update()
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
