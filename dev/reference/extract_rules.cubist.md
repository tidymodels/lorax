# Extract rules from a Cubist model

Extracts rule conditions from a Cubist regression model as R
expressions. Each rule consists of conditions that define when a linear
model applies.

## Usage

``` r
# S3 method for class 'cubist'
extract_rules(x, committee = 1L, ...)
```

## Arguments

- x:

  A `cubist` object from the Cubist package.

- committee:

  An integer vector specifying which committee(s) to extract rules from.
  Defaults to `1L` (first committee). Values must be between 1 and the
  total number of committees in the model.

- ...:

  Not used.

## Value

A tibble with columns:

- `committee`: Integer committee number

- `id`: Integer rule number within the committee

- `rules`: List column containing R expressions for each rule's
  conditions

## Details

Cubist models use committees (similar to boosting iterations) where each
committee contains multiple rules. Each rule has:

- Conditions that determine when the rule applies (splits on predictors)

- A linear model that makes predictions when conditions are met

This function extracts the conditions as R expressions that can be
evaluated on data. Rules with no conditions (applying to all data)
return `TRUE`.

The expressions use standard R operators:

- Continuous splits: `>`, `<=`, etc.

- Categorical single value: `==`

- Categorical multiple values: `%in%`

- Missing values: [`is.na()`](https://rdrr.io/r/base/NA.html)

## See also

`rules::tidy.cubist()` for extracting rules as text strings

## Examples

``` r
# \donttest{
if (rlang::is_installed("Cubist")) {
library(Cubist)
library(lorax)

# Create sample data
set.seed(1)
n <- 100
p <- 5
X <- matrix(rnorm(n * p), n, p)
colnames(X) <- paste0("x", 1:p)
y <- X[, 1] + X[, 2]^2 + rnorm(n)

# Fit Cubist model with multiple committees
mod <- cubist(X, y, committees = 3)

# Extract rules from first committee
rules <- extract_rules(mod)
rules

# Extract from multiple committees
rules_all <- extract_rules(mod, committee = 1:3)

# Convert to readable text
rule_text(rules$rules[[1]])
}
#> Loading required package: lattice
#> [1] "x2 <= -0.1796"
# }
```
