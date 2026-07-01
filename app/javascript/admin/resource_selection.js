import { adminSelectors, checkedResourceSelectSelector } from "./selectors"

export const selectedAdminResourceIds = () =>
  Array.from(document.querySelectorAll(checkedResourceSelectSelector)).map((input) => input.value)

export const updateAdminResourceSelectionState = ({ afterUpdate } = {}) => {
  const rowCheckboxes = Array.from(document.querySelectorAll(adminSelectors.resourceSelect))
  const selectedCount = rowCheckboxes.filter((input) => input.checked).length
  const selectedCountLabel = selectedCount.toLocaleString()

  document.querySelectorAll(adminSelectors.resourceSelectAll).forEach((input) => {
    input.checked = rowCheckboxes.length > 0 && selectedCount === rowCheckboxes.length
    input.indeterminate = selectedCount > 0 && selectedCount < rowCheckboxes.length
  })

  document.querySelectorAll(adminSelectors.selectionCount).forEach((item) => {
    item.textContent = selectedCountLabel
  })
  document.querySelectorAll(adminSelectors.selectionNote).forEach((item) => {
    item.textContent = selectedCount > 0 ? "選択した行を対象に一括操作できます。" : "一括操作を実行するには、対象行を選択してください。"
  })
  document.querySelectorAll(adminSelectors.resourceSelectionClear).forEach((button) => {
    button.disabled = selectedCount === 0
  })

  document.querySelectorAll(adminSelectors.operationSelectionCount).forEach((item) => {
    item.textContent = selectedCountLabel
  })
  document.querySelectorAll(adminSelectors.operationForm).forEach((form) => {
    const note = form.querySelector(adminSelectors.operationSelectionNote)
    if (!note || form.dataset.adminOperationSelectionRequired !== "true") return

    note.textContent = selectedCount > 0 ? "選択した対象で実行できます。" : "対象を選択してください。"
  })

  afterUpdate?.()
}

export const setupAdminResourceSelection = ({ afterUpdate } = {}) => {
  const content = document.querySelector(adminSelectors.resourceContent)
  if (!content || content.dataset.selectionInitialized === "true") return

  content.dataset.selectionInitialized = "true"
  content.addEventListener("change", (event) => {
    const selectAll = event.target.closest(adminSelectors.resourceSelectAll)
    if (selectAll) {
      document.querySelectorAll(adminSelectors.resourceSelect).forEach((input) => {
        input.checked = selectAll.checked
      })
      updateAdminResourceSelectionState({ afterUpdate })
      return
    }

    if (event.target.closest(adminSelectors.resourceSelect)) updateAdminResourceSelectionState({ afterUpdate })
  })

  content.addEventListener("click", (event) => {
    const clearButton = event.target.closest(adminSelectors.resourceSelectionClear)
    if (!clearButton) return

    document.querySelectorAll(adminSelectors.resourceSelect).forEach((input) => {
      input.checked = false
    })
    updateAdminResourceSelectionState({ afterUpdate })
  })

  updateAdminResourceSelectionState({ afterUpdate })
}
