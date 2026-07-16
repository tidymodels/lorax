# Extract rules from an xgb.Booster model

Extract interpretable decision rules from a single tree in an xgboost
boosted tree model. Each terminal node (leaf) becomes one rule
representing the path from root to that leaf.

## Usage

``` r
# S3 method for class 'xgb.Booster'
extract_rules(x, tree = 1L, nthread = NULL, ...)
```

## Arguments

- x:

  An `xgb.Booster` object from the xgboost package.

- tree:

  Integer specifying which tree to extract rules from. Uses 1-based
  indexing (default is `1L`). For multiclass models with `num_class`
  classes and `nrounds` boosting rounds, there are `num_class * nrounds`
  total trees.

- nthread:

  Integer number of threads to use when reading the tree structure out
  of the model. The default (`NULL`) inherits the `nthread` the booster
  was trained with.

- ...:

  Not currently used.

## Value

A tibble with class `c("rule_set_xgb.Booster", "rule_set")` and columns:

- `tree`: integer, the tree number (matches input parameter).

- `rules`: list of R expressions, one per terminal node.

- `id`: integer, terminal node ID (1-based).

## Details

xgboost uses 0-based indexing internally, but this function uses 1-based
indexing for the `tree` parameter and output `id` column (R convention).

Split conditions in xgboost follow the pattern: Yes branch when feature
\< threshold, No branch when feature \>= threshold. Rules are
combinations of these conditions using AND logic.

Note: This function does not work with xgboost models containing
categorical features or non-tree boosters (`gblinear`).

## Examples

``` r
if (rlang::is_installed("xgboost")) {
  data(agaricus.train, package = "xgboost")

  # Binary classification on a small subset for a fast example.
  rows <- seq_len(200)
  set.seed(2847)
  bst <- xgboost::xgb.train(
    data = xgboost::xgb.DMatrix(
      agaricus.train$data[rows, ],
      label = agaricus.train$label[rows],
      nthread = 1
    ),
    nrounds = 3,
    params = xgboost::xgb.params(
      max_depth = 3,
      objective = "binary:logistic",
      nthread = 1
    )
  )

  # Extract rules from first tree
  rules <- extract_rules(bst, tree = 1L)

  # View as text
  rule_text(rules$rules[[1]])

  # Regression example
  data(mtcars)
  set.seed(8472)
  bst_reg <- xgboost::xgb.train(
    data = xgboost::xgb.DMatrix(
      as.matrix(mtcars[, -1]),
      label = mtcars$mpg,
      nthread = 1
    ),
    nrounds = 3,
    params = xgboost::xgb.params(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    )
  )
  rules_reg <- extract_rules(bst_reg, tree = 1L)
}
```
