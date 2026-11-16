test_that("as.party.xgb.Booster returns valid party object", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(penguins[, c(
      "bill_length_mm",
      "bill_depth_mm",
      "flipper_length_mm",
      "body_mass_g"
    )]),
    label = as.numeric(penguins$species) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 3,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )
  p <- as.party(bst, tree = 1, data = penguins)

  expect_s3_class(p, "party")
  expect_s3_class(p$node, "partynode")
  expect_true(is.data.frame(p$data))
})

test_that("as.party.xgb.Booster works with binary classification", {
  skip_if_not_installed("xgboost")

  data <- get_binary_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("linear_1", "linear_2", "linear_3")]),
    label = as.numeric(data$y) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 2,
      objective = "binary:logistic",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )
  p <- as.party(bst, tree = 1, data = data)

  expect_s3_class(p, "party")
  expect_s3_class(p$node, "partynode")
})

test_that("as.party.xgb.Booster works with regression", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )
  p <- as.party(bst, tree = 1, data = data)

  expect_s3_class(p, "party")
  expect_s3_class(p$node, "partynode")
})

test_that("as.party.xgb.Booster validates tree parameter", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(penguins[, c(
      "bill_length_mm",
      "bill_depth_mm",
      "flipper_length_mm",
      "body_mass_g"
    )]),
    label = as.numeric(penguins$species) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 3,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  expect_snapshot(as.party(bst, tree = 0, data = penguins), error = TRUE)
  expect_snapshot(as.party(bst, tree = c(1, 2), data = penguins), error = TRUE)
  expect_snapshot(as.party(bst, tree = "1", data = penguins), error = TRUE)
  expect_snapshot(as.party(bst, tree = 100, data = penguins), error = TRUE)
})

test_that("as.party.xgb.Booster works with data parameter", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(penguins[, c(
      "bill_length_mm",
      "bill_depth_mm",
      "flipper_length_mm",
      "body_mass_g"
    )]),
    label = as.numeric(penguins$species) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 3,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 2,
    verbose = 0
  )
  p <- as.party(bst, tree = 1, data = penguins)

  expect_s3_class(p, "party")
  expect_equal(ncol(p$data), 5)
})

test_that("as.party.xgb.Booster handles single-node trees", {
  skip_if_not_installed("xgboost")

  # Create trivial data that might produce single-node tree
  test_data <- data.frame(
    x1 = rep(1, 10),
    y = rep(0, 10)
  )
  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(test_data[, "x1", drop = FALSE]),
    label = test_data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 0,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 1,
    verbose = 0
  )
  p <- as.party(bst, tree = 1, data = test_data)

  expect_s3_class(p, "party")
})

test_that("as.party.xgb.Booster extracts different trees in multiclass", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(penguins[, c(
      "bill_length_mm",
      "bill_depth_mm",
      "flipper_length_mm",
      "body_mass_g"
    )]),
    label = as.numeric(penguins$species) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 3,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  # Extract trees for different classes/rounds
  p1 <- as.party(bst, tree = 1, data = penguins)
  p2 <- as.party(bst, tree = 4, data = penguins) # Different class or round

  expect_s3_class(p1, "party")
  expect_s3_class(p2, "party")

  # Verify both work
  expect_true(length(partykit::nodeids(p1)) > 0)
  expect_true(length(partykit::nodeids(p2)) > 0)
})

test_that("as.party.xgb.Booster requires response in data", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(penguins[, c(
      "bill_length_mm",
      "bill_depth_mm",
      "flipper_length_mm",
      "body_mass_g"
    )]),
    label = as.numeric(penguins$species) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 3,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 2,
    verbose = 0
  )

  # Provide data with only predictors (no response)
  expect_snapshot(
    as.party(bst, tree = 1, data = penguins[, -1]),
    error = TRUE
  )
})

test_that("as.party.xgb.Booster handles trees with many nodes", {
  skip_if_not_installed("xgboost")

  # Create data that produces deeper tree
  set.seed(123)
  n <- 200
  data <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n),
    x3 = rnorm(n),
    x4 = rnorm(n),
    y = rnorm(n)
  )

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("x1", "x2", "x3", "x4")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 5,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  p <- as.party(bst, tree = 1, data = data)

  expect_s3_class(p, "party")
  # Deeper tree should have more nodes
  expect_true(length(partykit::nodeids(p)) > 5)
})

