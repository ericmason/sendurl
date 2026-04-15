// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(text).then(() => true).catch(() => legacyCopy(text))
  }
  return Promise.resolve(legacyCopy(text))
}

function legacyCopy(text) {
  const ta = document.createElement("textarea")
  ta.value = text
  ta.setAttribute("readonly", "")
  ta.style.position = "fixed"
  ta.style.top = "0"
  ta.style.left = "0"
  ta.style.opacity = "0"
  document.body.appendChild(ta)
  ta.focus()
  ta.select()
  ta.setSelectionRange(0, text.length)
  let ok = false
  try { ok = document.execCommand("copy") } catch (_) { ok = false }
  document.body.removeChild(ta)
  return ok
}

let Hooks = {}
Hooks.RememberInput = {
  mounted() {
    const key = this.el.dataset.rememberKey || `remember:${this.el.id}`
    const maxAge = parseInt(this.el.dataset.rememberMaxAge || "3600000", 10)

    if (!this.el.value) {
      try {
        const raw = localStorage.getItem(key)
        if (raw) {
          const { value, ts } = JSON.parse(raw)
          if (value && Date.now() - ts < maxAge) {
            this.el.value = value
            this.el.dispatchEvent(new Event("input", { bubbles: true }))
          } else {
            localStorage.removeItem(key)
          }
        }
      } catch (_) {}
    }

    const save = () => {
      if (this.el.value) {
        try {
          localStorage.setItem(key, JSON.stringify({ value: this.el.value, ts: Date.now() }))
        } catch (_) {}
      }
    }
    this.el.addEventListener("change", save)
    this.el.addEventListener("blur", save)

    this.el.addEventListener("focus", () => {
      if (this.el.value) {
        setTimeout(() => this.el.select(), 0)
      }
    })
  }
}
Hooks.ClearInput = {
  mounted() {
    this.el.addEventListener("click", () => {
      const target = document.getElementById(this.el.dataset.target)
      if (!target) return
      target.value = ""
      target.dispatchEvent(new Event("input", { bubbles: true }))
      target.focus()
      const key = this.el.dataset.clearKey
      if (key) {
        try { localStorage.removeItem(key) } catch (_) {}
      }
    })
  }
}
Hooks.Copy = {
  mounted() {
    this.el.addEventListener("click", () => {
      Promise.resolve(copyText(this.el.dataset.text)).then((ok) => {
        const original = this.el.textContent
        this.el.textContent = ok ? "Copied!" : "Copy failed"
        setTimeout(() => { this.el.textContent = original }, 1500)
      })
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket


// Update the contents of #url_receiver_id to upper case on keyup
function makeUpperCase(e) {
  var start = e.target.selectionStart;
  var end = e.target.selectionEnd;
  e.target.value = e.target.value.toUpperCase();
  e.target.selectionStart = start;
  e.target.selectionEnd = end;
}

var receiverIdField = document.getElementById("url_receiver_id");
if (receiverIdField) {
  receiverIdField.addEventListener("keyup", makeUpperCase);
  receiverIdField.addEventListener("change", makeUpperCase);
}