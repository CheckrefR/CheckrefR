
.checkrefr_api_endpoints <- list(
  processFulltextDocument  = list(
    path        = "/api/processFulltextDocument",
    method      = "POST",
    input_type  = "pdf",
    description = "Full text extraction"
  ),
  processHeaderDocument    = list(
    path        = "/api/processHeaderDocument",
    method      = "POST",
    input_type  = "pdf",
    description = "Header metadata extraction"
  ),
  processReferences        = list(
    path        = "/api/processReferences",
    method      = "POST",
    input_type  = "pdf",
    description = "Bibliographic references extraction"
  ),
  processCitationList      = list(
    path        = "/api/processCitationList",
    method      = "POST",
    input_type  = "txt",
    description = "Citation parsing from text input"
  )
)

