# Extract rules from an ObliqueForest model

Extracts the decision rules for terminal nodes in a specified tree from
an aorsf ObliqueForest model. Each rule represents the path from the
root node to a terminal node using oblique (linear combination) splits.

## Usage

``` r
# S3 method for class 'ObliqueForest'
extract_rules(x, tree = 1L, ...)
```

## Arguments

- x:

  An `ObliqueForest` object from the aorsf package

- tree:

  Integer specifying which tree to extract rules from (1-based). Default
  is `1L` for the first tree. Must be between 1 and the number of trees
  in the forest (`x$n_tree`).

- ...:

  Other arguments passed to methods

## Value

A tibble with columns:

- `tree`: integer, the tree number (1-based).

- `rules`: list of R expressions, one per terminal node.

- `id`: integer, the terminal node ID (1-based for user convenience).

## Details

### Tree and Node Indexing

Both the `tree` parameter and the `id` column use **1-based indexing**
for user convenience, matching R's standard indexing convention:

- `tree = 1` extracts rules from the first tree

- `id = 1` refers to the first terminal node

Internally, aorsf uses 0-based indexing (where node 0 is the root), but
this is automatically converted to 1-based indexing in the output for
consistency with R conventions.

### Factor Variables and Reference Coding

The aorsf package internally converts unordered factor variables using
**reference coding** (also called dummy coding). For a factor with k
levels, aorsf creates k-1 binary indicator variables, with the first
level serving as the reference category:

- A factor `color` with levels `["red", "blue", "green"]` creates
  indicators for `blue` and `green` only. When both indicators are 0, it
  represents `red`.

- The extracted rules automatically convert these back to factor
  comparisons: `2.1 * color_blue` becomes `2.1 * (color == "blue")`.

- Rules can be evaluated directly on data with the original factor
  columns (no need to manually create indicator variables).

- Ordered factors are converted to a single integer variable
  representing the ordinal level, not to multiple indicators.

Reference coding prevents collinearity in the internal regression
computations used to find optimal splits.

### Predictor Scaling

The aorsf package **always scales data during prediction**, regardless
of the `scale_x` parameter setting. The coefficients stored in trees are
for scaled data: `(x - mean) / sd` for numeric predictors.

To make rules work with unscaled input data, the extracted rules
automatically **include the scaling transformation** in the expressions
themselves. For example, instead of showing a pre-computed unscaled
coefficient, rules show:

    728.58 * ((flipper_length_mm - 200.97) / 14.02) > 400.23

This approach:

- Allows rules to be evaluated directly on original (unscaled) data

- Preserves full floating-point precision (avoids errors from
  pre-computing unscaled coefficients)

- Makes the scaling transformation explicit and transparent

Factor indicator variables are not scaled since they are binary 0/1
values.

## Examples

``` r
if (rlang::is_installed(c("aorsf", "palmerpenguins"))) {
  # Classification example
  penguins <- palmerpenguins::penguins[complete.cases(palmerpenguins::penguins), ]
  set.seed(2847)
  forest <- aorsf::orsf(
    species ~ ., data = penguins, n_tree = 3, n_thread = 1
  )

  # Extract rules from first tree (default)
  rules <- extract_rules(forest)

  # View rules as text
  rules$rules[[1]] |> rule_text(bullets = TRUE) |> cat("\n")

  # Extract rules from different tree
  rules3 <- extract_rules(forest, tree = 3L)

  # Regression example
  data(mtcars)
  set.seed(5193)
  forest_reg <- aorsf::orsf(
    mpg ~ ., data = mtcars, n_tree = 3, n_thread = 1
  )
  rules_reg <- extract_rules(forest_reg, tree = 1L)
}
#> * 1.276 * (sex == "male") + 0.00232 * ((year - 2008)/0.8129) - 1.884 * ((bill_length_mm - 43.99)/5.469) > 0.9291 
```
