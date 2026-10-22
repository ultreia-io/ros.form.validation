#' Validate every input in a saved ROS batch plan
#' @inheritParams read_ros_validation_plan
#' @inheritParams form.validation::validate_batch
#' @return Validation stage state, invisibly.
#' @details Delegates execution, checkpointing, timings and resume to
#'   [form.validation::validate_batch()]. Generates no CSV or HTML reports.
#' @export
validate_ros_plan <- function(plan, resume = TRUE) {
  batch_plan <- read_ros_validation_plan(plan)
  form.validation::validate_batch(batch_plan, resume = resume)
}

#' Generate individual ROS reports from saved results
#' @inheritParams read_ros_validation_plan
#' @inheritParams validate_ros_file
#' @param overwrite Rebuild the complete reports directory from saved results.
#' @return The reports directory, invisibly.
#' @details Delegates saved-result rendering and staging to the neutral engine,
#'   with IOTC branding. Reads no input form or reference CSV.
#' @export
write_ros_reports <- function(plan, report_filename = "index.html", overwrite = FALSE) {
  batch_plan <- read_ros_validation_plan(plan)
  form.validation::write_validation_batch_reports(batch_plan,
    report_filename = report_filename, overwrite = overwrite,
    stylesheet = system.file("report", "iotc.css", package = "ros.form.validation", mustWork = TRUE),
    logo = system.file("report", "IOTC_with_text.png", package = "ros.form.validation", mustWork = TRUE))
}

#' Build aggregate reports and a clean ROS publication
#' @inheritParams read_ros_validation_plan
#' @inheritParams prepare_ros_publication
#' @return The prepared publication directory, invisibly.
#' @details Delegates artifact copying, aggregates, navigation, evidence and
#'   verification to the neutral engine. Retains a portable `plan.json` for future
#'   navigation. Raw results and local paths are excluded. No upload is performed.
#'   The Warning findings card explains the META option saved in the batch plan.
#' @export
build_ros_publication <- function(plan, output = NULL, report_filename = "index.html", comment = NULL) {
  batch_plan <- read_ros_validation_plan(plan)
  publication <- form.validation::build_validation_publication(batch_plan,
    output = output, report_filename = report_filename, title = "ROS validation reports",
    stylesheet = system.file("report", "iotc.css", package = "ros.form.validation", mustWork = TRUE),
    logo = system.file("report", "IOTC_with_text.png", package = "ros.form.validation", mustWork = TRUE),
    reference_context_columns = "gear",
    report_notes = ros_meta_report_note(batch_plan$metadata$options$meta_as_warnings), comment = comment)
  finish_ros_publication_navigation(publication)
  invisible(publication)
}
