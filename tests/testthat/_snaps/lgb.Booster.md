# as.party.lgb.Booster validates tree parameter

    Code
      as.party(bst, tree = 0, data = penguins)
    Condition
      Error in `as.party()`:
      ! `tree` must be >= 1, not 0.

---

    Code
      as.party(bst, tree = c(1, 2), data = penguins)
    Condition
      Error in `as.party()`:
      ! `tree` must be a single integer, not a double vector.

---

    Code
      as.party(bst, tree = "1", data = penguins)
    Condition
      Error in `as.party()`:
      ! `tree` must be a single integer, not a string.

---

    Code
      as.party(bst, tree = 100, data = penguins)
    Condition
      Error in `as.party()`:
      ! `tree` must be between 1 and 15, not 100.

# as.party.lgb.Booster requires response in data

    Code
      as.party(bst, tree = 1, data = penguins[, -1])
    Condition
      Error in `as.party()`:
      ! `data` must contain the response variable in addition to predictors.

# extract_rules.lgb.Booster() validates categorical data

    Code
      extract_rules(cat_fit$fit, tree = 1L, data = too_few)
    Condition
      Error in `extract_rules()`:
      ! Invalid category codes for f.
      x The model uses codes 3, 4, and 6.
      x The factor in `data` only has 3 levels.
      i Codes are assumed to be `as.integer(factor) - 1L`.

---

    Code
      extract_rules(cat_fit$fit, tree = 1L, data = as.matrix(cat_fit$codes))
    Condition
      Error in `extract_rules()`:
      ! `data` must be a data frame, not a double matrix.

# as.party.lgb.Booster() validates categorical data

    Code
      as.party(cat_fit$fit, tree = 1L, data = too_few)
    Condition
      Error in `as.party()`:
      ! Invalid category codes for f.
      x The model uses codes 3, 4, and 6.
      x The factor in `data` only has 3 levels.
      i Codes are assumed to be `as.integer(factor) - 1L`.

# active_predictors.lgb.Booster() validates tree argument

    Code
      active_predictors(bst, tree = "1")
    Condition
      Error:
      ! `tree` must be an integer vector, not a string.

---

    Code
      active_predictors(bst, tree = 1.5)
    Condition
      Error:
      ! `tree` must be an integer vector, not a number.

---

    Code
      active_predictors(bst, tree = 0L)
    Condition
      Error:
      ! `tree` values must be between 1 and 5, not 0.

---

    Code
      active_predictors(bst, tree = 999L)
    Condition
      Error:
      ! `tree` values must be between 1 and 5, not 999.

