# Convert a bagged tree to a party object

Convert a single tree from a bagged model created by baguette (e.g.,
[`parsnip::bag_tree()`](https://parsnip.tidymodels.org/reference/bag_tree.html))
to a party object for use with partykit visualization and analysis
tools. Both the "rpart" and "C5.0" engines are supported.

## Usage

``` r
# S3 method for class 'bagger'
as.party(obj, tree = 1L, data = NULL, ...)
```

## Arguments

- obj:

  A `bagger` object, which is the `fit` element of a fitted `bag_tree()`
  model.

- tree:

  A single integer specifying which tree (ensemble member) to convert.
  Must be between 1 and the number of bagged trees.

- data:

  A data frame with the training data, including the outcome. The
  bootstrap samples used to fit each tree are not saved, so this is used
  for the node assignments and predictions in the party object.

- ...:

  Not currently used.

## Value

A `party` object from the partykit package.

## Examples

``` r
data(penguins, package = "palmerpenguins")
penguins <- na.omit(penguins)

set.seed(1)
bag_fit <- parsnip::bag_tree(mode = "classification", tree_depth = 3) |>
  parsnip::set_engine("rpart", times = 3) |>
  parsnip::fit(species ~ ., data = penguins)
#> Registered S3 method overwritten by 'butcher':
#>   method                 from    
#>   as.character.dev_topic generics

as.party(bag_fit$fit, tree = 2L, data = penguins)
#> 
#> Model formula:
#> .outcome ~ bill_length_mm + bill_depth_mm + flipper_length_mm + 
#>     body_mass_g + year + island + sex
#> 
#> Fitted party:
#> [1] root
#> |   [2] flipper_length_mm < 206.5
#> |   |   [3] bill_length_mm < 43.35: Adelie (n = 145, err = 3.4%)
#> |   |   [4] bill_length_mm >= 43.35
#> |   |   |   [5] island in Biscoe, Torgersen: Adelie (n = 4, err = 25.0%)
#> |   |   |   [6] island in Dream: Chinstrap (n = 59, err = 1.7%)
#> |   [7] flipper_length_mm >= 206.5
#> |   |   [8] bill_depth_mm >= 17.65
#> |   |   |   [9] bill_length_mm < 46.55: Adelie (n = 2, err = 0.0%)
#> |   |   |   [10] bill_length_mm >= 46.55: Chinstrap (n = 5, err = 0.0%)
#> |   |   [11] bill_depth_mm < 17.65: Gentoo (n = 118, err = 0.0%)
#> 
#> Number of inner nodes:    5
#> Number of terminal nodes: 6
```
