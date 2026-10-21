# Fit a small, silent catboost model
fit_catboost <- function(x, y, ...) {
  skip_if_not_installed("catboost")
  skip_if_not_installed("jsonlite")
  pool <- catboost::catboost.load_pool(x, label = y)
  catboost::catboost.train(
    pool,
    params = list(
      iterations = 3,
      depth = 3,
      thread_count = 1,
      random_seed = 7391,
      logging_level = "Silent",
      allow_writing_files = FALSE,
      ...
    )
  )
}

# Data with a categorical predictor for catboost one-hot splits
get_catboost_factor_data <- function() {
  set.seed(6052)
  dat <- data.frame(
    x = rnorm(200),
    g = factor(sample(letters[1:5], 200, replace = TRUE))
  )
  dat$y <- dat$x + (dat$g %in% c("b", "c")) * 3
  dat
}

# Rows that satisfy each rule (one column per rule)
rule_membership <- function(rules, data) {
  vapply(rules$rules, function(e) eval(e, data), logical(nrow(data)))
}

# Leaf index from catboost's oblivious tree encoding (numeric splits only)
oblivious_leaf_ids <- function(model, tree, x) {
  json <- cb_model_json(model)
  features <- cb_feature_info(json)
  leaf <- numeric(nrow(x))
  splits <- json$oblivious_trees[[tree]]$splits
  for (i in seq_along(splits)) {
    col <- cb_float_name(splits[[i]]$float_feature_index, features)
    leaf <- leaf + (x[[col]] > splits[[i]]$border) * 2^(i - 1)
  }
  as.integer(leaf) + 1L
}
