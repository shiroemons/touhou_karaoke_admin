let setupPageBehaviors = () => {}

const mobileNavigationToggleSelector = "[data-admin-mobile-navigation-toggle]"
const mobileNavigationToggleLabelSelector = "[data-admin-mobile-navigation-toggle-label]"
const mobileNavigationOpenSelector = ".admin-sidebar[data-admin-mobile-navigation-open=\"true\"]"

const setAdminMobileNavigationOpen = (sidebar, open) => {
  sidebar.dataset.adminMobileNavigationOpen = open.toString()

  const toggle = sidebar.querySelector(mobileNavigationToggleSelector)
  if (!toggle) return

  toggle.setAttribute("aria-expanded", open.toString())
  toggle.setAttribute("aria-label", open ? "メニューを閉じる" : "メニューを開く")

  const label = toggle.querySelector(mobileNavigationToggleLabelSelector)
  if (label) label.textContent = open ? "閉じる" : "メニュー"
}

export const setupAdminMobileNavigation = () => {
  if (document.documentElement.dataset.adminMobileNavigationInitialized === "true") return

  document.documentElement.dataset.adminMobileNavigationInitialized = "true"

  document.addEventListener("click", (event) => {
    const toggle = event.target.closest?.(mobileNavigationToggleSelector)
    if (toggle) {
      const sidebar = toggle.closest(".admin-sidebar")
      if (sidebar) {
        const open = sidebar.dataset.adminMobileNavigationOpen === "true"
        setAdminMobileNavigationOpen(sidebar, !open)
      }
      return
    }

    const navigationLink = event.target.closest?.(".admin-nav-link, .admin-brand")
    if (!navigationLink) return

    const sidebar = navigationLink.closest(".admin-sidebar")
    if (sidebar) setAdminMobileNavigationOpen(sidebar, false)
  })

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return

    const sidebar = document.querySelector(mobileNavigationOpenSelector)
    if (!sidebar) return

    setAdminMobileNavigationOpen(sidebar, false)
    sidebar.querySelector(mobileNavigationToggleSelector)?.focus()
  })
}

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

const validateAdminResourceContentPayload = (payload) => {
  if (!payload || typeof payload !== "object" || typeof payload.html !== "string" || payload.html.trim().length === 0) {
    throw new Error("一覧データの形式が不正です。")
  }

  return payload
}

let adminResourceContentController

const describeResourceContentFocus = (element, content) => {
  if (!element || !content?.contains?.(element)) return null

  return {
    id: element.id || "",
    name: element.name || "",
    type: element.type || "",
  }
}

const restoreResourceContentFocus = (descriptor) => {
  if (!descriptor) return

  const content = document.querySelector("[data-admin-resource-content]")
  const candidates = Array.from(content?.querySelectorAll?.("[id], [name]") || [])
  const focusTarget = candidates.find((element) => {
    if (descriptor.id && element.id === descriptor.id) return true
    return descriptor.name && element.name === descriptor.name && (!descriptor.type || element.type === descriptor.type)
  })

  focusTarget?.focus?.({ preventScroll: true })
  if (!focusTarget) content?.focus?.({ preventScroll: true })
}

export const replaceAdminResourceContent = async (url, { pushState = true } = {}) => {
  if (adminResourceContentController) adminResourceContentController.abort()

  const controller = new AbortController()
  adminResourceContentController = controller
  const currentContent = document.querySelector("[data-admin-resource-content]")
  const focusDescriptor = describeResourceContentFocus(document.activeElement, currentContent)
  currentContent?.setAttribute("aria-busy", "true")

  try {
    const response = await fetch(adminContentUrl(url), {
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest",
      },
      signal: controller.signal,
    })

    if (!response.ok) throw new Error(`リクエストに失敗しました（HTTP ${response.status}）。`)
    if (adminResourceContentController !== controller) return

    const payload = validateAdminResourceContentPayload(await response.json())
    if (adminResourceContentController !== controller || !currentContent) return

    currentContent.outerHTML = payload.html
    if (pushState) window.history.pushState({}, "", browserUrl(url))
    setupPageBehaviors()
    restoreResourceContentFocus(focusDescriptor)
  } finally {
    if (adminResourceContentController === controller) {
      currentContent?.setAttribute("aria-busy", "false")
      adminResourceContentController = undefined
    }
  }
}

const isAsyncAdminLink = (link) => {
  if (!link) return false
  if (!link.matches(".admin-sort-link, .admin-view-mode-button, .admin-pagination a, .admin-query-panel a")) return false

  const url = new URL(link.href, window.location.origin)
  return url.origin === window.location.origin && url.pathname.startsWith("/admin/")
}

export const setupAdminAsyncIndex = () => {
  if (document.documentElement.dataset.adminAsyncIndexInitialized === "true") return

  document.documentElement.dataset.adminAsyncIndexInitialized = "true"

  document.addEventListener("click", (event) => {
    const link = event.target.closest("a")
    if (!isAsyncAdminLink(link)) return

    event.preventDefault()
    replaceAdminResourceContent(link.href).catch((error) => {
      if (error.name === "AbortError") return

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
      if (error.name === "AbortError") return

      console.error(error)
      form.submit()
    })
  })

}


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

export const replaceAdminPage = (html, url, { pushState = true } = {}) => {
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
  pageContent?.scrollTo?.({ top: 0, left: 0 })
  setupPageBehaviors()
  pageContent?.focus?.({ preventScroll: true })
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

    if (!response.ok) throw new Error(`リクエストに失敗しました（HTTP ${response.status}）。`)

    replaceAdminPage(await response.text(), response.url, { pushState })
  } finally {
    if (adminPageNavigationController === controller) {
      delete document.body.dataset.adminNavigation
      document.querySelector("[data-admin-page-content]")?.setAttribute("aria-busy", "false")
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


export const setupAdminFilterForms = () => {
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


export const setupAdminNavigation = ({ setupPageBehaviors: nextSetupPageBehaviors } = {}) => {
  if (nextSetupPageBehaviors) setupPageBehaviors = nextSetupPageBehaviors

  setupAdminMobileNavigation()
  setupAdminFilterForms()
  setupAdminAsyncIndex()
  setupAdminPageNavigation()
  setupAdminClickableRows()
}
