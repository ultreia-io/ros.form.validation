#' Find classified ROS input workbooks
#' @param directory Root containing `<year>/<country>/<gear>/v<version>/*.xlsx`.
#' @param country,year Optional exact values; vectors select several values.
#' @param gear `"all"`, `ros.form.model::ROS_FORM_LL`, `ros.form.model::ROS_FORM_PS`, or both gear constants.
#' @param version Required exact form version; selects only its matching `v<version>` directory.
#' @return A data frame with path, relative path, gear, year, and country.
#' @details Filters intersect. Countries and gears are case-insensitive.
#'   Classification selects candidates; structure is checked against the chosen version.
#'   Filenames are preserved; Excel lock files and other version directories are excluded.
#' @export
ros_validation_inputs <- function(directory, country = NULL, year = NULL, gear = "all",
                                  version) {
  if (missing(version)) stop("Supply an explicit ROS data-model version", call. = FALSE)
  if (!is.character(version) || length(version) != 1L || is.na(version) ||
      !version %in% ros.form.model::ROS_FORM_VERSIONS) {
    stop("Unsupported ROS data-model version; available versions: ",
         paste(ros.form.model::ROS_FORM_VERSIONS, collapse = ", "), ".", call. = FALSE)
  }
  scan_ros_inputs(directory, version, country, year, gear)[c("path", "relative", "gear", "year", "country")]
}

# One discovery pass for all requested versions; later stages consume its saved rows.
scan_ros_inputs <- function(directory, versions, country = NULL, year = NULL, gear = "all") {
  directory <- normalizePath(directory, mustWork = TRUE)
  gear <- ros_batch_gears(gear)
  paths <- sort(list.files(directory, pattern = "\\.xlsx$", recursive = TRUE, ignore.case = TRUE))
  parts <- strsplit(paths, "/", fixed = TRUE)
  keep <- vapply(parts, function(x) length(x) == 5L && toupper(x[[3]]) %in% gear &&
    grepl("^[0-9]{4}$", x[[1]]) && x[[4]] %in% paste0("v", versions) && !startsWith(x[[5]], "~$") &&
    (is.null(country) || toupper(x[[2]]) %in% toupper(country)) &&
    (is.null(year) || x[[1]] %in% as.character(year)), logical(1))
  parts <- parts[keep]; paths <- paths[keep]
  data.frame(path = file.path(directory, paths), relative = paths,
    gear = vapply(parts, `[[`, character(1), 3L), year = vapply(parts, `[[`, character(1), 1L),
    country = vapply(parts, `[[`, character(1), 2L),
    version = vapply(parts, `[[`, character(1), 4L),
    model_version = sub("^v", "", vapply(parts, `[[`, character(1), 4L)), stringsAsFactors = FALSE)
}

ros_batch_gears <- function(gear) {
  gear <- unique(toupper(gear))
  if (identical(gear, "ALL")) gear <- c("LL", "PS")
  if (!length(gear) || anyNA(gear) || any(!gear %in% c("LL", "PS")))
    stop("gear must be all, ll or ps", call. = FALSE)
  gear
}

