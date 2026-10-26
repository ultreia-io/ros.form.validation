# ros.form.validation 0.3.0

- Check model-declared code lists, registries and primary keys in ROS forms 3.3.0, 4.0.0 and 4.1.0.
- Load verified code-list and registry snapshots with `form.references`, using shared ROS aliases.
- Show missing and duplicate primary-key values in individual and aggregate evidence reports.
- Run batch validation and report generation with configurable parallel workers.
- Use lowercase `ll` and `ps` form identifiers throughout the workflow.
- Use `form.model` 0.4.0, `form.validation` 0.4.0, `form.references` 0.1.0 and `ros.form.model` 0.2.0.

# ros.form.validation 0.2.0

- Add contextual evidence reports to forms and aggregates, with publication timestamps and ancestor navigation.
- Report table row counts as information and warn about internal blank rows.
- Update to `form.model` 0.3.1, `form.validation` 0.3.0 and `ros.form.model` 0.1.1.
- Prepare for CRAN submission: include generated help, preserve the vignette index and update maintainer details.
- Improve website branding, documentation links and contributor guidance.
- Update Linux CI containers and website dependency caching.

# ros.form.validation 0.1.0

- Validate LL and PS forms for versions 3.3.0, 4.0.0 and 4.1.0.
- Use `form.model` 0.3.0 and `form.validation` 0.2.1.
- Check structure, field values and ROS business rules with version-specific references.
- Prepare submitted values through trimming, type conversion and missing-value handling.
- Report META content issues as warnings by default, with an option to retain errors.
- Run resumable batches and rebuild reports without repeating validation.
- Produce individual, aggregate and evidence reports with CSV downloads.
- Publish verified reports with timestamps and optional comments.
