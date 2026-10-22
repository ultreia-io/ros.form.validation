#' Load versioned ROS validation rules
#'
#' Read the installed process: structure first, then generated and business checks.
#' Additional business files use explicitly supplied R callbacks; no file is
#' sourced and no YAML expression is evaluated.
#' @param name Workbook model: `ros.form.model::ROS_FORM_LL` (longline) or
#'   `ros.form.model::ROS_FORM_PS` (purse seine).
#' @param version Required exact model version; no default is selected.
#' @param business Optional character vector of additional business YAML paths.
#'   Files must bind to the same model and rules version as the installed rules.
#' @param checks Named list of additional callbacks following
#'   `form.validation::validation_rule()`. Built-in callbacks cannot be replaced.
#' @param meta_as_warnings Report META content errors as warnings? Defaults to
#'   `TRUE`. Structure checks and execution statuses are unchanged. Set `FALSE`
#'   to retain original rule severities. The choice is saved with the result.
#' @return A `validation_plan` for `form.validation::validate_data()`.
#' @seealso [form.validation documentation](https://ultreia-io.github.io/form.validation/)
#' @examples
#' plan <- ros_validation(
#'   name = ros.form.model::ROS_FORM_LL, version = ros.form.model::ROS_FORM_VERSION_4_1_0
#' )
#' plan$rules_version
#' @export
ros_validation <- function(name, version,
                           business = NULL, checks = list(), meta_as_warnings = TRUE) {
  check_meta_as_warnings(meta_as_warnings)
  model <- ros.form.model::ros_form(name, version)
  directory <- system.file("rules", version, package = "ros.form.validation", mustWork = TRUE)
  path <- file.path(directory, paste0(name, "-validation.yaml"))
  builtin <- list(registry_match = registry_match, source_issue = source_issue)
  if (!is.list(checks) || (length(checks) && (is.null(names(checks)) ||
      anyNA(names(checks)) || any(!nzchar(names(checks))) || anyDuplicated(names(checks))))) {
    stop("checks must be a named list", call. = FALSE)
  }
  if (any(names(checks) %in% names(builtin))) stop("Built-in ROS callbacks cannot be replaced", call. = FALSE)
  if (!is.null(business) && (!is.character(business) || anyNA(business) || any(!nzchar(business)))) {
    stop("business must contain explicit YAML filenames", call. = FALSE)
  }
  plan <- form.validation::read_validation_process(path, model, c(builtin, checks),
    business = if (is.null(business)) character() else business)
  if (meta_as_warnings) {
    plan$rules <- lapply(plan$rules, function(rule) {
      sheets <- c(rule$sheet, rule$parameters$sheet)
      fields <- c(rule$field, rule$parameters$field)
      is_meta <- "META" %in% sheets || any(startsWith(as.character(fields), "META."))
      if (rule$stage != "structure" && is_meta && rule$severity == "error") rule$severity <- "warning"
      rule
    })
  }
  plan$metadata <- list(options = list(meta_as_warnings = meta_as_warnings),
    report_notes = ros_meta_report_note(meta_as_warnings))
  plan
}

#' Describe the recorded META policy for individual and aggregate reports
#' @param meta_as_warnings Saved logical option, or NULL for batches without it.
#' @return Policy text, or an empty character vector when the policy is unknown.
#' @keywords internal
ros_meta_report_note <- function(meta_as_warnings) {
  if (is.null(meta_as_warnings)) return(character())
  check_meta_as_warnings(meta_as_warnings)
  if (meta_as_warnings) "META content issues are reported as warnings." else
    "META content checks use their original rule severities."
}

#' Check the META content severity option
#' @param meta_as_warnings Scalar logical policy.
#' @return Nothing; invalid values raise an error.
#' @keywords internal
check_meta_as_warnings <- function(meta_as_warnings) {
  if (!is.logical(meta_as_warnings) || length(meta_as_warnings) != 1L || is.na(meta_as_warnings))
    stop("meta_as_warnings must be TRUE or FALSE", call. = FALSE)
}

#' Validate supplied ROS data
#'
#' Run the versioned ROS checks with explicit data and reference snapshots.
#' @inheritParams ros_validation
#' @param data Named list of data frames or matrices in model sheet order.
#'   Retain physical preamble rows; columns follow the model field order.
#'   Nothing is coerced or loaded.
#' @param references Named list of snapshots. Code lists use `list(values=...)`
#'   with optional `aliases` mapping original codes to canonical values.
#'   Workbook registries use the exact YAML reference name and `list(values=...)`;
#'   repeated keys are retained because a registry match must be unique.
#'   Name rules request normalized matching and aliases explicitly in YAML.
#'   Snapshots from [`read_ros_references()`][ros.form.validation::read_ros_references] include reusable registry indexes.
#'   All snapshots are supplied explicitly; no external service is queried.
#' @param source Input label retained in findings and result exports.
#' @param config Options for `form.validation::validate_data()`. The default
#'   treats empty strings as missing, matching the workbook rules. Whitespace
#'   and `"-"` remain literal values; any import normalization is caller-owned.
#' @return The unchanged `validation_result` from form.validation, including
#'   findings and execution status. Export with
#'   `form.validation::write_validation_results()` for `summary.csv` and
#'   `findings.csv` in one directory per input. Use [`write_ros_validation_report()`][ros.form.validation::write_ros_validation_report]
#'   to render the same result as a standalone HTML report.
#' @details All structure checks run first. Structural errors or unfinished
#'   structure checks skip every generated and business check. After structure
#'   passes, generated checks run before business checks in one content ruleset.
#'   Structural warning and info findings do not close the gate.
#'   Missing lookup snapshots make affected rules incomplete. Invalid
#'   snapshots make execution fail. Unknown keys are validation findings.
#'   Unresolved source declarations are reported as incomplete execution when
#'   their affected sheet is supplied.
#' @seealso [form.validation documentation](https://ultreia-io.github.io/form.validation/)
#' @examples
#' result <- validate_ros(
#'   name = ros.form.model::ROS_FORM_LL, data = list(), source = "empty.xlsx",
#'   version = ros.form.model::ROS_FORM_VERSION_3_3_0
#' )
#' result$status
#' @export
validate_ros <- function(name, data, references = list(), source = "<data>",
                         version,
                         config = list(blank_strings = TRUE),
                         business = NULL, checks = list(), meta_as_warnings = TRUE) {
  plan <- ros_validation(name, version, business, checks, meta_as_warnings = meta_as_warnings)
  form.validation::validate_data(plan, data, references, source, config)
}
