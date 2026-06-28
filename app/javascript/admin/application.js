// Entry point for the build script in your package.json
import "@rails/ujs"
import Rails from "@rails/ujs"
import { setupAdminFlash, showAdminFlash } from "./flash"
import { setupAdminInfiniteScroll } from "./infinite_scroll"
import { setupAdminResourceOperations, updateAdminResourceSelectionState } from "./resource_operations"

Rails.start()

document.addEventListener("DOMContentLoaded", setupAdminFlash)
document.addEventListener("DOMContentLoaded", () => setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState }))

const selectedOriginalSongTitles = (picker) => {
  const value = picker.querySelector("[data-admin-original-song-value]")?.value || ""
  return value.split("/").map((item) => item.trim()).filter(Boolean)
}

const selectedOriginalSongItems = (picker) => {
  const chips = picker.querySelectorAll("[data-admin-original-song-item]")
  if (chips.length > 0) {
    return Array.from(chips).map((chip) => ({
      title: chip.dataset.adminOriginalSongItem,
      status: chip.dataset.adminOriginalSongStatus || "valid",
    }))
  }

  return selectedOriginalSongTitles(picker).map((title) => ({ title, status: "valid" }))
}

const normalizedOriginalSongPickerItems = (items) => {
  const itemByTitle = new Map()
  items.forEach((item) => {
    const title = (typeof item === "string" ? item : item.title).trim()
    if (!title) return

    const status = typeof item === "string" ? "valid" : (item.status || "valid")
    const current = itemByTitle.get(title)
    if (!current || current.status === "invalid" && status === "valid") {
      itemByTitle.set(title, { title, status })
    }
  })

  return Array.from(itemByTitle.values())
}

const updateOriginalSongPickerValue = (picker, items) => {
  const uniqueItems = normalizedOriginalSongPickerItems(items)
  const valueInput = picker.querySelector("[data-admin-original-song-value]")
  const chips = picker.querySelector("[data-admin-original-song-chips]")
  if (!valueInput || !chips) return

  valueInput.value = uniqueItems.map((item) => item.title).join("/")
  chips.innerHTML = ""
  uniqueItems.forEach((item) => {
    const chip = document.createElement("button")
    chip.type = "button"
    chip.className = `admin-original-song-chip admin-original-song-chip-${item.status}`
    chip.dataset.adminOriginalSongItem = item.title
    chip.dataset.adminOriginalSongStatus = item.status
    if (item.status === "invalid") {
      chip.dataset.adminOriginalSongEdit = item.title
    } else {
      chip.dataset.adminOriginalSongRemove = item.title
    }
    chip.textContent = item.title
    chip.title = item.status === "invalid" ? `${item.title} を編集する` : `${item.title} を外す`
    chips.appendChild(chip)
  })
}

const addOriginalSongTitle = (picker, title) => {
  updateOriginalSongPickerValue(picker, [...selectedOriginalSongItems(picker), { title, status: "valid" }])
}

const ORIGINAL_SONG_OPTIONS_MAX_HEIGHT = 240
let activeOriginalSongPicker

const positionOriginalSongOptions = (picker) => {
  const searchInput = picker.querySelector("[data-admin-original-song-search]")
  const options = picker.querySelector("[data-admin-original-song-options]")
  if (!searchInput || !options || options.hidden) return

  const viewportPadding = 12
  const gap = 4
  const inputRect = searchInput.getBoundingClientRect()
  const width = Math.min(Math.max(inputRect.width, 300), window.innerWidth - (viewportPadding * 2))
  const availableBelow = window.innerHeight - inputRect.bottom - viewportPadding - gap
  const availableAbove = inputRect.top - viewportPadding - gap
  const openAbove = availableBelow < 160 && availableAbove > availableBelow
  const availableHeight = openAbove ? availableAbove : availableBelow
  const maxHeight = Math.max(120, Math.min(ORIGINAL_SONG_OPTIONS_MAX_HEIGHT, availableHeight))
  const left = Math.max(
    viewportPadding,
    Math.min(inputRect.left, window.innerWidth - width - viewportPadding)
  )
  const top = openAbove
    ? Math.max(viewportPadding, inputRect.top - maxHeight - gap)
    : Math.min(inputRect.bottom + gap, window.innerHeight - maxHeight - viewportPadding)

  options.style.left = `${left}px`
  options.style.top = `${top}px`
  options.style.width = `${width}px`
  options.style.maxHeight = `${maxHeight}px`
}

