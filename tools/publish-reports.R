#!/usr/bin/env Rscript
# Upload an already prepared publication tree; never rebuild batch results here.
main <- function(args) {
  if (!length(args) || "--help" %in% args) {
    cat("Usage: Rscript tools/publish-reports.R output/aggregated_ros-validation-<timestamp> [--host ultreia]\n")
    return(invisible(NULL))
  }
  host <- "ultreia"
  if (length(args) == 3L && args[[2L]] == "--host") host <- args[[3L]] else
    if (length(args) != 1L) stop("Expected a prepared directory and optional --host", call. = FALSE)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9_.@-]*$", host)) stop("Invalid SSH host", call. = FALSE)
  for (package in c("jsonlite", "digest")) {
    if (!requireNamespace(package, quietly = TRUE)) stop("Publication requires ", package, call. = FALSE)
  }
  script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
  landing_page <- file.path(dirname(normalizePath(script, mustWork = TRUE)), "publication", "index.html")
  if (!file.exists(landing_page)) stop("Missing publication landing page: ", landing_page, call. = FALSE)
  directory <- normalizePath(args[[1L]], mustWork = TRUE)
  manifest_path <- file.path(directory, "publication.json")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  comment <- manifest$comment
  if (!is.null(comment) && (!is.character(comment) || length(comment) != 1L || is.na(comment)))
    stop("Publication comment must be a single text value or NULL", call. = FALSE)
  batch <- manifest$batch
  if (!is.character(batch) || length(batch) != 1L ||
      !grepl("^ros-validation-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z$", batch) ||
      basename(directory) != paste0("aggregated_", batch)) {
    stop("Prepared directory and publication manifest batch must agree", call. = FALSE)
  }
  paths <- vapply(manifest$files, function(x) x$path, character(1))
  if (!length(paths) || anyDuplicated(paths) || anyNA(paths) ||
      any(grepl("^/|\\\\", paths)) || any(vapply(strsplit(paths, "/", fixed = TRUE),
        function(x) any(x %in% c("", ".", "..")), logical(1)))) {
    stop("Invalid publication manifest paths", call. = FALSE)
  }
  actual <- list.files(directory, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  if (!setequal(actual, c(paths, "publication.json"))) {
    stop("Prepared files differ from publication manifest; prepare again", call. = FALSE)
  }
  for (i in seq_along(paths)) {
    path <- file.path(directory, paths[[i]])
    if (!startsWith(normalizePath(path, mustWork = TRUE), paste0(directory, "/")) ||
        !identical(digest::digest(file = path, algo = "sha256"), manifest$files[[i]]$sha256)) {
      stop("Publication checksum mismatch: ", paths[[i]], call. = FALSE)
    }
  }
  run <- function(command, arguments, capture = FALSE) {
    value <- system2(command, vapply(arguments, shQuote, character(1)), stdout = if (capture) TRUE else "")
    status <- if (capture) attr(value, "status") else value
    if (!is.null(status) && status != 0L) stop(command, " failed with exit status ", status, call. = FALSE)
    value
  }
  destination <- "/var/www/html/ros/validation"
  remote <- paste0(host, ":", destination, "/", batch, "/")
  # Use one publication instant for report titles, the manifest and the catalog.
  now <- Sys.time()
  navigation <- new.env(parent = globalenv())
  source(file.path(dirname(dirname(normalizePath(script))), "R", "publication.R"),
    local = navigation)
  navigation$finish_ros_publication_navigation(directory, published_at = now)
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  # Deletion is limited to this timestamped publication, preserving earlier batches.
  run("rsync", c("-az", "--delete", paste0(directory, "/"), remote))
  differences <- run("rsync", c("-acn", "--delete", "--out-format=%n", paste0(directory, "/"), remote), TRUE)
  if (any(nzchar(trimws(differences)))) stop("Uploaded files differ from prepared files", call. = FALSE)

  catalog_path <- paste0(destination, "/batches.json")
  catalog <- run("ssh", c(host, paste("cat", shQuote(catalog_path))), TRUE)
  entries <- jsonlite::fromJSON(paste(catalog, collapse = "\n"), simplifyVector = FALSE)
  stamp <- format(now, "%Y-%m-%dT%H:%M:%S%z", tz = "Europe/Paris")
  stamp <- sub("([+-][0-9]{2})([0-9]{2})$", "\\1:\\2", stamp)
  entry <- list(directory = batch, published_at = stamp)
  if (!is.null(comment) && nzchar(comment)) entry$comment <- comment
  matches <- which(vapply(entries, function(x) identical(x$directory, batch), logical(1)))
  if (length(matches)) entries[[matches[[1L]]]] <- entry else entries <- c(entries, list(entry))
  local_catalog <- tempfile("ros-catalog-", fileext = ".json")
  on.exit(unlink(local_catalog), add = TRUE)
  jsonlite::write_json(entries, local_catalog, auto_unbox = TRUE, pretty = TRUE)
  remote_catalog <- paste0(catalog_path, ".", batch, ".tmp")
  run("rsync", c("-az", local_catalog, paste0(host, ":", remote_catalog)))
  run("ssh", c(host, paste("mv", shQuote(remote_catalog), shQuote(catalog_path))))
  remote_landing <- paste0(destination, "/index.html.", batch, ".tmp")
  run("rsync", c("-az", landing_page, paste0(host, ":", remote_landing)))
  run("ssh", c(host, paste("mv", shQuote(remote_landing), shQuote(paste0(destination, "/index.html")))))
  cat(sprintf("Published %s individual and %s aggregate reports: https://ros.ultreia.io/validation/%s/\n",
              manifest$individual_reports, manifest$aggregate_reports, batch))
  if (!is.null(manifest$reference_reports) && manifest$reference_reports > 0L)
    cat(sprintf("Included %s code-list evidence report.\n", manifest$reference_reports))
  if (!is.null(manifest$registry_reports) && manifest$registry_reports > 0L)
    cat(sprintf("Included %s registry evidence report.\n", manifest$registry_reports))
  if (!is.null(manifest$conversion_reports) && manifest$conversion_reports > 0L)
    cat(sprintf("Included %s conversion evidence report.\n", manifest$conversion_reports))
  cat(format(now, "Publication — %d %B %Y — %H:%M (Europe/Paris)\n", tz = "Europe/Paris"))
}
main(commandArgs(trailingOnly = TRUE))
