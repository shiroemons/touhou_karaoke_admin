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
  flash.className = `admin-flash admin-flash-${type} alert ${type === "alert" ? "alert-error" : "alert-success"}`
  flash.dataset.adminFlash = type
  if (autohide) flash.dataset.adminFlashAutohide = "true"
  flash.textContent = message
  container.appendChild(flash)
  scheduleAdminFlashAutohide(flash)
}

export const setupAdminFlash = () => {
  document.querySelectorAll("[data-admin-flash-autohide='true']").forEach(scheduleAdminFlashAutohide)
}