const hideOriginalSongOptions = (picker) => {
  const options = picker.querySelector("[data-admin-original-song-options]")
  if (options) options.hidden = true
  if (activeOriginalSongPicker === picker) activeOriginalSongPicker = undefined
}

const renderOriginalSongOptions = (picker, optionsPayload) => {
  const options = picker.querySelector("[data-admin-original-song-options]")
  if (!options) return

  options.innerHTML = ""
  optionsPayload.forEach((item) => {
    const option = document.createElement("button")
    option.type = "button"
    option.className = "admin-original-song-option"
    option.dataset.adminOriginalSongSelect = item.title
    if (item.candidateFor) option.dataset.adminOriginalSongCandidateFor = item.candidateFor
    option.textContent = item.label || item.title
    options.appendChild(option)
  })
  options.hidden = optionsPayload.length === 0
  activeOriginalSongPicker = options.hidden ? undefined : picker
  positionOriginalSongOptions(picker)
}

const resolveOriginalSongText = async (picker, text) => {
  const response = await fetch(picker.dataset.resolveUrl, {
    method: "POST",
    credentials: "same-origin",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "",
      "X-Requested-With": "XMLHttpRequest",
    },
    body: JSON.stringify({ text }),
  })
  if (!response.ok) throw new Error(`Request failed: ${response.status}`)

  return response.json()
}

const setOriginalSongPickerText = async (searchInput, text) => {
  const picker = searchInput.closest("[data-admin-original-song-picker]")
  if (!picker) {
    searchInput.value = text
    return
  }

  try {
    const payload = await resolveOriginalSongText(picker, text)
    const items = payload.items?.length
      ? payload.items.map((item) => ({ title: item.title, status: item.exists ? "valid" : "invalid" }))
      : [{ title: text, status: payload.titles?.length ? "valid" : "invalid" }]
    updateOriginalSongPickerValue(picker, items)
    const selectedTitles = new Set(selectedOriginalSongTitles(picker))
    const candidates = (payload.items || []).flatMap((item) => (
      item.exists ? [] : (item.candidates || []).map((candidate) => ({
        ...candidate,
        candidateFor: item.title,
      }))
    )).filter((candidate, index, list) => (
      !selectedTitles.has(candidate.title) &&
        list.findIndex((item) => item.title === candidate.title) === index
    ))
    if (candidates.length > 0) {
      renderOriginalSongOptions(picker, candidates)
    } else {
      hideOriginalSongOptions(picker)
    }
  } catch (error) {
    console.error(error)
    updateOriginalSongPickerValue(picker, [{ title: text, status: "invalid" }])
    hideOriginalSongOptions(picker)
  } finally {
    searchInput.value = ""
  }
}

