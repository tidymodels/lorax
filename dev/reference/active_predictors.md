# Extract the active features from a tree

If a tree does not use a predictor in the training set in any of its
splits it is functionally independent of the prediction function. This
generic returns a data frame containing character vector of predictor
names that were used in at least one split.

## Usage

``` r
# S3 method for class 'C5.0'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'ObliqueForest'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'bart'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'cforest'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'cubist'
active_predictors(x, ...)

active_predictors(x, ...)

# S3 method for class 'grf'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'lgb.Booster'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'party'
active_predictors(x, ...)

# S3 method for class 'randomForest'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'ranger'
active_predictors(x, tree = 1L, ...)

# S3 method for class 'rpart'
active_predictors(x, ...)

# S3 method for class 'xgb.Booster'
active_predictors(x, tree = 1L, nthread = NULL, ...)
```

## Arguments

- x:

  A object

- tree:

  Integer vector specifying which trees to extract active predictors
  from. Default is `1L` for the first tree. Values must be between 1 and
  the number of trees in the forest.

- ...:

  Other arguments passed to methods

- nthread:

  Integer number of threads to use when reading the tree structure out
  of an xgboost model. The default (`NULL`) inherits the `nthread` the
  booster was trained with.

## Value

A tibble with list column `active_predictors` containing a character
vector of predictors.

## Examples

``` r
if (rlang::is_installed(c("rpart", "palmerpenguins"))) {
  data(penguins, package = "palmerpenguins")
  penguins <- na.omit(penguins)

  # Fit a tree
  tree <- rpart::rpart(species ~ ., data = penguins)
  tree

  # Extract active predictors
  active_predictors(tree)

  # Only primary splits are included - competing and surrogate splits
  # are excluded since they don't affect predictions
}
#> # A tibble: 1 × 1
#>   active_predictors
#>   <list>           
#> 1 <chr [3]>        

# C5.0 single tree
if (rlang::is_installed(c("C50", "palmerpenguins"))) {
  data(penguins, package = "palmerpenguins")
  penguins <- na.omit(penguins)

  # Tree-based model
  c5_tree <- C50::C5.0(species ~ ., data = penguins)
  active_predictors(c5_tree)

  # Boosted model - extract from multiple trials
  c5_boost <- C50::C5.0(species ~ ., data = penguins, trials = 5)
  active_predictors(c5_boost, tree = 1:3)

  # Rule-based model
  c5_rules <- C50::C5.0(species ~ ., data = penguins, rules = TRUE)
  active_predictors(c5_rules)
}
#> Registered S3 method overwritten by 'C50':
#>   method        from 
#>   as.party.C5.0 lorax
#> # A tibble: 1 × 1
#>   active_predictors
#>   <list>           
#> 1 <chr [4]>        
```
