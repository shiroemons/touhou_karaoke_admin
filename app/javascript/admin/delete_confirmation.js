import { adminSelectors } from "./selectors"

export const setupAdminDeleteConfirmations = () => {
  const dialog = document.querySelector(adminSelectors.deleteConfirmationDialog)
  if (!dialog || dialog.dataset.initialized === "true") return

  dialog.dataset.initialized = "true"
  const message = dialog.querySelector(adminSelectors.deleteConfirmationMessage)
  const confirmButton = dialog.querySelector(adminSelectors.deleteConfirmationConfirm)
  const cancelButton = dialog.querySelector(adminSelectors.deleteConfirmationCancel)
  let pendingForm = null
  let returnFocusElement = null

  const closeDialog = () => dialog.close()

  const submitPendingForm = () => {
    const form = pendingForm
    pendingForm = null
    closeDialog()
    if (!form || form.isConnected === false) return

    form.dataset.adminDeleteConfirmed = "true"
    form.requestSubmit()
  }

  document.addEventListener("submit", (event) => {
    const form = event.target.closest?.(adminSelectors.deleteConfirmation)
    if (!form) return

    if (form.dataset.adminDeleteConfirmed === "true") {
      delete form.dataset.adminDeleteConfirmed
      return
    }

    event.preventDefault()
    event.stopImmediatePropagation()

    const confirmationMessage = form.dataset.adminDeleteConfirmation || "このデータを削除します。よろしいですか？"
    if (!dialog.showModal) {
      if (window.confirm(confirmationMessage)) {
        pendingForm = form
        submitPendingForm()
      }
      return
    }

    if (dialog.open) return

    pendingForm = form
    returnFocusElement = document.activeElement
    if (message) message.textContent = confirmationMessage
    dialog.showModal()
  }, true)

  confirmButton?.addEventListener("click", submitPendingForm)
  cancelButton?.addEventListener("click", closeDialog)
  dialog.addEventListener("close", () => {
    pendingForm = null
    const focusTarget = returnFocusElement
    returnFocusElement = null
    if (focusTarget?.focus && focusTarget.isConnected !== false) focusTarget.focus()
  })
}
