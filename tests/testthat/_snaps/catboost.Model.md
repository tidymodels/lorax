# extract_rules.catboost.Model() errors informatively

    Code
      extract_rules(fit, tree = 0L)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 3, not 0.
    Code
      extract_rules(fit, tree = 10L)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 3, not 10.
    Code
      extract_rules(fit, tree = 1.5)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be a single integer, not a number.

---

    Code
      extract_rules(one_hot, tree = 1L)
    Condition
      Error in `extract_rules()`:
      ! `data` must be a data frame when the tree contains categorical splits.

---

    Code
      extract_rules(ctr, tree = 1L)
    Condition
      Error in `extract_rules()`:
      ! `data` must be a data frame when the tree contains categorical splits.

---

    Code
      extract_rules(ctr, tree = 1L, data = dat["g"])
    Condition
      Error in `extract_rules()`:
      ! `data` must contain features: x.

# as.party.catboost.Model() requires response in data

    Code
      as.party(fit, tree = 1L, data = x)
    Condition
      Error in `as.party()`:
      ! `data` must contain the response variable in addition to predictors.
    Code
      as.party(fit, tree = 1L)
    Condition
      Error in `as.party()`:
      ! `data` must be a data frame containing the predictors and response.
    Code
      as.party(fit, tree = 1L, data = mtcars[, 1:3])
    Condition
      Error in `as.party()`:
      ! `data` must contain features: hp, drat, wt, qsec, vs, am, gear, and carb.

# active_predictors.catboost.Model() validates tree argument

    Code
      active_predictors(fit, tree = 0:1)
    Condition
      Error in `active_predictors()`:
      ! `tree` values must be between 1 and 3, not 0 and 1.
    Code
      active_predictors(fit, tree = "a")
    Condition
      Error in `active_predictors()`:
      ! `tree` must be an integer vector, not a string.

