#' Prepare verified ROS reference snapshots
#'
#' Download only the code lists and registry tables declared by the six ROS
#' models. The resulting directory can be passed to `plan_ros_validation()` as
#' `references` for all three model versions.
#' @param directory New output directory for the batch's reference snapshots.
#' @param code_lists A `form.references::reference_source()` configured for the
#'   public code-list catalogue.
#' @param registries A `form.references::reference_source()` configured for the
#'   private registry catalogue, including its authentication headers.
#' @return The normalized snapshot directory path.
#' @details Both catalogues and every selected CSV are verified by
#'   `form.references` before their exact bytes are copied. Only model-declared
#'   tables are copied. The output is created after all downloads succeed.
#' @export
prepare_ros_reference_snapshots <- function(directory, code_lists, registries) {
  if (!is.character(directory) || length(directory) != 1L || is.na(directory) ||
      !nzchar(directory)) stop("directory must be one nonempty path", call. = FALSE)
  if (file.exists(directory)) stop("Output already exists: ", directory, call. = FALSE)
  code_paths <- character()
  registry_paths <- character()
  for (version in ros.form.model::ROS_FORM_VERSIONS) {
    for (gear in ros.form.model::ROS_FORMS) {
      model <- ros.form.model::ros_form(gear, version)
      code_paths <- c(code_paths, form.references::get_form_code_lists(model, code_lists)$paths)
      registry_paths <- c(registry_paths,
        form.references::get_form_registries(model, registries)$paths)
    }
  }
  code_paths <- code_paths[!duplicated(names(code_paths))]
  registry_paths <- registry_paths[!duplicated(names(registry_paths))]

  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  completed <- FALSE
  on.exit(if (!completed) unlink(directory, recursive = TRUE), add = TRUE)
  for (kind in c("code_lists", "registries")) {
    paths <- if (kind == "code_lists") code_paths else registry_paths
    destination <- file.path(directory, kind)
    dir.create(destination, showWarnings = FALSE)
    for (id in names(paths)) {
      if (!file.copy(paths[[id]], file.path(destination, paste0(id, ".csv"))))
        stop("Cannot stage verified reference: ", id, call. = FALSE)
    }
  }
  completed <- TRUE
  normalizePath(directory, mustWork = TRUE)
}