test_that("as.party.xgb.Booster handles different boosting rounds", {
  skip_if_not_installed("xgboost")

  data <- get_binary_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("linear_1", "linear_2", "linear_3")]),
    label = as.numeric(data$y) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "binary:logistic",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 10,
    verbose = 0
  )

  # Extract trees from different rounds
  p1 <- as.party(bst, tree = 1, data = data)
  p5 <- as.party(bst, tree = 5, data = data)
  p10 <- as.party(bst, tree = 10, data = data)

  expect_s3_class(p1, "party")
  expect_s3_class(p5, "party")
  expect_s3_class(p10, "party")

  # All should have valid structure
  expect_true(length(partykit::nodeids(p1)) > 0)
  expect_true(length(partykit::nodeids(p5)) > 0)
  expect_true(length(partykit::nodeids(p10)) > 0)
})

test_that("as.party.xgb.Booster handles narrow trees", {
  skip_if_not_installed("xgboost")

  data <- get_binary_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("linear_1", "linear_2", "linear_3")]),
    label = as.numeric(data$y) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 1,
      objective = "binary:logistic",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  p <- as.party(bst, tree = 1, data = data)

  expect_s3_class(p, "party")
  # Shallow tree (max_depth=1) should have at most 3 nodes
  expect_true(length(partykit::nodeids(p)) <= 3)
})

test_that("as.party.xgb.Booster preserves column order", {
  skip_if_not_installed("xgboost")

  # Use specific column order
  data <- data.frame(
    z_last = rnorm(50),
    a_first = rnorm(50),
    m_middle = rnorm(50),
    response = rnorm(50)
  )

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("z_last", "a_first", "m_middle")]),
    label = data$response
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 2,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 2,
    verbose = 0
  )

  p <- as.party(bst, tree = 1, data = data)

  expect_s3_class(p, "party")
  expect_true(all(c("z_last", "a_first", "m_middle") %in% names(p$data)))
})

test_that("as.party.xgb.Booster with large multiclass", {
  skip_if_not_installed("xgboost")

  # Multiclass with many classes
  set.seed(789)
  n <- 150
  data <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n),
    x3 = rnorm(n),
    y = factor(sample(1:5, n, replace = TRUE))
  )

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("x1", "x2", "x3")]),
    label = as.numeric(data$y) - 1
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 5,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  # Should have 5 classes * 3 rounds = 15 trees
  # Extract trees for different classes
  p1 <- as.party(bst, tree = 1, data = data)
  p6 <- as.party(bst, tree = 6, data = data)

  expect_s3_class(p1, "party")
  expect_s3_class(p6, "party")

  # Trees should not be identical
  expect_false(identical(p1$node, p6$node))
})

test_that("as.party.xgb.Booster does not show asterisks in node summaries", {
  skip_if_not_installed("xgboost")

  data(agaricus.train, package = "xgboost")
  train_data <- as.data.frame(as.matrix(agaricus.train$data))
  train_data$label <- agaricus.train$label

  dtrain <- xgboost::xgb.DMatrix(
    agaricus.train$data,
    label = agaricus.train$label
  )
  bst <- xgboost::xgb.train(
    params = list(max_depth = 3, objective = "binary:logistic", nthread = 1),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  p <- as.party(bst, tree = 1, data = train_data)

  output <- capture.output(print(p))

  # Check for asterisks in node summaries (after the colon)
  # Pattern: ": *" or ": * " indicates missing summary
  has_asterisk_summary <- any(grepl(":\\s*\\*\\s*($|\\()", output))

  expect_false(has_asterisk_summary)
})

# ------------------------------------------------------------------------------
# active_predictors tests
# ------------------------------------------------------------------------------

test_that("active_predictors.xgb.Booster() returns correct structure", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  result <- active_predictors(bst)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("active_predictors", "tree"))
  expect_type(result$active_predictors, "list")
  expect_type(result$tree, "integer")
  expect_equal(nrow(result), 1)
})

test_that("active_predictors.xgb.Booster() extracts from single tree", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- active_predictors(bst, tree = 1L)

  expect_equal(nrow(result), 1)
  expect_equal(result$tree, 1L)
  expect_type(result$active_predictors[[1]], "character")
})

