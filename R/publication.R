#' Prepare a clean publication tree from completed ROS batches
#'
#' @param batch Batch directory containing a saved plan and completed reports,
#'   or completed version run directories.
#' @param output New publication directory. Defaults to `publication`
#'   inside the batch directory.
#' @param report_filename Filename for aggregate HTML pages.
#' @param comment Optional plain-text publication note shown in the batch catalog.
#' @return Normalized publication directory, invisibly.
#' @details Copies only individual HTML/CSV reports, report assets and run logs.
#'   Raw outputs remain untouched. Metadata supplies leaf HTML filenames, with
#'   report.html as fallback. Aggregates use year/country/gear/version groups.
#'   The adjacent publication manifest records counts, empty versions, an optional publication
#'   comment and SHA-256 file checksums.
#'   Each copied report links to all ancestor aggregates using report_filename.
#'   Catalogue evidence reports group rejected values by snapshot,
#'   retaining severity, reason and exact source cells where applicable.
#'   Reference CSVs are checked against recorded batch hashes.
#'   Planned batches keep their portable publication plan outside the served directory.
#'   Preparation rejects unfinished runs, missing reports and broken local links.
#'   A sibling temporary directory is renamed only after successful verification.
#' @export
prepare_ros_publication <- function(batch, output = NULL, report_filename = "index.html", comment = NULL) {
  if (!is.null(comment) && (!is.character(comment) || length(comment) != 1L || is.na(comment)))
    stop("comment must be a single text value or NULL", call. = FALSE)
  check_report_filename(report_filename)
  for (package in c("yaml", "digest", "jsonlite"))
    if (!requireNamespace(package, quietly = TRUE)) stop("Publication preparation requires ", package)
  batch <- normalizePath(batch, mustWork = TRUE)
  if (!grepl("^ros-validation-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z$", basename(batch))) stop("Invalid batch directory name")
  if (file.exists(file.path(batch, "plan.rds")))
    return(build_ros_publication(batch, output, report_filename, comment = comment))
  if (is.null(output)) output <- file.path(batch, "publication")
  if (file.exists(output)) stop("Publication output already exists: ", output)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  output <- file.path(normalizePath(dirname(output), mustWork = TRUE), basename(output))
  stage <- tempfile(paste0(".", basename(output), "-"), tmpdir = dirname(output))
  dir.create(stage); on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  copy <- function(source, relative) {
    target <- file.path(stage, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (file.exists(target)) {
      if (!identical(digest::digest(file = source, algo = "sha256"), digest::digest(file = target, algo = "sha256")))
        stop("Conflicting publication file: ", relative)
    } else if (!file.copy(source, target, copy.date = TRUE)) stop("Cannot copy ", source)
  }
  runs <- setdiff(list.files(batch, full.names = TRUE, all.files = TRUE, no.. = TRUE), stage)
  if (!length(runs) || any(!dir.exists(runs)) || any(!grepl("^v[0-9]+\\.[0-9]+\\.[0-9]+_country-", basename(runs)))) stop("Unexpected batch entries")
  versions <- character(); empty <- character(); descriptors <- list(); expected <- 0L
  for (run in runs) {
    version <- sub("_country-.*$", "", basename(run))
    if (version %in% versions) stop("Duplicate model run: ", version)
    versions <- c(versions, version)
    metadata <- yaml::read_yaml(file.path(run, "run.yaml"))
    leaf <- metadata$report_filename
    if (is.null(leaf)) leaf <- "report.html"
    check_report_filename(leaf)
    count <- metadata$selected_files
    if (length(count) != 1L || is.na(count) || count < 0 || count != as.integer(count)) stop("Invalid selected_files")
    log <- readLines(file.path(run, "run.log"), warn = FALSE)
    finished <- grep(" FINISHED ", log, value = TRUE)
    if (!length(finished) || !grepl(paste0("FINISHED ", count, " inputs;"), utils::tail(finished, 1L), fixed = TRUE)) stop("Unfinished run: ", run)
    if (count > 0 && !grepl("; 0 export failures;", utils::tail(finished, 1L), fixed = TRUE)) stop("Run has export failures: ", run)
    if (count == 0) empty <- c(empty, version)
    expected <- expected + count
    paths <- list.files(run, recursive = TRUE, full.names = FALSE, all.files = TRUE, no.. = TRUE)
    leaves <- paths[basename(paths) == leaf & lengths(strsplit(paths, "/", fixed = TRUE)) == 6L]
    if (length(leaves) != count || sum(basename(paths) == "summary.csv") != count || sum(basename(paths) == "findings.csv") != count)
      stop("Report count differs from run metadata: ", run)
    for (path in leaves) {
      relative <- dirname(path); parts <- strsplit(relative, "/", fixed = TRUE)[[1]]
      if (length(parts) != 5L || parts[4] != version || any(parts %in% c("", ".", ".."))) stop("Invalid report hierarchy: ", relative)
      for (name in c(leaf, "summary.csv", "findings.csv", "evidence.json")) {
        source <- file.path(run, relative, name)
        if (!file.exists(source)) stop("Missing report artifact: ", source)
        copy(source, file.path(relative, name))
      }
      children <- paths[startsWith(paths, paste0(relative, "/"))]
      for (child in children) copy(file.path(run, child), child)
      add_publication_breadcrumbs(file.path(stage, relative, leaf), parts, report_filename)
      descriptors[[length(descriptors) + 1L]] <- data.frame(directory = relative, report = leaf,
        year = parts[1], country = parts[2], gear = parts[3], version = parts[4], stringsAsFactors = FALSE)
    }
    for (path in paths[startsWith(paths, "report-assets/")]) copy(file.path(run, path), path)
    copy(file.path(run, "run.log"), file.path("logs", paste0(version, ".log")))
  }
  descriptors <- if (length(descriptors)) do.call(rbind, descriptors) else
    data.frame(directory = character(), report = character(), year = character(), country = character(), gear = character(), version = character())
  if (anyDuplicated(descriptors$directory)) stop("Duplicate individual report directory")
  pages <- form.validation::write_validation_report_summary(descriptors, stage,
    group_columns = c("year", "country", "gear", "version"), identity_columns = c("gear", "version"),
    report_filename = report_filename, title = "ROS validation reports",
    stylesheet = system.file("report", "iotc.css", package = "ros.form.validation", mustWork = TRUE),
    logo = system.file("report", "IOTC_with_text.png", package = "ros.form.validation", mustWork = TRUE),
    model_versions = sub("^v", "", versions),
    reference_context_columns = "gear")
  individual_evidence <- basename(dirname(list.files(stage, pattern = "\\.html$", recursive = TRUE)))
  catalogue_reports <- lapply(attr(pages, "catalogues"), function(spec) {
    spec$reports <- sum(individual_evidence == spec$folder)
    spec
  })
  reference_reports <- sum(vapply(catalogue_reports, `[[`, numeric(1), "reports"))
  conversion_reports <- sum(individual_evidence == "conversion-evidence")
  primary_key_reports <- sum(individual_evidence == "primary-key-evidence")
  html <- list.files(stage, pattern = "\\.html$", recursive = TRUE, full.names = TRUE)
  if (length(html) != expected + length(pages) + reference_reports + conversion_reports + primary_key_reports) stop("Unexpected HTML report count")
  for (path in html) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    links <- regmatches(text, gregexpr('(?:href|src)="[^"]+"', text, perl = TRUE))[[1]]
    links <- sub('^[^=]+="', "", sub('"$', "", links))
    for (link in links) {
      link <- gsub("&amp;", "&", link, fixed = TRUE)
      if (grepl("^[A-Za-z]+:|^//|^#", link)) stop("Unexpected external link: ", link)
      target <- normalizePath(file.path(dirname(path), utils::URLdecode(link)), mustWork = TRUE)
      if (!startsWith(target, paste0(normalizePath(stage), "/")) || dir.exists(target)) stop("Invalid publication link: ", link)
    }
  }
  for (page in pages) {
    folder <- dirname(file.path(stage, page))
    files_table <- utils::read.csv(file.path(folder, "files.csv"), colClasses = "character",
      na.strings = NULL, fileEncoding = "UTF-8-BOM")
    for (link in files_table$report) {
      target <- normalizePath(file.path(folder, link), mustWork = TRUE)
      if (!startsWith(target, paste0(normalizePath(stage), "/")) || dir.exists(target)) stop("Invalid individual link: ", link)
    }
  }
  unlink(file.path(stage, descriptors$directory, "evidence.json"))
  files <- sort(list.files(stage, recursive = TRUE, full.names = FALSE, all.files = TRUE, no.. = TRUE))
  manifest <- list(batch = basename(batch), report_filename = report_filename,
    individual_reports = nrow(descriptors), aggregate_reports = length(pages), aggregate_pages = as.list(pages),
    reference_reports = reference_reports, catalogue_reports = catalogue_reports, conversion_reports = conversion_reports, primary_key_reports = primary_key_reports, no_inputs = as.list(empty),
    files = lapply(files, function(path) list(path = path, sha256 = digest::digest(file = file.path(stage, path), algo = "sha256"))))
  if (!is.null(comment) && nzchar(comment)) manifest$comment <- comment
  jsonlite::write_json(manifest, paste0(output, ".json"), auto_unbox = TRUE, pretty = TRUE)
  if (!file.rename(stage, output)) stop("Cannot finalize publication directory: ", output)
  finish_ros_publication_navigation(output)
  invisible(normalizePath(output, mustWork = TRUE))
}

