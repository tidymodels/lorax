# Fit a small, silent catboost model
fit_catboost <- function(x, y, ...) {
  skip_if_not_installed("catboost")
  skip_if_not_installed("jsonlite")
  pool <- catboost::catboost.load_pool(x, label = y)
  params <- list(
    iterations = 3,
    depth = 3,
    thread_count = 1,
    random_seed = 7391,
    logging_level = "Silent",
    allow_writing_files = FALSE
  )
  catboost::catboost.train(pool, params = utils::modifyList(params, list(...)))
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

# Data where categorical predictors interact for catboost CTR splits
get_catboost_ctr_data <- function() {
  set.seed(4127)
  n <- 400
  dat <- data.frame(
    x = rnorm(n),
    g = factor(sample(letters[1:6], n, replace = TRUE)),
    h = factor(sample(LETTERS[1:4], n, replace = TRUE))
  )
  dat$y <- dat$x +
    (dat$g %in% c("b", "c")) * 3 +
    (dat$h == "A") * (dat$g == "a") * 4 +
    (dat$g == "d") * (dat$x > 0) * 3
  dat
}

# Per-tree contributions to the raw predictions (one matrix per tree)
catboost_tree_contributions <- function(model, x) {
  pool <- catboost::catboost.load_pool(x)
  n_trees <- cb_num_trees(cb_model_json(model))
  res <- vector("list", n_trees)
  prev <- 0
  for (i in seq_len(n_trees)) {
    pred <- catboost::catboost.predict(
      model,
      pool,
      prediction_type = "RawFormulaVal",
      ntree_end = i
    )
    pred <- as.matrix(pred)
    res[[i]] <- pred - prev
    prev <- pred
  }
  res
}

# For each tree, do the rules partition `x` with one catboost leaf value per
# rule? `data` is the training data used to decode the levels.
catboost_rules_match <- function(model, x, trees = NULL, data = x) {
  contrib <- catboost_tree_contributions(model, x)
  if (is.null(trees)) {
    trees <- seq_along(contrib)
  }
  vapply(
    trees,
    function(tree) {
      rules <- extract_rules(model, tree = tree, data = data)
      memb <- vapply(
        rules$rules,
        function(e) rep_len(eval(e, x), nrow(x)),
        logical(nrow(x))
      )
      memb <- matrix(memb, nrow = nrow(x))
      if (any(rowSums(memb) != 1)) {
        return(FALSE)
      }
      leaf <- max.col(memb)
      spread <- apply(contrib[[tree]], 2, function(v) {
        max(tapply(v, leaf, function(z) diff(range(z))))
      })
      all(spread < 1e-8)
    },
    logical(1)
  )
}

# Trees with CTR splits on combinations of categorical predictors and on
# combinations that include a numeric predictor
catboost_ctr_trees <- function(model, data) {
  json <- cb_model_json(model)
  features <- cb_feature_info(json)
  pred_data <- cb_predictor_data(data, features)
  kinds <- lapply(seq_len(cb_num_trees(json)), function(tree) {
    ctrs <- cb_decode_ctrs(json, tree, features, pred_data)
    unlist(lapply(ctrs, function(ctr) {
      axis_kinds <- vapply(ctr$axes, function(a) a$kind, character(1))
      if (length(axis_kinds) < 2) {
        return(NULL)
      }
      if (any(axis_kinds == "float")) {
        return("numeric")
      }
      "categorical"
    }))
  })
  list(
    categorical = which(vapply(
      kinds,
      function(k) "categorical" %in% k,
      logical(1)
    )),
    numeric = which(vapply(kinds, function(k) "numeric" %in% k, logical(1)))
  )
}