#' Load explicit local CSV reference snapshots
#' @param directory Folder containing `code_lists/` and `registries/`.
#' @param plans Named validation plans for the selected gears.
#' @param prepare Whether to prepare lookup indexes. Use FALSE when freezing
#'   references for jobs without inputs; values and provenance are still retained.
#' @return References for the engine, with a `provenance` attribute recording
#'   CSV paths, SHA-256 digests, and missing declarations.
#' @details Code lists read `code` and optional `code_orig` aliases. Original
#'   codes are trimmed like the legacy reader; blank originals are excluded.
#'   Registry references identify a
#'   table and column separated by an arrow. Codes stay character; duplicate
#'   registry values are retained. Empty keys are excluded. No database is used.
#'   Missing files or columns remain missing snapshots, never empty valid ones.
#'   Registry indexes are prepared once using each business rule's matching
#'   strategy and explicit aliases. Code-list keys and aliases are also prepared
#'   once for the batch. Reload after changing snapshots or rules.
#' @export
read_ros_references <- function(directory, plans, prepare = TRUE) {
  if (!is.logical(prepare) || length(prepare) != 1L || is.na(prepare))
    stop("prepare must be TRUE or FALSE", call. = FALSE)
  directory <- normalizePath(directory, mustWork = TRUE)
  code_ids <- unique(unlist(lapply(plans, function(plan)
    vapply(Filter(function(r) r$kind == "reference", plan$rules), `[[`, character(1), "value")), use.names = FALSE))
  ids <- unique(c(code_ids, unlist(lapply(plans, function(plan)
    lapply(plan$rules, function(r) r$parameters$reference)), use.names = FALSE)))
  tables <- new.env(parent = emptyenv())
  refs <- list(); provenance <- list()
  for (id in ids) {
    parts <- strsplit(id, ".", fixed = TRUE)[[1]]
    registry <- length(parts) == 3L
    table <- paste(parts[1:2], collapse = ".")
    column <- if (registry) parts[[3]] else "code"
    path <- file.path(directory, if (registry) "registries" else "code_lists", paste0(table, ".csv"))
    if (!exists(path, tables, inherits = FALSE)) {
      tables[[path]] <- if (!file.exists(path)) list(data = NULL, sha256 = NULL) else list(
        data = utils::read.csv(path, colClasses = "character", check.names = FALSE,
          na.strings = "", strip.white = FALSE, fileEncoding = "UTF-8"),
        sha256 = digest::digest(file = path, algo = "sha256"))
    }
    snapshot <- tables[[path]]
    available <- !is.null(snapshot$data) && column %in% names(snapshot$data)
    provenance[[id]] <- list(path = path, column = column, sha256 = snapshot$sha256,
      status = if (available) "available" else "missing")
    if (available) {
      values <- snapshot$data[[column]]
      refs[[id]] <- list(values = values[!is.na(values) & nzchar(values)], version = snapshot$sha256)
      if (!registry && "code_orig" %in% names(snapshot$data)) {
        original <- trimws(snapshot$data$code_orig)
        keep <- !is.na(original) & nzchar(original)
        refs[[id]]$aliases <- stats::setNames(values[keep], original[keep])
      }
    }
  }
  attr(refs, "provenance") <- provenance
  if (!prepare) return(refs)
  for (plan in plans) {
    fields <- form.model::form_fields(plan$model)
    for (rule in plan$rules) {
      p <- rule$parameters
      if (!endsWith(rule$id, "/registry_match") || is.null(refs[[p$reference]])) next
      snapshot <- refs[[p$reference]]
      index <- registry_lookup(snapshot, p, fields[[p$field]]$type)
      same_policy <- vapply(snapshot$indexes, function(x) identical(
        x[c("type", "matching", "aliases")], index[c("type", "matching", "aliases")]), logical(1))
      if (!any(same_policy)) refs[[p$reference]]$indexes <- c(snapshot$indexes, list(index))
    }
  }
  form.validation::prepare_validation_references(refs, code_ids)
}

#' Validate and report one workbook
#' @param path Input XLSX file, left unchanged.
#' @param directory New output directory for this input.
#' @param plan A ROS validation plan, reusable across inputs.
#' @param references Explicit reference snapshots, reusable across inputs.
#' @param source Input label appended to the report heading and page title, and used in CSV output; defaults to `path`.
#' @param log Function receiving timing lines; defaults to [message()].
#' @param assets_directory Report asset directory relative to this input's output directory.
#' @param report_filename HTML report basename, ending in `.html`; defaults to `index.html`.
#' @param trim_ws Trim text-cell boundaries through readxl? Defaults to TRUE.
#'   Applies regardless of declared model type; the workbook is left unchanged.
#' @return The validation result, invisibly. Writes the HTML report, summary.csv and findings.csv.
#' @details Retains actual sheet order, leading rows, blank cells, and mixed cell
#'   types. Dimensions follow cells containing data, ignoring formatting-only
#'   trailing cells. No sheets are renamed, reordered, padded to the form, or removed.
#'   Conversion runs only after structure passes.
#'   Midnight Excel dates become Date only for date fields; times are not truncated.
#'   Declared string fields become character (including logical FALSE as "FALSE");
#'   missing cells stay missing and text codes retain leading zeros.
#'   Formula caches are read as stored values without recalculation or inspection.
#'   Excel error cells and formulas without cached values become missing values.
#'   Reader warnings and encrypted/corrupt files still produce a failed read and
#'   skip every validation rule.
#'   Prepares shared CSV/HTML tables once. Logs elapsed seconds for reading,
#'   validation, report preparation, CSV export and HTML rendering,
#'   including failed stages. Reading logs sheet discovery and worksheet loading.
#'   Conversion is logged separately and excluded from validation timing.
#'   A failed read logs validation as skipped.
#' @export
validate_ros_file <- function(path, directory, plan, references = list(), source = path, log = message,
                              assets_directory = "report-assets", report_filename = "index.html", trim_ws = TRUE) {
  check_report_filename(report_filename)
  rules_plan <- plan # Public plan argument contains rules, not a batch execution plan.
  if (!inherits(rules_plan, "validation_plan")) stop("plan must come from ros_validation()", call. = FALSE)
  if (!is.function(log)) stop("log must be a function", call. = FALSE)
  if (file.exists(directory)) stop("Output directory already exists: ", directory, call. = FALSE)
  result <- validate_ros_input(path, rules_plan, references, source, log, trim_ws)
  timed <- function(stage, expression) {
    started <- proc.time()[["elapsed"]]
    on.exit(log(sprintf("TIMING %s %s=%.3fs", source, stage, proc.time()[["elapsed"]] - started)))
    force(expression)
  }
  report <- timed("report.prepare", form.validation::validation_report_data(result, rules_plan$model,
    reference_provenance = attr(references, "provenance"),
    context = list(gear = toupper(result$model$form$id))))
  timed("csv", form.validation::write_validation_results(report, directory))
  timed("html", {
    form.validation::write_validation_report(report, file.path(directory, report_filename),
      title = paste("ROS validation report -", toupper(result$model$form$id), "-", source),
      assets_directory = assets_directory,
      stylesheet = system.file("report", "iotc.css", package = "ros.form.validation", mustWork = TRUE),
      logo = system.file("report", "IOTC_with_text.png", package = "ros.form.validation", mustWork = TRUE))
  })
  invisible(result)
}

