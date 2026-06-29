import { setOriginalSongPickerText } from "./original_song_picker"

export const setupAdminBulkEditTables = () => {
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
