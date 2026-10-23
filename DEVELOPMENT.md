# Developing ros.form.validation

`develop` is the integration branch. `main` contains releases. Implementation branches use `feature/`.

Rules live under `inst/rules/<version>/`, separately for each gear:

- `<gear>-validation.yaml`: validation process.
- `<gear>-structure-validation.yaml`: sheet order and dimensions.
- `<gear>-generated-validation.yaml`: generated field checks.
- `<gear>-business-validation.yaml`: handwritten business checks.

After changing a form in `ros.form.model`, regenerate the rules for that version:

```sh
Rscript tools/generate-validation.R --version 3.3.0
```

Generation preserves handwritten business files. Extra business files and callbacks use the `business` and `checks` arguments.

For local development, load sibling packages from the `ros.form.validation` directory:

```r
pkgload::load_all("../form.model")
pkgload::load_all("../form.validation")
pkgload::load_all("../ros.form.model")
pkgload::load_all(".")
roxygen2::roxygenise()
```

## Local verification

Install development dependencies first. Run roxygen in sibling packages too.

Commit generated `man/*.Rd` files and `NAMESPACE` alongside their roxygen source changes.

```sh
Rscript tools/check.R
Rscript tools/build-site.R
```

The check script installs sibling packages into `build/library`. Archives and checks go under `build/`.

The documentation site goes under `docs/`.

Single reports accept `parent_report = NULL` to omit navigation, or a URL to link to a parent aggregate.

Publication preparation adds breadcrumbs to copied reports for every ancestor aggregate, using the configured report filename.

## Pipeline responsibilities

`form.validation` owns saved plans, execution, resume, result storage, rendering and publication preparation.

`ros.form.validation` supplies input discovery, model and reference selection, grouping, IOTC branding and uploading.

Planning scans inputs once and records hashes, jobs, form definitions, rules and prepared reference values.

Empty jobs retain references without preparing unused lookup indexes. Changed inputs require a new plan.

Validation stores typed results under `validation/results/`. Reporting uses these saved results.

Local `plan.rds` and `resources/` contain private paths and frozen resources; keep them with the raw batch.

Public `plan.json` contains relative inputs and grouping metadata; publication adds statuses and report links.

Publication preparation checks stage completion, checksums, report counts and links before finalizing its tree.

`publication.json` lists the prepared artifacts and their SHA-256 checksums.

HTML templates, JavaScript and CSS are separate resources. Shared assets use content-based filenames.

## Release

Release `ros.form.model` before `ros.form.validation`, then pin its release tag in `Remotes`.

1. **Prepare the release on `develop`:**

   1. **Prepare the release files:** update the version in `DESCRIPTION`, finalize `NEWS.md` and documentation.
   2. **Perform the [local checks](#local-verification).**
   3. **Commit the changes:** use `[ros.form.validation] Release <version>`.
   4. **Push the release commit.**

2. **Start the release on GitHub:**

   1. Open **Actions → Start Release**.
   2. Click **Run workflow**, select `develop`, then click **Run workflow** to confirm.
   3. Open the release PR created by the workflow.

3. **Merge the release PR:**

   1. **Wait for the checks:** all checks on the release PR must be green.
   2. **Merge:** click **Merge pull request**, then **Confirm merge**.

**Publish Release** publishes the package, checksum and documentation automatically.
