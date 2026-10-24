# extract_rules.xgb.Booster validates tree parameter

    Code
      extract_rules(bst, tree = 0)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 2, the number of trees in the model.
      x Out of range: 0.

---

    Code
      extract_rules(bst, tree = "1")
    Condition
      Error in `extract_rules()`:
      ! `tree` must be an integer vector, not a string.

---

    Code
      extract_rules(bst, tree = 100)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 2, the number of trees in the model.
      x Out of range: 100.

# extract_rules.lgb.Booster validates tree parameter

    Code
      extract_rules(bst, tree = 0)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 2, the number of trees in the model.
      x Out of range: 0.

---

    Code
      extract_rules(bst, tree = "1")
    Condition
      Error in `extract_rules()`:
      ! `tree` must be an integer vector, not a string.

---

    Code
      extract_rules(bst, tree = 100)
    Condition
      Error in `extract_rules()`:
      ! `tree` must be between 1 and 2, the number of trees in the model.
      x Out of range: 100.

