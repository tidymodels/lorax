skip_if_not_installed("parsnip")
skip_if_not_installed("workflows")
skip_if_not_installed("ranger")

test_that("extract_rules() unwraps model_fit and workflow objects", {
  fits <- fit_tidymodels_rf()

  expect_equal(
    extract_rules(
      fits$rf_fit,
      tree = 2:3,
      data = mtcars,
      add_statistics = TRUE
    ),
    extract_rules(
      fits$rf_engine,
      tree = 2:3,
      data = mtcars,
      add_statistics = TRUE
    )
  )
  expect_equal(
    extract_rules(
      fits$rf_wflow,
      tree = 2:3,
      data = mtcars,
      add_statistics = TRUE
    ),
    extract_rules(
      fits$wflow_engine,
      tree = 2:3,
      data = mtcars,
      add_statistics = TRUE
    )
  )
})

test_that("active_predictors() unwraps model_fit and workflow objects", {
  fits <- fit_tidymodels_rf()

  expect_equal(
    active_predictors(fits$rf_fit, tree = 1:2),
    active_predictors(fits$rf_engine, tree = 1:2)
  )
  expect_equal(
    active_predictors(fits$rf_wflow, tree = 1:2),
    active_predictors(fits$wflow_engine, tree = 1:2)
  )
})

test_that("num_ensemble_members() unwraps model_fit and workflow objects", {
  fits <- fit_tidymodels_rf()

  expect_equal(num_ensemble_members(fits$rf_fit), 5L)
  expect_equal(num_ensemble_members(fits$rf_wflow), 5L)
})

test_that("var_imp() unwraps model_fit and workflow objects", {
  fits <- fit_tidymodels_rf()

  expect_equal(var_imp(fits$rf_fit), var_imp(fits$rf_engine))
  expect_equal(var_imp(fits$rf_wflow), var_imp(fits$wflow_engine))
})

test_that("as.party() unwraps model_fit and workflow objects", {
  fits <- fit_tidymodels_rf()

  expect_equal(
    extract_rules(partykit::as.party(fits$rf_fit, tree = 2, data = mtcars)),
    extract_rules(partykit::as.party(fits$rf_engine, tree = 2, data = mtcars))
  )
  expect_equal(
    extract_rules(partykit::as.party(fits$rf_wflow, tree = 2, data = mtcars)),
    extract_rules(partykit::as.party(
      fits$wflow_engine,
      tree = 2,
      data = mtcars
    ))
  )
})

test_that("unfitted workflows error", {
  fits <- fit_tidymodels_rf()

  unfitted <- workflows::workflow(mpg ~ ., fits$spec)
  expect_snapshot(extract_rules(unfitted), error = TRUE)
})

test_that("extract_rules() uses the factor levels saved by parsnip with engine = \"xgboost3\"", {
  # The "xgboost3" engine is only in the development version of parsnip
  skip_if_not_installed("parsnip", minimum_version = "1.6.1.9000")
  cat_fit <- get_xgb_cat_fit()

  spec <-
    parsnip::boost_tree(trees = 2, tree_depth = 3) |>
    parsnip::set_engine("xgboost3", max_cat_to_onehot = 1) |>
    parsnip::set_mode("regression")
  bt_fit <- parsnip::fit(spec, y ~ ., data = cat_fit$data)
  bt_wflow <- parsnip::fit(workflows::workflow(y ~ ., spec), cat_fit$data)

  rules <- extract_rules(bt_fit, tree = 1:2)
  rule_chr <- vapply(rules$rules, rule_text, character(1))
  expect_match(
    rule_chr,
    'f %in% c("b", "d", "e", "g")',
    fixed = TRUE,
    all = FALSE
  )
  expect_equal(
    rules,
    extract_rules(bt_fit$fit, tree = 1:2, data = cat_fit$data)
  )
  expect_equal(extract_rules(bt_wflow, tree = 1:2), rules)

  # `data` takes precedence over the saved levels
  expect_equal(
    extract_rules(bt_fit, data = NULL),
    extract_rules(bt_fit$fit)
  )
})