#' Supply a configured reader for submitted ROS forms
#'
#' Creates a callback without opening a form. Single-form validation invokes it
#' immediately; batch planning stores it for the later validation stage.
#' @param trim_ws Single logical value forwarded to readxl: trim leading and
#'   trailing whitespace in text cells, regardless of the declared field type.
#' @return A function accepting `path` and `timed`, returning the worksheet grids
#'   produced by [form.validation::read_validation_workbook()].
#' @details Embeds the logical option as a literal in the callback body. Its
#'   base environment captures no caller state, keeping serialization stable
#'   for saved batch-plan integrity checks. Native cell types and internal
#'   whitespace are unchanged. The callback does not modify the source file.
#' @keywords internal
ros_workbook_reader_supplier <- function(trim_ws) {
  if (!is.logical(trim_ws) || length(trim_ws) != 1L || is.na(trim_ws))
    stop("trim_ws must be TRUE or FALSE", call. = FALSE)
  eval(substitute(
    function(path, timed) form.validation::read_validation_workbook(path, timed, trim_ws = OPTION),
    list(OPTION = trim_ws)), envir = baseenv())
}

# Keep the ROS missing-value convention explicit in saved execution metadata.
ros_missing_value_policy <- function() {
  list(common = c("-", "NA", "NULL"), unknown = c("UNKNOWN", "UNKNOW"),
    types = c("boolean", "integer", "number", "latitude", "longitude", "date", "datetime", "email"),
    ignore_case = TRUE, preserve_unknown_references = TRUE)
}

# After reader trimming and structure checks, normalize only declared fields.
prepare_ros_validation_data <- function(data, model, reference_fields = character()) {
  policy <- ros_missing_value_policy()
  tokens <- function(field) {
    referenced <- !is.null(field$reference) || field$id %in% reference_fields
    if (!referenced && field$type %in% policy$types)
      c(policy$common, policy$unknown) else policy$common
  }
  form.validation::prepare_validation_data(data, model,
    na_strings = tokens, na_ignore_case = policy$ignore_case)
}

# Freeze custom reference-rule fields by model version and gear in the callback.
# Model-declared references are checked directly when preparing each field.
ros_preparation_supplier <- function(rules_plans) {
  reference_fields <- list()
  for (rules_plan in rules_plans) {
    form <- form.model::form_metadata(rules_plan$model)$form
    key <- paste(form$version, form$id, sep = "/")
    fields <- unlist(lapply(rules_plan$rules, function(rule) {
      if (!is.null(rule$parameters$reference)) rule$parameters$field else NULL
    }), use.names = FALSE)
    reference_fields[[key]] <- if (is.null(fields)) character() else unique(fields)
  }
  eval(substitute(function(data, model) {
    form <- form.model::form_metadata(model)$form
    prepare_ros_validation_data(data, model,
      reference_fields = FIELDS[[paste(form$version, form$id, sep = "/")]])
  }, list(FIELDS = reference_fields)), envir = asNamespace("ros.form.validation"))
}

# Single-form path: no batch plan exists, so supply a reader for this call.
validate_ros_input <- function(path, rules_plan, references, source, log, trim_ws = TRUE) {
  reader <- ros_workbook_reader_supplier(trim_ws)
  rules_plan$metadata$options$trim_ws <- trim_ws
  rules_plan$metadata$options$missing_values <- ros_missing_value_policy()
  form.validation::validate_workbook(path, rules_plan, references, source,
    config = list(blank_strings = TRUE), reader = reader,
    prepare_data = ros_preparation_supplier(list(rules_plan)), log = log)
}

# Validate the output basename before reading inputs or creating directories.
check_report_filename <- function(filename) {
  if (!is.character(filename) || length(filename) != 1L || is.na(filename) ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*\\.html$", filename)) {
    stop("report_filename must be a plain .html filename using letters, digits, dots, underscores or hyphens",
         call. = FALSE)
  }
  invisible(filename)
}
