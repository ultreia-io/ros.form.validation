#' Read bundled ROS registry aliases
#' @return A table identifying the registry, column, submitted alias, and
#'   canonical registry value.
#' @keywords internal
ros_registry_aliases <- function() {
  path <- system.file("registry-aliases.csv", package = "ros.form.validation",
    mustWork = TRUE)
  aliases <- utils::read.csv(path, colClasses = "character", check.names = FALSE,
    na.strings = "", fileEncoding = "UTF-8")
  if (!identical(names(aliases), c("registry", "column", "alias", "canonical")) ||
      anyNA(aliases) || any(!nzchar(as.matrix(aliases))) ||
      anyDuplicated(aliases[c("registry", "column", "alias")]))
    stop("Invalid bundled ROS registry aliases: ", path, call. = FALSE)
  aliases
}

#' Select registry aliases for one verified snapshot
#' @param aliases Bundled ROS registry aliases.
#' @param registry Registry table identifier.
#' @param column Checked registry column.
#' @param values Values in the supplied registry snapshot.
#' @return A named vector mapping submitted aliases to registry values, or NULL.
#' @keywords internal
registry_snapshot_aliases <- function(aliases, registry, column, values) {
  selected <- aliases[aliases$registry == registry & aliases$column == column, , drop = FALSE]
  if (!nrow(selected)) return(NULL)
  reference <- paste(registry, column, sep = ".")
  if (any(!selected$canonical %in% values))
    stop("Bundled aliases target values absent from ", reference, call. = FALSE)
  if (any(selected$alias %in% values))
    stop("Bundled aliases conflict with registry values in ", reference, call. = FALSE)
  stats::setNames(selected$canonical, selected$alias)
}
