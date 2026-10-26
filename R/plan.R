#' Plan a complete ROS validation batch
#'
#' Scan the classified input tree once and freeze its work list, form definitions,
#' rules and prepared references. Planning does not open input workbooks.
#' @param input Classified input root.
#' @param references One reference directory, or a named character vector mapping
#'   each selected model version to its reference directory.
#' @param versions Explicit model versions to include, including versions without inputs.
#' @param output New batch directory; defaults to `output/ros-validation-<UTC timestamp>`.
#' @inheritParams validate_ros_file
#' @inheritParams ros_validation_inputs
#' @inheritParams ros_validation
#' @return A neutral `validation_batch_plan`, also saved as `plan.rds`.
#' @details `plan.json` contains portable relative paths and grouping metadata for
#'   future report navigation. Private paths and frozen resources stay in local RDS
#'   files. Each selected version/gear combination is recorded, even with no forms.
#'   Input hashes bind validation to the planned files. Use a new plan after changing
#'   inputs or validation resources. Later stages never discover additional inputs.
#' @export
plan_ros_validation <- function(input, references, versions, output = NULL,
                                country = NULL, year = NULL, gear = "all", meta_as_warnings = TRUE, trim_ws = TRUE) {
  # Configure the callback now; the batch invokes it only during validation.
  reader <- ros_workbook_reader_supplier(trim_ws)
  check_meta_as_warnings(meta_as_warnings)
  if (missing(versions) || !is.character(versions) || !length(versions) ||
      anyNA(versions) || any(!versions %in% ros.form.model::ROS_FORM_VERSIONS))
    stop("Supply supported model versions explicitly", call. = FALSE)
  versions <- unique(versions)
  gears <- ros_batch_gears(gear)
  input <- normalizePath(input, mustWork = TRUE)
  files <- scan_ros_inputs(input, versions, country, year, gears)
  if (!is.character(references) || !length(references) || anyNA(references))
    stop("Supply reference directories", call. = FALSE)
  if (length(references) == 1L && is.null(names(references)))
    references <- stats::setNames(rep(references, length(versions)), versions)
  if (is.null(names(references)) || anyDuplicated(names(references)) ||
      !all(versions %in% names(references))) stop("References must cover every selected version", call. = FALSE)
  references <- vapply(references[versions], normalizePath, character(1), mustWork = TRUE)
  if (any(!dir.exists(references))) stop("References must be directories", call. = FALSE)
  if (is.null(output)) output <- file.path("output", paste0("ros-validation-",
    format(Sys.time(), "%Y-%m-%dT%H%M%SZ", tz = "UTC")))
  if (!grepl("^ros-validation-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z$", basename(output)))
    stop("Batch directory must be named ros-validation-<UTC timestamp>", call. = FALSE)
  if (file.exists(output)) stop("Batch directory already exists: ", output, call. = FALSE)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  output <- file.path(normalizePath(dirname(output), mustWork = TRUE), basename(output))
  if (startsWith(paste0(output, "/"), paste0(input, "/")))
    stop("Batch output must be outside the input tree", call. = FALSE)
  resources <- stats::setNames(lapply(versions, function(version) {
    rules_plans <- stats::setNames(lapply(gears, ros_validation, version = version,
      meta_as_warnings = meta_as_warnings), gears)
    rules_plans <- lapply(rules_plans, function(rules_plan) {
      rules_plan$metadata$options$trim_ws <- trim_ws
      rules_plan$metadata$options$missing_values <- ros_missing_value_policy()
      rules_plan
    })
    active <- unique(tolower(files$gear[files$model_version == version]))
    preparation_plans <- if (length(active)) rules_plans[active] else rules_plans
    list(plans = rules_plans, references = read_ros_references(references[[version]], preparation_plans,
      prepare = length(active) > 0L))
  }), versions)
  jobs <- expand.grid(model_version = versions, gear = gears, stringsAsFactors = FALSE)
  jobs$id <- paste(jobs$model_version, jobs$gear, sep = "-")
  jobs$resource <- jobs$model_version
  jobs$plan <- jobs$gear
  files$job <- paste(files$model_version, tolower(files$gear), sep = "-", recycle0 = TRUE)
  files$title <- paste("ROS validation report -", tolower(files$gear), "-", files$relative, recycle0 = TRUE)
  form.validation::validation_batch_plan(files, jobs, resources, output,
    group_columns = c("year", "country", "gear", "version"), identity_columns = c("gear", "version"),
    model_versions = versions, packages = c("ros.form.validation", "ros.form.model"),
    metadata = list(consumer = "ros.form.validation", input = input,
      options = list(meta_as_warnings = meta_as_warnings, trim_ws = trim_ws, missing_values = ros_missing_value_policy()),
      filters = list(country = country, year = year, gear = gears)),
    config = list(blank_strings = TRUE), reader = reader, prepare_data = ros_preparation_supplier(unlist(lapply(resources, function(bundle) bundle$plans), recursive = FALSE)))
}

#' Read a saved ROS batch plan
#' @param plan A `validation_batch_plan`, its batch directory, or its local `plan.rds` file.
#' @return The verified plan, with its current local batch directory.
#' @details RDS files are local application artifacts; read only plans you trust.
#'   Reading a plan does not scan inputs or reopen reference CSV files.
#' @export
read_ros_validation_plan <- function(plan) {
  batch_plan <- form.validation::read_validation_batch_plan(plan)
  if (!identical(batch_plan$metadata$consumer, "ros.form.validation")) stop("Expected a ROS batch plan", call. = FALSE)
  batch_plan
}