test_that("active_predictors.xgb.Booster() extracts from multiple trees", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- active_predictors(bst, tree = c(1L, 2L, 3L))

  expect_equal(nrow(result), 3)
  expect_equal(result$tree, c(1L, 2L, 3L))
  expect_equal(length(result$active_predictors), 3)
})

test_that("active_predictors.xgb.Booster() works with all trees", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  result <- active_predictors(bst, tree = 1:3)

  expect_equal(nrow(result), 3)
  expect_equal(result$tree, c(1L, 2L, 3L))
  expect_equal(length(result$active_predictors), 3)
})

test_that("active_predictors.xgb.Booster() validates tree argument", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  expect_snapshot(
    active_predictors(bst, tree = "1"),
    error = TRUE
  )

  expect_snapshot(
    active_predictors(bst, tree = 1.5),
    error = TRUE
  )

  expect_snapshot(
    active_predictors(bst, tree = 0L),
    error = TRUE
  )

  expect_snapshot(
    active_predictors(bst, tree = 999L),
    error = TRUE
  )
})

test_that("active_predictors.xgb.Booster() handles tree with no splits", {
  skip_if_not_installed("xgboost")

  # Create trivial data that produces single-node tree
  test_data <- data.frame(
    x1 = rep(1, 10),
    y = rep(0, 10)
  )
  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(test_data[, "x1", drop = FALSE]),
    label = test_data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 0,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 1,
    verbose = 0
  )

  result <- active_predictors(bst, tree = 1L)

  expect_equal(nrow(result), 1)
  expect_equal(result$tree, 1L)
  expect_type(result$active_predictors[[1]], "character")
  expect_length(result$active_predictors[[1]], 0)
})

test_that("active_predictors.xgb.Booster() returns sorted unique variables", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  result <- active_predictors(bst, tree = 1L)
  active_vars <- result$active_predictors[[1]]

  # Should be sorted (case-insensitive)
  expect_equal(active_vars, active_vars[order(tolower(active_vars))])

  # Should be unique
  expect_equal(length(active_vars), length(unique(active_vars)))
})

test_that("active_predictors.xgb.Booster() works with numeric predictors", {
  skip_if_not_installed("xgboost")

  # Use mtcars which has no factors
  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(mtcars[, c("cyl", "disp", "hp", "wt")]),
    label = mtcars$mpg
  )
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  result <- active_predictors(bst, tree = 1L)
  active_vars <- result$active_predictors[[1]]

  expect_type(active_vars, "character")
  expect_true(all(active_vars %in% c("cyl", "disp", "hp", "wt")))
})

test_that("active_predictors.xgb.Booster() works with feature names", {
  skip_if_not_installed("xgboost")

  data(agaricus.train, package = "xgboost")

  dtrain <- xgboost::xgb.DMatrix(
    agaricus.train$data,
    label = agaricus.train$label
  )
  bst <- xgboost::xgb.train(
    params = list(max_depth = 3, objective = "binary:logistic", nthread = 1),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  result <- active_predictors(bst, tree = 1L)
  active_vars <- result$active_predictors[[1]]

  expect_type(active_vars, "character")
  expect_true(length(active_vars) > 0)
})

# Tests for var_imp.xgb.Booster() ---------------------------------------------

test_that("var_imp.xgb.Booster() returns correct structure", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  set.seed(423)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("term", "estimate"))
  expect_type(result$term, "character")
  expect_type(result$estimate, "double")
})

test_that("var_imp.xgb.Booster() extracts variable importance scores", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  set.seed(817)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst)

  # Should have at least one variable with non-zero importance
  expect_true(any(result$estimate > 0))

  # All estimates should be non-negative
  expect_true(all(result$estimate >= 0))

  # Should have at least one predictor
  expect_true(nrow(result) > 0)
})

test_that("var_imp.xgb.Booster() with complete=TRUE fills missing predictors", {
  skip_if_not_installed("xgboost")

  set.seed(236)
  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  set.seed(591)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst, complete = TRUE)

  # Should have all predictors
  expect_true(nrow(result) >= 1)
  expect_true(all(
    c("predictor_01", "predictor_02", "predictor_03") %in% result$term
  ))

  # All estimates should be non-negative
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() with complete=FALSE returns only used predictors", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  set.seed(748)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst, complete = FALSE)

  # Should only have predictors with importance scores
  expect_true(nrow(result) >= 1)
  expect_true(all(result$estimate > 0))
})

