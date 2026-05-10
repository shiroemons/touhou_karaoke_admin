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
  setupAdminFilterForms()
  setupAdminInfiniteScroll()
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

  window.addEventListener("popstate", () => {
    replaceAdminResourceContent(window.location.href, { pushState: false }).catch((error) => {
      console.error(error)
      window.location.reload()
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminAsyncIndex)

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

const setupAdminOperationForms = () => {
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    const dialog = document.querySelector("[data-admin-operation-dialog]")
    const dialogMessage = dialog?.querySelector("[data-admin-operation-dialog-message]")
    const confirmButton = dialog?.querySelector("[data-admin-operation-confirm]")
    const cancelButton = dialog?.querySelector("[data-admin-operation-cancel]")
    const submitButton = form.querySelector("[data-admin-operation-submit]")
    const progress = form.querySelector("[data-admin-operation-progress]")
    const progressLabel = form.querySelector("[data-admin-operation-progress-label]")
    const progressPercent = form.querySelector("[data-admin-operation-progress-percent]")
    const progressElapsed = form.querySelector("[data-admin-operation-progress-elapsed]")
    const progressbar = form.querySelector("[data-admin-operation-progressbar]")
    const progressBar = form.querySelector("[data-admin-operation-progress-bar]")
    const progressSteps = form.querySelectorAll("[data-admin-operation-step]")
    let progressTimer
    let elapsedTimer

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

    const updateProgress = (value, label) => {
      if (progressLabel && label) progressLabel.textContent = label
      if (progressPercent) progressPercent.textContent = `${value}%`
      if (progressbar) progressbar.setAttribute("aria-valuenow", value)
      if (progressBar) progressBar.style.width = `${value}%`
    }

    const startProgress = () => {
      if (progress) progress.hidden = false
      if (submitButton) submitButton.disabled = true
      activateProgressStep("prepare")
      updateProgress(8, "入力内容を確認しています...")

      const startedAt = Date.now()
      if (progressElapsed) progressElapsed.textContent = elapsedTime(startedAt)
      elapsedTimer = window.setInterval(() => {
        if (progressElapsed) progressElapsed.textContent = elapsedTime(startedAt)
      }, 1000)
      let current = 8
      progressTimer = window.setInterval(() => {
        if (current >= 24) activateProgressStep("execute")
        current = Math.min(current + Math.ceil((92 - current) / 8), 92)
        updateProgress(current, current >= 92 ? "結果を待っています..." : "サーバーで処理中です...")
        if (current >= 92) activateProgressStep("finish")
        if (current >= 92) window.clearInterval(progressTimer)
      }, 450)
    }

    const submitConfirmed = () => {
      form.dataset.confirmed = "true"
      form.requestSubmit(submitButton || undefined)
    }

    form.addEventListener("submit", (event) => {
      if (form.dataset.confirmed === "true") {
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
  })
}

document.addEventListener("DOMContentLoaded", setupAdminOperationForms)
