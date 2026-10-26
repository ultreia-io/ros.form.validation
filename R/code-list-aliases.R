#' Read bundled ROS code-list aliases
#' @return A table with code-list ID, submitted original code, and canonical code.
#' @keywords internal
ros_code_list_aliases <- function() {
  path <- system.file("code-list-aliases.csv", package = "ros.form.validation",
    mustWork = TRUE)
  aliases <- utils::read.csv(path, colClasses = "character", check.names = FALSE,
    na.strings = "", fileEncoding = "UTF-8")
  if (!identical(names(aliases), c("id", "original", "code")) || anyNA(aliases) ||
      any(!nzchar(aliases$id) | !nzchar(aliases$original) | !nzchar(aliases$code)) ||
      anyDuplicated(aliases[c("id", "original")]))
    stop("Invalid bundled ROS code-list aliases: ", path, call. = FALSE)
  aliases
}

#' Add bundled aliases to one verified code-list snapshot
#' @param existing Aliases supplied by the snapshot, or NULL.
#' @param bundled Bundled aliases for this code list.
#' @param values Canonical codes in the supplied snapshot.
#' @param id Code-list identifier for diagnostic messages.
#' @return A named vector mapping original codes to canonical codes, or NULL.
#' @keywords internal
merge_ros_code_list_aliases <- function(existing, bundled, values, id) {
  if (!nrow(bundled)) return(existing)
  if (any(!bundled$code %in% values))
    stop("Bundled aliases target codes absent from ", id, call. = FALSE)
  if (any(bundled$original %in% values))
    stop("Bundled aliases conflict with canonical codes in ", id, call. = FALSE)
  if (is.null(existing)) existing <- character()
  previous <- match(bundled$original, names(existing))
  overlap <- which(!is.na(previous))
  if (length(overlap) && any(existing[previous[overlap]] != bundled$code[overlap]))
    stop("Bundled aliases conflict with snapshot aliases in ", id, call. = FALSE)
  added <- is.na(previous)
  c(existing, stats::setNames(bundled$code[added], bundled$original[added]))
}
