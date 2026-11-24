# Extract rules from an xgb.Booster model

Extract interpretable decision rules from a single tree in an xgboost
boosted tree model. Each terminal node (leaf) becomes one rule
representing the path from root to that leaf.

## Usage

``` r
# S3 method for class 'xgb.Booster'
extract_rules(
  x,
  tree = 1L,
  nthread = NULL,
  add_statistics = FALSE,
  data = NULL,
  ...
)
```

## Arguments

- x:

  An `xgb.Booster` object from the xgboost package.

- tree:

  Integer vector specifying which trees to extract rules from. Uses
  1-based indexing (default is `1L`). For multiclass models with
  `num_class` classes and `nrounds` boosting rounds, there are
  `num_class * nrounds` total trees.

- nthread:

  Integer number of threads to use when reading the tree structure out
  of the model. The default (`NULL`) inherits the `nthread` the booster
  was trained with.

- add_statistics:

  A single logical. If `TRUE`, two integer columns are added to the
  results:

  - `num_rule_terms`: the number of conditions joined by `&` in the
    rule.

  - `num_rule_predictors`: the number of unique predictors in the rule.

  A rule of `TRUE` (a tree with no splits) has zero terms and
  predictors.

- data:

  Optional data frame containing the predictors used to train the model.
  It is only used for models with categorical predictors, where the
  levels of the factor columns are used to convert category codes to
  factor levels.

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

### Categorical predictors

xgboost (version 3.0.0 and later) can use factor predictors directly as
categorical features. A categorical split sends a set of categories to
the Yes branch and all other categories to the No branch. The model
stores the categories as zero-based integer codes
(`as.integer(factor) - 1L`) and does not save the factor levels. When
`data` is supplied, the levels of its factor columns are used to write
rules such as `x %in% c("a", "c")`. Otherwise, rules use the integer
codes.

Models fit with indicator (dummy) variables, as well as those from
earlier versions of xgboost, only have numeric splits.

Note: This function does not work with non-tree boosters (`gblinear`).

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

# Categorical predictors
if (rlang::is_installed("xgboost", version = "3.0.0")) {
  cat_data <- data.frame(
    group = factor(rep(c("a", "b", "c", "d"), each = 25)),
    dose = rep(seq(0, 1, length.out = 25), times = 4)
  )
  outcome <- 2 * (cat_data$group %in% c("a", "c")) + cat_data$dose

  bst_cat <- xgboost::xgb.train(
    data = xgboost::xgb.DMatrix(cat_data, label = outcome, nthread = 1),
    nrounds = 2,
    params = xgboost::xgb.params(max_depth = 2, nthread = 1)
  )

  # Rules with integer codes
  extract_rules(bst_cat)$rules[[1]]

  # Rules with factor levels
  extract_rules(bst_cat, data = cat_data)$rules[[1]]
}
#> group %in% c("a", "c") & dose < 0.458333343
```
