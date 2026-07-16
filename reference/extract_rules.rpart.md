# Extract rules from an rpart model

Extract interpretable decision rules from an rpart decision tree. Each
terminal node becomes one rule representing the path from root to that
leaf.

## Usage

``` r
# S3 method for class 'rpart'
extract_rules(x, ...)
```

## Arguments

- x:

  An `rpart` object from the rpart package.

- ...:

  Not currently used.

## Value

A tibble with class `c("rule_set_rpart", "rule_set")` and columns:

- `id`: integer, the terminal node ID.

- `rules`: list of R expressions, one per terminal node.

## Examples

``` r
fit <- rpart::rpart(Species ~ ., data = iris)
extract_rules(fit)
#> # A tibble: 3 × 2
#>      id rules     
#>   <int> <list>    
#> 1     2 <language>
#> 2     6 <language>
#> 3     7 <language>
```
