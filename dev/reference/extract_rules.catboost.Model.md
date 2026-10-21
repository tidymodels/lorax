# Extract rules from a catboost model

Extract interpretable decision rules from a single tree in a CatBoost
boosted tree model. Each reachable terminal node (leaf) becomes one rule
representing the path from root to that leaf.

## Usage

``` r
# S3 method for class 'catboost.Model'
extract_rules(x, tree = 1L, data = NULL, ...)
```

## Arguments

- x:

  A `catboost.Model` object from the catboost package.

- tree:

  Integer specifying which tree to extract rules from. Uses 1-based
  indexing (default is `1L`). There is one tree per boosting iteration,
  including for multiclass models.

- data:

  A data frame containing the predictors used to train the model. This
  is only required when the tree contains categorical splits since
  catboost stores hashed values instead of the factor levels.

- ...:

  Not currently used.

## Value

A tibble with class `c("rule_set_catboost.Model", "rule_set")` and
columns:

- `tree`: integer, the tree number (matches input parameter).

- `rules`: list of R expressions, one per terminal node.

- `id`: integer, terminal node ID (1-based).

## Details

By default, catboost grows symmetric (oblivious) trees where every node
at the same depth uses the same split. For these trees, the leaf `id`
corresponds to catboost's leaf index plus one. Leaves that cannot be
reached (e.g., `cyl > 7` followed by `cyl <= 5`) are removed. For trees
grown with `grow_policy = "Depthwise"` or `"Lossguide"`, leaves are
numbered from left to right.

Numeric splits send observations with `feature <= border` to the left
and `feature > border` to the right.

### Categorical predictors

One-hot categorical splits (see the `one_hot_max_size` parameter) become
`==` or `%in%` conditions.

Most categorical splits use target statistics (CTRs): the levels are
converted to numeric values based on the outcome and the split compares
that value to a threshold. Since each level always goes to the same side
of a split, the split is equivalent to a set of levels. To find these
sets, the CTR splits are placed in a separate model that catboost uses
to predict every level of the categorical predictor(s) in `data`. A CTR
split then becomes a condition such as `g %in% c("b", "c")`.

catboost can also compute CTRs on combinations of features. These can
include several categorical predictors, binned numeric predictors (e.g.,
`x > 0.5`), and one-hot indicators. In this case, every combination of
levels is evaluated, and the rule is a set of combinations, such as
`(g == "a" & h %in% c("A", "B")) | (g == "b" & h == "C")`.

Levels that were not in the training set use a prior value for the CTR.
The side of the split that they go to is expressed as the negation of
the other side (e.g., `!(g %in% c("a", "d"))`) so that the rules match
how catboost would predict new levels.

## Examples

``` r
if (rlang::is_installed("catboost")) {
  pool <- catboost::catboost.load_pool(mtcars[, -1], label = mtcars$mpg)
  set.seed(3926)
  fit <- catboost::catboost.train(
    pool,
    params = list(
      iterations = 3,
      depth = 2,
      thread_count = 1,
      logging_level = "Silent",
      allow_writing_files = FALSE
    )
  )

  rules <- extract_rules(fit, tree = 1L)
  rules

  rule_text(rules$rules[[1]])
}
#> [1] "cyl <= 5"
```
