#' Extract rules from an xgb.Booster model
#'
#' Extract interpretable decision rules from a single tree in an \pkg{xgboost}
#' boosted tree model. Each terminal node (leaf) becomes one rule representing
#' the path from root to that leaf.
#'
#' @inheritParams extract_rules
#' @param x An `xgb.Booster` object from the \pkg{xgboost} package.
#' @param tree Integer vector specifying which trees to extract rules from.
#'   Uses 1-based indexing (default is `1L`). For multiclass models with `num_class`
#'   classes and `nrounds` boosting rounds, there are `num_class * nrounds`
#'   total trees.
#' @param nthread Integer number of threads to use when reading the tree
#'   structure out of the model. The default (`NULL`) inherits the `nthread`
#'   the booster was trained with.
#' @param ... Not currently used.
#'
#' @return A tibble with class `c("rule_set_xgb.Booster", "rule_set")` and
#'   columns:
#'   * `tree`: integer, the tree number (matches input parameter).
#'   * `rules`: list of R expressions, one per terminal node.
#'   * `id`: integer, terminal node ID (1-based).
#'
#' @details
#' \pkg{xgboost} uses 0-based indexing internally, but this function uses 1-based
#' indexing for the `tree` parameter and output `id` column (R convention).
#'
#' Split conditions in \pkg{xgboost} follow the pattern: Yes branch when feature <
#' threshold, No branch when feature >= threshold. Rules are combinations of
#' these conditions using AND logic.
#'
#' Note: This function does not work with \pkg{xgboost} models containing categorical
#' features or non-tree boosters (`gblinear`).
#'
#' @examples
#' if (rlang::is_installed("xgboost")) {
#'   data(agaricus.train, package = "xgboost")
#'
#'   # Binary classification on a small subset for a fast example.
#'   rows <- seq_len(200)
#'   set.seed(2847)
#'   bst <- xgboost::xgb.train(
#'     data = xgboost::xgb.DMatrix(
#'       agaricus.train$data[rows, ],
#'       label = agaricus.train$label[rows],
#'       nthread = 1
#'     ),
#'     nrounds = 3,
#'     params = xgboost::xgb.params(
#'       max_depth = 3,
#'       objective = "binary:logistic",
#'       nthread = 1
#'     )
#'   )
#'
#'   # Extract rules from first tree
#'   rules <- extract_rules(bst, tree = 1L)
#'
#'   # View as text
#'   rule_text(rules$rules[[1]])
#'
#'   # Regression example
#'   data(mtcars)
#'   set.seed(8472)
#'   bst_reg <- xgboost::xgb.train(
#'     data = xgboost::xgb.DMatrix(
#'       as.matrix(mtcars[, -1]),
#'       label = mtcars$mpg,
#'       nthread = 1
#'     ),
#'     nrounds = 3,
#'     params = xgboost::xgb.params(
#'       max_depth = 3,
#'       objective = "reg:squarederror",
#'       nthread = 1
#'     )
#'   )
#'   rules_reg <- extract_rules(bst_reg, tree = 1L)
#' }
#'
#' @export
extract_rules.xgb.Booster <- function(
  x,
  tree = 1L,
  nthread = NULL,
  add_statistics = FALSE,
  ...
) {
  check_bool(add_statistics)
  rlang::check_installed("xgboost")

  if (!is.numeric(tree) || !all(tree == as.integer(tree))) {
    cli::cli_abort(
      "{.arg tree} must be an integer vector, not {.obj_type_friendly {tree}}."
    )
  }
  tree <- as.integer(tree)

  x <- xgb_apply_nthread(x, nthread)

  # Get tree structure for all requested trees in one dump
  # Note: trees parameter uses 1-based indexing (R convention)
  # but the Tree column in output uses 0-based indexing (xgboost convention)
  if (any(tree < 1L)) {
    cli::cli_abort(
      "{.arg tree} values must be >= 1."
    )
  }
  tree_dt <- as.data.frame(
    xgboost::xgb.model.dt.tree(
      model = x,
      trees = unique(tree),
      use_int_id = TRUE
    )
  )

  # Validate tree numbers against available trees
  missing_trees <- setdiff(tree - 1L, tree_dt$Tree)
  if (length(missing_trees) > 0) {
    max_tree_num <- max(
      as.data.frame(xgboost::xgb.model.dt.tree(x, use_int_id = TRUE))$Tree
    )
    cli::cli_abort(
      "{.arg tree} values must be between 1 and {max_tree_num + 1}."
    )
  }

  tree_dts <- split(tree_dt, tree_dt$Tree)

  results <- lapply(tree, function(tree_num) {
    tree_rules <- xgb_tree_rules(tree_dts[[as.character(tree_num - 1L)]])
    tree_rules$tree <- tree_num
    tree_rules
  })

  dplyr::bind_rows(results) |>
    dplyr::relocate(tree, rules, id) |>
    dplyr::arrange(tree, id) |>
    tibble::new_tibble(class = c("rule_set_xgb.Booster", "rule_set")) |>
    maybe_add_rule_statistics(add_statistics)
}

