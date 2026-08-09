const adminInfiniteScrollBaseUrl = () =>
  typeof window !== "undefined" && window.location?.origin ? window.location.origin : "http://admin.example.test"

const validateAdminInfiniteScrollPayload = (payload, currentUrl) => {
  if (
    !payload ||
    typeof payload !== "object" ||
    typeof payload.html !== "string" ||
    !Object.prototype.hasOwnProperty.call(payload, "next_url") ||
    (payload.next_url !== null && typeof payload.next_url !== "string")
  ) {
    throw new Error("一覧データの形式が不正です。")
  }

  if (!payload.next_url) return

  const baseUrl = adminInfiniteScrollBaseUrl()
  const current = new URL(currentUrl, baseUrl)
  const next = new URL(payload.next_url, baseUrl)
  const isAdminUrl = (url) => url.origin === baseUrl && url.pathname.startsWith("/admin/")
  if (!isAdminUrl(next) || next.href === current.href) throw new Error("次の一覧ページを特定できません。")
}

export const setupAdminInfiniteScroll = ({ updateSelectionState } = {}) => {
  const sentinel = document.querySelector("[data-admin-infinite-scroll]")
  const rows = document.querySelector("#admin-resource-rows")
  if (!sentinel || !rows || sentinel.dataset.initialized === "true") return

  sentinel.dataset.initialized = "true"
  const scrollRoot = sentinel.closest(".admin-table-wrap")
  const status = sentinel.querySelector("[data-admin-infinite-scroll-status]")
  const retryButton = sentinel.querySelector("[data-admin-infinite-scroll-retry]")
  let loading = false

  const loadNextPage = async () => {
    const nextUrl = sentinel.dataset.nextUrl
    if (loading || !nextUrl) return

    loading = true
    sentinel.setAttribute("aria-busy", "true")
    if (status) status.textContent = "読み込み中..."

    try {
      const response = await fetch(nextUrl, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
      })

      if (!response.ok) throw new Error(`リクエストに失敗しました（HTTP ${response.status}）。`)

      const payload = await response.json()
      validateAdminInfiniteScrollPayload(payload, nextUrl)
      const followingUrl = payload.next_url || ""
      rows.insertAdjacentHTML("beforeend", payload.html)
      sentinel.dataset.nextUrl = followingUrl
      sentinel.hidden = !followingUrl
      if (retryButton) retryButton.hidden = true
      updateSelectionState?.()
      const visibleCount = document.querySelector("[data-admin-visible-count]")
      if (visibleCount) visibleCount.textContent = rows.querySelectorAll("tr").length.toLocaleString()
      if (status) status.textContent = followingUrl ? "さらに読み込みます" : "すべて読み込みました"
    } catch {
      if (status) status.textContent = "読み込みに失敗しました。再試行してください。"
      if (retryButton) retryButton.hidden = false
    } finally {
      sentinel.setAttribute("aria-busy", "false")
      loading = false
    }
  }

  retryButton?.addEventListener("click", () => {
    retryButton.hidden = true
    loadNextPage()
  })

  const observer = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) loadNextPage()
  }, { root: scrollRoot, rootMargin: "240px" })

  observer.observe(sentinel)
}
