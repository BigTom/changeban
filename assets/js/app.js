// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
// import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "./vendor/some-package.js"
//
// Alternatively, you can `npm install some-package` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
// -- Alpine
// import Alpine from "alpinejs";
// -- Chart
import Chart from 'chart.js/auto';

// Add this before your liveSocket call.
// window.Alpine = Alpine;
// Alpine.start();

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

var makeCFD = (ctx) => new Chart(ctx, {
  type: 'line', // The type of chart we want to create
  data: {
    // labels: 0, // The data for our dataset
    datasets: [{
        label: 'Complete',
        backgroundColor: '#666666',
        borderColor: '#666666',
        borderWidth: 0,
        data: [0],
        lineTension: 0,
        fill: 'origin'
      },
      {
        label: 'Verify Performance',
        backgroundColor: '#888888',
        borderColor: '#888888',
        borderWidth: 0,
        data: [0],
        lineTension: 0,
        fill: 'origin'
      },
      {
        label: 'Validate Adoption',
        backgroundColor: '#aaaaaa',
        borderColor: '#aaaaaa',
        borderWidth: 0,
        data: [0],
        lineTension: 0,
        fill: 'origin'
      },
      {
        label: 'Negotiate Change',
        backgroundColor: '#cccccc',
        borderColor: '#cccccc',
        borderWidth: 0,
        data: [0],
        lineTension: 0,
        fill: 'origin'
      }
    ]
  },
  options: { // Configuration options go here
    scales: {
      y: {
        stacked: true,
        title: {
          display: true,
          text: 'Ticket Count'
        },
        ticks: {
          max: 16,
          min: 0,
          stepSize: 1
        }
      },
      x: {
        title: {
          display: true,
          text: 'Day'
        },
        position: 'bottom',
        ticks: {
          suggestedMax: 10,
          min: 0,
          stepSize: 5
        }
      }
    },
    elements: {
      point: {
        radius: 0
      }
    },
    legend: {
      reverse: true
    }
  }
});

var makeAge = (ctx) => new Chart(ctx, {
  type: 'scatter', // The type of chart we want to create
  data: {
    labels: 0, // The data for our dataset
    datasets: [{
      data: [],
      label: "Ticket Age",
      backgroundColor: '#666666',
    }]
  },
  options: { // Configuration options go here
    scales: {
      yAxes: [{
        scaleLabel: {
          display: true,
          labelString: 'Ticket Age'
        },
        ticks: {
          suggestedMax: 10,
          min: 0,
          stepSize: 1
        }
      }],
      xAxes: [{
        scaleLabel: {
          display: true,
          labelString: 'Day Completed'
        },
        position: 'bottom',
        ticks: {
          suggestedMax: 10,
          min: 0,
          stepSize: 1
        }
      }]
    }
  }
});

let Hooks = {}
Hooks.cfd = {
  mounted() {
    var ctx = this.el.getContext('2d');
    var chart = makeCFD(ctx);

    this.handleEvent("chart_data", ({
      cfd
    }) => {
      chart.data.datasets[0].data = cfd.data[3]
      chart.data.datasets[1].data = cfd.data[2]
      chart.data.datasets[2].data = cfd.data[1]
      chart.data.datasets[3].data = cfd.data[0]
      chart.data.labels = cfd.turns
      chart.update()
    })
  }
}
Hooks.age = {
  mounted() {
    var ctx = this.el.getContext('2d');
    var chart = makeAge(ctx);

    this.handleEvent("chart_data", ({
      age
    }) => {
      chart.data.datasets[0].data = age.data
      chart.data.labels = age.turns
      chart.update()
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken
  },
  hooks: Hooks
  // dom: {
  //   onBeforeElUpdated(from, to) {
  //     if (from._x_dataStack) {
  //       window.Alpine.clone(from, to);
  //     }
  //   },
  // },
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: {
    0: "#29d"
  },
  shadowColor: "rgba(0, 0, 0, .3)"
})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
