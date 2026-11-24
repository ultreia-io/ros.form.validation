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

Install the dependency versions declared in `DESCRIPTION`, then load this package:

```r
pkgload::load_all(".")
roxygen2::roxygenise()
```

## Local verification

Install development dependencies first. Regenerate documentation for any sibling packages you modify.

Commit generated `man/*.Rd` files and `NAMESPACE` alongside their roxygen source changes.

```sh
Rscript tools/check.R
Rscript tools/build-site.R
```

The check script uses matching sibling versions or installed dependencies. Archives and checks go under `build/`.

The documentation site goes under `docs/`.

Single reports accept `parent_report = NULL` to omit navigation, or a URL to link to a parent aggregate.

Publication preparation adds breadcrumbs to copied reports for every ancestor aggregate, using the configured report filename.

**Build** runs one Linux R-release check for routine changes.

Run **Actions → Check All Platforms** for Linux with R release and R-devel, macOS, and Windows.

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

## GitHub Release

1. **Prepare the release on `develop`:**

   1. **Prepare the release files:** update the version in `DESCRIPTION`, finalize `NEWS.md` and documentation.
   2. **Perform the [local checks](#local-verification).**
   3. **Commit the changes:** use `[ros.form.validation] Release <version>`.
   4. **Push the release commit.**

2. **Start the release on GitHub:**

   1. Open **Actions → Start Release**.
   2. Click **Run workflow**, select `develop`, then click **Run workflow** to confirm.
   3. The workflow checks the selected commit on all four environments and saves the checked Linux archive.
   4. After all four checks pass, it opens the release PR at the checked commit.

3. **Merge the release PR:**

   1. Review the release PR and merge it. Its checks already passed in **Start Release**.
   2. Merging starts **Publish Release**, which verifies that the merged files match the checked candidate.

**Publish Release** publishes the checked archive and checksum, then deploys the documentation.

If the merge changes the checked files, update `develop` and rerun **Start Release** before merging a new PR.

### Enable CRAN submission

Leave CRAN submission disabled until the package and its required dependencies are ready for CRAN.

1. Open the repository's **Settings → Secrets and variables → Actions → Variables**.
2. Click **New repository variable** and set `SUBMIT_TO_CRAN` to `true`.

To disable submission, remove the variable or set it to `false`.
