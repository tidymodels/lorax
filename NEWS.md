# lorax (development version)

* `active_predictors()`, `as.party()`, `extract_rules()`, and `var_imp()` now have methods for catboost models (`catboost.Model`). Symmetric and non-symmetric trees are supported, as are one-hot encoded categorical splits; splits based on categorical target statistics (CTRs) cannot be converted to rules.

* `as.party()` and `extract_rules()` now support lightgbm models with categorical predictors. Category codes are mapped to factor levels using the training data, assuming the codes are `as.integer(factor) - 1L`. `extract_rules()` for lightgbm models gains an optional `data` argument for this; without it, rules use the integer codes.

* `extract_rules()` for lightgbm models now assigns left and right child nodes correctly and compares numeric thresholds as numbers rather than strings.

* `rect_split_to_expr()` now accepts numeric vectors for the `%in%` operator.

# lorax 0.1.0

* Initial version.
