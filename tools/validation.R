#!/usr/bin/env Rscript
# Each command runs one stage; publication is always an explicit final command.
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
if (requireNamespace("pkgload", quietly = TRUE)) {
  for (package in c("form.model", "form.validation", "ros.form.model", "ros.form.validation")) {
    path <- file.path(dirname(root), package)
    if (file.exists(file.path(path, "DESCRIPTION"))) pkgload::load_all(path, quiet = TRUE)
  }
}
args <- commandArgs(TRUE)
if (!length(args) || "--help" %in% args) {
  cat(paste(
    "Usage: Rscript tools/validation.R <stage> [options]",
    "  plan --input DIR --versions 3.3.0,4.0.0,4.1.0",
    "       --reference 3.3.0=DIR --reference 4.0.0=DIR --reference 4.1.0=DIR",
    "       [--output output/ros-validation-<timestamp>] [--country CODE] [--year YEAR] [--gear all|ll|ps]",
    "       [--meta-as-warnings true|false] (default: true; fixed when planning)",
    "       [--trim-ws true|false] (default: true; fixed when planning)",
    "       Use --references DIR when all selected versions use the same reference directory.",
    "  validate --plan BATCH_OR_PLAN_RDS [--no-resume]",
    "  report --plan BATCH_OR_PLAN_RDS [--report-filename index.html] [--overwrite]",
    "  build-publication --plan BATCH_OR_PLAN_RDS [--output DIR] [--report-filename index.html] [--comment TEXT]",
    "  publish --directory output/aggregated_ros-validation-<timestamp> [--host ultreia]",
    sep = "\n"), "\n")
  quit(status = 0)
}
stage <- args[[1L]]
allowed <- switch(stage,
  plan = c("input", "versions", "references", "reference", "output", "country", "year", "gear", "meta-as-warnings", "trim-ws"),
  validate = c("plan", "no-resume"),
  report = c("plan", "report-filename", "overwrite"),
  `build-publication` = c("plan", "output", "report-filename", "comment"),
  publish = c("directory", "host"),
  stop("Unknown stage: ", stage, call. = FALSE))
options <- list()
references <- character()
i <- 2L
while (i <= length(args)) {
  key <- sub("^--", "", args[[i]])
  if (!startsWith(args[[i]], "--") || !key %in% allowed)
    stop("Unknown option for ", stage, ": ", args[[i]], call. = FALSE)
  if (key %in% names(options)) stop("Repeated option: ", key, call. = FALSE)
  if (key %in% c("overwrite", "no-resume")) {
    options[[key]] <- TRUE
    i <- i + 1L
    next
  }
  if (i == length(args) || startsWith(args[[i + 1L]], "--")) stop("Missing value for --", key, call. = FALSE)
  value <- args[[i + 1L]]
  if (key == "reference") {
    if (!grepl("^[0-9]+[.][0-9]+[.][0-9]+=.+$", value)) stop("Use --reference VERSION=DIR", call. = FALSE)
    version <- sub("=.*$", "", value)
    if (version %in% names(references)) stop("Repeated reference version: ", version, call. = FALSE)
    references[[version]] <- sub("^[^=]+=", "", value)
  } else options[[key]] <- value
  i <- i + 2L
}
required <- switch(stage, plan = c("input", "versions"), publish = "directory", "plan")
for (key in required) if (is.null(options[[key]])) stop("Supply --", key, call. = FALSE)
if (stage == "plan") {
  if (!is.null(options[["trim-ws"]])) {
    value <- tolower(options[["trim-ws"]])
    if (!value %in% c("true", "false")) stop("--trim-ws must be true or false", call. = FALSE)
    options$trim_ws <- value == "true"
    options[["trim-ws"]] <- NULL
  }
  if (!is.null(options[["meta-as-warnings"]])) {
    value <- tolower(options[["meta-as-warnings"]])
    if (!value %in% c("true", "false")) stop("--meta-as-warnings must be true or false", call. = FALSE)
    options$meta_as_warnings <- value == "true"
    options[["meta-as-warnings"]] <- NULL
  }
  if (length(references)) {
    if (!is.null(options$references)) stop("Use either --reference or --references", call. = FALSE)
    options$references <- references
  }
  if (is.null(options$references)) stop("Supply reference directories", call. = FALSE)
  for (key in intersect(c("versions", "country", "year", "gear"), names(options)))
    options[[key]] <- strsplit(options[[key]], ",", fixed = TRUE)[[1L]]
  plan <- do.call(ros.form.validation::plan_ros_validation, options)
  cat("Plan:", file.path(plan$directory, "plan.rds"), "\n")
  print(plan$jobs, row.names = FALSE)
} else if (stage == "publish") {
  arguments <- c(file.path(root, "tools", "publish-reports.R"), options$directory)
  if (!is.null(options$host)) arguments <- c(arguments, "--host", options$host)
  status <- system2(file.path(R.home("bin"), "Rscript"), vapply(arguments, shQuote, character(1)))
  if (status != 0L) stop("Publication failed", call. = FALSE)
} else {
  if (!is.null(options[["report-filename"]])) {
    options$report_filename <- options[["report-filename"]]
    options[["report-filename"]] <- NULL
  }
  if (stage == "validate") {
    options$resume <- !isTRUE(options[["no-resume"]])
    options[["no-resume"]] <- NULL
    state <- do.call(ros.form.validation::validate_ros_plan, options)
    print(state$jobs, row.names = FALSE)
  } else if (stage == "report") {
    cat("Reports:", do.call(ros.form.validation::write_ros_reports, options), "\n")
  } else cat("Publication:", do.call(ros.form.validation::build_ros_publication, options), "\n")
}
