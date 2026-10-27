skip_if_not_installed("parsnip")
skip_if_not_installed("workflows")
skip_if_not_installed("ranger")

rf_spec <-
  parsnip::rand_forest(trees = 5) |>
  parsnip::set_engine("ranger", importance = "impurity") |>
  parsnip::set_mode("regression")

rf_fit <- parsnip::fit(rf_spec, mpg ~ ., data = mtcars)
rf_wflow <-
  workflows::workflow(mpg ~ ., rf_spec) |>
  parsnip::fit(data = mtcars)
rf_engine <- parsnip::extract_fit_engine(rf_fit)
wflow_engine <- parsnip::extract_fit_engine(rf_wflow)

test_that("extract_rules() unwraps model_fit and workflow objects", {
  expect_equal(
    extract_rules(rf_fit, tree = 2:3, data = mtcars, add_statistics = TRUE),
    extract_rules(rf_engine, tree = 2:3, data = mtcars, add_statistics = TRUE)
  )
  expect_equal(
    extract_rules(rf_wflow, tree = 2:3, data = mtcars, add_statistics = TRUE),
    extract_rules(
      wflow_engine,
      tree = 2:3,
      data = mtcars,
      add_statistics = TRUE
    )
  )
})

test_that("active_predictors() unwraps model_fit and workflow objects", {
  expect_equal(
    active_predictors(rf_fit, tree = 1:2),
    active_predictors(rf_engine, tree = 1:2)
  )
  expect_equal(
    active_predictors(rf_wflow, tree = 1:2),
    active_predictors(wflow_engine, tree = 1:2)
  )
})

test_that("num_ensemble_members() unwraps model_fit and workflow objects", {
  expect_equal(num_ensemble_members(rf_fit), 5L)
  expect_equal(num_ensemble_members(rf_wflow), 5L)
})

test_that("var_imp() unwraps model_fit and workflow objects", {
  expect_equal(var_imp(rf_fit), var_imp(rf_engine))
  expect_equal(var_imp(rf_wflow), var_imp(wflow_engine))
})

test_that("as.party() unwraps model_fit and workflow objects", {
  expect_equal(
    extract_rules(partykit::as.party(rf_fit, tree = 2, data = mtcars)),
    extract_rules(partykit::as.party(rf_engine, tree = 2, data = mtcars))
  )
  expect_equal(
    extract_rules(partykit::as.party(rf_wflow, tree = 2, data = mtcars)),
    extract_rules(partykit::as.party(wflow_engine, tree = 2, data = mtcars))
  )
})

test_that("unfitted workflows error", {
  unfitted <- workflows::workflow(mpg ~ ., rf_spec)
  expect_snapshot(extract_rules(unfitted), error = TRUE)
})
