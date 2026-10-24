skip_on_cran()

fit_bagger <- function(formula, data, engine, mode = "classification") {
  skip_if_not_installed("baguette")
  skip_if_not_installed("parsnip")
  engine_pkg <- ifelse(engine == "rpart", "rpart", "C50")
  skip_if_not_installed(engine_pkg)

  set.seed(528)
  parsnip::bag_tree(mode = mode, tree_depth = 3) |>
    parsnip::set_engine(engine, times = 3) |>
    parsnip::fit(formula, data = data) |>
    purrr::pluck("fit")
}

test_that("num_ensemble_members.bagger() returns the number of trees", {
  data <- get_factor_data()

  for (engine in c("rpart", "C5.0")) {
    fit <- fit_bagger(y ~ ., data, engine)
    expect_identical(num_ensemble_members(fit), 3L)
  }

  fit <- fit_bagger(mpg ~ ., get_mtcars_data(), "rpart", "regression")
  expect_identical(num_ensemble_members(fit), 3L)
})

test_that("extract_rules.bagger() works with bagged CART", {
  data <- get_factor_data()
  fit <- fit_bagger(y ~ ., data, "rpart")

  res <- extract_rules(fit, tree = 1:2)
  expect_s3_class(res, c("rule_set_rpart", "rule_set"))
  expect_named(res, c("id", "rules", "tree"))
  expect_setequal(res$tree, 1:2)
  expect_snapshot(res$rules)

  one <- extract_rules(fit, tree = 2L)
  expect_identical(one$rules, extract_rules(fit$model_df$model[[2]]$fit)$rules)
})

test_that("extract_rules.bagger() works with bagged C5.0", {
  data <- get_factor_data()
  fit <- fit_bagger(y ~ ., data, "C5.0")

  res <- extract_rules(fit, tree = 1:3)
  expect_s3_class(res, c("rule_set_C5.0", "rule_set"))
  expect_named(res, c("id", "rules", "tree"))
  expect_setequal(res$tree, 1:3)
  expect_snapshot(res$rules[res$tree == 3])
})

test_that("extract_rules.bagger() works with regression", {
  fit <- fit_bagger(mpg ~ ., get_mtcars_data(), "rpart", "regression")

  res <- extract_rules(fit, tree = 1:3)
  expect_s3_class(res, "rule_set")
  expect_setequal(res$tree, 1:3)
})

test_that("extract_rules.bagger() adds statistics", {
  fit <- fit_bagger(y ~ ., get_factor_data(), "rpart")

  res <- extract_rules(fit, add_statistics = TRUE)
  expect_named(
    res,
    c("id", "rules", "tree", "num_rule_terms", "num_rule_predictors")
  )
})

test_that("extract_rules.bagger() uses factor levels", {
  fit <- fit_bagger(y ~ ., get_single_factor_data(), "rpart")

  res <- extract_rules(fit, tree = 1:3)
  rule_text <- vapply(res$rules, rlang::expr_text, character(1))
  expect_false(any(grepl("c\\(\"?[0-9]", rule_text)))
})

test_that("extract_rules.bagger() validates tree", {
  fit <- fit_bagger(y ~ ., get_factor_data(), "rpart")

  expect_snapshot(extract_rules(fit, tree = 4L), error = TRUE)
  expect_snapshot(extract_rules(fit, tree = "a"), error = TRUE)
})

test_that("active_predictors.bagger() works", {
  data <- get_factor_data()

  for (engine in c("rpart", "C5.0")) {
    fit <- fit_bagger(y ~ ., data, engine)
    res <- active_predictors(fit, tree = 1:3)
    expect_named(res, c("active_predictors", "tree"))
    expect_identical(res$tree, 1:3)
    expect_all_true(
      unlist(res$active_predictors) %in% setdiff(names(data), "y")
    )
  }
})

test_that("active_predictors.bagger() validates tree", {
  fit <- fit_bagger(y ~ ., get_factor_data(), "C5.0")

  expect_snapshot(active_predictors(fit, tree = 0L), error = TRUE)
})

test_that("bagger methods reject unsupported base models", {
  fit <- fit_bagger(y ~ ., get_factor_data(), "rpart")
  fit$base_model <- c("MARS", "classification")

  expect_snapshot(num_ensemble_members(fit), error = TRUE)
})

test_that("as.party.bagger() works with bagged CART", {
  data <- get_factor_data()
  fit <- fit_bagger(y ~ ., data, "rpart")
  member <- fit$model_df$model[[2]]$fit

  res <- as.party(fit, tree = 2L, data = data)
  expect_s3_class(res, "constparty")
  expect_identical(nrow(res$data), nrow(data))
  expect_setequal(
    partykit::nodeids(res, terminal = TRUE),
    which(member$frame$var == "<leaf>")
  )
  expect_identical(
    as.character(predict(res, newdata = res$data)),
    as.character(predict(member, newdata = data, type = "class"))
  )
})

test_that("as.party.bagger() works with bagged CART regression", {
  data <- get_mtcars_data()
  fit <- fit_bagger(mpg ~ ., data, "rpart", "regression")

  res <- as.party(fit, tree = 1L, data = data)
  expect_s3_class(res, "party")
  expect_identical(nrow(res$data), nrow(data))
})

test_that("as.party.bagger() works with bagged C5.0", {
  data <- get_factor_data()
  fit <- fit_bagger(y ~ ., data, "C5.0")

  res <- as.party(fit, tree = 3L, data = data)
  expect_s3_class(res, "party")
  expect_identical(nrow(res$data), nrow(data))
})

test_that("as.party.bagger() validates its arguments", {
  data <- get_factor_data()
  fit <- fit_bagger(y ~ ., data, "rpart")

  expect_snapshot(as.party(fit, tree = 1L), error = TRUE)
  expect_snapshot(as.party(fit, tree = 4L, data = data), error = TRUE)
  expect_snapshot(as.party(fit, tree = 1:2, data = data), error = TRUE)
  expect_snapshot(as.party(fit, data = data[-2]), error = TRUE)
})