const setupAdminOriginalSongPickers = () => {
  document.querySelectorAll("[data-admin-original-song-picker]").forEach((picker) => {
    if (picker.dataset.adminOriginalSongPickerInitialized === "true") return

    picker.dataset.adminOriginalSongPickerInitialized = "true"
    updateOriginalSongPickerValue(picker, selectedOriginalSongTitles(picker))
    let searchController

    picker.addEventListener("click", (event) => {
      const editTitle = event.target.closest("[data-admin-original-song-edit]")?.dataset.adminOriginalSongEdit
      if (editTitle) {
        updateOriginalSongPickerValue(
          picker,
          selectedOriginalSongItems(picker).filter((item) => item.title !== editTitle)
        )
        const searchInput = picker.querySelector("[data-admin-original-song-search]")
        if (searchInput) {
          searchInput.value = editTitle
          searchInput.focus()
          searchInput.dispatchEvent(new Event("input", { bubbles: true }))
        }
        return
      }

      const removeTitle = event.target.closest("[data-admin-original-song-remove]")?.dataset.adminOriginalSongRemove
      if (removeTitle) {
        updateOriginalSongPickerValue(
          picker,
          selectedOriginalSongItems(picker).filter((item) => item.title !== removeTitle)
        )
        return
      }

      const selectedOption = event.target.closest("[data-admin-original-song-select]")
      const selectedTitle = selectedOption?.dataset.adminOriginalSongSelect
      if (!selectedTitle) return

      const candidateFor = selectedOption.dataset.adminOriginalSongCandidateFor
      const currentItems = candidateFor
        ? selectedOriginalSongItems(picker).filter((item) => !(item.status === "invalid" && item.title === candidateFor))
        : selectedOriginalSongItems(picker)
      updateOriginalSongPickerValue(picker, [...currentItems, { title: selectedTitle, status: "valid" }])
      picker.querySelector("[data-admin-original-song-search]").value = ""
      hideOriginalSongOptions(picker)
    })

    picker.querySelector("[data-admin-original-song-search]")?.addEventListener("input", async (event) => {
      const query = event.target.value.trim()
      if (searchController) searchController.abort()
      if (!query) {
        hideOriginalSongOptions(picker)
        return
      }

      searchController = new AbortController()
      try {
        const url = new URL(picker.dataset.optionsUrl, window.location.origin)
        url.searchParams.set("q", query)
        const response = await fetch(url, {
          credentials: "same-origin",
          headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
          signal: searchController.signal,
        })
        if (!response.ok) throw new Error(`Request failed: ${response.status}`)

        renderOriginalSongOptions(picker, await response.json())
      } catch (error) {
        if (error.name !== "AbortError") console.error(error)
      }
    })

    const searchInput = picker.querySelector("[data-admin-original-song-search]")

    searchInput?.addEventListener("compositionstart", (event) => {
      event.target.dataset.adminOriginalSongComposing = "true"
    })

    searchInput?.addEventListener("compositionend", (event) => {
      event.target.dataset.adminOriginalSongComposing = "false"
    })

    searchInput?.addEventListener("keydown", (event) => {
      if (event.key !== "Enter") return
      if (
        event.isComposing ||
        event.keyCode === 229 ||
        event.target.dataset.adminOriginalSongComposing === "true"
      ) {
        return
      }

      event.preventDefault()
      const firstOption = picker.querySelector("[data-admin-original-song-select]")
      if (firstOption) {
        addOriginalSongTitle(picker, firstOption.dataset.adminOriginalSongSelect)
        event.target.value = ""
        hideOriginalSongOptions(picker)
        return
      }

      const text = event.target.value.trim()
      if (text) setOriginalSongPickerText(event.target, text)
    })

    picker.querySelector("[data-admin-original-song-search]")?.addEventListener("paste", (event) => {
      const text = event.clipboardData?.getData("text")
      if (!text || text.includes("\t") || text.includes("\n")) return

      event.preventDefault()
      setOriginalSongPickerText(event.target, text)
    })
  })
}

document.addEventListener("click", (event) => {
  if (!activeOriginalSongPicker) return
  if (event.target.closest("[data-admin-original-song-picker]") === activeOriginalSongPicker) return

  hideOriginalSongOptions(activeOriginalSongPicker)
})

window.addEventListener("resize", () => {
  if (activeOriginalSongPicker) positionOriginalSongOptions(activeOriginalSongPicker)
})

document.addEventListener("scroll", () => {
  if (activeOriginalSongPicker) positionOriginalSongOptions(activeOriginalSongPicker)
}, true)

const setupAdminBulkEditTables = () => {
  document.querySelectorAll("[data-admin-bulk-edit-table]").forEach((table) => {
    if (table.dataset.adminBulkEditInitialized === "true") return

    table.dataset.adminBulkEditInitialized = "true"
    table.addEventListener("paste", (event) => {
      const target = event.target.closest("[data-admin-bulk-cell]")
      if (!target) return

      const text = event.clipboardData?.getData("text")
      if (!text || (!text.includes("\t") && !text.includes("\n"))) return

      event.preventDefault()
      const startRow = Number(target.dataset.adminBulkRow)
      const startColumn = Number(target.dataset.adminBulkColumnIndex)
      const pastedRows = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n")
      if (pastedRows[pastedRows.length - 1] === "") pastedRows.pop()

      pastedRows.forEach((rowText, rowOffset) => {
        rowText.split("\t").forEach((value, columnOffset) => {
          const cell = table.querySelector(
            `[data-admin-bulk-cell][data-admin-bulk-row="${startRow + rowOffset}"][data-admin-bulk-column-index="${startColumn + columnOffset}"]`
          )
          if (!cell) return

          if (cell.dataset.adminOriginalSongSearch === "true") {
            setOriginalSongPickerText(cell, value)
          } else {
            cell.value = value
            cell.dispatchEvent(new Event("input", { bubbles: true }))
            cell.dispatchEvent(new Event("change", { bubbles: true }))
          }
        })
      })
    })
  })
}

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

