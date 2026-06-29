const searchableSelectText = (value) => value.toString().normalize("NFKC").toLowerCase()

const showAdminSearchableSelect = (container) => {
  const list = container.querySelector("[data-admin-searchable-select-options]")
  if (list) list.hidden = false
}

const hideAdminSearchableSelect = (container) => {
  const search = container.querySelector("[data-admin-searchable-select-search]")
  const list = container.querySelector("[data-admin-searchable-select-options]")
  if (search) search.value = ""
  if (list) list.hidden = true
  updateAdminSearchableSelect(container)
}

const adminSearchableSelectValues = (container) =>
  Array.from(container.querySelectorAll("[data-admin-searchable-select-value]")).map((input) => input.value)

const findAdminSearchableSelectOption = (container, value) =>
  Array.from(container.querySelectorAll("[data-admin-searchable-select-checkbox]")).find((checkbox) => checkbox.value === value)?.closest("[data-admin-searchable-select-option]")

const writeAdminSearchableSelectValues = (container, values) => {
  const valuesContainer = container.querySelector("[data-admin-searchable-select-values]")
  const inputName = valuesContainer?.dataset.inputName
  if (!valuesContainer || !inputName) return

  valuesContainer.replaceChildren()
  values.forEach((value) => {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = inputName
    input.value = value
    input.dataset.adminSearchableSelectValue = "true"
    valuesContainer.appendChild(input)
  })
}

const syncAdminSearchableSelectCheckboxes = (container) => {
  const selectedValues = new Set(adminSearchableSelectValues(container))
  container.querySelectorAll("[data-admin-searchable-select-checkbox]").forEach((checkbox) => {
    checkbox.checked = selectedValues.has(checkbox.value)
  })
}

const renderAdminSearchableSelectChips = (container) => {
  const chips = container.querySelector("[data-admin-searchable-select-chips]")
  if (!chips) return

  chips.replaceChildren()
  adminSearchableSelectValues(container).forEach((value) => {
    const option = findAdminSearchableSelectOption(container, value)
    const chip = document.createElement("button")
    chip.type = "button"
    chip.className = "admin-searchable-select-chip"
    chip.dataset.adminSearchableSelectRemove = value
    chip.textContent = option?.dataset.searchableText || option?.textContent?.trim() || value
    chip.title = `${chip.textContent} を外す`
    chips.appendChild(chip)
  })
}

const updateAdminSearchableSelect = (container) => {
  const search = container.querySelector("[data-admin-searchable-select-search]")
  const options = Array.from(container.querySelectorAll("[data-admin-searchable-select-option]"))
  const status = container.querySelector("[data-admin-searchable-select-status]")
  if (!search || options.length === 0) return

  const query = searchableSelectText(search.value.trim())
  let visibleCount = 0

  options.forEach((option) => {
    const matches = query.length === 0 || searchableSelectText(option.dataset.searchableText || option.textContent).includes(query)
    option.hidden = !matches
    if (!option.hidden) visibleCount += 1
  })

  if (status) {
    const selectedCount = adminSearchableSelectValues(container).length
    status.textContent = `選択中 ${selectedCount.toLocaleString()}件 / 表示 ${visibleCount.toLocaleString()}件`
  }
  syncAdminSearchableSelectCheckboxes(container)
  renderAdminSearchableSelectChips(container)
}

export const setupAdminSearchableSelects = () => {
  document.querySelectorAll("[data-admin-searchable-select]").forEach((container) => {
    if (container.dataset.adminSearchableSelectInitialized === "true") return

    container.dataset.adminSearchableSelectInitialized = "true"
    container.querySelector("[data-admin-searchable-select-search]")?.addEventListener("focus", () => {
      showAdminSearchableSelect(container)
      updateAdminSearchableSelect(container)
    })
    container.addEventListener("input", (event) => {
      if (!event.target.closest("[data-admin-searchable-select-search]")) return

      showAdminSearchableSelect(container)
      updateAdminSearchableSelect(container)
    })
    container.addEventListener("change", (event) => {
      const checkbox = event.target.closest("[data-admin-searchable-select-checkbox]")
      if (checkbox) {
        const values = adminSearchableSelectValues(container).filter((value) => value !== checkbox.value)
        if (checkbox.checked) values.push(checkbox.value)
        writeAdminSearchableSelectValues(container, values)
      }

      updateAdminSearchableSelect(container)
      if (checkbox) hideAdminSearchableSelect(container)
    })
    container.addEventListener("click", (event) => {
      const removeValue = event.target.closest("[data-admin-searchable-select-remove]")?.dataset.adminSearchableSelectRemove
      if (!removeValue) return

      writeAdminSearchableSelectValues(
        container,
        adminSearchableSelectValues(container).filter((value) => value !== removeValue)
      )
      updateAdminSearchableSelect(container)
    })
    container.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") return

      hideAdminSearchableSelect(container)
      container.querySelector("[data-admin-searchable-select-search]")?.blur()
    })
    updateAdminSearchableSelect(container)
  })
}

document.addEventListener("click", (event) => {
  document.querySelectorAll("[data-admin-searchable-select]").forEach((container) => {
    if (container.contains(event.target)) return

    hideAdminSearchableSelect(container)
  })
})
