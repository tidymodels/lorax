skip_if_not_installed("catboost")

# ------------------------------------------------------------------------------
# extract_rules()

test_that("extract_rules.catboost.Model() returns correct structure", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  rules <- extract_rules(fit, tree = 2L)

  expect_s3_class(rules, c("rule_set_catboost.Model", "rule_set"))
  expect_named(rules, c("tree", "rules", "id"))
  expect_all_equal(rules$tree, 2L)
  expect_type(rules$id, "integer")
})

test_that("extract_rules.catboost.Model() matches catboost leaf assignments", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  for (i in 1:3) {
    rules <- extract_rules(fit, tree = i)
    memb <- rule_membership(rules, x)
    expect_all_equal(rowSums(memb), 1)
    expect_equal(
      rules$id[max.col(memb)],
      oblivious_leaf_ids(fit, i, x)
    )
  }
})

test_that("extract_rules.catboost.Model() drops unreachable leaves", {
  x <- mtcars[, "cyl", drop = FALSE]
  fit <- fit_catboost(x, mtcars$mpg, depth = 2)

  rules <- extract_rules(fit, tree = 1L)
  memb <- rule_membership(rules, x)

  expect_lt(nrow(rules), 4L)
  expect_all_true(colSums(memb) > 0)
})

test_that("extract_rules.catboost.Model() works with non-symmetric trees", {
  x <- mtcars[, -1]
  depthwise <- fit_catboost(x, mtcars$mpg, grow_policy = "Depthwise")
  lossguide <- fit_catboost(x, mtcars$mpg, grow_policy = "Lossguide")

  for (fit in list(depthwise, lossguide)) {
    rules <- extract_rules(fit, tree = 1L)
    memb <- rule_membership(rules, x)
    expect_all_equal(rowSums(memb), 1)
    expect_equal(anyDuplicated(rules$id), 0L)
  }
})

test_that("extract_rules.catboost.Model() works with multiclass models", {
  penguins <- get_penguins_data()
  x <- as.data.frame(penguins[, -1])
  fit <- fit_catboost(
    x,
    as.integer(penguins$species) - 1,
    loss_function = "MultiClass"
  )

  rules <- extract_rules(fit, tree = 3L)
  memb <- rule_membership(rules, x)
  expect_all_equal(rowSums(memb), 1)
})

test_that("extract_rules.catboost.Model() handles unnamed features", {
  x <- as.matrix(mtcars[, -1])
  colnames(x) <- NULL
  fit <- fit_catboost(x, mtcars$mpg)

  rules <- extract_rules(fit, tree = 1L)
  vars <- all.vars(rules$rules[[1]])
  expect_all_true(grepl("^X[0-9]+$", vars))
})

test_that("extract_rules.catboost.Model() decodes one-hot splits", {
  dat <- get_catboost_factor_data()
  x <- dat[, c("x", "g")]
  fit <- fit_catboost(x, dat$y, one_hot_max_size = 10)

  rules <- extract_rules(fit, tree = 1L, data = x)
  memb <- rule_membership(rules, x)
  expect_all_equal(rowSums(memb), 1)

  text <- vapply(rules$rules, rule_text, character(1))
  expect_match(text, "g ==", fixed = TRUE, all = FALSE)

  depthwise <- fit_catboost(
    x,
    dat$y,
    one_hot_max_size = 10,
    grow_policy = "Depthwise"
  )
  rules <- extract_rules(depthwise, tree = 1L, data = x)
  memb <- rule_membership(rules, x)
  expect_all_equal(rowSums(memb), 1)
})

test_that("extract_rules.catboost.Model() errors informatively", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  expect_snapshot(error = TRUE, {
    extract_rules(fit, tree = 0L)
    extract_rules(fit, tree = 10L)
    extract_rules(fit, tree = 1.5)
  })

  dat <- get_catboost_factor_data()
  one_hot <- fit_catboost(dat[, c("x", "g")], dat$y, one_hot_max_size = 10)
  expect_snapshot(extract_rules(one_hot, tree = 1L), error = TRUE)

  ctr <- fit_catboost(dat[, c("x", "g")], dat$y)
  expect_snapshot(extract_rules(ctr, tree = 1L), error = TRUE)
  expect_snapshot(extract_rules(ctr, tree = 1L, data = dat["g"]), error = TRUE)
})

