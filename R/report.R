#' Write one ROS input's validation report
#'
#' Use the shared report renderer with the matching ROS form and report title.
#' The existing validation result is reused; no workbook is read or revalidated.
#' @param result A result from [validate_ros()].
#' @param path Destination HTML filename.
#' @param overwrite Replace an existing report? Defaults to `FALSE`.
#' @param parent_report Optional URL of the parent aggregate report.
#' @return The normalized HTML path, invisibly.
#' @examples
#' if (interactive()) {
#'   result <- validate_ros(
#'     name = ros.form.model::ROS_FORM_LL, data = list(), source = "submission.xlsx",
#'     version = ros.form.model::ROS_FORM_VERSION_4_1_0
#'   )
#'   write_ros_validation_report(result, tempfile(fileext = ".html"))
#' }
#' @export
write_ros_validation_report <- function(result, path, overwrite = FALSE, parent_report = NULL) {
  if (!inherits(result, "validation_result")) stop("result must come from validate_ros()", call. = FALSE)
  name <- result$model$form$id
  model <- ros.form.model::ros_form(name, result$model$form$version)
  report <- model.validation::validation_report_data(result, model)
  model.validation::write_validation_report(report, path,
    title = paste("ROS validation report \u2014", toupper(name)),
    overwrite = overwrite, parent_report = parent_report,
    stylesheet = system.file("report", "iotc.css", package = "ros.form.validation", mustWork = TRUE),
    logo = system.file("report", "IOTC_with_text.png", package = "ros.form.validation", mustWork = TRUE))
}
