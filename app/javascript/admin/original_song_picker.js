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

const updateOriginalSongPickerStatus = (picker, message, { error = false } = {}) => {
  const status = picker.querySelector("[data-admin-original-song-picker-status]")
  if (!status) return

  status.textContent = message
  if (error) {
    status.dataset.adminOriginalSongStatusLevel = "error"
  } else {
    delete status.dataset.adminOriginalSongStatusLevel
  }
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

const isStructuredOriginalSongPaste = (text) => /[\t\r\n]/.test(text)

const normalizeOriginalSongPasteText = (text) => text
  .replace(/\r\n/g, "\n")
  .replace(/\r/g, "\n")
  .split("\n")
  .map((row) => row.split("\t", 1)[0].trim())
  .filter(Boolean)
  .join("\n")

const ORIGINAL_SONG_OPTIONS_MAX_HEIGHT = 240
const ORIGINAL_SONG_OPTIONS_TIMEOUT_MS = 15000
let activeOriginalSongPicker
const originalSongPickerResolveQueues = new WeakMap()

const createOriginalSongRequestTimeout = (controller, timeoutMs = ORIGINAL_SONG_OPTIONS_TIMEOUT_MS) => {
  const setTimeoutFunction = globalThis.setTimeout
  const clearTimeoutFunction = globalThis.clearTimeout
  if (typeof setTimeoutFunction !== "function" || typeof clearTimeoutFunction !== "function") return undefined

  let timedOut = false
  const timeoutId = setTimeoutFunction(() => {
    timedOut = true
    controller.abort()
  }, timeoutMs)

  return {
    clear: () => clearTimeoutFunction(timeoutId),
    timedOut: () => timedOut,
  }
}

const originalSongPickerIsMounted = (picker) => picker?.isConnected !== false

const setOriginalSongPickerOptionsExpanded = (picker, expanded) => {
  const searchInput = picker.querySelector("[data-admin-original-song-search]")
  const options = picker.querySelector("[data-admin-original-song-options]")
  if (searchInput) searchInput.setAttribute("aria-expanded", expanded.toString())
  if (options) options.hidden = !expanded
}

const positionOriginalSongOptions = (picker) => {
  if (!originalSongPickerIsMounted(picker)) {
    if (activeOriginalSongPicker === picker) activeOriginalSongPicker = undefined
    return
  }

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
  if (!originalSongPickerIsMounted(picker)) {
    if (activeOriginalSongPicker === picker) activeOriginalSongPicker = undefined
    return
  }

  setOriginalSongPickerOptionsExpanded(picker, false)
  if (activeOriginalSongPicker === picker) activeOriginalSongPicker = undefined
}

const focusOriginalSongPickerSearch = (picker) => {
  picker.querySelector("[data-admin-original-song-search]")?.focus?.({ preventScroll: true })
}

const renderOriginalSongOptions = (picker, optionsPayload) => {
  if (!originalSongPickerIsMounted(picker)) return

  const options = picker.querySelector("[data-admin-original-song-options]")
  if (!options) return

  options.innerHTML = ""
  optionsPayload.forEach((item) => {
    const option = document.createElement("button")
    option.type = "button"
    option.className = "admin-original-song-option"
    option.setAttribute("role", "option")
    option.setAttribute("aria-selected", "false")
    option.dataset.adminOriginalSongSelect = item.title
    if (item.candidateFor) option.dataset.adminOriginalSongCandidateFor = item.candidateFor
    option.textContent = item.label || item.title
    options.appendChild(option)
  })
  const expanded = optionsPayload.length > 0
  setOriginalSongPickerOptionsExpanded(picker, expanded)
  activeOriginalSongPicker = expanded ? picker : undefined
  if (expanded) positionOriginalSongOptions(picker)
}

const resolveOriginalSongText = async (picker, text) => {
  const controller = typeof AbortController === "function" ? new AbortController() : undefined
  const requestTimeout = controller ? createOriginalSongRequestTimeout(controller) : undefined

  try {
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
      signal: controller?.signal,
    })
    if (requestTimeout?.timedOut()) throw new Error("原曲候補の解決がタイムアウトしました。")
    if (!response.ok) throw new Error(`リクエストに失敗しました（HTTP ${response.status}）。`)

    const payload = await response.json()
    if (requestTimeout?.timedOut()) throw new Error("原曲候補の解決がタイムアウトしました。")
    return payload
  } finally {
    requestTimeout?.clear()
  }
}

const enqueueOriginalSongResolve = (picker, text) => {
  const previousRequest = originalSongPickerResolveQueues.get(picker) || Promise.resolve()
  const request = previousRequest
    .catch(() => {})
    .then(() => resolveOriginalSongText(picker, text))

  originalSongPickerResolveQueues.set(picker, request)
  return request.finally(() => {
    if (originalSongPickerResolveQueues.get(picker) === request) originalSongPickerResolveQueues.delete(picker)
  })
}

