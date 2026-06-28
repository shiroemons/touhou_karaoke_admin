export const selectedAdminResourceIds = () =>
  Array.from(document.querySelectorAll("[data-admin-resource-select]:checked")).map((input) => input.value)

export const updateAdminResourceSelectionState = ({ afterUpdate } = {}) => {
  const rowCheckboxes = Array.from(document.querySelectorAll("[data-admin-resource-select]"))
  const selectedCount = rowCheckboxes.filter((input) => input.checked).length

  document.querySelectorAll("[data-admin-resource-select-all]").forEach((input) => {
    input.checked = rowCheckboxes.length > 0 && selectedCount === rowCheckboxes.length
    input.indeterminate = selectedCount > 0 && selectedCount < rowCheckboxes.length
  })

  document.querySelectorAll("[data-admin-operation-selection-count]").forEach((item) => {
    item.textContent = selectedCount.toLocaleString()
  })
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    const note = form.querySelector("[data-admin-operation-selection-note]")
    if (!note || form.dataset.adminOperationSelectionRequired !== "true") return

    note.textContent = selectedCount > 0 ? "選択した対象で実行できます。" : "対象を選択してください。"
  })

  afterUpdate?.()
}

export const setupAdminResourceSelection = ({ afterUpdate } = {}) => {
  const content = document.querySelector("[data-admin-resource-content]")
  if (!content || content.dataset.selectionInitialized === "true") return

  content.dataset.selectionInitialized = "true"
  content.addEventListener("change", (event) => {
    const selectAll = event.target.closest("[data-admin-resource-select-all]")
    if (selectAll) {
      document.querySelectorAll("[data-admin-resource-select]").forEach((input) => {
        input.checked = selectAll.checked
      })
      updateAdminResourceSelectionState({ afterUpdate })
      return
    }

    if (event.target.closest("[data-admin-resource-select]")) updateAdminResourceSelectionState({ afterUpdate })
  })

  updateAdminResourceSelectionState({ afterUpdate })
}
