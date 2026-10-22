# ros.form.validation

Validate submitted IOTC Regional Observer Scheme forms and review the results in interactive reports.

Start with one form, or process a collection organised by year, country, gear and model version.

## Installation

Install the latest released version:

```r
install.packages("pak") # Once
pak::pak("ultreia-io/ros.form.validation@*release")
```

`pak` installs the required dependencies automatically.

For the development version:

```r
pak::pak("ultreia-io/ros.form.validation@develop")
```

## Validate one form

Obtain the reference snapshot approved for your form version from the person maintaining your IOTC references.

```r
library(ros.form.validation)

rules <- ros_validation(
  name = ros.form.model::ROS_FORM_LL,
  version = ros.form.model::ROS_FORM_VERSION_3_3_0
)
references <- read_ros_references("references/3.3.0", plans = list(rules))
result <- validate_ros_file(
  path = "submitted-form.xlsx",
  directory = "output/my-first-form",
  plan = rules,
  references = references
)
result$status
```

Use a new output directory. It contains `index.html`, `summary.csv` and `findings.csv`.

Reports need a local or hosted web server to load their data; opening the HTML file directly is insufficient.

## Practical guides

- [Validate one submitted form](https://ultreia-io.github.io/ros.form.validation/articles/validate-one-form.html): choose a version, run checks and open the report.
- [Validate a collection](https://ultreia-io.github.io/ros.form.validation/articles/validate-collection.html): plan, validate, generate reports and build aggregates.
- [Understand results](https://ultreia-io.github.io/ros.form.validation/articles/understand-results.html): review statuses, findings, code-list evidence and registry evidence.
- [Resume and share results](https://ultreia-io.github.io/ros.form.validation/articles/resume-and-share.html): resume a run, refresh reports and share the folder.

Operators using a repository checkout can follow [Command-line operation](https://ultreia-io.github.io/ros.form.validation/articles/operator-workflow.html).

Package contributors can use the [development instructions](https://github.com/ultreia-io/ros.form.validation/blob/develop/DEVELOPMENT.md).
