// Entry point for the build script in your package.json
import "@rails/ujs"
import Rails from "@rails/ujs"

Rails.start()

const setupAdminInfiniteScroll = () => {
  const sentinel = document.querySelector("[data-admin-infinite-scroll]")
  const rows = document.querySelector("#admin-resource-rows")
  if (!sentinel || !rows || sentinel.dataset.initialized === "true") return

  sentinel.dataset.initialized = "true"
  const scrollRoot = sentinel.closest(".admin-table-wrap")
  const status = sentinel.querySelector("[data-admin-infinite-scroll-status]")
  let loading = false

  const loadNextPage = async () => {
    const nextUrl = sentinel.dataset.nextUrl
    if (loading || !nextUrl) return

    loading = true
    if (status) status.textContent = "読み込み中..."

    try {
      const response = await fetch(nextUrl, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
      })

      if (!response.ok) throw new Error(`Request failed: ${response.status}`)

      const payload = await response.json()
      rows.insertAdjacentHTML("beforeend", payload.html)
      sentinel.dataset.nextUrl = payload.next_url || ""
      sentinel.hidden = !payload.next_url
      updateAdminResourceSelectionState()
      const visibleCount = document.querySelector("[data-admin-visible-count]")
      if (visibleCount) visibleCount.textContent = rows.querySelectorAll("tr").length.toLocaleString()
      if (status) status.textContent = payload.next_url ? "さらに読み込みます" : "すべて読み込みました"
    } catch (error) {
      console.error(error)
      if (status) status.textContent = "読み込みに失敗しました"
    } finally {
      loading = false
    }
  }

  const observer = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) loadNextPage()
  }, { root: scrollRoot, rootMargin: "240px" })

  observer.observe(sentinel)
}

document.addEventListener("DOMContentLoaded", setupAdminInfiniteScroll)

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
  setupAdminInfiniteScroll()
  setupAdminOriginalSongPickers()
  setupAdminBulkEditTables()
  setupAdminSearchableSelects()
  setupAdminAssociationDialogs()
  setupAdminResourceSelection()
  setupAdminOperationModal()
  setupAdminOperationForms()
  setupAdminWorkflowRunner()
}

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

const selectedAdminResourceIds = () =>
  Array.from(document.querySelectorAll("[data-admin-resource-select]:checked")).map((input) => input.value)

const adminOperationRequiredInputsReady = (form) =>
  Array.from(form.querySelectorAll("[data-admin-operation-required-input]")).every((input) => {
    if (input.type === "file") return input.files.length > 0

    return input.value.trim().length > 0
  })

const adminOperationFormReady = (form) => {
  const selectionRequired = form.dataset.adminOperationSelectionRequired === "true"
  const selectionReady = !selectionRequired || selectedAdminResourceIds().length > 0

  return selectionReady && adminOperationRequiredInputsReady(form)
}

const updateAdminOperationSubmitStates = () => {
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    const submitButton = form.querySelector("[data-admin-operation-submit]")
    if (!submitButton) return

    submitButton.disabled = form.dataset.adminOperationBusy === "true" || !adminOperationFormReady(form)
  })
}

const updateAdminResourceSelectionState = () => {
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
  updateAdminOperationSubmitStates()
}

const setupAdminResourceSelection = () => {
  const content = document.querySelector("[data-admin-resource-content]")
  if (!content || content.dataset.selectionInitialized === "true") return

  content.dataset.selectionInitialized = "true"
  content.addEventListener("change", (event) => {
    const selectAll = event.target.closest("[data-admin-resource-select-all]")
    if (selectAll) {
      document.querySelectorAll("[data-admin-resource-select]").forEach((input) => {
        input.checked = selectAll.checked
      })
      updateAdminResourceSelectionState()
      return
    }

    if (event.target.closest("[data-admin-resource-select]")) updateAdminResourceSelectionState()
  })

  updateAdminResourceSelectionState()
}

document.addEventListener("DOMContentLoaded", setupAdminResourceSelection)