test_that("engine = \"xgboost\" models fit with indicators only have numeric splits", {
  cat_fit <- get_xgb_cat_fit()

  spec <-
    parsnip::boost_tree(trees = 2, tree_depth = 3) |>
    parsnip::set_engine("xgboost") |>
    parsnip::set_mode("regression")
  bt_wflow <- parsnip::fit(workflows::workflow(y ~ ., spec), cat_fit$data)
  bt_engine <- parsnip::extract_fit_engine(bt_wflow)

  expect_equal(num_ensemble_members(bt_wflow), 2L)
  expect_equal(extract_rules(bt_wflow), extract_rules(bt_engine))

  rule_chr <- vapply(extract_rules(bt_wflow)$rules, rule_text, character(1))
  expect_all_false(grepl("%in%|==", rule_chr))
  expect_all_true(grepl("^f[a-h] (<|>=) 1", rule_chr))
})

# All methods for a parsnip fit and a workflow should match those for the
# xgboost model inside of them. `party_data` is the data in the form given to
# xgboost, which differs from `data` when indicators are made.
expect_xgb_engine_methods <- function(
  engine,
  formula,
  data,
  party_data = data
) {
  # parsnip's contrast function for indicators is only found when attached
  withr::local_package("parsnip")

  spec <-
    parsnip::boost_tree(trees = 3, tree_depth = 2) |>
    parsnip::set_engine(engine) |>
    parsnip::set_mode("regression")
  bt_fit <- parsnip::fit(spec, formula, data = data)
  bt_wflow <- parsnip::fit(workflows::workflow(formula, spec), data)

  fits <- list(bt_fit, bt_wflow)
  for (fit in fits) {
    booster <- parsnip::extract_fit_engine(fit)

    expect_s3_class(extract_rules(fit), "rule_set_xgb.Booster")
    expect_equal(
      extract_rules(fit, tree = 1:3, data = data, add_statistics = TRUE),
      extract_rules(booster, tree = 1:3, data = data, add_statistics = TRUE)
    )
    expect_equal(
      active_predictors(fit, tree = 1:3),
      active_predictors(booster, tree = 1:3)
    )
    expect_equal(num_ensemble_members(fit), 3L)
    expect_equal(var_imp(fit), var_imp(booster))
    expect_equal(
      extract_rules(partykit::as.party(fit, tree = 2, data = party_data)),
      extract_rules(partykit::as.party(booster, tree = 2, data = party_data))
    )
  }
}

test_that("methods work with engine = \"xgboost\"", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("withr")

  expect_xgb_engine_methods("xgboost", mpg ~ ., mtcars)
})

test_that("methods work with engine = \"xgboost\" and factor predictors", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("withr")
  cat_data <- get_xgb_cat_data()

  # Factors are converted to one indicator column per level
  indicators <- as.data.frame(model.matrix(
    ~ . - 1,
    data = cat_data[, c("f", "g", "z")],
    contrasts.arg = list(
      f = contrasts(cat_data$f, contrasts = FALSE),
      g = contrasts(cat_data$g, contrasts = FALSE)
    )
  ))
  indicators$y <- cat_data$y

  expect_xgb_engine_methods("xgboost", y ~ ., cat_data, indicators)

  withr::local_package("parsnip")
  bt_fit <-
    parsnip::boost_tree(trees = 3, tree_depth = 2) |>
    parsnip::set_engine("xgboost") |>
    parsnip::set_mode("regression") |>
    parsnip::fit(y ~ ., data = cat_data)
  rule_chr <- vapply(
    extract_rules(bt_fit, tree = 1:3)$rules,
    rule_text,
    character(1)
  )
  expect_all_false(grepl("%in%|==", rule_chr))
  expect_match(rule_chr, "f[a-h] (<|>=) 1", all = FALSE)
})

test_that("methods work with engine = \"xgboost3\"", {
  # The "xgboost3" engine is only in the development version of parsnip
  skip_if_not_installed("parsnip", minimum_version = "1.6.1.9000")
  skip_if_not_installed("xgboost", "3.0.0")
  skip_if_not_installed("withr")
  cat_fit <- get_xgb_cat_fit()

  expect_xgb_engine_methods("xgboost3", mpg ~ ., mtcars)
  expect_xgb_engine_methods("xgboost3", y ~ ., cat_fit$data)
})
