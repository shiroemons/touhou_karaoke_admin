// Entry point for the build script in your package.json
import "@rails/ujs"
import Rails from "@rails/ujs"
import { setupAdminBulkEditControls } from "./bulk_edit_controls"
import { setupAdminFlash, showAdminFlash } from "./flash"
import { setupAdminInfiniteScroll } from "./infinite_scroll"
import { setupAdminFilterForms, setupAdminNavigation } from "./navigation"
import { setupAdminResourceOperations, updateAdminResourceSelectionState } from "./resource_operations"
import { setupAdminWorkflowRunner } from "./workflow_runner"

Rails.start()

document.addEventListener("DOMContentLoaded", setupAdminFlash)
document.addEventListener("DOMContentLoaded", () => setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState }))
document.addEventListener("DOMContentLoaded", setupAdminBulkEditControls)
document.addEventListener("DOMContentLoaded", () => setupAdminNavigation({ setupPageBehaviors: setupAdminPageBehaviors }))
document.addEventListener("DOMContentLoaded", () => setupAdminWorkflowRunner({ showFlash: showAdminFlash }))

const setupAdminPageBehaviors = () => {
  setupAdminFilterForms()
  setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState })
  setupAdminBulkEditControls()
  setupAdminResourceOperations()
  setupAdminWorkflowRunner({ showFlash: showAdminFlash })
}

document.addEventListener("DOMContentLoaded", setupAdminResourceOperations)
