# Test data helpers
# These functions create test datasets for various scenarios

# Get penguins data (classification with numeric predictors)
get_penguins_data <- function() {
  skip_if_not_installed("palmerpenguins")
  data("penguins", package = "palmerpenguins", envir = environment())
  penguins <- get("penguins", envir = environment())
  na.omit(penguins[, c(
    "species",
    "bill_length_mm",
    "bill_depth_mm",
    "flipper_length_mm",
    "body_mass_g"
  )])
}

# Get mtcars data (regression with numeric predictors)
get_mtcars_data <- function() {
  mtcars
}

# Get wa_trees data (mixed predictors with factors)
get_wa_trees_data <- function() {
  load(system.file(package = "lorax", "wa_trees.RData"), envir = environment())
  get("wa_trees", envir = environment())
}

# Create binary classification data with predictive ability
get_binary_data <- function() {
  skip_if_not_installed("modeldata")
  set.seed(487)
  data <- modeldata::sim_classification(100, num_linear = 3)
  # Rename class to y for consistency
  names(data)[names(data) == "class"] <- "y"
  data
}

# Create regression data with predictive ability
get_regression_data <- function() {
  skip_if_not_installed("modeldata")
  set.seed(487)
  data <- modeldata::sim_regression(100)
  # Rename outcome to y for consistency
  names(data)[names(data) == "outcome"] <- "y"
  data
}

# Get penguins data with factor predictors
get_factor_data <- function() {
  skip_if_not_installed("palmerpenguins")
  data("penguins", package = "palmerpenguins", envir = environment())
  penguins <- get("penguins", envir = environment())
  # Use species as outcome and island, sex as predictors
  data <- na.omit(penguins[, c(
    "species",
    "island",
    "sex",
    "bill_length_mm",
    "bill_depth_mm"
  )])
  names(data)[names(data) == "species"] <- "y"
  data
}

# Get penguins forest for ObliqueForest tests
get_penguins_forest <- function() {
  skip_if_not_installed("aorsf")
  skip_if_not_installed("palmerpenguins")
  penguins <- palmerpenguins::penguins[
    complete.cases(palmerpenguins::penguins),
  ]
  set.seed(487) # Ensure reproducible forest structure
  aorsf::orsf(species ~ ., data = penguins, n_tree = 10, n_thread = 1)
}

# Get penguins tree for party tests
get_penguins_tree <- function() {
  skip_if_not_installed("partykit")
  skip_if_not_installed("palmerpenguins")
  penguins <- palmerpenguins::penguins
  partykit::ctree(species ~ ., data = penguins)
}

# Get penguins rpart tree for rpart tests
get_penguins_rpart_tree <- function() {
  skip_if_not_installed("rpart")
  skip_if_not_installed("palmerpenguins")
  data("penguins", package = "palmerpenguins", envir = environment())
  penguins <- get("penguins", envir = environment())
  penguins <- na.omit(penguins)
  rpart::rpart(species ~ ., data = penguins)
}

# Get penguins data with single numeric predictor
get_single_numeric_data <- function() {
  skip_if_not_installed("palmerpenguins")
  data("penguins", package = "palmerpenguins", envir = environment())
  penguins <- get("penguins", envir = environment())
  # Use species as outcome and flipper_length_mm as single numeric predictor
  data <- na.omit(penguins[, c("species", "flipper_length_mm")])
  names(data)[names(data) == "species"] <- "y"
  names(data)[names(data) == "flipper_length_mm"] <- "x"
  data
}

# Get penguins data with single factor predictor
get_single_factor_data <- function() {
  skip_if_not_installed("palmerpenguins")
  data("penguins", package = "palmerpenguins", envir = environment())
  penguins <- get("penguins", envir = environment())
  # Use species as outcome and island as single factor predictor
  data <- na.omit(penguins[, c("species", "island")])
  names(data)[names(data) == "species"] <- "y"
  names(data)[names(data) == "island"] <- "x"
  data
}

# Cubist-specific test helpers

# Get Ames housing data for Cubist regression tests
get_ames_data <- function(n = 200) {
  skip_if_not_installed("modeldata")
  data("ames", package = "modeldata", envir = environment())
  ames <- get("ames", envir = environment())

  # Select relevant numeric and factor predictors
  # Focus on variables likely to affect house price
  ames_subset <- ames[
    1:min(n, nrow(ames)),
    c(
      "Sale_Price", # outcome
      "Gr_Liv_Area", # numeric: above grade living area
      "Year_Built", # numeric: original construction date
      "Overall_Cond", # ordinal: overall condition
      "Garage_Cars", # numeric: size of garage in car capacity
      "Total_Bsmt_SF", # numeric: total basement area
      "Neighborhood", # factor: physical location
      "Bldg_Type" # factor: type of dwelling
    )
  ]

  # Convert to data frame and ensure no NAs
  ames_subset <- na.omit(as.data.frame(ames_subset))

  # Separate predictors and outcome
  list(
    x = ames_subset[, -1],
    y = ames_subset[, 1]
  )
}

