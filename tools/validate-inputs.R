#!/usr/bin/env Rscript
# Run from the source checkout with its declared dependencies installed.
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
# Use installed dependency versions from DESCRIPTION and load this checkout only.
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(root, quiet = TRUE)
args <- commandArgs(TRUE)
if (!length(args) || "--help" %in% args) {
  cat("Usage: Rscript tools/validate-inputs.R --input DIR --references DIR [--output DIR]\n",
      "  [--country EU-FRANCE,TAIWAN] [--year 2023,2024] [--gear all|ll|ps] --version 3.3.0|4.0.0|4.1.0 [--dry-run] [--report-filename index.html]\n",
      "  [--meta-as-warnings true|false] [--trim-ws true|false] (defaults: true)\n")
  quit(status = 0)
}
options <- list(); i <- 1L
while (i <= length(args)) {
  key <- sub("^--", "", args[[i]])
  if (!startsWith(args[[i]], "--") || !key %in% c("input", "references", "output", "country", "year", "gear", "version", "dry-run", "report-filename", "meta-as-warnings", "trim-ws"))
    stop("Unknown option: ", args[[i]], call. = FALSE)
  if (key %in% names(options)) stop("Repeated option: ", key, call. = FALSE)
  if (key == "dry-run") { options[[key]] <- TRUE; i <- i + 1L; next }
  if (i == length(args) || startsWith(args[[i + 1L]], "--")) stop("Missing value for --", key, call. = FALSE)
  options[[key]] <- args[[i + 1L]]; i <- i + 2L
}
if (is.null(options$version)) stop("Supply --version", call. = FALSE)
if (is.null(options$input)) stop("Supply --input", call. = FALSE)
if (is.null(options$references) && !isTRUE(options[["dry-run"]])) stop("Supply --references", call. = FALSE)
for (key in intersect(c("country", "year", "gear"), names(options))) options[[key]] <- strsplit(options[[key]], ",", fixed = TRUE)[[1L]]
if (!is.null(options[["dry-run"]])) { options$dry_run <- options[["dry-run"]]; options[["dry-run"]] <- NULL }
if (is.null(options$references)) options$references <- ""
if (!is.null(options[["report-filename"]])) {
  options$report_filename <- options[["report-filename"]]
  options[["report-filename"]] <- NULL
}
if (!is.null(options[["meta-as-warnings"]])) {
  value <- tolower(options[["meta-as-warnings"]])
  if (!value %in% c("true", "false")) stop("--meta-as-warnings must be true or false", call. = FALSE)
  options$meta_as_warnings <- value == "true"
  options[["meta-as-warnings"]] <- NULL
}
if (!is.null(options[["trim-ws"]])) {
  value <- tolower(options[["trim-ws"]])
  if (!value %in% c("true", "false")) stop("--trim-ws must be true or false", call. = FALSE)
  options$trim_ws <- value == "true"
  options[["trim-ws"]] <- NULL
}
result <- do.call(ros.form.validation::validate_ros_inputs, options)
if (is.data.frame(result)) { print(result[c("year", "country", "gear", "relative")], row.names = FALSE); cat(nrow(result), "selected input(s)\n") } else cat("Reports:", result, "\n")
