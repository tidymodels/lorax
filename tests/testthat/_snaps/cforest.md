# extract_rules.cforest() validates tree argument

    Code
      extract_rules(cf, tree = "1")
    Condition
      Error in `extract_rules()`:
      ! `tree` must be an integer vector, not a string.

---

    Code
      extract_rules(cf, tree = 1.5)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be an integer vector, not a number.

---

    Code
      extract_rules(cf, tree = 0L)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 3, the number of trees in the model.
      x Out of range: 0.

---

    Code
      extract_rules(cf, tree = 10L)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 3, the number of trees in the model.
      x Out of range: 10.

# active_predictors.cforest() validates tree argument

    Code
      active_predictors(cf, tree = "1")
    Condition
      Error in `active_predictors()`:
      ! `tree` must be an integer vector, not a string.

---

    Code
      active_predictors(cf, tree = 1.5)
    Condition
      Error in `active_predictors()`:
      ! `tree` must be an integer vector, not a number.

---

    Code
      active_predictors(cf, tree = 0L)
    Condition
      Error in `active_predictors()`:
      ! `tree` must be between 1 and 3, the number of trees in the model.
      x Out of range: 0.

---

    Code
      active_predictors(cf, tree = 10L)
    Condition
      Error in `active_predictors()`:
      ! `tree` must be between 1 and 3, the number of trees in the model.
      x Out of range: 10.