# Internal helper: override the booster's nthread setting in place. A `NULL`
# value leaves the model alone, so downstream xgboost calls reuse whatever the
# booster was trained with.
xgb_apply_nthread <- function(model, nthread) {
  if (!is.null(nthread)) {
    xgboost::xgb.model.parameters(model) <- list(nthread = nthread)
  }
  model
}

# Internal helper: rules for every leaf of one tree from a single top-down
# walk of the xgb.model.dt.tree() rows. A single-node tree gives the rule TRUE.
xgb_tree_rules <- function(tree_dt) {
  row_of <- function(node_id) match(node_id, tree_dt$Node)
  ids <- integer()
  rules <- list()

  walk <- function(node_id, exprs) {
    row <- row_of(node_id)
    if (tree_dt$Feature[row] == "Leaf") {
      ids[[length(ids) + 1L]] <<- as.integer(node_id) + 1L
      rules[[length(rules) + 1L]] <<- combine_rule_elements(exprs)
      return(invisible(NULL))
    }
    # XGBoost convention: Yes branch when feature < threshold
    children <- c(tree_dt$Yes[row], tree_dt$No[row])
    operators <- c("<", ">=")
    for (k in 1:2) {
      expr <- rect_split_to_expr(list(
        column = tree_dt$Feature[row],
        value = tree_dt$Split[row],
        operator = operators[k]
      ))
      walk(children[k], c(exprs, list(expr)))
    }
    invisible(NULL)
  }

  walk(0L, list())

  tibble::tibble(rules = rules, id = ids)
}

# ------------------------------------------------------------------------------