const setupAdminSearchableSelects = () => {
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

document.addEventListener("DOMContentLoaded", setupAdminOriginalSongPickers)
document.addEventListener("DOMContentLoaded", setupAdminBulkEditTables)
document.addEventListener("DOMContentLoaded", setupAdminSearchableSelects)

const setupAdminAssociationDialogs = () => {
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

document.addEventListener("DOMContentLoaded", setupAdminAssociationDialogs)

const adminContentUrl = (url) => {
  const contentUrl = new URL(url, window.location.origin)
  contentUrl.searchParams.set("partial", "content")
  return contentUrl
}

const browserUrl = (url) => {
  const nextUrl = new URL(url, window.location.origin)
  nextUrl.searchParams.delete("partial")
  return nextUrl
}

const setupAdminPageBehaviors = () => {
  setupAdminFilterForms()
  setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState })
  setupAdminOriginalSongPickers()
  setupAdminBulkEditTables()
  setupAdminSearchableSelects()
  setupAdminAssociationDialogs()
  setupAdminResourceOperations()
  setupAdminWorkflowRunner()
}

document.addEventListener("DOMContentLoaded", setupAdminResourceOperations)

const replaceAdminResourceContent = async (url, { pushState = true } = {}) => {
  const response = await fetch(adminContentUrl(url), {
    headers: {
      Accept: "application/json",
      "X-Requested-With": "XMLHttpRequest",
    },
  })

  if (!response.ok) throw new Error(`Request failed: ${response.status}`)

  const payload = await response.json()
  const currentContent = document.querySelector("[data-admin-resource-content]")
  if (!currentContent) return

  currentContent.outerHTML = payload.html
  if (pushState) window.history.pushState({}, "", browserUrl(url))
  setupAdminPageBehaviors()
}

const isAsyncAdminLink = (link) => {
  if (!link) return false
  if (!link.matches(".admin-sort-link, .admin-view-mode-button, .admin-pagination a, .admin-query-panel a")) return false

  const url = new URL(link.href, window.location.origin)
  return url.origin === window.location.origin && url.pathname.startsWith("/admin/")
}

const setupAdminAsyncIndex = () => {
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a")
    if (!isAsyncAdminLink(link)) return

    event.preventDefault()
    replaceAdminResourceContent(link.href).catch((error) => {
      console.error(error)
      window.location.href = link.href
    })
  })

  document.addEventListener("submit", (event) => {
    const form = event.target.closest("form[data-admin-filter-form]")
    if (!form || form.method.toLowerCase() !== "get") return

    event.preventDefault()
    const url = new URL(form.action, window.location.origin)
    new FormData(form).forEach((value, key) => {
      if (value.toString().length > 0) url.searchParams.append(key, value)
    })

    replaceAdminResourceContent(url).catch((error) => {
      console.error(error)
      form.submit()
    })
  })

}

document.addEventListener("DOMContentLoaded", setupAdminAsyncIndex)

let adminPageNavigationController

const adminPageUrl = (url) => {
  const nextUrl = new URL(url, window.location.origin)
  nextUrl.searchParams.delete("partial")
  return nextUrl
}

const isPrimaryNavigationClick = (event) =>
  event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey

const isAsyncAdminPageLink = (link, event) => {
  if (!link || !isPrimaryNavigationClick(event)) return false
  if (event.defaultPrevented) return false
  if (link.matches("[data-admin-operation-trigger]")) return false
  if (link.target || link.hasAttribute("download")) return false
  if (link.dataset.turbo === "false" || link.dataset.adminFullPage === "true") return false
  if (link.dataset.method && link.dataset.method.toLowerCase() !== "get") return false
  if (isAsyncAdminLink(link)) return false

  const url = adminPageUrl(link.href)
  return url.origin === window.location.origin && url.pathname.startsWith("/admin/")
}