test_that("var_imp.xgb.Booster() works with numeric predictors only", {
  skip_if_not_installed("xgboost")

  mtcars <- get_mtcars_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(mtcars[, c("cyl", "disp", "hp", "wt")]),
    label = mtcars$mpg
  )
  set.seed(312)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst, complete = TRUE)

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) >= 1)
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() importance scores match underlying object", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  set.seed(659)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst, complete = FALSE)

  # Get expected importance from xgboost
  expected <- as.data.frame(xgboost::xgb.importance(model = bst))

  # Match scores
  for (i in seq_len(nrow(result))) {
    term <- result$term[i]
    estimate <- result$estimate[i]
    expected_row <- expected[expected$Feature == term, ]
    expect_equal(estimate, expected_row$Gain, tolerance = 1e-10)
  }
})

test_that("var_imp.xgb.Booster() works with binary classification", {
  skip_if_not_installed("xgboost")

  data <- get_binary_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("linear_1", "linear_2", "linear_3")]),
    label = as.numeric(data$y) - 1
  )
  set.seed(184)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "binary:logistic",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst)

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) >= 1)
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() works with multiclass classification", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(penguins[, c(
      "bill_length_mm",
      "bill_depth_mm",
      "flipper_length_mm",
      "body_mass_g"
    )]),
    label = as.numeric(penguins$species) - 1
  )
  set.seed(937)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "multi:softmax",
      num_class = 3,
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst)

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) >= 1)
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() handles model with no valid splits", {
  skip_if_not_installed("xgboost")

  # Create data that produces no splits
  test_data <- data.frame(
    x1 = rep(1, 10),
    y = rep(0, 10)
  )

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(test_data[, "x1", drop = FALSE]),
    label = test_data$y
  )
  set.seed(462)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 0,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 1,
    verbose = 0
  )

  result <- var_imp(bst, complete = FALSE)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("term", "estimate"))
  # Should have 0 rows since no features were used
  expect_equal(nrow(result), 0)

  # With feature_names, should return the feature with 0 importance
  result_complete <- var_imp(bst, complete = TRUE, feature_names = "x1")
  expect_equal(nrow(result_complete), 1)
  expect_equal(result_complete$term, "x1")
  expect_equal(result_complete$estimate, 0)
})

test_that("var_imp.xgb.Booster() handles many predictors", {
  skip_if_not_installed("xgboost")

  set.seed(705)
  n <- 200
  p <- 15
  X <- as.data.frame(matrix(rnorm(n * p), nrow = n, ncol = p))
  colnames(X) <- paste0("x", 1:p)
  X$y <- X$x1 + X$x2 + rnorm(n)

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(X[, paste0("x", 1:p)]),
    label = X$y
  )
  set.seed(128)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst, complete = FALSE)

  # Should have only predictors that were used
  expect_true(nrow(result) >= 1)
  expect_true(nrow(result) <= p)
  expect_true(all(result$estimate >= 0))

  # With feature_names parameter, should have all predictors
  result_complete <- var_imp(
    bst,
    complete = TRUE,
    feature_names = paste0("x", 1:p)
  )
  expect_equal(nrow(result_complete), p)
  expect_true(all(result_complete$estimate >= 0))
  expect_setequal(result_complete$term, paste0("x", 1:p))
})

test_that("var_imp.xgb.Booster() works with constrained trees", {
  skip_if_not_installed("xgboost")

  set.seed(873)
  small_data <- data.frame(
    y = rnorm(100),
    x1 = rnorm(100),
    x2 = rnorm(100)
  )

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(small_data[, c("x1", "x2")]),
    label = small_data$y
  )
  set.seed(546)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 1,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )

  result <- var_imp(bst, complete = TRUE)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("term", "estimate"))
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() works with deep trees", {
  skip_if_not_installed("xgboost")

  set.seed(291)
  data <- get_regression_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
    label = data$y
  )
  set.seed(764)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 10,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst)

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) >= 1)
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() handles agaricus data", {
  skip_if_not_installed("xgboost")

  data(agaricus.train, package = "xgboost")

  dtrain <- xgboost::xgb.DMatrix(
    agaricus.train$data,
    label = agaricus.train$label
  )
  set.seed(539)
  bst <- xgboost::xgb.train(
    params = list(max_depth = 3, objective = "binary:logistic", nthread = 1),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst, complete = TRUE)

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) > 0)
  expect_true(all(result$estimate >= 0))
})