# Add navigation only to publication copies; standalone reports remain unchanged.
add_publication_breadcrumbs <- function(path, parts, report_filename) {
  check_report_filename(report_filename)
  if (length(parts) != 5L) stop("Expected year/country/gear/version/file hierarchy")
  template <- readLines(system.file("report", "breadcrumbs.html", package = "ros.form.validation", mustWork = TRUE), warn = FALSE)
  values <- c(stats::setNames(parts, c("year", "country", "gear", "version", "filename")), report_filename = report_filename)
  escape <- function(value) {
    for (pair in list(c("&", "&amp;"), c("<", "&lt;"), c(">", "&gt;"), c('"', "&quot;")))
      value <- gsub(pair[[1]], pair[[2]], value, fixed = TRUE)
    value
  }
  navigation <- vapply(template, function(line) {
    matches <- gregexpr("\\{\\{[a-z_]+\\}\\}", line, perl = TRUE)
    tokens <- regmatches(line, matches)[[1L]]
    keys <- substring(tokens, 3L, nchar(tokens) - 2L)
    regmatches(line, matches) <- list(vapply(values[keys], escape, character(1)))
    line
  }, character(1))
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  html <- gsub('<nav (?:class="report-parent"|id="breadcrumbs")[^>]*>.*?</nav>', "", html, perl = TRUE)
  if (!grepl("<main>", html, fixed = TRUE)) stop("Missing report main element: ", path)
  logo <- regmatches(html, regexpr('<img class="report-logo"[^>]*>', html, perl = TRUE))
  anchor <- if (grepl('<div class="report-navigation">', html, fixed = TRUE))
    '<div class="report-navigation">' else if (length(logo)) logo else "<main>"
  html <- sub(anchor, paste0(anchor, "\n", paste(navigation, collapse = "\n")), html, fixed = TRUE)
  writeLines(html, path, useBytes = TRUE)
}

