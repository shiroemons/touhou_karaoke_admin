const COPY_TOAST_DURATION_MS = 2000

let copyToast
let copyToastTimer

const showCopyToast = (message, type) => {
  if (!copyToast) {
    copyToast = document.createElement("div")
    document.body.appendChild(copyToast)
  }

  copyToast.className = `admin-copy-toast admin-copy-toast-${type}`
  copyToast.textContent = message
  const isError = type === "alert"
  copyToast.setAttribute("role", isError ? "alert" : "status")
  copyToast.setAttribute("aria-live", isError ? "assertive" : "polite")
  copyToast.setAttribute("aria-atomic", "true")

  if (copyToastTimer) window.clearTimeout(copyToastTimer)
  copyToastTimer = window.setTimeout(() => {
    copyToast?.remove()
    copyToast = undefined
    copyToastTimer = undefined
  }, COPY_TOAST_DURATION_MS)
}

const copyTextToClipboard = async (text) => {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }

  const textarea = document.createElement("textarea")
  textarea.value = text
  textarea.style.position = "fixed"
  textarea.style.opacity = "0"
  document.body.appendChild(textarea)
  textarea.focus()
  textarea.select()
  try {
    if (!document.execCommand("copy")) throw new Error("execCommand('copy') に失敗しました。")
  } finally {
    textarea.remove()
  }
}

export const setupAdminCopyText = () => {
  document.querySelectorAll("[data-admin-copy-text]").forEach((element) => {
    if (element.dataset.adminCopyTextInitialized === "true") return

    element.dataset.adminCopyTextInitialized = "true"
    element.addEventListener("click", async (event) => {
      event.preventDefault()

      try {
        await copyTextToClipboard(element.dataset.adminCopyText)
        showCopyToast("コピーしました", "notice")
      } catch (error) {
        console.error(error)
        showCopyToast("コピーに失敗しました", "alert")
      }
    })
  })
}