test_that("extract_rules.catboost.Model() converts CTR splits to level sets", {
  dat <- get_catboost_ctr_data()
  x <- dat[, c("x", "g", "h")]
  symmetric <- fit_catboost(x, dat$y, iterations = 10)
  depthwise <- fit_catboost(
    x,
    dat$y,
    iterations = 10,
    grow_policy = "Depthwise"
  )

  for (fit in list(symmetric, depthwise)) {
    expect_all_true(catboost_rules_match(fit, x))
  }

  rules <- purrr::map(1:10, \(i) extract_rules(symmetric, tree = i, data = x))
  text <- vapply(dplyr::bind_rows(rules)$rules, rule_text, character(1))
  expect_match(text, "g %in%", fixed = TRUE, all = FALSE)
})

test_that("extract_rules.catboost.Model() converts CTR feature combinations", {
  dat <- get_catboost_ctr_data()
  x <- dat[, c("x", "g", "h")]
  fit <- fit_catboost(
    x,
    dat$y,
    iterations = 100,
    depth = 6,
    max_ctr_complexity = 4
  )

  combos <- catboost_ctr_trees(fit, x)
  expect_gt(length(combos$categorical), 0)
  expect_gt(length(combos$numeric), 0)

  trees <- unique(c(combos$categorical[1:2], combos$numeric[1:2]))
  expect_all_true(catboost_rules_match(fit, x, trees = trees))
})

test_that("extract_rules.catboost.Model() handles new levels in CTR splits", {
  dat <- get_catboost_ctr_data()
  x <- dat[, c("x", "g", "h")]
  fit <- fit_catboost(x, dat$y, iterations = 10, max_ctr_complexity = 4)

  new_x <- x[1:20, ]
  new_x$g <- factor(rep(c("a", "new"), 10))
  new_x$h <- factor(rep(c("unknown", "B"), each = 10))

  expect_all_true(catboost_rules_match(fit, new_x, data = x))
})

# ------------------------------------------------------------------------------
# as.party()

test_that("as.party.catboost.Model() returns valid party object", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  p <- as.party(fit, tree = 1L, data = mtcars)

  expect_s3_class(p, "constparty")
  expect_s3_class(p$node, "partynode")
  expect_named(p$fitted, c("(fitted)", "(response)"))
  expect_equal(p$fitted[["(response)"]], mtcars$mpg)

  rules <- extract_rules(fit, tree = 1L)
  memb <- rule_membership(rules, x)
  expect_equal(
    sort(unname(as.vector(table(p$fitted[["(fitted)"]])))),
    sort(unname(colSums(memb)[colSums(memb) > 0]))
  )
})

test_that("as.party.catboost.Model() works with one-hot splits", {
  dat <- get_catboost_factor_data()
  x <- dat[, c("x", "g")]
  fit <- fit_catboost(x, dat$y, one_hot_max_size = 10)

  p <- as.party(fit, tree = 1L, data = dat)
  expect_s3_class(p, "constparty")

  rules <- extract_rules(fit, tree = 1L, data = x)
  memb <- rule_membership(rules, x)
  expect_equal(
    sort(unname(as.vector(table(p$fitted[["(fitted)"]])))),
    sort(unname(colSums(memb)[colSums(memb) > 0]))
  )
})

test_that("as.party.catboost.Model() works with CTR splits", {
  dat <- get_catboost_ctr_data()
  x <- dat[, c("x", "g", "h")]
  fit <- fit_catboost(
    x,
    dat$y,
    iterations = 100,
    depth = 6,
    max_ctr_complexity = 4
  )
  combos <- catboost_ctr_trees(fit, x)

  for (tree in c(1L, combos$categorical[1], combos$numeric[1])) {
    p <- as.party(fit, tree = tree, data = dat)
    expect_s3_class(p, "constparty")

    rules <- extract_rules(fit, tree = tree, data = x)
    rule_id <- max.col(rule_membership(rules, x))
    node_id <- p$fitted[["(fitted)"]]
    expect_all_equal(
      as.vector(tapply(rule_id, node_id, function(i) length(unique(i)))),
      1L
    )
  }

  p <- as.party(fit, tree = combos$categorical[1], data = dat)
  expect_contains(names(p$data), "g:h")
})

