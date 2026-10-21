# Changelog

## lorax (development version)

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

- [`rect_split_to_expr()`](https://lorax.tidymodels.org/dev/reference/rect_split_to_expr.md)
  now accepts numeric vectors for the `%in%` operator.

## lorax 0.1.0

CRAN release: 2026-07-16

- Initial version.
