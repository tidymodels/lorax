# Convert xgb.Booster model to party object

Convert a single tree from an xgboost boosted tree model to a party
object for use with partykit visualization and analysis tools.

## Usage

``` r
# S3 method for class 'xgb.Booster'
as.party(obj, tree = 1L, data, ...)
```

## Arguments

- obj:

  An `xgb.Booster` object from the xgboost package.

- tree:

  Integer specifying which tree to convert (1-based indexing, default is
  1). For multiclass models with `num_class` classes and `nrounds`
  boosting rounds, there are `num_class * nrounds` total trees.

- data:

  data.frame containing the training data **with the response variable
  included** (required). XGBoost models do not store the original
  training data or response values. You must provide the original data
  frame that includes both the predictor variables and the response
  variable.

- ...:

  Not currently used.

## Value

A `constparty` object from the partykit package.

## Details

### Important note on data

XGBoost models do not store the original training data or response
values. You **must** provide the original data frame (including the
response variable) via the `data` parameter for correct terminal node
statistics, bar charts, and other visualizations.

### XGBoost tree storage format

xgboost stores trees in a tabular format accessible via
[`xgboost::xgb.model.dt.tree()`](https://rdrr.io/pkg/xgboost/man/xgb.model.dt.tree.html).
Each tree is represented as rows in a table:

- `Tree`: 0-based tree index (e.g., 0, 1, 2, ...)

- `Node`: 0-based node ID within tree (e.g., "0-0", "0-1" for tree 0)

- `Feature`: Feature name (character) or "Leaf" for terminal nodes

- `Split`: Numeric threshold for splits (NA for leaves)

- `Yes`: 0-based node ID of yes branch (feature \< threshold)

- `No`: 0-based node ID of no branch (feature \>= threshold)

- `Missing`: 0-based node ID for missing values

- `Quality`: Prediction value for leaf nodes, gain for internal nodes

### Node indexing

- Internally, xgboost uses 0-based tree and node indices

- User-facing `tree` parameter uses 1-based indexing (R convention)

- When `tree=1` is requested, we filter to `Tree==0` internally

### Split encoding

- Yes branch: feature \< threshold (left child)

- No branch: feature \>= threshold (right child)

- partykit split created with `right = TRUE` (right interval closed)

### Child node references

- `Yes` column: node ID for left child (\< condition)

- `No` column: node ID for right child (\>= condition)

- Leaf nodes have `Feature == "Leaf"`

### Variable names

- `Feature` column contains actual feature names (not indices)

- Must map to column positions in data.frame

- If numeric indices used (`f0`, `f1`, ...), map to data columns

The party object will use 1-based node IDs and variable indices as
required by partykit.

## Examples

``` r
if (rlang::is_installed("xgboost")) {
  data(agaricus.train, package = "xgboost")

  # Binary classification example
  train_data <- as.data.frame(as.matrix(agaricus.train$data))
  train_data$label <- agaricus.train$label

  dtrain <- xgboost::xgb.DMatrix(agaricus.train$data, label = agaricus.train$label)

  set.seed(3691)
  bst <- xgboost::xgb.train(
    data = dtrain,
    max_depth = 3,
    nrounds = 3,
    objective = "binary:logistic",
    verbose = 0
  )

  # Convert first tree - data parameter is required
  party_tree <- as.party(bst, tree = 1L, data = train_data)
  print(party_tree)
  plot(party_tree)

  # Regression example
  data(mtcars)
  reg_data <- mtcars
  dtrain_reg <- xgboost::xgb.DMatrix(as.matrix(mtcars[, -1]), label = mtcars$mpg)

  set.seed(9158)
  bst_reg <- xgboost::xgb.train(
    data = dtrain_reg,
    max_depth = 3,
    nrounds = 3,
    objective = "reg:squarederror",
    verbose = 0
  )

  party_tree_reg <- as.party(bst_reg, tree = 1L, data = reg_data)
  print(party_tree_reg)
}
#> Warning: Passed invalid function arguments: max_depth. These should be passed as a list to argument 'params'. Conversion from argument to 'params' entry will be done automatically, but this behavior will become an error in a future version.
#> Warning: Argument 'objective' is only for custom objectives. For built-in objectives, pass the objective under 'params'. This warning will become an error in a future version.
#> 
#> Model formula:
#> ~`odor=none` + `spore-print-color=green` + `stalk-root=club` + 
#>     `stalk-surface-below-ring=scaly` + `bruises?=bruises` + `stalk-root=rooted` + 
#>     `odor=foul`
#> 
#> Fitted party:
#> [1] root
#> |   [2] odor=none <= 2.00001
#> |   |   [3] spore-print-color=green <= 2.00001: 0.057 (n = 6513, err = 348.1)
#> |   |   [4] spore-print-color=green > 2.00001
#> |   |   |   [5] stalk-surface-below-ring=scaly <= 2.00001: NA (n = 0, err = NA)
#> |   |   |   [6] stalk-surface-below-ring=scaly > 2.00001: NA (n = 0, err = NA)
#> |   [7] odor=none > 2.00001
#> |   |   [8] stalk-root=club <= 2.00001
#> |   |   |   [9] bruises?=bruises <= 2.00001: NA (n = 0, err = NA)
#> |   |   |   [10] bruises?=bruises > 2.00001: NA (n = 0, err = NA)
#> |   |   [11] stalk-root=club > 2.00001
#> |   |   |   [12] stalk-root=rooted <= 2.00001: NA (n = 0, err = NA)
#> |   |   |   [13] stalk-root=rooted > 2.00001: NA (n = 0, err = NA)
#> 
#> Number of inner nodes:    6
#> Number of terminal nodes: 7

#> Warning: Passed invalid function arguments: max_depth. These should be passed as a list to argument 'params'. Conversion from argument to 'params' entry will be done automatically, but this behavior will become an error in a future version.
#> Warning: Argument 'objective' is only for custom objectives. For built-in objectives, pass the objective under 'params'. This warning will become an error in a future version.
#> 
#> Model formula:
#> ~cyl + wt + hp + disp
#> 
#> Fitted party:
#> [1] root
#> |   [2] cyl <= 6
#> |   |   [3] wt <= 2.32: 30.067 (n = 6, err = 44.6)
#> |   |   [4] wt > 2.32
#> |   |   |   [5] hp <= 97: 23.333 (n = 3, err = 1.7)
#> |   |   |   [6] hp > 97: 21.450 (n = 2, err = 0.0)
#> |   [7] cyl > 6
#> |   |   [8] cyl <= 8
#> |   |   |   [9] wt <= 3.435: 20.775 (n = 4, err = 1.6)
#> |   |   |   [10] wt > 3.435: 18.367 (n = 3, err = 1.1)
#> |   |   [11] cyl > 8
#> |   |   |   [12] hp <= 205: 16.786 (n = 7, err = 16.6)
#> |   |   |   [13] hp > 205: 13.414 (n = 7, err = 28.8)
#> 
#> Number of inner nodes:    6
#> Number of terminal nodes: 7
```