test_that("as.party.catboost.Model() works with unnamed features", {
  x <- as.matrix(mtcars[, -1])
  colnames(x) <- NULL
  fit <- fit_catboost(x, mtcars$mpg)

  p <- as.party(fit, tree = 1L, data = mtcars[, c(2:11, 1)])
  expect_s3_class(p, "constparty")
  expect_equal(p$fitted[["(response)"]], mtcars$mpg)
})

test_that("as.party.catboost.Model() requires response in data", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  expect_snapshot(error = TRUE, {
    as.party(fit, tree = 1L, data = x)
    as.party(fit, tree = 1L)
    as.party(fit, tree = 1L, data = mtcars[, 1:3])
  })
})

# ------------------------------------------------------------------------------
# var_imp()

test_that("var_imp.catboost.Model() returns importance scores", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg, depth = 2)

  imp <- var_imp(fit)
  expect_s3_class(imp, "tbl_df")
  expect_named(imp, c("term", "estimate"))
  expect_equal(imp$term, names(x))

  native <- catboost::catboost.get_feature_importance(fit)
  expect_equal(imp$estimate, unname(native[, 1]))

  used <- var_imp(fit, complete = FALSE)
  expect_all_true(used$estimate != 0)
  expect_lt(nrow(used), nrow(imp))
})

test_that("var_imp.catboost.Model() handles unnamed features", {
  x <- as.matrix(mtcars[, -1])
  colnames(x) <- NULL
  fit <- fit_catboost(x, mtcars$mpg)

  imp <- var_imp(fit)
  expect_equal(imp$term, paste0("X", 1:10))
})

# ------------------------------------------------------------------------------
# active_predictors()

test_that("active_predictors.catboost.Model() extracts from trees", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  res <- active_predictors(fit, tree = 1:3)
  expect_named(res, c("active_predictors", "tree"))
  expect_equal(res$tree, 1:3)

  rules <- extract_rules(fit, tree = 2L)
  rule_vars <- unique(unlist(lapply(rules$rules, all.vars)))
  expect_setequal(res$active_predictors[[2]], rule_vars)
})

test_that("active_predictors.catboost.Model() includes categorical features", {
  dat <- get_catboost_factor_data()
  x <- dat[, c("x", "g")]

  one_hot <- fit_catboost(x, dat$y, one_hot_max_size = 10)
  ctr <- fit_catboost(x, dat$y)

  for (fit in list(one_hot, ctr)) {
    res <- active_predictors(fit, tree = 1:3)
    expect_contains(unlist(res$active_predictors), "g")
  }
})

test_that("active_predictors.catboost.Model() validates tree argument", {
  x <- mtcars[, -1]
  fit <- fit_catboost(x, mtcars$mpg)

  expect_snapshot(error = TRUE, {
    active_predictors(fit, tree = 0:1)
    active_predictors(fit, tree = "a")
  })
})

# ------------------------------------------------------------------------------
# helpers

test_that("cb_hash_strings() matches hashes stored in the model", {
  dat <- get_catboost_factor_data()
  fit <- fit_catboost(dat[, c("x", "g")], dat$y, one_hot_max_size = 10)

  json <- cb_model_json(fit)
  stored <- unlist(json$features_info$categorical_features[[1]]$values)
  expect_all_true(stored %in% cb_hash_strings(levels(dat$g)))
})

test_that("num_ensemble_members() counts catboost trees", {
  fit <- fit_catboost(mtcars[, -1], mtcars$mpg, iterations = 4)

  expect_identical(num_ensemble_members(fit), 4L)
})
