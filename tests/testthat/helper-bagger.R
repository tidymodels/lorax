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

# Avoid capturing the package namespace, which baguette serializes (warns)
environment(fit_bagger) <- globalenv()
