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
      rows.insertAdjacentHTML("beforeend", payload.html)
      sentinel.dataset.nextUrl = payload.next_url || ""
      sentinel.hidden = !payload.next_url
      if (retryButton) retryButton.hidden = true
      updateSelectionState?.()
      const visibleCount = document.querySelector("[data-admin-visible-count]")
      if (visibleCount) visibleCount.textContent = rows.querySelectorAll("tr").length.toLocaleString()
      if (status) status.textContent = payload.next_url ? "さらに読み込みます" : "すべて読み込みました"
    } catch (error) {
      if (status) status.textContent = "読み込みに失敗しました。再試行してください。"
      if (retryButton) retryButton.hidden = false
    } finally {
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