const replaceAdminPage = (html, url, { pushState = true } = {}) => {
  const nextDocument = new DOMParser().parseFromString(html, "text/html")
  const nextContent = nextDocument.querySelector("[data-admin-page-content]")
  const currentContent = document.querySelector("[data-admin-page-content]")

  if (!nextContent || !currentContent) throw new Error("Admin page content was not found.")

  const nextSidebar = nextDocument.querySelector(".admin-sidebar")
  const currentSidebar = document.querySelector(".admin-sidebar")
  if (nextSidebar && currentSidebar) currentSidebar.outerHTML = nextSidebar.outerHTML

  currentContent.replaceWith(nextContent)
  document.title = nextDocument.title || document.title
  if (pushState) window.history.pushState({}, "", adminPageUrl(url))

  const pageContent = document.querySelector("[data-admin-page-content]")
  pageContent?.scrollTo({ top: 0, left: 0 })
  setupAdminPageBehaviors()
}

const fetchAndReplaceAdminPage = async (url, { pushState = true } = {}) => {
  if (adminPageNavigationController) adminPageNavigationController.abort()

  const controller = new AbortController()
  adminPageNavigationController = controller
  document.body.dataset.adminNavigation = "loading"
  document.querySelector("[data-admin-page-content]")?.setAttribute("aria-busy", "true")

  try {
    const response = await fetch(adminPageUrl(url), {
      credentials: "same-origin",
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest",
      },
      signal: controller.signal,
    })

    if (!response.ok) throw new Error(`Request failed: ${response.status}`)

    replaceAdminPage(await response.text(), response.url, { pushState })
  } finally {
    if (adminPageNavigationController === controller) {
      delete document.body.dataset.adminNavigation
      document.querySelector("[data-admin-page-content]")?.removeAttribute("aria-busy")
      adminPageNavigationController = undefined
    }
  }
}

