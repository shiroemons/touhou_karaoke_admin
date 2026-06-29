import { setupAdminAssociationDialogs } from "./association_dialogs"
import { setupAdminBulkEditTables } from "./bulk_edit_table"
import { setupAdminOriginalSongPickers } from "./original_song_picker"
import { setupAdminSearchableSelects } from "./searchable_select"

export const setupAdminBulkEditControls = () => {
  setupAdminOriginalSongPickers()
  setupAdminBulkEditTables()
  setupAdminSearchableSelects()
  setupAdminAssociationDialogs()
}
