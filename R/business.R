#' Reuse a registry index matching the explicit rule policy
#' @param snapshot Prepared registry reference index with catalogue-owned aliases.
#' @param rule Rule parameters with optional `matching` and `ignore_case`.
#' @return A matching `reference_index` index, or a newly prepared index.
#'   The supplied snapshot is not modified.
#' @keywords internal
registry_lookup <- function(snapshot, rule) {
  matching <- if (is.null(rule$matching)) "exact" else rule$matching
  ignore_case <- !identical(rule$ignore_case, FALSE)
  if (inherits(snapshot, "reference_index")) {
    if (identical(snapshot$matching, matching) &&
        identical(snapshot$ignore_case, ignore_case)) return(snapshot)
    return(form.references::reference_index(snapshot$data, snapshot$column,
      matching = matching, ignore_case = ignore_case))
  }
  form.references::reference_index(snapshot$values, matching = matching,
    ignore_case = ignore_case)
}

#' Require exactly one registry match for each eligible field value
#' @param model,data Standard callback inputs, unused; values come from the
#'   engine's prepared field accessor.
#' @param references Explicit snapshots keyed by the rule's reference identifier.
#' @param config Callback options containing `field_values` and `rule` parameters:
#'   `field`, `reference`, and optional `matching`.
#' @return Finding rows for unknown or ambiguous values, or `NULL` when none occur.
#'   Missing snapshots signal incomplete execution when eligible values exist;
#'   malformed snapshots raise errors. No external data is read.
#' @keywords internal
registry_match <- function(model, data, references, config) {
  p <- config$rule
  field <- config$field_values(p$field)
  usable <- field$eligible
  if (!length(usable)) return(NULL)
  snapshot <- references[[p$reference]]
  if (is.null(snapshot)) form.validation::signal_validation_incomplete(paste("Missing registry snapshot:", p$reference))
  if (!is.list(snapshot) || is.null(snapshot$values) ||
      !(is.atomic(snapshot$values) || is.list(snapshot$values))) stop("Registry snapshot needs values: ", p$reference)
  index <- registry_lookup(snapshot, p)
  counts <- lengths(form.references::reference_match_rows(index, field$original[usable]))
  bad <- which(counts != 1L)
  if (!length(bad)) return(NULL)
  positions <- usable[bad]
  form.validation::create_validation_findings(
    ifelse(counts[bad] == 0L,
      paste("Value not found in registry", p$reference),
      paste("Value has", counts[bad], "matches in registry", paste0(p$reference, "; expected exactly one"))),
    row = field$rows[positions], sheet = field$sheet, field = field$field,
    column = field$column, value = field$original[positions],
    expected = list(list(reference = p$reference, matches = 1L)))
}

#' Keep an unresolved source declaration explicitly incomplete
#' @param model,references Standard callback inputs, unused.
#' @param data Supplied worksheet grids, used to check an optional sheet scope.
#' @param config Callback options whose `rule` contains `message`, optional `sheet`
#'   and optional `field` identifying an unresolved source field.
#' @return `NULL` when the scoped sheet is absent; otherwise signals incomplete
#'   execution with the declaration's message.
#' @keywords internal
source_issue <- function(model, data, references, config) {
  p <- config$rule
  if (!is.null(p$sheet) && !p$sheet %in% names(data)) return(NULL)
  form.validation::signal_validation_incomplete(p$message, sheet = p$sheet, field = p$field)
}