const setupAdminPageNavigation = () => {
  if (document.documentElement.dataset.adminPageNavigationInitialized === "true") return

  document.documentElement.dataset.adminPageNavigationInitialized = "true"
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a")
    if (!isAsyncAdminPageLink(link, event)) return

    event.preventDefault()
    fetchAndReplaceAdminPage(link.href).catch((error) => {
      if (error.name === "AbortError") return

      console.error(error)
      window.location.href = link.href
    })
  })

  window.addEventListener("popstate", () => {
    fetchAndReplaceAdminPage(window.location.href, { pushState: false }).catch((error) => {
      if (error.name === "AbortError") return

      console.error(error)
      window.location.reload()
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminPageNavigation)

const isAdminClickableRowTarget = (target) =>
  !target.closest("a, button, input, select, textarea, label, form, [data-admin-row-ignore]")

const setupAdminClickableRows = () => {
  if (document.documentElement.dataset.adminClickableRowsInitialized === "true") return

  document.documentElement.dataset.adminClickableRowsInitialized = "true"
  document.addEventListener("click", (event) => {
    if (!isPrimaryNavigationClick(event) || event.defaultPrevented) return
    if (!isAdminClickableRowTarget(event.target)) return

    const row = event.target.closest("[data-admin-row-href]")
    if (!row?.dataset.adminRowHref) return

    event.preventDefault()
    fetchAndReplaceAdminPage(row.dataset.adminRowHref).catch((error) => {
      if (error.name === "AbortError") return

      console.error(error)
      window.location.href = row.dataset.adminRowHref
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminClickableRows)

const setupAdminFilterForms = () => {
  document.querySelectorAll("[data-admin-filter-form]").forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    form.querySelectorAll("[data-admin-auto-submit]").forEach((input) => {
      input.addEventListener("change", () => {
        form.requestSubmit()
      })
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminFilterForms)


const setupAdminWorkflowRunner = () => {
  document.querySelectorAll("[data-admin-workflow-runner]").forEach((runner) => {
    if (runner.dataset.initialized === "true") return
    if (!runner.dataset.adminWorkflowRunId || !runner.dataset.adminWorkflowProgressUrl) return

    runner.dataset.initialized = "true"
    const stepItems = Array.from(runner.querySelectorAll("[data-admin-workflow-step]"))
    const statusPanel = document.querySelector("[data-admin-workflow-status]")
    const statusLabel = statusPanel?.querySelector("[data-admin-workflow-status-label]")
    const statusState = statusPanel?.querySelector("[data-admin-workflow-status-state]")
    const statusPercent = statusPanel?.querySelector("[data-admin-workflow-status-percent]")
    const statusCurrent = statusPanel?.querySelector("[data-admin-workflow-status-current]")
    const statusCount = statusPanel?.querySelector("[data-admin-workflow-status-count]")
    const currentStepLabel = runner.querySelector("[data-admin-workflow-current-step]")
    const resultsPanel = document.querySelector("[data-admin-workflow-results]")
    const resultsList = resultsPanel?.querySelector("[data-admin-workflow-result-list]")
    let completionNotified = runner.dataset.adminWorkflowState === "completed"

    const applyStatus = (payload) => {
      const currentStep = payload.workflow?.current_step
      const currentText = currentStep?.label || (payload.state === "completed" ? "完了" : "確認中")

      if (statusPanel) {
        if (statusLabel) statusLabel.textContent = payload.label || "実行状況を確認しています"
        if (statusState) statusState.textContent = payload.status || payload.state || "確認中"
        if (statusPercent) statusPercent.textContent = `${Number.parseInt(payload.percentage || "0", 10)}%`
        if (statusCurrent) statusCurrent.textContent = currentText
      }
      if (currentStepLabel) currentStepLabel.textContent = `現在: ${currentText}`
      if (statusPanel && statusCount) {
        const workflow = payload.workflow || {}
        statusCount.textContent = `${Number.parseInt(workflow.completed_steps || "0", 10)} / ${Number.parseInt(workflow.total_steps || "0", 10)}`
      }
    }

    const applyStep = (step) => {
      const item = stepItems.find((candidate) => candidate.dataset.adminWorkflowStep === step.key)
      if (!item) return

      item.dataset.adminWorkflowStatus = step.status
      const progress = item.querySelector("[data-admin-workflow-step-progress]")
      const childProgress = step.progress || {}
      const labels = {
        pending: "順番待ち",
        running: childProgress.label || "実行中",
        completed: childProgress.detail || "完了",
        failed: step.error || childProgress.detail || "失敗",
        manual: "個別実行のみ",
      }
      if (progress) {
        progress.textContent = labels[step.status] || step.status
        if (step.status === "running" && Number.isFinite(Number.parseInt(childProgress.percentage || "0", 10))) {
          progress.textContent += ` ${Number.parseInt(childProgress.percentage || "0", 10)}%`
        }
      }
    }

    const attemptDetailText = (step) => {
      const attempts = Array.isArray(step.attempts) && step.attempts.length > 0 ? step.attempts : [{ attempt: step.attempt, detail: step.detail }]
      return attempts
        .filter((attempt) => attempt?.detail)
        .map((attempt) => {
          const attemptNumber = Number.parseInt(attempt.attempt || "1", 10)
          return `${attemptNumber > 1 ? `${attemptNumber}周目: ` : ""}${attempt.detail}`
        })
        .join(" / ")
    }

    const applyResults = (payload) => {
      if (!resultsPanel || !resultsList) return

      const resultSteps = payload.workflow?.result_steps || []
      resultsPanel.hidden = resultSteps.length === 0
      resultsList.replaceChildren()
      resultSteps.forEach((step) => {
        const item = document.createElement("li")
        item.className = "admin-workflow-result-item"
        item.dataset.adminWorkflowResultStep = step.key

        const title = document.createElement("strong")
        const attempt = Number.parseInt(step.attempt || "1", 10)
        title.textContent = `${step.label}${attempt > 1 ? `（${attempt}周実行）` : ""}`

        const detail = document.createElement("span")
        detail.textContent = attemptDetailText(step)

        item.append(title, detail)
        resultsList.appendChild(item)
      })
    }

    const poll = async () => {
      try {
        const response = await fetch(runner.dataset.adminWorkflowProgressUrl, {
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
          },
        })
        if (!response.ok) return

        const payload = await response.json()
        applyStatus(payload)
        payload.workflow?.steps?.forEach(applyStep)
        applyResults(payload)
        runner.dataset.adminWorkflowState = payload.state
        if (payload.state === "completed" && !completionNotified) {
          completionNotified = true
          showAdminFlash(payload.label || `${payload.workflow?.workflow_label || "運用フロー"}が完了しました。`)
        }
        if (payload.state === "completed" || payload.state === "failed") return
        window.setTimeout(poll, 1500)
      } catch (error) {
        console.error(error)
        window.setTimeout(poll, 3000)
      }
    }

    poll()
  })
}

document.addEventListener("DOMContentLoaded", setupAdminWorkflowRunner)
