# lorax (development version)

* `as.party()` and `extract_rules()` now support lightgbm models with categorical predictors. Category codes are mapped to factor levels using the training data, assuming the codes are `as.integer(factor) - 1L`. `extract_rules()` for lightgbm models gains an optional `data` argument for this; without it, rules use the integer codes.

* `extract_rules()` for lightgbm models now assigns left and right child nodes correctly and compares numeric thresholds as numbers rather than strings.

* `extract_rules()` methods gain an `add_statistics` argument that appends the columns `num_term_nodes`, `num_rule_terms`, and `num_rule_predictors`.

* `rect_split_to_expr()` now accepts numeric vectors for the `%in%` operator.

# lorax 0.1.0

* Initial version.