#' Convert xgb.Booster model to party object
#'
#' Convert a single tree from an \pkg{xgboost} boosted tree model to a party object
#' for use with \pkg{partykit} visualization and analysis tools.
#'
#' @param obj An `xgb.Booster` object from the \pkg{xgboost} package.
#' @param tree Integer specifying which tree to convert (1-based indexing,
#'   default is 1). For multiclass models with `num_class` classes and
#'   `nrounds` boosting rounds, there are `num_class * nrounds` total trees.
#' @param data data.frame containing the training data **with the response
#'   variable included** (required). XGBoost models do not store the original
#'   training data or response values. You must provide the original data frame
#'   that includes both the predictor variables and the response variable.
#' @param nthread Integer number of threads to use when reading the tree
#'   structure out of the model. The default (`NULL`) inherits the `nthread`
#'   the booster was trained with.
#' @param ... Not currently used.
#'
#' @return A `constparty` object from the \pkg{partykit} package.
#'
#' @details
#' ## Important note on data
#'
#' XGBoost models do not store the original training data or response values.
#' You **must** provide the original data frame (including the response variable)
#' via the `data` parameter for correct terminal node statistics, bar charts,
#' and other visualizations.
#'
#' ## XGBoost tree storage format
#'
#' \pkg{xgboost} stores trees in a tabular format accessible via
#' `xgboost::xgb.model.dt.tree()`. Each tree is represented as rows in a table:
#' - `Tree`: 0-based tree index (e.g., 0, 1, 2,  ...)
#' - `Node`: 0-based node ID within tree (e.g., "0-0", "0-1" for tree 0)
#' - `Feature`: Feature name (character) or "Leaf" for terminal nodes
#' - `Split`: Numeric threshold for splits (NA for leaves)
#' - `Yes`: 0-based node ID of yes branch (feature < threshold)
#' - `No`: 0-based node ID of no branch (feature >= threshold)
#' - `Missing`: 0-based node ID for missing values
#' - `Quality`: Prediction value for leaf nodes, gain for internal nodes
#'
#' ## Node indexing
#'
#' - Internally, \pkg{xgboost} uses 0-based tree and node indices
#' - User-facing `tree` parameter uses 1-based indexing (R convention)
#' - When `tree=1` is requested, we filter to `Tree==0` internally
#'
#' ## Split encoding
#'
#' - Yes branch: feature < threshold (left child)
#' - No branch: feature >= threshold (right child)
#' - \pkg{partykit} split created with `right = TRUE` (right interval closed)
#'
#' ## Child node references
#'
#' - `Yes` column: node ID for left child (< condition)
#' - `No` column: node ID for right child (>= condition)
#' - Leaf nodes have `Feature == "Leaf"`
#'
#' ## Variable names
#'
#' - `Feature` column contains actual feature names (not indices)
#' - Must map to column positions in data.frame
#' - If numeric indices used (`f0`, `f1`, ...), map to data columns
#'
#' The party object will use 1-based node IDs and variable indices as required
#' by \pkg{partykit}.
#'
#' @examples
#' if (rlang::is_installed("xgboost")) {
#'   data(agaricus.train, package = "xgboost")
#'
#'   # Binary classification example, on a small subset for a fast example.
#'   rows <- seq_len(200)
#'   train_data <- as.data.frame(as.matrix(agaricus.train$data[rows, ]))
#'   train_data$label <- agaricus.train$label[rows]
#'
#'   dtrain <- xgboost::xgb.DMatrix(
#'     agaricus.train$data[rows, ],
#'     label = agaricus.train$label[rows],
#'     nthread = 1
#'   )
#'
#'   set.seed(3691)
#'   bst <- xgboost::xgb.train(
#'     data = dtrain,
#'     nrounds = 3,
#'     verbose = 0,
#'     params = xgboost::xgb.params(
#'       max_depth = 3,
#'       objective = "binary:logistic",
#'       nthread = 1
#'     )
#'   )
#'
#'   # Convert first tree - data parameter is required
#'   party_tree <- as.party(bst, tree = 1L, data = train_data)
#'   print(party_tree)
#'   plot(party_tree)
#'
#'   # Regression example
#'   data(mtcars)
#'   reg_data <- mtcars
#'   dtrain_reg <- xgboost::xgb.DMatrix(
#'     as.matrix(mtcars[, -1]),
#'     label = mtcars$mpg,
#'     nthread = 1
#'   )
#'
#'   set.seed(9158)
#'   bst_reg <- xgboost::xgb.train(
#'     data = dtrain_reg,
#'     nrounds = 3,
#'     verbose = 0,
#'     params = xgboost::xgb.params(
#'       max_depth = 3,
#'       objective = "reg:squarederror",
#'       nthread = 1
#'     )
#'   )
#'
#'   party_tree_reg <- as.party(bst_reg, tree = 1L, data = reg_data)
#'   print(party_tree_reg)
#' }
#'
#' @export
as.party.xgb.Booster <- function(obj, tree = 1L, data, nthread = NULL, ...) {
  rlang::check_installed("xgboost")
  # Validate tree parameter
  if (!is.numeric(tree) || length(tree) != 1 || tree != as.integer(tree)) {
    cli::cli_abort(
      "{.arg tree} must be a single integer, not {.obj_type_friendly {tree}}."
    )
  }
  tree <- as.integer(tree)

  if (tree < 1) {
    cli::cli_abort(
      "{.arg tree} must be >= 1, not {tree}."
    )
  }

  obj <- xgb_apply_nthread(obj, nthread)

  # Extract all trees using xgboost API
  # This returns a data.table/data.frame with all trees
  tree_dt <- xgboost::xgb.model.dt.tree(
    model = obj,
    use_int_id = TRUE
  )

  # Convert to data.frame to avoid data.table syntax
  tree_dt <- as.data.frame(tree_dt)

  # Validate tree number against available trees
  # Tree column uses 0-based indexing
  max_tree_internal <- max(tree_dt$Tree)
  num_trees <- max_tree_internal + 1L # Convert to 1-based count
  if (tree > num_trees) {
    cli::cli_abort(
      "{.arg tree} must be between 1 and {num_trees}, not {tree}."
    )
  }

  # Filter to selected tree (convert 1-based input to 0-based internal)
  tree_internal <- tree - 1L
  tree_df <- tree_dt[tree_dt$Tree == tree_internal, ]

  if (nrow(tree_df) == 0) {
    cli::cli_abort(
      "Tree {tree} not found in model."
    )
  }

  # Get feature names from ALL trees (not just selected tree)
  # This ensures we have the complete feature set
  feature_names <- unique(tree_dt$Feature[tree_dt$Feature != "Leaf"])
  # Filter out numeric-only feature names like "f0", "f1"
  # These are default XGBoost names when no feature names provided
  if (length(feature_names) > 0 && all(grepl("^f[0-9]+$", feature_names))) {
    # Use generic names but extract count
    n_features <- length(feature_names)
    var_names <- paste0("X", seq_len(n_features))
  } else if (length(feature_names) > 0) {
    var_names <- feature_names
  } else {
    # No features found (e.g., single-node tree with no splits)
    var_names <- character(0)
  }

  # Handle single-node tree (root is leaf)
  if (nrow(tree_df) == 1 && tree_df$Feature[1] == "Leaf") {
    root_node <- partykit::partynode(id = 1L)
  } else {
    # Build partynode structure recursively from root node (Node == 0)
    root_node <- xgb_build_partynode(
      node_id = 0,
      tree_df = tree_df,
      var_names = var_names
    )

    # Assign sequential IDs
    root_node <- assign_node_ids(root_node)$node
  }

  # Validate and extract data
  # Map XGBoost feature names to data columns
  if (all(grepl("^f[0-9]+$", feature_names))) {
    # XGBoost used default names f0, f1, .. use first n columns
    if (ncol(data) < length(var_names)) {
      cli::cli_abort(
        "{.arg data} must have at least {length(var_names)} columns."
      )
    }
    orig_data <- data[, seq_len(length(var_names)), drop = FALSE]
    colnames(orig_data) <- var_names
    # Preserve any additional columns beyond features (e.g., response)
    if (ncol(data) > length(var_names)) {
      extra_cols <- names(data)[(length(var_names) + 1):ncol(data)]
      for (col in extra_cols) {
        orig_data[[col]] <- data[[col]]
      }
      response_cols <- extra_cols
    } else {
      response_cols <- character(0)
    }
  } else {
    # Use actual feature names
    if (!all(feature_names %in% names(data))) {
      missing <- setdiff(feature_names, names(data))
      cli::cli_abort(
        "{.arg data} must contain features: {.field {missing}}."
      )
    }
    # Select feature columns
    orig_data <- data[, var_names, drop = FALSE]
    # Preserve any additional columns beyond features (e.g., response)
    response_cols <- setdiff(names(data), var_names)
    for (col in response_cols) {
      orig_data[[col]] <- data[[col]]
    }
  }

  # Check that response is included
  if (length(response_cols) == 0) {
    cli::cli_abort(
      "{.arg data} must contain the response variable in addition to predictors."
    )
  }

  # Use first non-predictor column as response
  response_name <- response_cols[1]

  # Create terms object
  if (length(var_names) > 0) {
    # Quote variable names with backticks to handle special characters
    quoted_names <- paste0("`", var_names, "`")
    formula <- stats::as.formula(paste(
      "~",
      paste(quoted_names, collapse = " + ")
    ))
    terms <- stats::terms(formula, data = orig_data)
  } else {
    # No features - single-node tree
    terms <- NULL
  }

  # Create fitted values structure
  # Compute which terminal node each observation belongs to
  fitted_ids <- compute_fitted_node_ids(
    root_node,
    orig_data[, var_names, drop = FALSE]
  )

  # Get response (will be in original format)
  response <- orig_data[[response_name]]

  fitted <- create_fitted_dataframe(fitted_ids, response)

  # Create constparty object
  party_obj <- create_party_object(
    node = root_node,
    data = orig_data,
    fitted = fitted,
    terms = terms,
    info = list(method = "xgboost", tree = tree)
  )

  class(party_obj) <- c("constparty", "party")

  party_obj
}

