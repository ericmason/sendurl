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

const ICE_SERVERS = [{ urls: "stun:stun.l.google.com:19302" }]
const CHUNK_SIZE = 16 * 1024
const BUFFERED_LOW = 256 * 1024
const BUFFERED_HIGH = 1024 * 1024

function humanSize(bytes) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
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
  },

  WebRTCSender: {
    mounted() {
      this.button = this.el
      this.receiverInput = document.getElementById(this.el.dataset.receiverInput)
      this.fileInput = document.getElementById(this.el.dataset.fileInput)
      this.statusEl = document.getElementById(this.el.dataset.status)
      this.progressEl = document.getElementById(this.el.dataset.progress)

      this.pc = null
      this.dc = null
      this.receiverId = null
      this.queuedCandidates = []

      this.handleEvent("rtc_signal", (signal) => this.onSignal(signal))

      this.button.addEventListener("click", () => this.start())
    },

    start() {
      const rid = (this.receiverInput.value || "").trim().toUpperCase()
      if (!/^[A-Z0-9]{6}$/.test(rid)) {
        this.setStatus("Enter a valid 6-character Receiver ID above.")
        return
      }
      const files = Array.from(this.fileInput.files || [])
      if (files.length === 0) {
        this.setStatus("Pick a file to send.")
        return
      }

      this.receiverId = rid
      this.files = files
      this.currentFileIndex = 0
      this.resetProgress()
      this.cleanupConnection()

      this.setStatus(`Connecting to ${rid}…`)

      this.pc = new RTCPeerConnection({ iceServers: ICE_SERVERS })
      this.pc.onicecandidate = (e) => {
        if (e.candidate) {
          this.sendSignal({ type: "ice", candidate: e.candidate.toJSON() })
        }
      }
      this.pc.onconnectionstatechange = () => {
        const s = this.pc && this.pc.connectionState
        if (s === "failed" || s === "disconnected" || s === "closed") {
          this.setStatus(`Connection ${s}.`)
        }
      }

      this.dc = this.pc.createDataChannel("file", { ordered: true })
      this.dc.binaryType = "arraybuffer"
      this.dc.bufferedAmountLowThreshold = BUFFERED_LOW
      this.dc.onopen = () => {
        this.setStatus("Connected. Sending…")
        this.sendNextFile()
      }
      this.dc.onerror = (err) => {
        console.error("DataChannel error", err)
        this.setStatus("Send error.")
      }
      this.dc.onclose = () => {
        if (this.currentFileIndex < this.files.length) {
          this.setStatus("Channel closed before transfer completed.")
        }
      }

      this.pc.createOffer()
        .then((offer) => this.pc.setLocalDescription(offer))
        .then(() => this.sendSignal({ type: "offer", sdp: this.pc.localDescription.toJSON() }))
        .catch((err) => {
          console.error("Offer error", err)
          this.setStatus("Failed to start WebRTC.")
        })
    },

    sendSignal(signal) {
      this.pushEvent("rtc_signal", { receiver_id: this.receiverId, signal })
    },

    onSignal(signal) {
      if (!this.pc) return

      if (signal.type === "answer") {
        this.pc.setRemoteDescription(signal.sdp)
          .then(() => {
            this.queuedCandidates.forEach((c) =>
              this.pc.addIceCandidate(c).catch((e) => console.error(e))
            )
            this.queuedCandidates = []
          })
          .catch((e) => {
            console.error("setRemoteDescription failed", e)
            this.setStatus("Handshake failed.")
          })
      } else if (signal.type === "ice" && signal.candidate) {
        if (this.pc.remoteDescription) {
          this.pc.addIceCandidate(signal.candidate).catch(console.error)
        } else {
          this.queuedCandidates.push(signal.candidate)
        }
      }
    },

    async sendNextFile() {
      if (this.currentFileIndex >= this.files.length) {
        this.setStatus(`Sent ${this.files.length} file${this.files.length === 1 ? "" : "s"}.`)
        if (this.progressEl) this.progressEl.classList.add("hidden")
        return
      }

      const file = this.files[this.currentFileIndex]
      this.setStatus(`Sending ${file.name} (${humanSize(file.size)})…`)
      if (this.progressEl) {
        this.progressEl.classList.remove("hidden")
        this.progressEl.value = 0
      }

      this.dc.send(JSON.stringify({
        type: "meta",
        name: file.name,
        size: file.size,
        mime: file.type || "application/octet-stream"
      }))

      let sent = 0
      let offset = 0
      while (offset < file.size) {
        const end = Math.min(offset + CHUNK_SIZE, file.size)
        const buf = await file.slice(offset, end).arrayBuffer()
        await this.waitForDrain()
        this.dc.send(buf)
        sent += buf.byteLength
        offset = end
        if (this.progressEl) {
          this.progressEl.value = Math.round((sent / file.size) * 100)
        }
      }

      this.dc.send(JSON.stringify({ type: "done" }))
      this.currentFileIndex += 1
      // Small yield so the browser can paint progress
      await new Promise((r) => setTimeout(r, 0))
      this.sendNextFile()
    },

    waitForDrain() {
      if (!this.dc) return Promise.resolve()
      if (this.dc.bufferedAmount < BUFFERED_HIGH) return Promise.resolve()
      return new Promise((resolve) => {
        const handler = () => {
          this.dc.removeEventListener("bufferedamountlow", handler)
          resolve()
        }
        this.dc.addEventListener("bufferedamountlow", handler)
      })
    },

    setStatus(msg) {
      if (this.statusEl) this.statusEl.textContent = msg
    },

    resetProgress() {
      if (!this.progressEl) return
      this.progressEl.value = 0
      this.progressEl.classList.add("hidden")
    },

    cleanupConnection() {
      try { this.dc && this.dc.close() } catch (_) {}
      try { this.pc && this.pc.close() } catch (_) {}
      this.dc = null
      this.pc = null
      this.queuedCandidates = []
    },

    destroyed() {
      this.cleanupConnection()
    }
  },

  WebRTCReceiver: {
    mounted() {
      this.pc = null
      this.dc = null
      this.queuedCandidates = []
      this.current = null
      this.statusEl = document.getElementById("receive-file-status")
      this.listEl = document.getElementById("receive-file-list")
      this.progressEl = document.getElementById("receive-progress")
      this.progressName = document.getElementById("receive-progress-name")
      this.progressPct = document.getElementById("receive-progress-pct")
      this.progressBar = document.getElementById("receive-progress-bar")

      this.handleEvent("rtc_signal", (signal) => this.onSignal(signal))
      this.handleEvent("clear_files", () => this.clearFiles())
    },

    clearFiles() {
      this.current = null
      if (this.listEl) this.listEl.innerHTML = ""
      if (this.statusEl) this.statusEl.textContent = ""
      this.hideProgress()
    },

    showProgress(name, size) {
      if (!this.progressEl) return
      this.progressName.textContent = `Receiving ${name}`
      this.progressPct.textContent = `0% · 0 B / ${humanSize(size)}`
      this.progressBar.value = 0
      this.progressEl.hidden = false
    },

    updateProgress(received, size) {
      if (!this.progressEl) return
      const pct = size ? Math.min(100, Math.round((received / size) * 100)) : 0
      this.progressBar.value = pct
      this.progressPct.textContent = `${pct}% · ${humanSize(received)} / ${humanSize(size)}`
    },

    hideProgress() {
      if (this.progressEl) this.progressEl.hidden = true
    },

    onSignal(signal) {
      if (signal.type === "offer") {
        this.setupPeer()
        this.pc.setRemoteDescription(signal.sdp)
          .then(() => this.pc.createAnswer())
          .then((answer) => this.pc.setLocalDescription(answer))
          .then(() => {
            this.sendSignal({ type: "answer", sdp: this.pc.localDescription.toJSON() })
            this.queuedCandidates.forEach((c) =>
              this.pc.addIceCandidate(c).catch((e) => console.error(e))
            )
            this.queuedCandidates = []
          })
          .catch((e) => {
            console.error("Answer error", e)
            this.setStatus("Failed to accept connection.")
          })
      } else if (signal.type === "ice" && signal.candidate) {
        if (this.pc && this.pc.remoteDescription) {
          this.pc.addIceCandidate(signal.candidate).catch(console.error)
        } else {
          this.queuedCandidates.push(signal.candidate)
        }
      }
    },

    setupPeer() {
      if (this.pc) {
        try { this.pc.close() } catch (_) {}
      }
      this.pc = new RTCPeerConnection({ iceServers: ICE_SERVERS })
      this.pc.onicecandidate = (e) => {
        if (e.candidate) {
          this.sendSignal({ type: "ice", candidate: e.candidate.toJSON() })
        }
      }
      this.pc.ondatachannel = (e) => {
        this.dc = e.channel
        this.dc.binaryType = "arraybuffer"
        this.dc.onopen = () => this.setStatus("Connected. Waiting for files…")
        this.dc.onmessage = (msg) => this.onMessage(msg.data)
        this.dc.onclose = () => {
          if (this.current) {
            this.setStatus("Channel closed mid-transfer.")
            this.current = null
          }
        }
      }
    },

    sendSignal(signal) {
      this.pushEvent("rtc_signal", { signal })
    },

    onMessage(data) {
      if (typeof data === "string") {
        let msg
        try { msg = JSON.parse(data) } catch (_) { return }

        if (msg.type === "meta") {
          this.current = {
            name: msg.name || "file",
            size: msg.size || 0,
            mime: msg.mime || "application/octet-stream",
            chunks: [],
            received: 0
          }
          this.setStatus(`Receiving ${this.current.name} (${humanSize(this.current.size)})…`)
          this.showProgress(this.current.name, this.current.size)
          this.pushEvent("file_started", { name: this.current.name, size: this.current.size })
        } else if (msg.type === "done") {
          this.finalizeFile()
        }
      } else if (data instanceof ArrayBuffer) {
        if (!this.current) return
        this.current.chunks.push(data)
        this.current.received += data.byteLength
        this.updateProgress(this.current.received, this.current.size)
        const pct = this.current.size
          ? Math.min(100, Math.round((this.current.received / this.current.size) * 100))
          : 0
        this.setStatus(`Receiving ${this.current.name}: ${pct}%`)
      }
    },

    finalizeFile() {
      const f = this.current
      if (!f) return
      const blob = new Blob(f.chunks, { type: f.mime })
      const url = URL.createObjectURL(blob)
      const isImage = (f.mime || "").startsWith("image/")

      const item = document.createElement("div")
      item.className = "received-file space-y-2"

      const actions = document.createElement("div")
      actions.className = "flex items-center gap-2 flex-wrap"

      const download = document.createElement("a")
      download.href = url
      download.download = f.name
      download.className = "btn btn-primary"
      download.textContent = "Save"
      actions.appendChild(download)

      const clearBtn = document.createElement("button")
      clearBtn.type = "button"
      clearBtn.className = "btn"
      clearBtn.textContent = "Clear"
      clearBtn.addEventListener("click", () => this.pushEvent("clear"))
      actions.appendChild(clearBtn)

      const meta = document.createElement("span")
      meta.className = "text-sm opacity-80 break-all ml-1"
      meta.textContent = `${f.name} · ${humanSize(f.size)}`
      actions.appendChild(meta)

      item.appendChild(actions)

      if (isImage) {
        const img = document.createElement("img")
        img.src = url
        img.alt = f.name
        img.className = "block mx-auto w-full max-h-[calc(100vh-10rem)] object-contain rounded border border-base-300"
        item.appendChild(img)
      }

      this.listEl.prepend(item)

      this.hideProgress()
      this.setStatus(`Received ${f.name}.`)
      this.pushEvent("file_received", { name: f.name, size: f.size, mime: f.mime })
      this.current = null
    },

    setStatus(msg) {
      if (this.statusEl) this.statusEl.textContent = msg
    },

    destroyed() {
      try { this.dc && this.dc.close() } catch (_) {}
      try { this.pc && this.pc.close() } catch (_) {}
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
