fit_tidymodels_rf <- function() {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("workflows")
  skip_if_not_installed("ranger")

  spec <-
    parsnip::rand_forest(trees = 5) |>
    parsnip::set_engine("ranger", importance = "impurity") |>
    parsnip::set_mode("regression")

  rf_fit <- parsnip::fit(spec, mpg ~ ., data = mtcars)
  rf_wflow <-
    workflows::workflow(mpg ~ ., spec) |>
    parsnip::fit(data = mtcars)

  list(
    spec = spec,
    rf_fit = rf_fit,
    rf_wflow = rf_wflow,
    rf_engine = parsnip::extract_fit_engine(rf_fit),
    wflow_engine = parsnip::extract_fit_engine(rf_wflow)
  )
}
