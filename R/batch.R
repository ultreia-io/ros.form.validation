#' Plan, validate and report one selected ROS model version
#' @inheritParams ros_validation_inputs
#' @param input Root directory containing classified input forms.
#' @param references Directory containing explicit reference CSV snapshots.
#' @param output Parent directory for the new timestamped batch.
#' @param dry_run List selected inputs without reading forms or writing files.
#' @inheritParams validate_ros_file
#' @inheritParams ros_validation
#' @return Selected metadata in dry-run mode; otherwise the batch directory, invisibly.
#' @details Convenience entry point for the staged pipeline. Creates a saved plan,
#'   completes validation for every selected form, then generates individual reports.
#'   Use [`plan_ros_validation()`][ros.form.validation::plan_ros_validation], [`validate_ros_plan()`][ros.form.validation::validate_ros_plan] and [`write_ros_reports()`][ros.form.validation::write_ros_reports]
#'   to run or resume these stages separately. Aggregate preparation and uploading
#'   remain separate operations.
#' @export
validate_ros_inputs <- function(input, references, output = "build/validation",
                                country = NULL, year = NULL, gear = "all", dry_run = FALSE,
                                version, report_filename = "index.html", meta_as_warnings = TRUE, trim_ws = TRUE) {
  check_meta_as_warnings(meta_as_warnings)
  if (missing(version)) stop("Supply an explicit ROS data-model version", call. = FALSE)
  check_report_filename(report_filename)
  if (dry_run) return(ros_validation_inputs(input, country, year, gear, version))
  batch <- file.path(output, paste0("ros-validation-", format(Sys.time(), "%Y-%m-%dT%H%M%SZ", tz = "UTC")))
  batch_plan <- plan_ros_validation(input, references, version, batch, country, year, gear,
    meta_as_warnings = meta_as_warnings, trim_ws = trim_ws)
  validate_ros_plan(batch_plan)
  write_ros_reports(batch_plan, report_filename)
  invisible(batch_plan$directory)
}
