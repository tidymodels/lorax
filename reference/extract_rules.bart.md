# Extract rules from a BART model

Extract interpretable decision rules from a single tree in a BART
(Bayesian Additive Regression Trees) model. Each terminal node (leaf)
becomes one rule representing the path from root to that leaf.

## Usage

``` r
# S3 method for class 'bart'
extract_rules(x, tree = 1L, chain = 1L, ...)
```

## Arguments

- x:

  A `bart` object from the dbarts package fitted with
  `keeptrees = TRUE`.

- tree:

  Integer specifying which tree to extract rules from. Uses 1-based
  indexing (default is `1L`). BART models contain `n.trees` trees in the
  ensemble.

- chain:

  Integer specifying which MCMC chain to extract from. Uses 1-based
  indexing (default is `1L`). Only relevant for models fitted with
  multiple chains.

- ...:

  Not currently used.

## Value

A tibble with class `c("rule_set_bart", "rule_set")` and columns:

- `tree`: integer, the tree number (matches input parameter).

- `rules`: list of R expressions, one per terminal node.

- `id`: integer, terminal node ID (1-based).

## Details

The BART model must be fitted with `keeptrees = TRUE` to enable tree
extraction. This function uses 1-based indexing for the `tree` parameter
and output `id` column (R convention).

Split conditions in BART follow the pattern: left child when feature \<
threshold, right child when feature \>= threshold. Rules are
combinations of these conditions using AND logic.

## Examples

``` r
if (rlang::is_installed(c("dbarts", "palmerpenguins"))) {
  # Classification example
  data(penguins, package = "palmerpenguins")
  penguins <- na.omit(penguins)

  train_data <- penguins[, c("bill_length_mm", "bill_depth_mm",
                             "flipper_length_mm", "body_mass_g", "species")]

  set.seed(2847)
  fit <- dbarts::bart(
    x.train = train_data[, 1:4],
    y.train = train_data$species,
    keeptrees = TRUE,
    verbose = FALSE,
    ntree = 2
  )

  # Extract rules from first tree
  rules <- extract_rules(fit, tree = 1L)

  # View as text
  rule_text(rules$rules[[1]])

  # Regression example
  data(mtcars)
  set.seed(5193)
  fit_reg <- dbarts::bart(
    x.train = mtcars[, -1],
    y.train = mtcars$mpg,
    keeptrees = TRUE,
    verbose = FALSE,
    ntree = 2
  )
  rules_reg <- extract_rules(fit_reg, tree = 1L)
}
```