test_that("var_imp.xgb.Booster() handles very shallow trees", {
  skip_if_not_installed("xgboost")

  data <- get_binary_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, c("linear_1", "linear_2", "linear_3")]),
    label = as.numeric(data$y) - 1
  )
  set.seed(672)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 1,
      objective = "binary:logistic",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 5,
    verbose = 0
  )

  result <- var_imp(bst)

  expect_s3_class(result, "tbl_df")
  expect_true(all(result$estimate >= 0))
})

test_that("as.party.xgb.Booster works with single numeric predictor", {
  skip_if_not_installed("xgboost")

  data <- get_single_numeric_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, "x", drop = FALSE]),
    label = as.numeric(data$y) - 1
  )
  set.seed(127)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )
  p <- as.party(bst, tree = 1, data = data)

  expect_s3_class(p, "party")
  expect_s3_class(p$node, "partynode")
})

test_that("active_predictors.xgb.Booster() works with single numeric predictor", {
  skip_if_not_installed("xgboost")

  data <- get_single_numeric_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, "x", drop = FALSE]),
    label = as.numeric(data$y) - 1
  )
  set.seed(298)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )
  active <- active_predictors(bst)

  expect_s3_class(active, "tbl_df")
  # If the model made splits, should have "x" as active predictor
  if (length(unique(unlist(active$active_predictors))) > 0) {
    expect_setequal(unique(unlist(active$active_predictors)), "x")
  }
})

test_that("var_imp.xgb.Booster() works with single numeric predictor", {
  skip_if_not_installed("xgboost")

  data <- get_single_numeric_data()

  dtrain <- xgboost::xgb.DMatrix(
    as.matrix(data[, "x", drop = FALSE]),
    label = as.numeric(data$y) - 1
  )
  set.seed(413)
  bst <- xgboost::xgb.train(
    params = list(
      max_depth = 3,
      objective = "reg:squarederror",
      nthread = 1
    ),
    data = dtrain,
    nrounds = 3,
    verbose = 0
  )
  importance <- var_imp(bst)

  expect_s3_class(importance, "tbl_df")
  # If the model made splits, "x" should have importance
  if (nrow(importance) > 0) {
    expect_equal(importance$term, "x")
    expect_true(importance$estimate >= 0)
  }
})

test_that("num_ensemble_members() counts xgboost trees", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("palmerpenguins")

  penguins <- get_penguins_data()
  x <- as.matrix(penguins[, -1])

  multi <- xgboost::xgb.train(
    params = list(objective = "multi:softprob", num_class = 3, nthread = 1),
    data = xgboost::xgb.DMatrix(x, label = as.numeric(penguins$species) - 1),
    nrounds = 2
  )
  reg <- xgboost::xgb.train(
    params = list(objective = "reg:squarederror", nthread = 1),
    data = xgboost::xgb.DMatrix(x[, -1], label = x[, 1]),
    nrounds = 4
  )

  expect_identical(num_ensemble_members(multi), 6L)
  expect_identical(num_ensemble_members(reg), 4L)
})

test_that("extract_rules.xgb.Booster() handles several trees in one call", {
  skip_if_not_installed("xgboost")

  data <- get_regression_data()
  bst <- xgboost::xgb.train(
    params = list(max_depth = 3, objective = "reg:squarederror", nthread = 1),
    data = xgboost::xgb.DMatrix(
      as.matrix(data[, c("predictor_01", "predictor_02", "predictor_03")]),
      label = data$y
    ),
    nrounds = 3,
    verbose = 0
  )

  all_rules <- extract_rules(bst, tree = 1:3)
  one_at_a_time <- dplyr::bind_rows(lapply(1:3, \(i) {
    extract_rules(bst, tree = i)
  }))

  expect_s3_class(all_rules, "rule_set_xgb.Booster")
  expect_equal(names(all_rules), c("tree", "rules", "id"))
  expect_equal(as.data.frame(all_rules), as.data.frame(one_at_a_time))
  expect_equal(unique(all_rules$tree), 1:3)
})

