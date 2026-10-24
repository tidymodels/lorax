# Changelog

## lorax (development version)

- [`num_ensemble_members()`](https://lorax.tidymodels.org/dev/reference/num_ensemble_members.md)
  is a new generic that returns the number of trees (or boosting trials
  or committees) in an ensemble model.

- [`active_predictors()`](https://lorax.tidymodels.org/dev/reference/active_predictors.md),
  [`as.party()`](https://rdrr.io/pkg/partykit/man/party-coercion.html),
  [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md),
  and [`var_imp()`](https://generics.r-lib.org/reference/var_imp.html)
  now have methods for catboost models (`catboost.Model`). Symmetric and
  non-symmetric trees are supported. Categorical splits, both one-hot
  and those based on target statistics (CTRs), are converted to sets of
  factor levels, including CTRs on combinations of features.

- [`as.party()`](https://rdrr.io/pkg/partykit/man/party-coercion.html)
  and
  [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md)
  now support lightgbm models with categorical predictors. Category
  codes are mapped to factor levels using the training data, assuming
  the codes are `as.integer(factor) - 1L`.
  [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md)
  for lightgbm models gains an optional `data` argument for this;
  without it, rules use the integer codes.

- [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md)
  for lightgbm models now assigns left and right child nodes correctly
  and compares numeric thresholds as numbers rather than strings.

- [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md)
  methods gain an `add_statistics` argument that appends the columns
  `num_rule_terms` and `num_rule_predictors`.

- [`active_predictors()`](https://lorax.tidymodels.org/dev/reference/active_predictors.md),
  [`as.party()`](https://rdrr.io/pkg/partykit/man/party-coercion.html),
  [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md),
  and
  [`num_ensemble_members()`](https://lorax.tidymodels.org/dev/reference/num_ensemble_members.md)
  now have methods for bagged trees from the baguette package (`bagger`,
  from
  [`parsnip::bag_tree()`](https://parsnip.tidymodels.org/reference/bag_tree.html)
  with the “rpart” or “C5.0” engine). The `tree` argument selects
  ensemble members, and
  [`as.party()`](https://rdrr.io/pkg/partykit/man/party-coercion.html)
  needs the training data because the bootstrap samples are not saved.

- [`extract_rules()`](https://lorax.tidymodels.org/dev/reference/extract_rules.md)
  for rpart models now uses the `xlevels` attribute to label categorical
  splits with factor levels, so it works for models that no longer have
  access to their training data.

- [`rect_split_to_expr()`](https://lorax.tidymodels.org/dev/reference/rect_split_to_expr.md)
  now accepts numeric vectors for the `%in%` operator.

## lorax 0.1.0

CRAN release: 2026-07-16

- Initial version.
