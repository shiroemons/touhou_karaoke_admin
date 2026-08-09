const ADMIN_FLASH_AUTOHIDE_MS = 5000

const hideAdminFlash = (flash) => {
  if (!flash) return

  flash.hidden = true
  flash.remove()
}

const scheduleAdminFlashAutohide = (flash) => {
  if (!flash || flash.dataset.adminFlashAutohide !== "true" || flash.dataset.adminFlashTimer === "true") return

  flash.dataset.adminFlashTimer = "true"
  window.setTimeout(() => hideAdminFlash(flash), ADMIN_FLASH_AUTOHIDE_MS)
}

export const showAdminFlash = (message, type = "notice", autohide = true) => {
  const container = document.querySelector("[data-admin-flash-container]")
  if (!container || !message) return

  const flash = document.createElement("div")
  const isAlert = type === "alert"
  flash.className = `admin-flash admin-flash-${type} alert ${type === "alert" ? "alert-error" : "alert-success"}`
  flash.dataset.adminFlash = type
  flash.setAttribute("role", isAlert ? "alert" : "status")
  flash.setAttribute("aria-live", isAlert ? "assertive" : "polite")
  flash.setAttribute("aria-atomic", "true")
  if (autohide) flash.dataset.adminFlashAutohide = "true"
  flash.textContent = message
  container.appendChild(flash)
  scheduleAdminFlashAutohide(flash)
}

export const setupAdminFlash = () => {
  document.querySelectorAll("[data-admin-flash-autohide='true']").forEach(scheduleAdminFlashAutohide)
}