# Get Sacramento housing data for Cubist regression tests
get_sacramento_data <- function() {
  skip_if_not_installed("modeldata")
  data("Sacramento", package = "modeldata", envir = environment())
  sacramento <- get("Sacramento", envir = environment())

  # price is the outcome, all others are predictors
  list(
    x = sacramento[, c("beds", "baths", "sqft", "type", "city")],
    y = sacramento$price
  )
}

# Get simple regression data with clear structure for testing splits
get_structured_regression_data <- function(n = 100) {
  set.seed(42)
  X <- data.frame(
    x1 = runif(n, 0, 10),
    x2 = runif(n, 0, 10),
    x3 = factor(sample(c("A", "B", "C"), n, replace = TRUE))
  )

  # Create outcome with clear conditional structure
  # This ensures Cubist will create meaningful splits
  y_high_x1 <- ifelse(X$x2 > 5, X$x1 + X$x2, X$x1 - X$x2)
  y_low_x1 <- ifelse(X$x3 == "A", 2 * X$x2, X$x1 + 3)
  y <- ifelse(X$x1 > 5, y_high_x1, y_low_x1)
  y <- y + rnorm(n, sd = 0.5)

  list(x = X, y = y)
}

# Get data that produces simple models (for edge case testing)
get_simple_cubist_data <- function(n = 10) {
  set.seed(123)
  # Very simple linear relationship, likely to produce single rule
  x <- data.frame(x1 = seq(1, n))
  y <- x$x1 + rnorm(n, sd = 0.01)
  list(x = x, y = y)
}

# Get high-dimensional data for testing edge cases
get_high_dim_cubist_data <- function(n = 20, p = 50) {
  set.seed(456)
  x <- matrix(rnorm(n * p), n, p)
  colnames(x) <- paste0("x", 1:p)
  # Only first two predictors are relevant
  y <- x[, 1] + 0.5 * x[, 2] + rnorm(n, sd = 0.1)
  list(x = as.data.frame(x), y = y)
}

# Get noisy data where predictors have little relationship with outcome
# Used specifically for testing "no valid splits" scenarios
get_noisy_cubist_data <- function(n = 100, p = 5) {
  set.seed(789)
  x <- matrix(rnorm(n * p), n, p)
  colnames(x) <- paste0("x", 1:p)
  y <- rnorm(n) # Completely independent of x
  list(x = as.data.frame(x), y = y)
}

# Get data and a lightgbm model with categorical predictors. Factors are
# encoded as 0-based integer codes (bonsai's convention).
get_lgb_cat_fit <- function() {
  skip_if_not_installed("lightgbm")
  set.seed(8317)
  n <- 1000
  data <- data.frame(
    f = factor(sample(letters[1:8], n, replace = TRUE)),
    g = factor(sample(c("u", "v"), n, replace = TRUE)),
    z = rnorm(n)
  )
  data$y <- c(0, 5, 0, 5, 5, 0, 5, 0)[as.integer(data$f)] +
    2 * (data$g == "v") +
    data$z +
    rnorm(n)

  codes <- data
  codes$f <- as.integer(codes$f) - 1L
  codes$g <- as.integer(codes$g) - 1L
  x <- as.matrix(codes[, c("f", "g", "z")])

  bst <- lightgbm::lgb.train(
    params = list(
      objective = "regression",
      max_depth = 3,
      num_threads = 1L,
      max_cat_to_onehot = 1,
      min_data_per_group = 5,
      cat_smooth = 1
    ),
    data = lightgbm::lgb.Dataset(
      x,
      label = data$y,
      categorical_feature = c("f", "g")
    ),
    nrounds = 3,
    verbose = -1
  )

  list(
    fit = bst,
    data = data,
    codes = codes,
    leaves = predict(bst, x, type = "leaf") + 1L
  )
}

# Terminal node ID from a rule set for each row of `data`
rule_node_ids <- function(rules, data) {
  hits <- vapply(rules$rules, \(e) eval(e, data), logical(nrow(data)))
  rules$id[max.col(hits)]
}