# Apply ROS navigation after internal link checks; publication time is set by the uploader.
finish_ros_publication_navigation <- function(directory, published_at = NULL) {
  manifest_path <- paste0(directory, ".json")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  stamp <- NULL
  if (!is.null(published_at)) {
    if (!inherits(published_at, "POSIXt") || length(published_at) != 1L || is.na(published_at))
      stop("published_at must be a single timestamp", call. = FALSE)
    manifest$published_at <- format(published_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    stamp <- format(published_at, "%Y/%m/%d %H:%M UTC", tz = "UTC")
  }
  paths <- vapply(manifest$files, function(item) item$path, character(1))
  changed <- character()
  for (relative in unlist(manifest$aggregate_pages, use.names = FALSE)) {
    group <- dirname(relative)
    scope <- if (group == ".") "All forms" else paste(strsplit(group, "/", fixed = TRUE)[[1]], collapse = " / ")
    title <- paste(c("ROS validation summary", scope, stamp), collapse = " \u2014 ")
    html_path <- file.path(directory, relative)
    set_ros_publication_title(html_path, title)
    if (group == ".") {
      html <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
      navigation <- paste0('<nav id="breadcrumbs" aria-label="Breadcrumb">',
        '<a href="../">Validation publications</a> / <span aria-current="page">All reports</span></nav>')
      html <- sub('(?s)<nav id="breadcrumbs"[^>]*>.*?</nav>', navigation, html, perl = TRUE)
      writeLines(html, html_path, useBytes = TRUE)
    }
    changed <- c(changed, relative)
  }
  evidence <- c(vapply(manifest$catalogue_reports, `[[`, character(1), "folder"),
    "conversion-evidence", "primary-key-evidence")
  for (relative in paths[basename(dirname(paths)) %in% evidence & basename(paths) == manifest$report_filename]) {
    path <- file.path(directory, relative)
    html <- paste(readLines(path, warn = FALSE), collapse = "\n")
    current <- regmatches(html, regexpr("<h1>[^<]*</h1>", html))
    if (!length(current)) stop("Missing evidence title: ", path)
    title <- sub("</h1>$", "", sub("^<h1>", "", current))
    title <- sub(" \u2014 [0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2} UTC$", "", title)
    # Existing evidence headings are already HTML-escaped.
    set_ros_publication_title(path, paste(c(title, stamp), collapse = " \u2014 "), escaped = TRUE)
    changed <- c(changed, relative)
  }
  for (i in seq_along(manifest$files)) {
    if (manifest$files[[i]]$path %in% changed)
      manifest$files[[i]]$sha256 <- digest::digest(
        file = file.path(directory, manifest$files[[i]]$path), algo = "sha256")
  }
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE)
  invisible(directory)
}


# Keep the browser title and visible report heading identical.
set_ros_publication_title <- function(path, title, escaped = FALSE) {
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  if (!escaped) for (pair in list(c("&", "&amp;"), c("<", "&lt;"), c(">", "&gt;"), c('"', "&quot;")))
    title <- gsub(pair[[1]], pair[[2]], title, fixed = TRUE)
  for (tag in c("title", "h1")) {
    match <- regexpr(paste0("<", tag, ">[^<]*</", tag, ">"), html)
    if (match[[1]] < 0L) stop("Missing report ", tag, ": ", path)
    regmatches(html, match) <- paste0("<", tag, ">", title, "</", tag, ">")
  }
  writeLines(html, path, useBytes = TRUE)
}
