export const setupAdminOperationModal = ({ updateSelectionState } = {}) => {
  document.querySelectorAll("[data-admin-operation-modal]").forEach((modal) => {
    if (modal.dataset.initialized === "true") return

    modal.dataset.initialized = "true"
    const title = modal.querySelector("[data-admin-operation-modal-title]")
    const panels = Array.from(modal.querySelectorAll("[data-admin-operation-panel]"))
    const closeButton = modal.querySelector("[data-admin-operation-modal-close]")
    const resourceKey = modal.dataset.adminOperationResource

    const showPanel = (operationKey, label) => {
      let activePanel
      panels.forEach((panel) => {
        const active = panel.dataset.adminOperationPanel === operationKey
        panel.hidden = !active
        if (active) activePanel = panel
      })
      if (title) title.textContent = label
      updateSelectionState?.()
      activePanel?.dispatchEvent(new Event("admin-operation-panel-open"))
    }

    document.querySelectorAll("[data-admin-operation-trigger]").forEach((trigger) => {
      if (trigger.dataset.modalInitialized === "true") return
      if (resourceKey && trigger.dataset.adminOperationResource !== resourceKey) return

      trigger.dataset.modalInitialized = "true"
      trigger.addEventListener("click", (event) => {
        const operationKey = trigger.dataset.adminOperationKey
        const panel = panels.find((item) => item.dataset.adminOperationPanel === operationKey)
        if (!panel || !modal.showModal) return

        event.preventDefault()
        trigger.closest("details")?.removeAttribute("open")
        showPanel(operationKey, trigger.dataset.adminOperationLabel || trigger.textContent.trim())
        modal.showModal()
      })
    })

    closeButton?.addEventListener("click", () => modal.close())
  })
}
