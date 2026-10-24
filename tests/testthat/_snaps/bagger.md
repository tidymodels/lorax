# extract_rules.bagger() works with bagged CART

    Code
      res$rules
    Output
      [[1]]
      bill_length_mm < 42.35 & bill_depth_mm >= 14.6
      
      [[2]]
      bill_length_mm < 42.35 & bill_depth_mm < 14.6
      
      [[3]]
      bill_length_mm >= 42.35 & island %in% c("Dream", "Torgersen") & 
          island == "Torgersen"
      
      [[4]]
      bill_length_mm >= 42.35 & island %in% c("Dream", "Torgersen") & 
          island == "Dream"
      
      [[5]]
      bill_length_mm >= 42.35 & island == "Biscoe" & bill_depth_mm >= 
          18.15
      
      [[6]]
      bill_length_mm >= 42.35 & island == "Biscoe" & bill_depth_mm < 
          18.15
      
      [[7]]
      bill_length_mm < 42.35 & bill_depth_mm >= 15.1
      
      [[8]]
      bill_length_mm < 42.35 & bill_depth_mm < 15.1
      
      [[9]]
      bill_length_mm >= 42.35 & island %in% c("Dream", "Torgersen") & 
          island == "Torgersen"
      
      [[10]]
      bill_length_mm >= 42.35 & island %in% c("Dream", "Torgersen") & 
          island == "Dream"
      
      [[11]]
      bill_length_mm >= 42.35 & island == "Biscoe" & bill_depth_mm >= 
          17.8
      
      [[12]]
      bill_length_mm >= 42.35 & island == "Biscoe" & bill_depth_mm < 
          17.8
      

# extract_rules.bagger() works with bagged C5.0

    Code
      res$rules[res$tree == 3]
    Output
      [[1]]
      is.na(bill_depth_mm)
      
      [[2]]
      bill_depth_mm <= 16.4 & island == "Biscoe"
      
      [[3]]
      bill_depth_mm <= 16.4 & island == "Biscoe"
      
      [[4]]
      bill_depth_mm <= 16.4 & island == "Biscoe"
      
      [[5]]
      bill_depth_mm > 16.4 & is.na(bill_length_mm)
      
      [[6]]
      bill_depth_mm > 16.4 & bill_length_mm <= 44.5 & is.na(bill_depth_mm)
      
      [[7]]
      bill_depth_mm > 16.4 & bill_length_mm <= 44.5 & bill_depth_mm <= 
          16.700001 & is.na(bill_length_mm)
      
      [[8]]
      bill_depth_mm > 16.4 & bill_length_mm <= 44.5 & bill_depth_mm <= 
          16.700001 & bill_length_mm <= 40.200001
      
      [[9]]
      bill_depth_mm > 16.4 & bill_length_mm <= 44.5 & bill_depth_mm <= 
          16.700001 & bill_length_mm > 40.200001
      
      [[10]]
      bill_depth_mm > 16.4 & bill_length_mm <= 44.5 & bill_depth_mm > 
          16.700001
      
      [[11]]
      bill_depth_mm > 16.4 & bill_length_mm > 44.5 & island == "Biscoe" & 
          is.na(bill_depth_mm)
      
      [[12]]
      bill_depth_mm > 16.4 & bill_length_mm > 44.5 & island == "Biscoe" & 
          bill_depth_mm <= 18.799999
      
      [[13]]
      bill_depth_mm > 16.4 & bill_length_mm > 44.5 & island == "Biscoe" & 
          bill_depth_mm > 18.799999
      
      [[14]]
      bill_depth_mm > 16.4 & bill_length_mm > 44.5 & island == "Biscoe"
      

# extract_rules.bagger() validates tree

    Code
      extract_rules(fit, tree = 4L)
    Condition
      Error in `extract_rules()`:
      ! `tree` values must be between 1 and 3.

---

    Code
      extract_rules(fit, tree = "a")
    Condition
      Error in `extract_rules()`:
      ! `tree` must be an integer vector, not a string.

# active_predictors.bagger() validates tree

    Code
      active_predictors(fit, tree = 0L)
    Condition
      Error in `active_predictors()`:
      ! `tree` values must be between 1 and 3.

# bagger methods reject unsupported base models

    Code
      num_ensemble_members(fit)
    Condition
      Error in `num_ensemble_members()`:
      ! Only bagged "CART" and "C5.0" trees are supported, not "MARS".

# as.party.bagger() validates its arguments

    Code
      as.party(fit, tree = 1L)
    Condition
      Error in `as.party()`:
      ! `data` is required for `as.party.bagger()`.

---

    Code
      as.party(fit, tree = 4L, data = data)
    Condition
      Error in `as.party()`:
      ! `tree` values must be between 1 and 3.

---

    Code
      as.party(fit, tree = 1:2, data = data)
    Condition
      Error in `as.party()`:
      ! `tree` must be a single integer, not an integer vector.

---

    Code
      as.party(fit, data = data[-2])
    Condition
      Error in `as.party()`:
      ! `data` is missing column "island".