# ------------------------------------------------------------------------------
# Categorical predictors

test_that("xgb_parse_dump() agrees with xgb.model.dt.tree()", {
  skip_if_not_installed("xgboost")

  set.seed(40718)
  bst <- xgboost::xgb.train(
    data = xgboost::xgb.DMatrix(
      as.matrix(mtcars[, -1]),
      label = mtcars$mpg,
      nthread = 1
    ),
    nrounds = 3,
    params = xgboost::xgb.params(max_depth = 3, nthread = 1)
  )

  from_table <- xgb_tree_table(bst)
  from_dump <- xgb_parse_dump(xgboost::xgb.dump(bst, with_stats = TRUE))
  from_dump <- from_dump[order(from_dump$Tree, from_dump$Node), ]

  expect_named(from_dump, names(from_table))
  expect_equal(from_dump, from_table, ignore_attr = TRUE, tolerance = 1e-6)
  expect_all_equal(xgb_tree_table(bst, trees = 2L)$Tree, 1L)
})

test_that("xgb_parse_dump() handles feature names with special characters", {
  lines <- c(
    "booster[0]",
    "0:[a<b:{c}<1.5] yes=1,no=2,missing=2,gain=10,cover=20",
    "1:leaf=-0.5,cover=8",
    "2:[a:b<c:{0,3}] yes=4,no=3,missing=3,gain=4,cover=12",
    "3:leaf=0.25,cover=5",
    "4:leaf=1,cover=7"
  )
  res <- xgb_parse_dump(lines)

  expect_equal(res$Feature, c("a<b:{c}", "Leaf", "a:b<c", "Leaf", "Leaf"))
  expect_equal(res$Split, c(1.5, NA, NA, NA, NA))
  expect_equal(res$Categories, list(NULL, NULL, c(0L, 3L), NULL, NULL))
  expect_equal(res$Yes, c(1L, NA, 4L, NA, NA))
  expect_equal(res$Missing, c(2L, NA, 3L, NA, NA))
  expect_equal(res$Gain, c(10, -0.5, 4, 0.25, 1))
})

test_that("extract_rules.xgb.Booster() uses factor levels for categorical splits", {
  cat_fit <- get_xgb_cat_fit()

  rules <- extract_rules(cat_fit$fit, tree = 1L, data = cat_fit$data)
  rule_chr <- vapply(rules$rules, rule_text, character(1))

  expect_s3_class(rules, "rule_set_xgb.Booster")
  expect_all_true(
    grepl('f %in% c("b", "d", "e", "g")', rule_chr, fixed = TRUE) |
      grepl('f %in% c("a", "c", "f", "h")', rule_chr, fixed = TRUE)
  )

  rules <- extract_rules(cat_fit$fit, tree = 1:3, data = cat_fit$data)
  for (i in 1:3) {
    expect_equal(
      rule_node_ids(rules[rules$tree == i, ], cat_fit$data),
      cat_fit$leaves[, i]
    )
  }
})

test_that("extract_rules.xgb.Booster() uses integer codes without factor data", {
  cat_fit <- get_xgb_cat_fit()

  rules_1 <- extract_rules(cat_fit$fit, tree = 1L)
  rule_chr <- vapply(rules_1$rules, rule_text, character(1))
  expect_all_true(grepl("f %in% c(0, 2, 5, 7)", rule_chr, fixed = TRUE))

  for (i in 1:3) {
    rules <- extract_rules(cat_fit$fit, tree = i)
    expect_equal(rule_node_ids(rules, cat_fit$codes), cat_fit$leaves[, i])
  }

  # Numeric columns in `data` are not translated
  rules_codes <- extract_rules(cat_fit$fit, tree = 1L, data = cat_fit$codes)
  expect_equal(rules_codes$rules, rules_1$rules)
})