# Internal helper to recursively build partynode from XGBoost tree table
#
# @param node_id Current node ID (0-based, XGBoost convention)
# @param tree_df Data.frame with tree structure from xgb.model.dt.tree
# @param var_names Character vector of variable names
#
# @return A partynode object
xgb_build_partynode <- function(node_id, tree_df, var_names) {
  # Find current node's row
  node_row <- tree_df[tree_df$Node == node_id, ]

  if (nrow(node_row) == 0) {
    cli::cli_abort("Node {node_id} not found in tree structure.")
  }

  # Use first matching row if duplicates
  node_row <- node_row[1, ]

  # Check if terminal node
  if (node_row$Feature == "Leaf") {
    # Terminal node - no info for constparty
    return(partykit::partynode(id = 1L))
  }

  # Internal node - get split info
  feature_name <- node_row$Feature
  split_val <- as.numeric(node_row$Split)

  # Map feature name to variable index (1-based)
  varid <- which(var_names == feature_name)
  if (length(varid) == 0) {
    # Try matching XGBoost default names to generic names
    if (grepl("^f[0-9]+$", feature_name)) {
      feature_idx <- as.integer(sub("^f", "", feature_name))
      varid <- feature_idx + 1L # Convert 0-based to 1-based
    } else {
      cli::cli_abort(
        "Feature {feature_name} not found in variable names."
      )
    }
  }

  if (varid < 1 || varid > length(var_names)) {
    cli::cli_abort(
      "Invalid variable index {varid} for feature {feature_name}."
    )
  }

  # Create split object
  # XGBoost: Yes branch when feature < threshold, No branch when feature >= threshold
  split <- build_partysplit(varid, split_val, right = TRUE)

  # Get child node IDs (0-based)
  yes_child_id <- node_row$Yes # Left child (< condition)
  no_child_id <- node_row$No # Right child (>= condition)

  # Recursively build children
  left_node <- xgb_build_partynode(yes_child_id, tree_df, var_names)
  right_node <- xgb_build_partynode(no_child_id, tree_df, var_names)

  # Return internal node
  partykit::partynode(
    id = 1L, # Will be updated by assign_node_ids
    split = split,
    kids = list(left_node, right_node),
    info = list(node_id = node_id)
  )
}

