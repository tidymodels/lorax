# Methods for tidymodels objects

Fitted parsnip model objects (`model_fit`) and fitted workflows objects
(`workflow`) are unwrapped with
[`hardhat::extract_fit_engine()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html)
and the generic is then called on the underlying engine model. All other
arguments, such as `tree`, `add_statistics`, or `data`, are passed to
the method for the engine model; see the documentation for that model's
method.

## Usage

``` r
# S3 method for class 'model_fit'
extract_rules(x, ...)

# S3 method for class 'workflow'
extract_rules(x, ...)

# S3 method for class 'model_fit'
active_predictors(x, ...)

# S3 method for class 'workflow'
active_predictors(x, ...)

# S3 method for class 'model_fit'
num_ensemble_members(x, ...)

# S3 method for class 'workflow'
num_ensemble_members(x, ...)

# S3 method for class 'model_fit'
as.party(obj, ...)

# S3 method for class 'workflow'
as.party(obj, ...)

# S3 method for class 'model_fit'
var_imp(object, ...)

# S3 method for class 'workflow'
var_imp(object, ...)
```

## Arguments

- x, obj, object:

  A fitted `model_fit` or `workflow` object.

- ...:

  Other arguments passed to the method for the engine model.

## Value

The result of the generic applied to the engine model.

## Details

For
[`as.party()`](https://rdrr.io/pkg/partykit/man/party-coercion.html),
engines that need the training data (e.g., xgboost) require it via
`data`. For workflows, this should be the preprocessed predictors that
were given to the engine.

## Examples

``` r
if (rlang::is_installed(c("parsnip", "ranger"))) {
  library(parsnip)

  rf_fit <-
    rand_forest(trees = 5) |>
    set_engine("ranger") |>
    set_mode("regression") |>
    fit(mpg ~ ., data = mtcars)

  num_ensemble_members(rf_fit)
  extract_rules(rf_fit, tree = 1:2, data = mtcars)
}
#> # A tibble: 21 × 3
#>       id rules       tree
#>    <int> <list>     <int>
#>  1     3 <language>     1
#>  2     4 <language>     1
#>  3     7 <language>     1
#>  4     8 <language>     1
#>  5    10 <language>     1
#>  6    12 <language>     1
#>  7    15 <language>     1
#>  8    17 <language>     1
#>  9    18 <language>     1
#> 10    19 <language>     1
#> # ℹ 11 more rows
```
