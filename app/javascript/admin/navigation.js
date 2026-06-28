let setupPageBehaviors = () => {}

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
  setupPageBehaviors()
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
  setupPageBehaviors()
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

  setupAdminFilterForms()
  setupAdminAsyncIndex()
  setupAdminPageNavigation()
  setupAdminClickableRows()
}