export const setOriginalSongPickerText = async (searchInput, text, { append = false } = {}) => {
  const picker = searchInput.closest("[data-admin-original-song-picker]")
  if (!picker) {
    searchInput.value = text
    return
  }

  try {
    const payload = await enqueueOriginalSongResolve(picker, text)
    if (!originalSongPickerIsMounted(picker)) return

    const items = payload.items?.length
      ? payload.items.map((item) => ({ title: item.title, status: item.exists ? "valid" : "invalid" }))
      : [{ title: text, status: payload.titles?.length ? "valid" : "invalid" }]
    const nextItems = append ? [...selectedOriginalSongItems(picker), ...items] : items
    updateOriginalSongPickerValue(picker, nextItems)
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
      updateOriginalSongPickerStatus(picker, `${candidates.length.toLocaleString()}件の候補があります。選択してください。`)
    } else {
      hideOriginalSongOptions(picker)
      const resolvedCount = (payload.items || []).filter((item) => item.exists).length || payload.titles?.length || 0
      updateOriginalSongPickerStatus(
        picker,
        resolvedCount > 0 ? "原曲を追加しました。" : "一致する原曲がありません。入力を確認してください。"
      )
    }
  } catch (error) {
    if (!originalSongPickerIsMounted(picker)) return

    console.error(error)
    const invalidItem = { title: text, status: "invalid" }
    updateOriginalSongPickerValue(picker, append ? [...selectedOriginalSongItems(picker), invalidItem] : [invalidItem])
    hideOriginalSongOptions(picker)
    updateOriginalSongPickerStatus(picker, "原曲候補の取得に失敗しました。入力を確認して再試行してください。", { error: true })
  } finally {
    if (originalSongPickerIsMounted(picker) && searchInput.value.trim() === text.trim()) searchInput.value = ""
  }
}

export const setupAdminOriginalSongPickers = () => {
  document.querySelectorAll("[data-admin-original-song-picker]").forEach((picker) => {
    if (picker.dataset.adminOriginalSongPickerInitialized === "true") return

    picker.dataset.adminOriginalSongPickerInitialized = "true"
    setOriginalSongPickerOptionsExpanded(picker, false)
    updateOriginalSongPickerValue(picker, selectedOriginalSongTitles(picker))
    let searchController
    let searchRequestSequence = 0

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
        focusOriginalSongPickerSearch(picker)
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
      const searchInput = picker.querySelector("[data-admin-original-song-search]")
      if (searchInput) {
        searchInput.value = ""
      }
      focusOriginalSongPickerSearch(picker)
      hideOriginalSongOptions(picker)
      updateOriginalSongPickerStatus(picker, "原曲を追加しました。")
    })

    picker.querySelector("[data-admin-original-song-search]")?.addEventListener("input", async (event) => {
      const query = event.target.value.trim()
      const requestSequence = ++searchRequestSequence
      if (searchController) searchController.abort()
      if (!query) {
        hideOriginalSongOptions(picker)
        updateOriginalSongPickerStatus(picker, "")
        return
      }

      searchController = new AbortController()
      const requestTimeout = createOriginalSongRequestTimeout(searchController)
      updateOriginalSongPickerStatus(picker, "候補を検索しています...")
      try {
        const url = new URL(picker.dataset.optionsUrl, window.location.origin)
        url.searchParams.set("q", query)
        const response = await fetch(url, {
          credentials: "same-origin",
          headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
          signal: searchController.signal,
        })
        if (!response.ok) throw new Error(`リクエストに失敗しました（HTTP ${response.status}）。`)

        const optionsPayload = await response.json()
        if (requestTimeout?.timedOut()) throw new Error("原曲候補の検索がタイムアウトしました。")
        if (!Array.isArray(optionsPayload)) throw new Error("候補データの形式が不正です。")
        if (requestSequence !== searchRequestSequence || !originalSongPickerIsMounted(picker)) return

        renderOriginalSongOptions(picker, optionsPayload)
        updateOriginalSongPickerStatus(
          picker,
          optionsPayload.length > 0
            ? `${optionsPayload.length.toLocaleString()}件の候補があります。選択してください。`
            : "一致する原曲がありません。"
        )
      } catch (error) {
        if ((error?.name === "AbortError" && !requestTimeout?.timedOut()) || requestSequence !== searchRequestSequence || !originalSongPickerIsMounted(picker)) return

        console.error(error)
        hideOriginalSongOptions(picker)
        updateOriginalSongPickerStatus(picker, "候補の取得に失敗しました。もう一度お試しください。", { error: true })
      } finally {
        requestTimeout?.clear()
        if (requestSequence === searchRequestSequence) searchController = undefined
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
      if (event.key === "Escape") {
        const options = picker.querySelector("[data-admin-original-song-options]")
        if (options && !options.hidden) event.preventDefault?.()
        hideOriginalSongOptions(picker)
        return
      }

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
        updateOriginalSongPickerStatus(picker, "原曲を追加しました。")
        return
      }

      const text = event.target.value.trim()
      if (text) setOriginalSongPickerText(event.target, text, { append: true })
    })

    picker.querySelector("[data-admin-original-song-search]")?.addEventListener("paste", (event) => {
      const text = event.clipboardData?.getData("text")
      if (!text) return
      if (event.shiftKey && isStructuredOriginalSongPaste(text)) return

      const normalizedText = normalizeOriginalSongPasteText(text)
      if (!normalizedText) return

      event.preventDefault()
      event.stopPropagation()
      return setOriginalSongPickerText(event.target, normalizedText, { append: true })
    })
  })
}

document.addEventListener("click", (event) => {
  if (!activeOriginalSongPicker) return
  if (!originalSongPickerIsMounted(activeOriginalSongPicker)) {
    activeOriginalSongPicker = undefined
    return
  }
  if (event.target.closest("[data-admin-original-song-picker]") === activeOriginalSongPicker) return

  hideOriginalSongOptions(activeOriginalSongPicker)
})

window.addEventListener("resize", () => {
  if (activeOriginalSongPicker) positionOriginalSongOptions(activeOriginalSongPicker)
})

document.addEventListener("scroll", () => {
  if (activeOriginalSongPicker) positionOriginalSongOptions(activeOriginalSongPicker)
}, true)
