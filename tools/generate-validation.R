# Run from ros.form.validation with its declared dependencies installed.
pkgload::load_all(".", quiet = TRUE)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L || args[[1L]] != "--version")
  stop("Usage: Rscript tools/generate-validation.R --version 3.3.0|4.0.0|4.1.0", call. = FALSE)
version <- args[[2L]]
output <- file.path("inst", "rules", version)
for (name in ros.form.model::ROS_FORMS) {
  model <- ros.form.model::ros_form(name, version)
  paths <- file.path(output, paste0(name, c("-structure-validation.yaml", "-generated-validation.yaml")))
  form.validation::write_validation_rules(model, paths[[1L]], paths[[2L]],
    version = "1.0.0", overwrite = any(file.exists(paths)))
  identity <- form.model::form_metadata(model)$form[c("id", "version")]
  process <- list(schema_version = "1.0.0", rules_version = "1.0.0", model = identity,
    rulesets = list(structure = basename(paths[[1L]]), content = as.list(c(
      basename(paths[[2L]]), paste0(name, "-business-validation.yaml")))))
  yaml::write_yaml(process, file.path(output, paste0(name, "-validation.yaml")))
}
