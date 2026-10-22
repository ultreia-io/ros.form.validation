# ros.form.validation 0.1.0

- Validate LL and PS forms for versions 3.3.0, 4.0.0 and 4.1.0.
- Use `form.model` 0.3.0 and `form.validation` 0.2.1.
- Check structure, field values and ROS business rules with version-specific references.
- Prepare submitted values through trimming, type conversion and missing-value handling.
- Report META content issues as warnings by default, with an option to retain errors.
- Run resumable batches and rebuild reports without repeating validation.
- Produce individual, aggregate and evidence reports with CSV downloads.
- Publish verified reports with timestamps and optional comments.
