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
