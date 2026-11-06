# Convert catboost model to party object

Convert a single tree from a catboost boosted tree model to a party
object for use with partykit visualization and analysis tools.

## Usage

``` r
# S3 method for class 'catboost.Model'
as.party(obj, tree = 1L, data, ...)
```

## Arguments

- obj:

  A `catboost.Model` object from the catboost package.

- tree:

  Integer specifying which tree to convert (1-based indexing, default is
  1).

- data:

  data.frame containing the training data **with the response variable
  included** (required). catboost models do not store the original
  training data or response values. The first column that is not a
  predictor is used as the response.

- ...:

  Not currently used.

## Value

A `constparty` object from the partykit package.

## Details

The tree structure is obtained by saving the model in JSON format via
`catboost.save_model()` from catboost. Symmetric (oblivious) trees are
expanded into a binary tree and branches that cannot be reached are
removed.

Numeric splits send observations with `feature <= border` to the left
child. One-hot categorical splits send the matching level to the right
child.

Categorical splits based on target statistics (CTRs) are converted to
factor splits using the approach described in
[`extract_rules.catboost.Model()`](https://lorax.tidymodels.org/dev/reference/extract_rules.catboost.Model.md).
When a CTR uses a combination of features, a factor with one level per
combination is added to the data (named, for example, `g:h`) and the
split uses that factor.

If the model was trained without feature names, predictors are matched
to the columns of `data` by position.

### Examples

These examples require the catboost package, which is not on CRAN. See
the [catboost installation
instructions](https://catboost.ai/docs/en/concepts/r-installation) for
details.

Fit a small model:

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

Extract the rules for the first tree:

    rules <- extract_rules(fit, tree = 1L)
    rules

    #> # A tibble: 3 x 3
    #>    tree rules         id
    #>   <int> <list>     <int>
    #> 1     1 <language>     1
    #> 2     1 <language>     2
    #> 3     1 <language>     4

    rule_text(rules$rules[[1]])

    #> [1] "cyl <= 5"

Convert the first tree to a party object. The response is the first
column that is not a predictor:

    party_tree <- as.party(fit, tree = 1L, data = mtcars)
    party_tree

    #>
    #> Model formula:
    #> ~cyl + disp + hp + drat + wt + qsec + vs + am + gear + carb
    #>
    #> Fitted party:
    #> [1] root
    #> |   [2] cyl < 5: 26.664 (n = 11, err = 203.4)
    #> |   [3] cyl >= 5
    #> |   |   [4] cyl < 7: 19.743 (n = 7, err = 12.7)
    #> |   |   [5] cyl >= 7: 15.100 (n = 14, err = 85.2)
    #>
    #> Number of inner nodes:    2
    #> Number of terminal nodes: 3
