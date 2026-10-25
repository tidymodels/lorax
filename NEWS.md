# lorax (development version)

* `num_ensemble_members()` is a new generic that returns the number of trees (or boosting trials or committees) in an ensemble model.

* `active_predictors()`, `as.party()`, `extract_rules()`, and `var_imp()` now have methods for catboost models (`catboost.Model`). Symmetric and non-symmetric trees are supported. Categorical splits, both one-hot and those based on target statistics (CTRs), are converted to sets of factor levels, including CTRs on combinations of features.

* `as.party()` and `extract_rules()` now support lightgbm models with categorical predictors. Category codes are mapped to factor levels using the training data, assuming the codes are `as.integer(factor) - 1L`. `extract_rules()` for lightgbm models gains an optional `data` argument for this; without it, rules use the integer codes.

* `extract_rules()` for lightgbm models now assigns left and right child nodes correctly and compares numeric thresholds as numbers rather than strings.

* `extract_rules()` methods now error when given an argument they don't use, such as a misspelled `trees = 2`, instead of silently ignoring it. This includes `data` for C5.0 models, which was accepted but never used.

* `extract_rules()` for aorsf (`ObliqueForest`), BART (`bart`), catboost, lightgbm, and xgboost models now accepts a vector of tree numbers, as the other ensemble methods do, and reads the model once instead of once per tree. Rules for each tree are also built in a single pass, which makes these methods and `extract_rules()` for rpart and grf models much faster.

* `extract_rules()` is much faster for ranger, randomForest, C5.0, grf, cforest, and partykit models. Rules are now collected in a single pass over the tree instead of searching for each node's parent, and the ranger and randomForest methods no longer compute fitted node ids for the training data.

* `extract_rules()` methods gain an `add_statistics` argument that appends the columns `num_rule_terms` and `num_rule_predictors`.

* `active_predictors()`, `as.party()`, `extract_rules()`, and `num_ensemble_members()` now have methods for bagged trees from the baguette package (`bagger`, from `parsnip::bag_tree()` with the "rpart" or "C5.0" engine). The `tree` argument selects ensemble members, and `as.party()` needs the training data because the bootstrap samples are not saved.

* `extract_rules()` for rpart models now uses the `xlevels` attribute to label categorical splits with factor levels, so it works for models that no longer have access to their training data.

* `rect_split_to_expr()` now accepts numeric vectors for the `%in%` operator.

# lorax 0.1.0

* Initial version.
