# Extract rules from an lgb.Booster model

Extract interpretable decision rules from a single tree in a LightGBM
boosted tree model. Each terminal node (leaf) becomes one rule
representing the path from root to that leaf.

## Usage

``` r
# S3 method for class 'lgb.Booster'
extract_rules(x, tree = 1L, data = NULL, ...)
```

## Arguments

- x:

  An `lgb.Booster` object from the lightgbm package.

- tree:

  Integer specifying which tree to extract rules from. Uses 1-based
  indexing (default is `1L`). For multiclass models with `num_class`
  classes and `nrounds` boosting rounds, there are `num_class * nrounds`
  total trees.

- data:

  An optional data frame of the training data. It is only used to
  translate the integer codes of categorical predictors into factor
  levels. Factor columns with the same names as the categorical
  predictors are used; other columns are ignored.

- ...:

  Not currently used.

## Value

A tibble with class `c("rule_set_lgb.Booster", "rule_set")` and columns:

- `tree`: integer, the tree number (matches input parameter).

- `rules`: list of R expressions, one per terminal node.

- `id`: integer, terminal node ID (1-based).

## Details

lightgbm uses 0-based indexing internally, but this function uses
1-based indexing for the `tree` parameter and output `id` column (R
convention).

Split conditions in lightgbm follow the pattern: left child when feature
\<= threshold, right child when feature \> threshold. Rules are
combinations of these conditions using AND logic.

### Categorical predictors

lightgbm requires categorical predictors to be encoded as non-negative
integers and the model only stores these codes. If `data` contains a
factor column for a categorical predictor, the codes are assumed to be
`as.integer(factor) - 1L` (the encoding used by bonsai) and the rules
are written in terms of the factor levels (e.g.,
`island %in% c("Biscoe", "Dream")`). Otherwise, the rules use the
integer codes (e.g., `island %in% c(0L, 1L)`).

## Examples

``` r
if (rlang::is_installed("lightgbm")) {
  # Binary classification
  data(agaricus.train, package = "lightgbm")
  dtrain <- lightgbm::lgb.Dataset(
    agaricus.train$data,
    label = agaricus.train$label
  )
  set.seed(2847)
  bst <- lightgbm::lgb.train(
    params = list(objective = "binary", max_depth = 3, num_threads = 1L),
    data = dtrain,
    nrounds = 3,
    verbose = -1
  )

  # Extract rules from first tree
  rules <- extract_rules(bst, tree = 1L)

  # View as text
  rule_text(rules$rules[[1]])

  # Regression example
  data(mtcars)
  dtrain_reg <- lightgbm::lgb.Dataset(as.matrix(mtcars[, -1]), label = mtcars$mpg)
  set.seed(5193)
  bst_reg <- lightgbm::lgb.train(
    params = list(
      objective = "regression", max_depth = 3, min_data_in_leaf = 1,
      num_threads = 1L
    ),
    data = dtrain_reg,
    nrounds = 3,
    verbose = -1
  )
  rules_reg <- extract_rules(bst_reg, tree = 1L)

  # Categorical predictors, encoded as 0-based integers
  if (rlang::is_installed("palmerpenguins")) {
    penguins <- na.omit(palmerpenguins::penguins)
    x_cat <- data.frame(
      island = as.integer(penguins$island) - 1L,
      bill_length_mm = penguins$bill_length_mm
    )
    dtrain_cat <- lightgbm::lgb.Dataset(
      as.matrix(x_cat),
      label = penguins$body_mass_g,
      categorical_feature = "island"
    )
    set.seed(8126)
    bst_cat <- lightgbm::lgb.train(
      params = list(
        objective = "regression", max_depth = 2, num_threads = 1L
      ),
      data = dtrain_cat,
      nrounds = 3,
      verbose = -1
    )

    # Rules with integer codes
    extract_rules(bst_cat)

    # Rules with factor levels
    extract_rules(bst_cat, data = penguins)
  }
}
#> # A tibble: 4 × 3
#>    tree rules         id
#>   <int> <list>     <int>
#> 1     1 <language>     1
#> 2     1 <language>     2
#> 3     1 <language>     3
#> 4     1 <language>     4
```
