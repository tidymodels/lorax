# Count the number of members in an ensemble

Ensembles of trees or rules, such as random forests or boosted models,
contain multiple models. This generic returns how many there are. For
most models this is the number of trees. For C5.0 models it is the
number of boosting trials and, for Cubist models, the number of
committees. For multiclass boosted models (e.g., from xgboost and
lightgbm), the count is the total number of trees across all classes.

## Usage

``` r
# S3 method for class 'C5.0'
num_ensemble_members(x, ...)

# S3 method for class 'ObliqueForest'
num_ensemble_members(x, ...)

# S3 method for class 'bart'
num_ensemble_members(x, ...)

# S3 method for class 'catboost.Model'
num_ensemble_members(x, ...)

# S3 method for class 'cforest'
num_ensemble_members(x, ...)

# S3 method for class 'cubist'
num_ensemble_members(x, ...)

num_ensemble_members(x, ...)

# S3 method for class 'grf'
num_ensemble_members(x, ...)

# S3 method for class 'lgb.Booster'
num_ensemble_members(x, ...)

# S3 method for class 'randomForest'
num_ensemble_members(x, ...)

# S3 method for class 'ranger'
num_ensemble_members(x, ...)

# S3 method for class 'xgb.Booster'
num_ensemble_members(x, ...)
```

## Arguments

- x:

  A object

- ...:

  Other arguments passed to methods

## Value

A single integer.

## Details

The value is the largest index that can be passed to the `tree` (or
`committee`) argument of methods such as
[`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md)
and
[`active_predictors()`](https://lorax.tidymodels.org/dev/reference/active_predictors.md).

Methods are only available for model classes that can be ensembles;
single tree models (e.g., from
[`rpart::rpart()`](https://rdrr.io/pkg/rpart/man/rpart.html)) do not
have a method.

## Examples

``` r
if (rlang::is_installed("ranger")) {
  rf <- ranger::ranger(mpg ~ ., data = mtcars, num.trees = 10)
  num_ensemble_members(rf)
}
#> [1] 10
```
