#!/usr/bin/env Rscript
# Run from the source checkout with its declared dependencies installed.
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
# Use installed dependency versions from DESCRIPTION and load this checkout only.
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(root, quiet = TRUE)
args <- commandArgs(TRUE)
if (!length(args) || "--help" %in% args) {
  cat("Usage: Rscript tools/prepare-publication.R --batch output/ros-validation-<timestamp>\n",
      "  [--output output/aggregated_ros-validation-<timestamp>] [--report-filename index.html] [--comment TEXT]\n")
  quit(status = 0)
}
options <- list(); i <- 1L
while (i <= length(args)) {
  key <- sub("^--", "", args[[i]])
  if (!startsWith(args[[i]], "--") || !key %in% c("batch", "output", "report-filename", "comment")) stop("Unknown option: ", args[[i]])
  if (key %in% names(options)) stop("Repeated option: ", key)
  if (i == length(args) || startsWith(args[[i + 1L]], "--")) stop("Missing value for --", key)
  options[[key]] <- args[[i + 1L]]; i <- i + 2L
}
if (is.null(options$batch)) stop("Supply --batch")
if (!is.null(options[["report-filename"]])) {
  options$report_filename <- options[["report-filename"]]; options[["report-filename"]] <- NULL
}
cat("Publication:", do.call(ros.form.validation::prepare_ros_publication, options), "\n")
