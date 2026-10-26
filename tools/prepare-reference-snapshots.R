#!/usr/bin/env Rscript
# Fetch the model's references before planning a batch.
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(root, quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6L ||
    !identical(args[c(1L, 3L, 5L)], c("--code-lists", "--registries", "--output"))) {
  stop("Usage: Rscript tools/prepare-reference-snapshots.R --code-lists URL_OR_DIR ",
       "--registries URL_OR_DIR --output DIR", call. = FALSE)
}
output <- args[[6L]]
cache <- file.path(dirname(output), "reference-cache")
registry_header <- function() {
  value <- Sys.getenv("ROS_REGISTRY_AUTHORIZATION", unset = "")
  if (nzchar(value)) c(Authorization = value) else character()
}
code_source <- form.references::reference_source(args[[2L]], cache, catalogue = "codelists")
registry_source <- form.references::reference_source(args[[4L]], cache,
  headers = registry_header, catalogue = "registries")
snapshots <- ros.form.validation::prepare_ros_reference_snapshots(
  output, code_source, registry_source)
cat("Verified ROS reference snapshots:", snapshots, "\n")
