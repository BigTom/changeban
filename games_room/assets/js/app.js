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
import {LiveSocket} from "phoenix_live_view"

let Hooks = {}
Hooks.SetSession = {
  DEBOUNCE_MS: 200,

  // Called when a LiveView is mounted, if it includes an element that uses this hook.
  mounted() {
    // `this.el` is the form.
    this.el.addEventListener("input", (e) => {
      console.log("---------------- SetSession hook --------------------")
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        // Ajax request to update session.
        fetch(`/api/session?${e.target.name}=${encodeURIComponent(e.target.value)}`, { method: "post" })

        // Optionally, include this so other LiveViews can be notified of changes.
        // this.pushEventTo(".phx-hook-subscribe-to-session", "updated_session_data", [e.target.name, e.target.value])
      }, this.DEBOUNCE_MS)
    })
  },
 }


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
// Modifying this pre-existing code to include the hook.
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket



