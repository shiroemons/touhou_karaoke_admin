const dialogFocusTargets = new WeakMap()
const initializedDialogs = new WeakSet()

export const rememberAdminDialogFocus = (dialog) => {
  const focusTarget = document.activeElement
  if (!dialog?.addEventListener || !focusTarget?.focus || focusTarget === dialog) return

  dialogFocusTargets.set(dialog, focusTarget)
  if (initializedDialogs.has(dialog)) return

  initializedDialogs.add(dialog)
  dialog.addEventListener("close", () => {
    const returnFocusElement = dialogFocusTargets.get(dialog)
    dialogFocusTargets.delete(dialog)
    if (returnFocusElement?.isConnected !== false) returnFocusElement?.focus()
  })
}
