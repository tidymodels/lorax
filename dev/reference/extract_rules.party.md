# Extract rules from a party object

Extract interpretable decision rules from a partykit `party` or
`constparty` object. Each terminal node becomes one rule representing
the path from root to that leaf.

## Usage

``` r
# S3 method for class 'party'
extract_rules(x, add_statistics = FALSE, ...)
```

## Arguments

- x:

  A `party` or `constparty` object from the partykit package.

- add_statistics:

  A single logical. If `TRUE`, two integer columns are added to the
  results:

  - `num_rule_terms`: the number of conditions joined by `&` in the
    rule.

  - `num_rule_predictors`: the number of unique predictors in the rule.

  A rule of `TRUE` (a tree with no splits) has zero terms and
  predictors.

- ...:

  Not currently used.

## Value

A tibble with class `c("rule_set_party", "rule_set")` and columns:

- `id`: integer, the terminal node ID.

- `rules`: list of R expressions, one per terminal node.

## Examples

``` r
fit <- partykit::ctree(Species ~ ., data = iris)
extract_rules(fit)
#> # A tibble: 4 × 2
#>      id rules     
#>   <int> <list>    
#> 1     2 <language>
#> 2     5 <language>
#> 3     6 <language>
#> 4     7 <language>
```
