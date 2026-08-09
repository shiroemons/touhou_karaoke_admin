const adminFormErrorSummarySelector = "[data-admin-form-error-summary]"

export const focusAdminFormErrorSummary = (root = document) => {
  const summary = root.querySelector?.(adminFormErrorSummarySelector)
  if (!summary?.focus) return false

  summary.focus()
  return true
}

export const setupAdminFormErrors = () => {
  if (document.documentElement.dataset.adminFormErrorsInitialized === "true") return

  document.documentElement.dataset.adminFormErrorsInitialized = "true"
  focusAdminFormErrorSummary()
}