# ------------------------------------------------------------------------------
# Variable importance Wrapper

#' @export
#' @rdname lorax_var_imp
#' @param feature_names Character vector of feature names to include when
#'   `complete = TRUE`. For \pkg{xgboost} models, the model object does not
#'   store unused feature names, so this parameter allows you to specify the
#'   complete feature set. If `NULL` (default), only features that appear in
#'   at least one tree will be included.
#' @param nthread Integer number of threads to use when reading the tree
#'   structure out of the model. The default (`NULL`) inherits the `nthread`
#'   the booster was trained with.
var_imp.xgb.Booster <- function(
  object,
  complete = TRUE,
  feature_names = NULL,
  nthread = NULL,
  ...
) {
  rlang::check_installed("xgboost")
  object <- xgb_apply_nthread(object, nthread)

  # Try to get variable importance using xgboost's function
  # This returns a data.table with Feature, Gain, Cover, Frequency columns
  # Wrap in tryCatch because it can fail for models with no splits
  imp_dt <- tryCatch(
    xgboost::xgb.importance(model = object, ...),
    error = function(e) NULL
  )

  # Check if any features were used
  if (is.null(imp_dt) || nrow(imp_dt) == 0) {
    # No features used in model
    res <- tibble::tibble(
      term = character(0),
      estimate = numeric(0)
    )
  } else {
    # Convert to data.frame to avoid data.table syntax
    imp_df <- as.data.frame(imp_dt)

    # Extract Feature and Gain columns
    # Gain is the improvement in accuracy brought by a feature to the branches it is on
    res <- tibble::tibble(
      term = imp_df$Feature,
      estimate = imp_df$Gain
    )
  }

  if (complete) {
    # Determine which features to include
    if (!is.null(feature_names)) {
      # User provided feature names - use those
      pred_names <- feature_names
    } else {
      # Extract feature names from all trees
      # Note: xgboost models don't store unused features, so this will only
      # include features that appear in at least one tree
      tree_dt <- xgboost::xgb.model.dt.tree(model = object, use_int_id = TRUE)
      tree_df <- as.data.frame(tree_dt)

      # Get unique feature names (exclude "Leaf")
      pred_names <- unique(tree_df$Feature[tree_df$Feature != "Leaf"])
    }

    if (length(pred_names) > 0) {
      res <- complete_results(res, pred_names)
    }
  }

  res
}

