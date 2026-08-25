// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/tracms"
import topbar from "../vendor/topbar"

const CertificateLayoutLineDetection = {
  mounted() {
    this.detect()
  },
  updated() {
    this.detect()
  },
  detect() {
    const image = this.el
    if (!image.complete || !image.naturalWidth) {
      image.addEventListener("load", () => this.detect(), {once: true})
      return
    }

    const signature = `${image.currentSrc}:${image.naturalWidth}x${image.naturalHeight}`
    if (this.lastSignature === signature) return
    this.lastSignature = signature

    const position = this.findNameLine(image)
    if (position == null) return

    this.pushEvent("detect_participant_name_line", {
      asset_path: image.dataset.assetPath,
      position: position.toFixed(2),
    })
  },
  findNameLine(image) {
    const scale = Math.min(1, 1800 / image.naturalWidth)
    const width = Math.round(image.naturalWidth * scale)
    const height = Math.round(image.naturalHeight * scale)
    const canvas = document.createElement("canvas")
    canvas.width = width
    canvas.height = height
    const context = canvas.getContext("2d", {willReadFrequently: true})
    context.drawImage(image, 0, 0, width, height)

    const pixels = context.getImageData(0, 0, width, height).data
    const left = Math.floor(width * 0.15)
    const right = Math.ceil(width * 0.85)
    const minimumLength = (right - left) * 0.28
    let best = null

    for (let y = Math.floor(height * 0.32); y < Math.ceil(height * 0.58); y += 1) {
      let run = 0
      let longest = 0

      for (let x = left; x < right; x += 1) {
        const offset = (y * width + x) * 4
        const luminance = pixels[offset] * 0.213 + pixels[offset + 1] * 0.715 + pixels[offset + 2] * 0.072

        if (luminance < 150 && pixels[offset + 3] > 180) {
          run += 1
          longest = Math.max(longest, run)
        } else {
          run = 0
        }
      }

      if (longest < minimumLength) continue
      const score = longest * (1 - Math.abs(y / height - 0.4))
      if (!best || score > best.score) best = {score, y}
    }

    // Store the underline position with a slight gap so the name rests just above it.
    return best ? Math.max(15, Math.min(75, (best.y / height) * 100 - 0.2)) : null
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, CertificateLayoutLineDetection},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

window.addEventListener("click", event => {
  const trigger = event.target.closest("[data-print-certificate]")

  if (!trigger) return

  event.preventDefault()
  window.print()
})

window.addEventListener("click", event => {
  document.querySelectorAll("details.account-menu[open]").forEach(menu => {
    if (!menu.contains(event.target)) menu.removeAttribute("open")
  })
})

window.addEventListener("keydown", event => {
  if (event.key !== "Escape") return

  document.querySelectorAll("details.account-menu[open]").forEach(menu => {
    menu.removeAttribute("open")
  })
})

window.addEventListener("load", () => {
  if (document.body?.dataset?.certificateAutoprint === "true") {
    window.setTimeout(() => window.print(), 180)
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
