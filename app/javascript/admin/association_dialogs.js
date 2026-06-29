import { setupAdminSearchableSelects } from "./searchable_select"

export const setupAdminAssociationDialogs = () => {
  document.querySelectorAll("[data-admin-association-dialog]").forEach((dialog) => {
    if (dialog.dataset.adminAssociationDialogInitialized === "true") return

    dialog.dataset.adminAssociationDialogInitialized = "true"
    const dialogKey = dialog.dataset.adminAssociationDialog

    document.querySelectorAll(`[data-admin-association-dialog-trigger="${dialogKey}"]`).forEach((trigger) => {
      trigger.addEventListener("click", () => {
        setupAdminSearchableSelects()
        dialog.showModal()
      })
    })

    dialog.querySelectorAll("[data-admin-association-dialog-close]").forEach((button) => {
      button.addEventListener("click", () => dialog.close())
    })
  })
}
