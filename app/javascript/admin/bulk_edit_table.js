import { setOriginalSongPickerText } from "./original_song_picker"

const parseBulkEditCoordinate = (value) => {
  const coordinate = Number(value)
  return Number.isInteger(coordinate) && coordinate >= 0 ? coordinate : null
}

export const setupAdminBulkEditTables = () => {
  document.querySelectorAll("[data-admin-bulk-edit-table]").forEach((table) => {
    if (table.dataset.adminBulkEditInitialized === "true") return

    table.dataset.adminBulkEditInitialized = "true"
    table.addEventListener("paste", (event) => {
      const target = event.target.closest("[data-admin-bulk-cell]")
      if (!target) return

      const text = event.clipboardData?.getData("text")
      if (!text || !/[\t\r\n]/.test(text)) return

      if (target.dataset.adminOriginalSongSearch === "true" && !event.shiftKey) return

      const startRow = parseBulkEditCoordinate(target.dataset.adminBulkRow)
      const startColumn = parseBulkEditCoordinate(target.dataset.adminBulkColumnIndex)
      if (startRow === null || startColumn === null) return

      const pastedRows = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n")
      if (pastedRows[pastedRows.length - 1] === "") pastedRows.pop()
      if (pastedRows.length === 0) return

      event.preventDefault()

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