#' @rdname active_predictors
#' @param nthread Integer number of threads to use when reading the tree
#'   structure out of an \pkg{xgboost} model. The default (`NULL`) inherits
#'   the `nthread` the booster was trained with.
#' @export
active_predictors.xgb.Booster <- function(x, tree = 1L, nthread = NULL, ...) {
  rlang::check_installed("xgboost")

  # Validate tree argument
  if (!is.numeric(tree) || !all(tree == as.integer(tree))) {
    cli::cli_abort(
      "{.arg tree} must be an integer vector, not {.obj_type_friendly {tree}}.",
      call = rlang::caller_env()
    )
  }

  tree <- as.integer(tree)

  x <- xgb_apply_nthread(x, nthread)

  # Get all trees to determine number
  tree_dt <- xgboost::xgb.model.dt.tree(x, use_int_id = TRUE)
  tree_dt <- as.data.frame(tree_dt)

  num_trees <- max(tree_dt$Tree) + 1L

  if (any(tree < 1L) || any(tree > num_trees)) {
    cli::cli_abort(
      "{.arg tree} values must be between 1 and {num_trees}, not {tree}.",
      call = rlang::caller_env()
    )
  }

  # Extract active predictors for each tree
  results <- lapply(tree, xgb_active_vars_one_tree, x = x, tree_dt = tree_dt)

  # Combine results and sort by tree
  dplyr::bind_rows(results) |>
    dplyr::arrange(tree)
}

# Internal helper to extract active predictors from one tree
xgb_active_vars_one_tree <- function(tree_num, x, tree_dt) {
  # Filter to selected tree (convert 1-based to 0-based)
  tree_df <- tree_dt[tree_dt$Tree == (tree_num - 1L), ]

  # Get non-leaf features
  features <- unique(tree_df$Feature[tree_df$Feature != "Leaf"])

  # Handle default names like "f0", "f1" - map to actual feature names
  if (length(features) > 0 && all(grepl("^f[0-9]+$", features))) {
    feature_names <- x$feature_names
    if (!is.null(feature_names)) {
      indices <- as.integer(sub("^f", "", features)) + 1L # 0-based to 1-based
      features <- feature_names[indices]
    }
  }

  new_active_predictors(features, tree = tree_num)
}

# ------------------------------------------------------------------------------

#' @rdname num_ensemble_members
#' @export
num_ensemble_members.xgb.Booster <- function(x, ...) {
  tree_dt <- xgboost::xgb.model.dt.tree(x, use_int_id = TRUE)
  as.integer(max(tree_dt$Tree) + 1L)
}
