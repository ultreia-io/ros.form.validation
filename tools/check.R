# Run from this package's root. Generated outputs stay under build/.
root <- normalizePath(".", mustWork = TRUE)
metadata <- read.dcf(file.path(root, "DESCRIPTION"))
package <- metadata[[1L, "Package"]]
build <- file.path(root, "build")
lib <- file.path(build, "library")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
           `_R_CHECK_CRAN_INCOMING_` = "false",
           `_R_CHECK_CRAN_INCOMING_REMOTE_` = "false",
           `_R_CHECK_SYSTEM_CLOCK_` = "false")
r <- file.path(R.home("bin"), "R")
install <- function(path) {
  status <- system2(r, c("CMD", "INSTALL", "--no-multiarch",
                        paste0("--library=", shQuote(lib)), shQuote(path)))
  if (status != 0L) stop("Installation failed: ", path)
}
# Sibling source checkouts are optional; installed dependencies also work.
for (dependency in c("model.form", "model.validation", "ros.form.model")) {
  source <- file.path(dirname(root), dependency)
  if (file.exists(file.path(source, "DESCRIPTION"))) install(source)
  else if (!requireNamespace(dependency, quietly = TRUE))
    stop("Install the dependency first: ", dependency)
}
setwd(build)
status <- system2(r, c("CMD", "build", "--no-manual", shQuote(root)))
setwd(root)
if (status != 0L) stop("Build failed: ", package)
archive <- file.path(build, paste0(package, "_", metadata[[1L, "Version"]], ".tar.gz"))
rcmdcheck::rcmdcheck(archive, args = c("--no-manual", "--as-cran"),
  check_dir = file.path(build, "check"), error_on = "note")
install(archive)
