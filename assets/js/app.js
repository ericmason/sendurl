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
import {hooks as colocatedHooks} from "phoenix-colocated/sendurl"
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

function upcaseInput(el) {
  const start = el.selectionStart
  const end = el.selectionEnd
  const upper = el.value.toUpperCase()
  if (el.value !== upper) {
    el.value = upper
    try { el.setSelectionRange(start, end) } catch (_) {}
  }
}

const Hooks = {
  RememberInput: {
    mounted() {
      const key = this.el.dataset.rememberKey || `remember:${this.el.id}`
      const maxAge = parseInt(this.el.dataset.rememberMaxAge || "3600000", 10)
      const upcase = this.el.dataset.upcase === "true"

      if (upcase) upcaseInput(this.el)

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

      if (upcase) {
        this.el.addEventListener("input", () => upcaseInput(this.el))
      }

      this.el.addEventListener("focus", () => {
        if (this.el.value) {
          setTimeout(() => this.el.select(), 0)
        }
      })
    }
  },

  ClearInput: {
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
  },

  Copy: {
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
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

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

