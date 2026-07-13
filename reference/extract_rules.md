# Extract an expression that defines a path to a terminal node

A rule is a logical expression of predictor variables that reflects
which data are contained in or sent to a terminal node in a tree-based
model. Rules can take any form but, for most trees, they are simple
statements such as `x < 1.2`, `y == "red"`, or
`z %in% c("blue", "green")`.

## Usage

``` r
# S3 method for class 'C5.0'
extract_rules(x, tree = 1L, ...)

# S3 method for class 'cforest'
extract_rules(x, tree = 1L, ...)

extract_rules(x, ...)

# S3 method for class 'grf'
extract_rules(x, tree = 1L, ...)

# S3 method for class 'randomForest'
extract_rules(x, tree = 1L, data = NULL, ...)

# S3 method for class 'ranger'
extract_rules(x, tree = 1L, data = NULL, ...)
```

## Arguments

- x:

  A object

- tree:

  Integer vector specifying which trees to extract rules from. Default
  is `1L` for the first tree. Values must be between 1 and the number of
  trees in the forest (`x$num.trees`).

- ...:

  Other arguments passed to methods

- data:

  Data.frame containing the training data. Required for ranger models to
  properly extract rules with fitted values and node summaries.

## Value

A data frame with column `rules` (an R expression) and `id` (an
identifier).
