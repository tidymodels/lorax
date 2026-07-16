# Tree Importance Scores

Methods for computing variable importance scores via the model object
using a common interface.

## Usage

``` r
# S3 method for class 'ObliqueForest'
var_imp(object, complete = TRUE, ...)

# S3 method for class 'cforest'
var_imp(object, complete = TRUE, ...)

# S3 method for class 'grf'
var_imp(object, complete = TRUE, ...)

# S3 method for class 'lgb.Booster'
var_imp(object, complete = TRUE, feature_names = NULL, ...)

# S3 method for class 'party'
var_imp(object, complete = TRUE, ...)

# S3 method for class 'randomForest'
var_imp(object, complete = TRUE, type = NULL, ...)

# S3 method for class 'ranger'
var_imp(object, complete = TRUE, ...)

# S3 method for class 'rpart'
var_imp(object, complete = TRUE, ...)

# S3 method for class 'xgb.Booster'
var_imp(object, complete = TRUE, feature_names = NULL, nthread = NULL, ...)
```

## Arguments

- object:

  A model object.

- complete:

  A logical to filling absent importance values with zeros.

- ...:

  Arguments passed to importance functions (if any).

- feature_names:

  Character vector of feature names to include when `complete = TRUE`.
  For xgboost models, the model object does not store unused feature
  names, so this parameter allows you to specify the complete feature
  set. If `NULL` (default), only features that appear in at least one
  tree will be included.

- type:

  Character string specifying which importance measure to extract. For
  classification forests, options are `"gini"` (default, uses
  MeanDecreaseGini), `"accuracy"` (uses MeanDecreaseAccuracy), or a
  class name. For regression forests, options are `"mse"` (default, uses
  IncNodePurity) or `"permutation"` (uses %IncMSE). If `NULL`, uses the
  default for the forest type.

- nthread:

  Integer number of threads to use when reading the tree structure out
  of the model. The default (`NULL`) inherits the `nthread` the booster
  was trained with.

## Value

A tibble with columns `term` and `estimate`.

## Details

Different engines compute importances differently:

- [`rpart::rpart()`](https://rdrr.io/pkg/rpart/man/rpart.html),
  [`xgboost::xgb.importance()`](https://rdrr.io/pkg/xgboost/man/xgb.importance.html),
  and
  [`lightgbm::lgb.importance()`](https://rdrr.io/pkg/lightgbm/man/lgb.importance.html)
  follow the change in the objective function (e.g., Gini, MSE, gain,
  ...) as the tree is constructed and reports the aggregate improvement
  in these statistics as importance.

- [`randomForest::importance()`](https://rdrr.io/pkg/randomForest/man/importance.html)
  and
  [`ranger::ranger()`](http://imbs-hl.github.io/ranger/reference/ranger.md)
  produce standard permutation-based importance scores.

- [`grf::variable_importance()`](https://rdrr.io/pkg/grf/man/variable_importance.html)
  states that a "simple weighted sum of how many times feature i was
  split on at each depth in the forest" is used.

Keep in mind that, for
[`rpart::rpart()`](https://rdrr.io/pkg/rpart/man/rpart.html), the
importance calculation is affected by competing and surrogate splits.
Consequently, there might be non-zero importances for predictors that
were not used in any actual split in the tree. To make the splits and
importances align, use the options `maxcompete = 0` and
`maxsurrogate = 0`.

## Examples

``` r
fit <- partykit::ctree(Species ~ ., data = iris)
var_imp(fit)
#> # A tibble: 4 × 2
#>   term         estimate
#>   <chr>           <dbl>
#> 1 Petal.Length    7.22 
#> 2 Petal.Width     0.639
#> 3 Sepal.Length    0    
#> 4 Sepal.Width     0    
```