test_that("extract_rules.xgb.Booster() works with one-hot categorical splits", {
  cat_fit <- get_xgb_cat_fit(max_cat_to_onehot = 20)

  rules <- extract_rules(cat_fit$fit, tree = 1L, data = cat_fit$data)
  rule_chr <- vapply(rules$rules, rule_text, character(1))
  expect_match(rule_chr, 'f == "f"', fixed = TRUE, all = FALSE)

  for (i in 1:3) {
    rules <- extract_rules(cat_fit$fit, tree = i, data = cat_fit$data)
    expect_equal(rule_node_ids(rules, cat_fit$data), cat_fit$leaves[, i])
    rules <- extract_rules(cat_fit$fit, tree = i)
    expect_equal(rule_node_ids(rules, cat_fit$codes), cat_fit$leaves[, i])
  }
})

test_that("extract_rules.xgb.Booster() validates categorical data", {
  cat_fit <- get_xgb_cat_fit()

  too_few <- cat_fit$data
  too_few$f <- factor(as.character(too_few$f), levels = letters[1:3])
  expect_snapshot(
    extract_rules(cat_fit$fit, tree = 1L, data = too_few),
    error = TRUE
  )
  expect_snapshot(
    extract_rules(cat_fit$fit, tree = 1L, data = as.matrix(cat_fit$codes)),
    error = TRUE
  )
})

test_that("as.party.xgb.Booster() works with categorical predictors as factors", {
  cat_fit <- get_xgb_cat_fit()

  for (i in 1:3) {
    p <- as.party(cat_fit$fit, tree = i, data = cat_fit$data)
    expect_s3_class(p, "constparty")
    fitted_ids <- p$fitted[["(fitted)"]]
    expect_all_equal(rowSums(table(fitted_ids, cat_fit$leaves[, i]) > 0), 1L)
    expect_all_equal(colSums(table(fitted_ids, cat_fit$leaves[, i]) > 0), 1L)
  }

  p <- as.party(cat_fit$fit, tree = 1L, data = cat_fit$data)
  expect_equal(levels(p$data$f), letters[1:8])
  rules <- extract_rules(p)
  rule_chr <- vapply(rules$rules, rule_text, character(1))
  expect_all_true(
    grepl('f %in% c("b", "d", "e", "g")', rule_chr, fixed = TRUE) |
      grepl('f %in% c("a", "c", "f", "h")', rule_chr, fixed = TRUE)
  )
})

test_that("as.party.xgb.Booster() works with integer-coded categorical predictors", {
  cat_fit <- get_xgb_cat_fit()

  for (i in 1:3) {
    p <- as.party(cat_fit$fit, tree = i, data = cat_fit$codes)
    expect_s3_class(p, "constparty")
    fitted_ids <- p$fitted[["(fitted)"]]
    expect_all_equal(rowSums(table(fitted_ids, cat_fit$leaves[, i]) > 0), 1L)
    expect_all_equal(colSums(table(fitted_ids, cat_fit$leaves[, i]) > 0), 1L)
  }

  p <- as.party(cat_fit$fit, tree = 1L, data = cat_fit$codes)
  expect_s3_class(p$data$f, "factor")
  expect_equal(levels(p$data$f), as.character(0:7))
})

test_that("as.party.xgb.Booster() validates categorical data", {
  cat_fit <- get_xgb_cat_fit()

  too_few <- cat_fit$data
  too_few$f <- factor(as.character(too_few$f), levels = letters[1:3])
  expect_snapshot(
    as.party(cat_fit$fit, tree = 1L, data = too_few),
    error = TRUE
  )

  not_factor <- cat_fit$data
  not_factor$f <- as.character(not_factor$f)
  expect_snapshot(
    as.party(cat_fit$fit, tree = 1L, data = not_factor),
    error = TRUE
  )
})

test_that("other xgb.Booster methods work with categorical predictors", {
  cat_fit <- get_xgb_cat_fit()

  expect_equal(num_ensemble_members(cat_fit$fit), 3L)

  active <- active_predictors(cat_fit$fit, tree = 1:3)
  expect_equal(active$tree, 1:3)
  expect_equal(active$active_predictors[[1]], c("f", "g", "z"))

  imp <- var_imp(cat_fit$fit)
  expect_named(imp, c("term", "estimate"))
  expect_setequal(imp$term, c("f", "g", "z"))
})