const setupAdminOperationModal = () => {
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
      updateAdminResourceSelectionState()
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

document.addEventListener("DOMContentLoaded", setupAdminOperationModal)

const setupAdminOperationForms = () => {
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    const dialog = document.querySelector("[data-admin-operation-confirm-dialog]")
    const dialogMessage = dialog?.querySelector("[data-admin-operation-dialog-message]")
    const confirmButton = dialog?.querySelector("[data-admin-operation-confirm]")
    const cancelButton = dialog?.querySelector("[data-admin-operation-cancel]")
    const inlineConfirmation = form.dataset.adminOperationInlineConfirmation === "true"
    const asyncOperation = form.dataset.adminOperationAsync === "true"
    const operationModal = form.closest("[data-admin-operation-modal]")
    const operationPanel = form.closest("[data-admin-operation-panel]")
    const selectedIdsContainer = form.querySelector("[data-admin-operation-selected-ids]")
    const modalCancelButton = form.querySelector("[data-admin-operation-modal-cancel]")
    const submitButton = form.querySelector("[data-admin-operation-submit]")
    const progress = form.querySelector("[data-admin-operation-progress]")
    const progressLabel = form.querySelector("[data-admin-operation-progress-label]")
    const progressPercent = form.querySelector("[data-admin-operation-progress-percent]")
    const progressStatus = form.querySelector("[data-admin-operation-progress-status]")
    const progressElapsed = form.querySelector("[data-admin-operation-progress-elapsed]")
    const progressbar = form.querySelector("[data-admin-operation-progressbar]")
    const progressBar = form.querySelector("[data-admin-operation-progress-bar]")
    const progressSteps = form.querySelectorAll("[data-admin-operation-step]")
    const progressUrl = form.dataset.adminOperationProgressUrl
    const parsedEstimatedSeconds = Number.parseInt(form.dataset.adminOperationEstimatedSeconds || "40", 10)
    const estimatedSeconds = Number.isFinite(parsedEstimatedSeconds) && parsedEstimatedSeconds > 0 ? parsedEstimatedSeconds : 40
    let elapsedTimer
    let pollTimer
    let progressPhase = "waiting"
    let executeStartedAt
    let lastServerPercentage = 0
    let hasServerProgress = false
    let lastProgressStatus = "外部サイト取得中"
    let lastProgressLabel = "外部サイトから取得・保存しています..."
    let finishTimer

    const elapsedTime = (startedAt) => {
      const elapsedSeconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000))
      const minutes = Math.floor(elapsedSeconds / 60).toString().padStart(2, "0")
      const seconds = (elapsedSeconds % 60).toString().padStart(2, "0")
      return `${minutes}:${seconds}`
    }

    const activateProgressStep = (step) => {
      const stepOrder = ["prepare", "execute", "finish"]
      const activeIndex = stepOrder.indexOf(step)
      progressSteps.forEach((item) => {
        const itemIndex = stepOrder.indexOf(item.dataset.adminOperationStep)
        item.classList.toggle("admin-operation-progress-step-active", itemIndex === activeIndex)
        item.classList.toggle("admin-operation-progress-step-complete", itemIndex < activeIndex)
      })
    }

    const estimatedExternalFetchProgress = () => {
      if (!executeStartedAt) return 8

      const elapsedSeconds = Math.max(0, Math.floor((Date.now() - executeStartedAt) / 1000))
      const progressRatio = Math.min(elapsedSeconds / estimatedSeconds, 1)
      const estimated = 8 + (84 * Math.pow(progressRatio, 0.72))
      return Math.min(92, Math.max(8, Math.floor(estimated)))
    }

    const updateProgress = (value, status, label) => {
      const normalizedValue = Math.max(0, Math.min(100, value))
      if (progressLabel && label) progressLabel.textContent = label
      if (progressPercent) progressPercent.textContent = `${normalizedValue}%`
      if (progressStatus) progressStatus.textContent = status
      if (progressbar) {
        progressbar.setAttribute("aria-valuenow", normalizedValue.toString())
        progressbar.setAttribute("aria-valuetext", `${status} ${normalizedValue}%`)
      }
      if (progressBar) progressBar.style.width = `${normalizedValue}%`
    }

    const resetProgress = () => {
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      if (pollTimer) window.clearInterval(pollTimer)
      if (finishTimer) window.clearTimeout(finishTimer)

      elapsedTimer = undefined
      pollTimer = undefined
      finishTimer = undefined
      executeStartedAt = undefined
      progressPhase = "waiting"
      lastServerPercentage = 0
      hasServerProgress = false
      lastProgressStatus = "外部サイト取得中"
      lastProgressLabel = "外部サイトから取得・保存しています..."
      delete form.dataset.confirmed

      if (submitButton) submitButton.disabled = false
      if (modalCancelButton) modalCancelButton.disabled = false
      if (progress) progress.hidden = true
      if (progressElapsed) progressElapsed.textContent = "00:00"
      progressBar?.classList.remove("admin-operation-progress-bar-active")
      activateProgressStep("prepare")
      updateProgress(0, "待機中", "処理を開始しています...")
      updateAdminOperationSubmitStates()
    }

    const finishProgress = (payload = {}) => {
      if (progress?.hidden || progressPhase === "finished") return

      progressPhase = "finished"
      activateProgressStep("finish")
      const completedLabel = payload.detail || payload.label || (inlineConfirmation ? "処理が完了しました。ダイアログを閉じます..." : "処理が完了しました。画面を切り替えています...")
      updateProgress(100, "完了", completedLabel)
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      if (pollTimer) window.clearInterval(pollTimer)
      if (inlineConfirmation && operationModal?.open) {
        finishTimer = window.setTimeout(() => {
          operationModal.close()
          resetProgress()
        }, 1200)
      }
    }

    const applyServerProgress = (payload) => {
      if (!payload || progressPhase === "finished") return

      const percentage = Number.parseInt(payload.percentage || "0", 10)
      const status = payload.status || "外部サイト取得中"
      const label = payload.label || "外部サイトから取得・保存しています..."
      lastProgressStatus = status
      lastProgressLabel = label

      if (Number.isFinite(percentage)) {
        hasServerProgress = payload.state !== "pending" || percentage > 0
        lastServerPercentage = Math.max(lastServerPercentage, percentage)
        updateProgress(lastServerPercentage, status, label)
      } else {
        updateProgress(lastServerPercentage, status, label)
      }

      if (payload.state === "running") activateProgressStep("execute")
      if (payload.state === "completed") finishProgress(payload)
      if (payload.state === "failed") {
        progressPhase = "failed"
        updateProgress(lastServerPercentage, "エラー", payload.detail || label)
        if (pollTimer) window.clearInterval(pollTimer)
        if (elapsedTimer) window.clearInterval(elapsedTimer)
        progressBar?.classList.remove("admin-operation-progress-bar-active")
        if (modalCancelButton) modalCancelButton.disabled = false
        delete form.dataset.adminOperationBusy
        delete form.dataset.confirmed
        updateAdminOperationSubmitStates()
      }
    }

    const startProgressPolling = () => {
      if (!progressUrl) return

      const poll = async () => {
        try {
          const response = await fetch(progressUrl, {
            headers: {
              Accept: "application/json",
              "X-Requested-With": "XMLHttpRequest",
            },
          })
          if (!response.ok) return

          applyServerProgress(await response.json())
        } catch (error) {
          console.debug(error)
        }
      }

      poll()
      pollTimer = window.setInterval(poll, 1200)
    }

    const startProgress = () => {
      if (progress) progress.hidden = false
      form.dataset.adminOperationBusy = "true"
      if (submitButton) submitButton.disabled = true
      if (modalCancelButton) modalCancelButton.disabled = true
      progressPhase = "prepare"
      activateProgressStep("prepare")
      updateProgress(4, "確認中", "入力内容を確認しています...")

      const startedAt = Date.now()
      if (progressElapsed) progressElapsed.textContent = elapsedTime(startedAt)
      elapsedTimer = window.setInterval(() => {
        if (progressElapsed) progressElapsed.textContent = elapsedTime(startedAt)
        if (progressPhase === "execute") {
          const fallbackProgress = estimatedExternalFetchProgress()
          const nextProgress = hasServerProgress ? lastServerPercentage : fallbackProgress
          updateProgress(nextProgress, lastProgressStatus, lastProgressLabel)
        }
      }, 1000)

      window.setTimeout(() => {
        progressPhase = "execute"
        executeStartedAt = Date.now()
        activateProgressStep("execute")
        progressBar?.classList.add("admin-operation-progress-bar-active")
        updateProgress(8, "外部サイト取得中", "外部サイトから取得・保存しています...")
      }, 250)

      startProgressPolling()
      window.addEventListener("pagehide", finishProgress, { once: true })
    }

    const failProgress = (message) => {
      progressPhase = "failed"
      updateProgress(lastServerPercentage, "エラー", message || "処理の開始に失敗しました")
      if (pollTimer) window.clearInterval(pollTimer)
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      progressBar?.classList.remove("admin-operation-progress-bar-active")
      if (modalCancelButton) modalCancelButton.disabled = false
      delete form.dataset.adminOperationBusy
      delete form.dataset.confirmed
      updateAdminOperationSubmitStates()
    }

    const submitAsyncOperation = async () => {
      syncSelectedIds()
      startProgress()

      try {
        const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
        const response = await fetch(form.action, {
          method: form.method.toUpperCase(),
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
          },
          body: new FormData(form),
          credentials: "same-origin",
        })

        const payload = await response.json().catch(() => ({}))
        if (!response.ok) throw new Error(payload.message || `Request failed: ${response.status}`)

        applyServerProgress(payload.progress)
      } catch (error) {
        console.error(error)
        failProgress(error.message)
      }
    }

    const syncSelectedIds = () => {
      if (!selectedIdsContainer) return

      selectedIdsContainer.replaceChildren()
      selectedAdminResourceIds().forEach((id) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "selected_ids[]"
        input.value = id
        selectedIdsContainer.appendChild(input)
      })
    }

    const submitConfirmed = () => {
      form.dataset.confirmed = "true"
      form.requestSubmit(submitButton || undefined)
    }

    form.addEventListener("submit", (event) => {
      if (!adminOperationFormReady(form)) {
        event.preventDefault()
        updateAdminOperationSubmitStates()
        return
      }

      if (form.dataset.confirmed === "true") {
        syncSelectedIds()
        if (asyncOperation) {
          event.preventDefault()
          submitAsyncOperation()
          return
        }
        startProgress()
        return
      }

      if (inlineConfirmation) {
        syncSelectedIds()
        if (asyncOperation) {
          event.preventDefault()
          submitAsyncOperation()
          return
        }
        startProgress()
        return
      }

      event.preventDefault()

      const message = form.dataset.confirmation || "アクションを実行します。よろしいですか？"
      if (!dialog?.showModal) {
        if (window.confirm(message)) submitConfirmed()
        return
      }

      if (dialogMessage) dialogMessage.textContent = message
      dialog.showModal()
    })

    confirmButton?.addEventListener("click", () => {
      dialog?.close()
      submitConfirmed()
    })

    cancelButton?.addEventListener("click", () => {
      dialog?.close()
    })

    modalCancelButton?.addEventListener("click", () => {
      operationModal?.close()
    })

    form.querySelectorAll("[data-admin-operation-required-input]").forEach((input) => {
      input.addEventListener("input", updateAdminOperationSubmitStates)
      input.addEventListener("change", updateAdminOperationSubmitStates)
    })

    operationModal?.addEventListener("close", () => {
      if (progressPhase !== "waiting") resetProgress()
    })

    operationPanel?.addEventListener("admin-operation-panel-open", () => {
      resetProgress()
    })

    updateAdminOperationSubmitStates()
  })
}

document.addEventListener("DOMContentLoaded", setupAdminOperationForms)

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
        runner.dataset.adminWorkflowState = payload.state
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
