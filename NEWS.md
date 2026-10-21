# lorax 0.1.0

* Initial version.

* `active_predictors()`, `as.party()`, `extract_rules()`, and `var_imp()` now have methods for catboost models (`catboost.Model`). Symmetric and non-symmetric trees are supported, as are one-hot encoded categorical splits; splits based on categorical target statistics (CTRs) cannot be converted to rules.
