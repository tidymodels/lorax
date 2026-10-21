#' Extract rules from a catboost model
#'
#' Extract interpretable decision rules from a single tree in a CatBoost
#' boosted tree model. Each reachable terminal node (leaf) becomes one rule
#' representing the path from root to that leaf.
#'
#' @param x A `catboost.Model` object from the \pkg{catboost} package.
#' @param tree Integer specifying which tree to extract rules from. Uses
#'   1-based indexing (default is `1L`). There is one tree per boosting
#'   iteration, including for multiclass models.
#' @param data A data frame containing the predictors used to train the model.
#'   This is only required when the tree contains categorical splits since
#'   \pkg{catboost} stores hashed values instead of the factor levels.
#' @param ... Not currently used.
#'
#' @return A tibble with class `c("rule_set_catboost.Model", "rule_set")` and
#'   columns:
#'   * `tree`: integer, the tree number (matches input parameter).
#'   * `rules`: list of R expressions, one per terminal node.
#'   * `id`: integer, terminal node ID (1-based).
#'
#' @details
#' By default, \pkg{catboost} grows symmetric (oblivious) trees where every
#' node at the same depth uses the same split. For these trees, the leaf `id`
#' corresponds to \pkg{catboost}'s leaf index plus one. Leaves that cannot be
#' reached (e.g., `cyl > 7` followed by `cyl <= 5`) are removed. For trees
#' grown with `grow_policy = "Depthwise"` or `"Lossguide"`, leaves are numbered
#' from left to right.
#'
#' Numeric splits send observations with `feature <= border` to the left and
#' `feature > border` to the right.
#'
#' ## Categorical predictors
#'
#' One-hot categorical splits (see the `one_hot_max_size` parameter) become
#' `==` or `%in%` conditions.
#'
#' Most categorical splits use target statistics (CTRs): the levels are
#' converted to numeric values based on the outcome and the split compares
#' that value to a threshold. Since each level always goes to the same side
#' of a split, the split is equivalent to a set of levels. To find these sets,
#' the CTR splits are placed in a separate model that \pkg{catboost} uses to
#' predict every level of the categorical predictor(s) in `data`. A CTR split
#' then becomes a condition such as `g %in% c("b", "c")`.
#'
#' \pkg{catboost} can also compute CTRs on combinations of features. These
#' can include several categorical predictors, binned numeric predictors (e.g.,
#' `x > 0.5`), and one-hot indicators. In this case, every combination of
#' levels is evaluated, and the rule is a set of combinations, such as
#' `(g == "a" & h %in% c("A", "B")) | (g == "b" & h == "C")`.
#'
#' Levels that were not in the training set use a prior value for the CTR.
#' The side of the split that they go to is expressed as the negation of the
#' other side (e.g., `!(g %in% c("a", "d"))`) so that the rules match how
#' \pkg{catboost} would predict new levels.
#'
#' @examples
#' if (rlang::is_installed("catboost")) {
#'   pool <- catboost::catboost.load_pool(mtcars[, -1], label = mtcars$mpg)
#'   set.seed(3926)
#'   fit <- catboost::catboost.train(
#'     pool,
#'     params = list(
#'       iterations = 3,
#'       depth = 2,
#'       thread_count = 1,
#'       logging_level = "Silent",
#'       allow_writing_files = FALSE
#'     )
#'   )
#'
#'   rules <- extract_rules(fit, tree = 1L)
#'   rules
#'
#'   rule_text(rules$rules[[1]])
#' }
#'
#' @export
extract_rules.catboost.Model <- function(x, tree = 1L, data = NULL, ...) {
  rlang::check_installed(c("catboost", "jsonlite"))
  json <- cb_model_json(x)
  tree <- cb_check_tree(tree, cb_num_trees(json))

  features <- cb_feature_info(json)
  pred_data <- NULL
  if (cb_tree_needs_data(json, tree)) {
    if (is.null(data) || !is.data.frame(data)) {
      cli::cli_abort(
        "{.arg data} must be a data frame when the tree contains categorical
         splits."
      )
    }
    pred_data <- cb_predictor_data(data, features)
  }
  ctrs <- cb_decode_ctrs(json, tree, features, pred_data)
  lvls <- cb_decode_levels(features, pred_data)
  nested <- cb_tree_to_nested(json, tree, features, ctrs)

  leaves <- cb_collect_rules(nested, lvls)
  ids <- vapply(leaves, function(leaf) leaf$id, integer(1))
  rules <- lapply(leaves, function(leaf) leaf$rule)

  tibble::tibble(
    tree = tree,
    rules = rules,
    id = ids
  ) |>
    dplyr::arrange(id) |>
    tibble::new_tibble(class = c("rule_set_catboost.Model", "rule_set"))
}

# ------------------------------------------------------------------------------

#' Convert catboost model to party object
#'
#' Convert a single tree from a \pkg{catboost} boosted tree model to a party
#' object for use with \pkg{partykit} visualization and analysis tools.
#'
#' @param obj A `catboost.Model` object from the \pkg{catboost} package.
#' @param tree Integer specifying which tree to convert (1-based indexing,
#'   default is 1).
#' @param data data.frame containing the training data **with the response
#'   variable included** (required). \pkg{catboost} models do not store the
#'   original training data or response values. The first column that is not a
#'   predictor is used as the response.
#' @param ... Not currently used.
#'
#' @return A `constparty` object from the \pkg{partykit} package.
#'
#' @details
#' The tree structure is obtained by saving the model in JSON format via
#' `catboost::catboost.save_model()`. Symmetric (oblivious) trees are expanded
#' into a binary tree and branches that cannot be reached are removed.
#'
#' Numeric splits send observations with `feature <= border` to the left
#' child. One-hot categorical splits send the matching level to the right
#' child.
#'
#' Categorical splits based on target statistics (CTRs) are converted to
#' factor splits using the approach described in
#' [extract_rules.catboost.Model()]. When a CTR uses a combination of
#' features, a factor with one level per combination is added to the data
#' (named, for example, `g:h`) and the split uses that factor.
#'
#' If the model was trained without feature names, predictors are matched to
#' the columns of `data` by position.
#'
#' @examples
#' if (rlang::is_installed("catboost")) {
#'   pool <- catboost::catboost.load_pool(mtcars[, -1], label = mtcars$mpg)
#'   set.seed(8153)
#'   fit <- catboost::catboost.train(
#'     pool,
#'     params = list(
#'       iterations = 3,
#'       depth = 2,
#'       thread_count = 1,
#'       logging_level = "Silent",
#'       allow_writing_files = FALSE
#'     )
#'   )
#'
#'   # The response is the first non-predictor column
#'   party_tree <- as.party(fit, tree = 1L, data = mtcars)
#'   print(party_tree)
#'   plot(party_tree)
#' }
#'
#' @export
as.party.catboost.Model <- function(obj, tree = 1L, data, ...) {
  rlang::check_installed(c("catboost", "jsonlite"))
  json <- cb_model_json(obj)
  tree <- cb_check_tree(tree, cb_num_trees(json))

  if (missing(data) || !is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame containing the predictors and response."
    )
  }

  features <- cb_feature_info(json)
  pred_data <- cb_predictor_data(data, features)

  if (any(features$all$unnamed)) {
    response_cols <- names(data)[-(features$all$flat_index + 1L)]
  } else {
    response_cols <- setdiff(names(data), features$all$name)
  }

  if (length(response_cols) == 0) {
    cli::cli_abort(
      "{.arg data} must contain the response variable in addition to predictors."
    )
  }
  response_name <- response_cols[1]

  ctrs <- cb_decode_ctrs(json, tree, features, pred_data)
  lvls <- cb_decode_levels(features, pred_data)
  nested <- cb_tree_to_nested(json, tree, features, ctrs)

  # CTRs on feature combinations are split on a derived factor
  for (ctr in ctrs) {
    if (!ctr$party_column %in% names(pred_data)) {
      pred_data[[ctr$party_column]] <- cb_combination_factor(ctr, pred_data)
    }
  }
  var_names <- names(pred_data)

  orig_data <- pred_data
  orig_data[[response_name]] <- data[[response_name]]

  root_node <- cb_build_partynode(nested, var_names, lvls)
  root_node <- assign_node_ids(root_node)$node

  quoted_names <- paste0("`", var_names, "`")
  formula <- stats::as.formula(paste(
    "~",
    paste(quoted_names, collapse = " + ")
  ))
  terms <- stats::terms(formula, data = orig_data)

  fitted_ids <- compute_fitted_node_ids(root_node, pred_data)
  fitted <- create_fitted_dataframe(fitted_ids, orig_data[[response_name]])

  party_obj <- create_party_object(
    node = root_node,
    data = orig_data,
    fitted = fitted,
    terms = terms,
    info = list(method = "catboost", tree = tree)
  )

  class(party_obj) <- c("constparty", "party")

  party_obj
}

# Internal helper to recursively build a partynode from the nested tree
cb_build_partynode <- function(node, var_names, lvls) {
  if (!is.null(node$leaf)) {
    return(partykit::partynode(id = 1L))
  }

  split <- node$split
  varid <- match(split$column, var_names)

  if (split$type == "float") {
    psplit <- build_partysplit(varid, split$border, right = FALSE)
  } else if (split$type == "ctr") {
    varid <- match(split$party_column, var_names)
    index <- ifelse(split$right, 2L, 1L)
    # When the only difference between the sides is where unseen levels go,
    # the training data all follow one branch
    if (all(index == 2L)) {
      return(cb_build_partynode(node$right, var_names, lvls))
    }
    if (all(index == 1L)) {
      return(cb_build_partynode(node$left, var_names, lvls))
    }
    psplit <- partykit::partysplit(varid = as.integer(varid), index = index)
  } else {
    all_levels <- lvls[[split$column]]$levels
    match_level <- cb_hash_to_level(split$hash, split$column, lvls)
    index <- rep(1L, length(all_levels))
    index[all_levels == match_level] <- 2L
    psplit <- partykit::partysplit(varid = as.integer(varid), index = index)
  }

  partykit::partynode(
    id = 1L,
    split = psplit,
    kids = list(
      cb_build_partynode(node$left, var_names, lvls),
      cb_build_partynode(node$right, var_names, lvls)
    )
  )
}

# ------------------------------------------------------------------------------
# Variable importance Wrapper

#' @export
#' @rdname lorax_var_imp
var_imp.catboost.Model <- function(object, complete = TRUE, ...) {
  rlang::check_installed("catboost")

  cl <- rlang::call2(
    "catboost.get_feature_importance",
    .ns = "catboost",
    model = quote(object),
    !!!rlang::list2(...)
  )
  imp <- rlang::eval_bare(cl)
  terms <- rownames(imp)
  if (is.null(terms)) {
    terms <- paste0("X", seq_len(nrow(imp)))
  }

  res <- tibble::tibble(
    term = terms,
    estimate = unname(imp[, 1])
  )

  # catboost reports all features (unused ones are zero), so drop them to be
  # consistent with other methods
  if (!complete) {
    res <- res[res$estimate != 0, ]
  }

  res
}

#' @rdname active_predictors
#' @export
active_predictors.catboost.Model <- function(x, tree = 1L, ...) {
  rlang::check_installed(c("catboost", "jsonlite"))

  if (!is.numeric(tree) || !all(tree == as.integer(tree))) {
    cli::cli_abort(
      "{.arg tree} must be an integer vector, not {.obj_type_friendly {tree}}."
    )
  }
  tree <- as.integer(tree)

  json <- cb_model_json(x)
  num_trees <- cb_num_trees(json)
  if (any(tree < 1L) || any(tree > num_trees)) {
    cli::cli_abort(
      "{.arg tree} values must be between 1 and {num_trees}, not {tree}."
    )
  }

  features <- cb_feature_info(json)

  results <- lapply(
    tree,
    cb_active_vars_one_tree,
    json = json,
    features = features
  )

  dplyr::bind_rows(results) |>
    dplyr::arrange(tree)
}

# Internal helper to extract active predictors from one tree
cb_active_vars_one_tree <- function(tree_num, json, features) {
  splits <- cb_tree_splits(json, tree_num)
  vars <- lapply(splits, cb_split_features, json = json, features = features)
  new_active_predictors(as.character(unlist(vars)), tree = tree_num)
}

# All raw splits in a tree (both storage formats)
cb_tree_splits <- function(json, tree) {
  if (!is.null(json$oblivious_trees)) {
    return(json$oblivious_trees[[tree]]$splits)
  }
  collect <- function(node) {
    if (is.null(node$split)) {
      return(list())
    }
    c(list(node$split), collect(node$left), collect(node$right))
  }
  collect(json$trees[[tree]])
}

# Feature names used by a raw split
cb_split_features <- function(split, json, features) {
  if (split$split_type == "FloatFeature") {
    return(cb_float_name(split$float_feature_index, features))
  }
  if (split$split_type == "OneHotFeature") {
    return(cb_cat_name(split$cat_feature_index, features))
  }
  if (split$split_type == "OnlineCtr") {
    ctr <- cb_ctr_for_split(split, json)
    res <- character(0)
    for (el in ctr$elements) {
      if (!is.null(el$cat_feature_index)) {
        res <- c(res, cb_cat_name(el$cat_feature_index, features))
      }
      if (!is.null(el$float_feature_index)) {
        res <- c(res, cb_float_name(el$float_feature_index, features))
      }
    }
    return(res)
  }
  cli::cli_abort(
    "Unknown {.pkg catboost} split type {.val {split$split_type}}."
  )
}

# CTR splits use a global split index. Splits are numbered as all float
# borders, then all one-hot values, then all CTR borders.
cb_ctr_for_split <- function(split, json) {
  info <- json$features_info
  n_float <- sum(vapply(
    info$float_features,
    function(f) length(f$borders),
    integer(1)
  ))
  n_one_hot <- sum(vapply(
    info$categorical_features,
    function(f) length(f$values),
    integer(1)
  ))
  ctr_borders <- vapply(info$ctrs, function(f) length(f$borders), integer(1))
  pos <- split$split_index - n_float - n_one_hot + 1L
  ctr_idx <- which(cumsum(ctr_borders) >= pos)[1]
  if (pos < 1 || is.na(ctr_idx)) {
    cli::cli_abort(
      "Cannot find the categorical features used by a CTR split."
    )
  }
  info$ctrs[[ctr_idx]]
}

# ------------------------------------------------------------------------------
# Internal helpers

cb_model_json <- function(x) {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  cl <- rlang::call2(
    "catboost.save_model",
    .ns = "catboost",
    model = quote(x),
    model_path = quote(path),
    file_format = "json"
  )
  rlang::eval_bare(cl)
  jsonlite::read_json(path, simplifyVector = FALSE)
}

cb_num_trees <- function(json) {
  if (!is.null(json$oblivious_trees)) {
    return(length(json$oblivious_trees))
  }
  length(json$trees)
}

cb_check_tree <- function(tree, num_trees, call = rlang::caller_env()) {
  if (!is.numeric(tree) || length(tree) != 1 || tree != as.integer(tree)) {
    cli::cli_abort(
      "{.arg tree} must be a single integer, not {.obj_type_friendly {tree}}.",
      call = call
    )
  }
  tree <- as.integer(tree)
  if (tree < 1 || tree > num_trees) {
    cli::cli_abort(
      "{.arg tree} must be between 1 and {num_trees}, not {tree}.",
      call = call
    )
  }
  tree
}

# Lookup tables for float and categorical features. `index` is the
# within-type index used by splits; `flat_index` is the column position.
cb_feature_info <- function(json) {
  to_df <- function(lst, type) {
    if (length(lst) == 0) {
      return(data.frame(
        index = integer(0),
        flat_index = integer(0),
        name = character(0),
        unnamed = logical(0),
        type = character(0)
      ))
    }
    flat_index <- vapply(lst, function(f) f$flat_feature_index, integer(1))
    name <- vapply(lst, function(f) f$feature_id %||% "", character(1))
    unnamed <- name == ""
    name[unnamed] <- paste0("X", flat_index[unnamed] + 1L)
    data.frame(
      index = vapply(lst, function(f) f$feature_index, integer(1)),
      flat_index = flat_index,
      name = name,
      unnamed = unnamed,
      type = type
    )
  }
  float <- to_df(json$features_info$float_features, "float")
  cat <- to_df(json$features_info$categorical_features, "cat")
  all <- rbind(float, cat)
  all <- all[order(all$flat_index), ]
  list(float = float, cat = cat, all = all)
}

cb_float_name <- function(index, features) {
  features$float$name[match(index, features$float$index)]
}

cb_cat_name <- function(index, features) {
  features$cat$name[match(index, features$cat$index)]
}

# Convert a raw split into a list with the feature name and split value
cb_parse_split <- function(
  split,
  features,
  ctrs,
  call = rlang::caller_env()
) {
  if (split$split_type == "FloatFeature") {
    return(list(
      type = "float",
      column = cb_float_name(split$float_feature_index, features),
      border = as.numeric(split$border)
    ))
  }
  if (split$split_type == "OneHotFeature") {
    return(list(
      type = "one_hot",
      column = cb_cat_name(split$cat_feature_index, features),
      hash = as.integer(split$value)
    ))
  }
  if (split$split_type == "OnlineCtr") {
    return(ctrs[[as.character(split$split_index)]])
  }
  cli::cli_abort(
    "Unknown {.pkg catboost} split type {.val {split$split_type}}.",
    call = call
  )
}

# Convert either tree format into a nested list where internal nodes are
# `list(split, left, right)` and leaves are `list(leaf = id)`. Branches that
# cannot be reached given the splits above them are removed.
cb_tree_to_nested <- function(
  json,
  tree,
  features,
  ctrs,
  call = rlang::caller_env()
) {
  if (!is.null(json$oblivious_trees)) {
    splits <- lapply(
      json$oblivious_trees[[tree]]$splits,
      cb_parse_split,
      features = features,
      ctrs = ctrs,
      call = call
    )
    return(cb_expand_oblivious(splits, level = 1L, leaf = 0L, state = list()))
  }
  cb_convert_nonsymmetric(
    json$trees[[tree]],
    features,
    ctrs,
    list(),
    1L,
    call
  )$node
}

# For oblivious trees, split i sets bit i - 1 of the leaf index when the
# observation goes right (`> border` or matching the one-hot level).
cb_expand_oblivious <- function(splits, level, leaf, state) {
  if (level > length(splits)) {
    return(list(leaf = as.integer(leaf) + 1L))
  }
  split <- splits[[level]]
  feasible <- cb_feasible(split, state)
  right_leaf <- leaf + 2^(level - 1)

  if (!feasible[["left"]]) {
    return(cb_expand_oblivious(splits, level + 1L, right_leaf, state))
  }
  if (!feasible[["right"]]) {
    return(cb_expand_oblivious(splits, level + 1L, leaf, state))
  }

  list(
    split = split,
    left = cb_expand_oblivious(
      splits,
      level + 1L,
      leaf,
      cb_update_state(split, state, "left")
    ),
    right = cb_expand_oblivious(
      splits,
      level + 1L,
      right_leaf,
      cb_update_state(split, state, "right")
    )
  )
}

# Non-symmetric trees: leaves are numbered left to right, including
# unreachable leaves, so that ids are stable.
cb_convert_nonsymmetric <- function(
  node,
  features,
  ctrs,
  state,
  next_id,
  call
) {
  if (is.null(node$split)) {
    return(list(node = list(leaf = next_id), next_id = next_id + 1L))
  }
  split <- cb_parse_split(node$split, features, ctrs, call = call)
  feasible <- cb_feasible(split, state)

  left <- cb_convert_nonsymmetric(
    node$left,
    features,
    ctrs,
    cb_update_state(split, state, "left"),
    next_id,
    call
  )
  right <- cb_convert_nonsymmetric(
    node$right,
    features,
    ctrs,
    cb_update_state(split, state, "right"),
    left$next_id,
    call
  )

  if (!feasible[["left"]]) {
    return(list(node = right$node, next_id = right$next_id))
  }
  if (!feasible[["right"]]) {
    return(list(node = left$node, next_id = right$next_id))
  }

  list(
    node = list(split = split, left = left$node, right = right$node),
    next_id = right$next_id
  )
}

# `state` holds, per feature, the interval (lower, upper] for numeric
# features or the known (non-)matching hashes for categorical features. For
# CTR splits, it holds the level combinations (and whether unseen levels) that
# can still reach the node.
cb_feasible <- function(split, state) {
  current <- state[[split$column]]
  if (split$type == "ctr") {
    allowed <- current$allowed %||% rep(TRUE, length(split$right))
    unseen <- current$unseen %||% !is.na(split$unseen_right)
    unseen_left <- unseen && isFALSE(split$unseen_right)
    unseen_right <- unseen && isTRUE(split$unseen_right)
    return(c(
      left = any(allowed & !split$right) || unseen_left,
      right = any(allowed & split$right) || unseen_right
    ))
  }
  if (split$type == "float") {
    lower <- current$lower %||% -Inf
    upper <- current$upper %||% Inf
    return(c(left = split$border > lower, right = split$border < upper))
  }
  eq <- current$eq
  neq <- current$neq
  if (!is.null(eq)) {
    return(c(left = eq != split$hash, right = eq == split$hash))
  }
  c(left = TRUE, right = !(split$hash %in% neq))
}

cb_update_state <- function(split, state, direction) {
  current <- state[[split$column]] %||% list()
  if (split$type == "ctr") {
    allowed <- current$allowed %||% rep(TRUE, length(split$right))
    unseen <- current$unseen %||% !is.na(split$unseen_right)
    goes_right <- direction == "right"
    current$allowed <- allowed & (split$right == goes_right)
    current$unseen <- unseen && identical(split$unseen_right, goes_right)
  } else if (split$type == "float") {
    if (direction == "left") {
      current$upper <- min(current$upper %||% Inf, split$border)
    } else {
      current$lower <- max(current$lower %||% -Inf, split$border)
    }
  } else {
    if (direction == "left") {
      current$neq <- unique(c(current$neq, split$hash))
    } else {
      current$eq <- split$hash
    }
  }
  state[[split$column]] <- current
  state
}

# Do any splits in the tree need the training data to decode levels?
cb_tree_needs_data <- function(json, tree) {
  types <- vapply(
    cb_tree_splits(json, tree),
    function(split) split$split_type,
    character(1)
  )
  any(types %in% c("OneHotFeature", "OnlineCtr"))
}

# Select the predictors from `data` in catboost's column order (by name or,
# for unnamed features, by position) and make categorical predictors factors
cb_predictor_data <- function(data, features, call = rlang::caller_env()) {
  var_names <- features$all$name
  if (any(features$all$unnamed)) {
    if (ncol(data) < nrow(features$all)) {
      cli::cli_abort(
        "{.arg data} must have at least {nrow(features$all)} columns.",
        call = call
      )
    }
    pred_data <- data[, features$all$flat_index + 1L, drop = FALSE]
    names(pred_data) <- var_names
  } else {
    if (!all(var_names %in% names(data))) {
      missing_vars <- setdiff(var_names, names(data))
      cli::cli_abort(
        "{.arg data} must contain features: {.field {missing_vars}}.",
        call = call
      )
    }
    pred_data <- data[, var_names, drop = FALSE]
  }
  pred_data <- as.data.frame(pred_data)

  for (col in features$cat$name) {
    if (!is.factor(pred_data[[col]])) {
      pred_data[[col]] <- factor(pred_data[[col]])
    }
  }
  pred_data
}

# Map hashed one-hot values back to factor levels using the training data
cb_decode_levels <- function(features, pred_data) {
  if (is.null(pred_data)) {
    return(list())
  }
  res <- list()
  for (name in features$cat$name) {
    lvls <- levels(pred_data[[name]])
    res[[name]] <- list(levels = lvls, hashes = cb_hash_strings(lvls))
  }
  res
}

cb_hash_to_level <- function(hash, column, lvls, call = rlang::caller_env()) {
  info <- lvls[[column]]
  level <- info$levels[info$hashes == hash]
  if (length(level) != 1) {
    cli::cli_abort(
      "Cannot find the level of {.field {column}} used in a split; does
       {.arg data} contain the training set levels?",
      call = call
    )
  }
  level
}

# catboost hashes factor levels to uint32 values that are stored in doubles
# via a float32 reinterpretation; the JSON model shows them as int32.
cb_hash_strings <- function(x) {
  native <- rlang::call2(
    ":::",
    rlang::sym("catboost"),
    rlang::sym("CatBoostHashStrings_R")
  )
  cl <- rlang::call2(".Call", native, as.character(x))
  hashes <- rlang::eval_bare(cl)
  readBin(writeBin(hashes, raw(), size = 4), "integer", n = length(hashes))
}

cb_collect_rules <- function(node, lvls, conditions = list()) {
  if (!is.null(node$leaf)) {
    if (length(conditions) == 0) {
      rule <- rlang::expr(TRUE)
    } else {
      rule <- combine_rule_elements(conditions)
    }
    return(list(list(id = node$leaf, rule = rule)))
  }

  split <- node$split
  left <- cb_split_expr(split, lvls, "left")
  right <- cb_split_expr(split, lvls, "right")

  c(
    cb_collect_rules(node$left, lvls, c(conditions, list(left))),
    cb_collect_rules(node$right, lvls, c(conditions, list(right)))
  )
}

cb_split_expr <- function(split, lvls, direction) {
  if (split$type == "ctr") {
    return(cb_ctr_expr(split, direction))
  }
  rect_split_to_expr(cb_split_info(split, lvls, direction))
}

cb_split_info <- function(split, lvls, direction) {
  if (split$type == "float") {
    if (direction == "left") {
      operator <- "<="
    } else {
      operator <- ">"
    }
    return(list(
      column = split$column,
      value = split$border,
      operator = operator
    ))
  }

  level <- cb_hash_to_level(split$hash, split$column, lvls)
  if (direction == "right") {
    return(list(column = split$column, value = level, operator = "=="))
  }
  other <- setdiff(lvls[[split$column]]$levels, level)
  if (length(other) == 1) {
    operator <- "=="
  } else {
    operator <- "%in%"
  }
  list(column = split$column, value = other, operator = operator)
}

# ------------------------------------------------------------------------------
# CTR splits
#
# A CTR split compares a target statistic for a categorical predictor (or a
# combination of features) to a border. Every level (or combination of levels)
# always goes to the same side, so the split is equivalent to a set of levels.
# The sets are found by putting the CTR splits into a single-tree model and
# having catboost predict every level combination; the leaf values of that
# tree are the leaf indices so that each prediction encodes the side of every
# split.

cb_decode_ctrs <- function(
  json,
  tree,
  features,
  pred_data,
  call = rlang::caller_env()
) {
  splits <- cb_tree_splits(json, tree)
  is_ctr <- vapply(splits, function(s) s$split_type == "OnlineCtr", logical(1))
  splits <- splits[is_ctr]
  if (length(splits) == 0) {
    return(list())
  }
  ids <- vapply(splits, function(s) s$split_index, integer(1))
  splits <- splits[!duplicated(ids)]

  info <- lapply(splits, function(split) {
    ctr <- cb_ctr_for_split(split, json)
    axes <- cb_ctr_axes(ctr, features, pred_data, call = call)
    grid <- cb_ctr_grid(axes)
    probe <- cb_probe_frame(axes, grid, pred_data)
    keep <- c(probe$feasible, TRUE)
    grid <- grid[probe$feasible, , drop = FALSE]
    rownames(grid) <- NULL
    list(
      split = split,
      axes = axes,
      grid = grid,
      probe = probe$probe[keep, , drop = FALSE]
    )
  })

  # Splits are probed in chunks to keep the probe tree small
  chunks <- split(seq_along(info), ceiling(seq_along(info) / 8))
  res <- list()
  for (chunk in chunks) {
    probes <- lapply(info[chunk], function(i) i$probe)
    leaves <- cb_probe_leaves(
      json,
      lapply(info[chunk], function(i) i$split),
      do.call(rbind, probes)
    )
    probe_id <- rep(seq_along(chunk), vapply(probes, nrow, integer(1)))

    for (k in seq_along(chunk)) {
      i <- info[[chunk[k]]]
      goes_right <- (leaves[probe_id == k] %/% 2^(k - 1)) %% 2 == 1
      n_grid <- nrow(i$grid)
      kinds <- vapply(i$axes, function(a) a$kind, character(1))
      if (any(kinds == "cat")) {
        unseen_right <- goes_right[n_grid + 1L]
      } else {
        unseen_right <- NA
      }
      party <- cb_ctr_party_info(i$axes, i$grid)
      res[[as.character(i$split$split_index)]] <- list(
        type = "ctr",
        column = paste0("ctr:", party$column),
        axes = i$axes,
        grid = i$grid,
        right = goes_right[seq_len(n_grid)],
        unseen_right = unseen_right,
        party_column = party$column,
        party_levels = party$levels
      )
    }
  }
  res
}

# Each element of a CTR is an "axis" with a finite set of states: the levels
# of a categorical predictor, the two sides of a numeric border, or
# matching/not matching a single level.
cb_ctr_axes <- function(ctr, features, pred_data, call = rlang::caller_env()) {
  lapply(ctr$elements, function(el) {
    type <- el$combination_element
    if (identical(type, "cat_feature_value")) {
      col <- cb_cat_name(el$cat_feature_index, features)
      return(list(
        kind = "cat",
        column = col,
        levels = levels(pred_data[[col]])
      ))
    }
    if (identical(type, "float_feature")) {
      return(list(
        kind = "float",
        column = cb_float_name(el$float_feature_index, features),
        border = as.numeric(el$border)
      ))
    }
    if (identical(type, "cat_feature_exact_value") && !is.null(el$value)) {
      col <- cb_cat_name(el$cat_feature_index, features)
      lvls <- levels(pred_data[[col]])
      level <- lvls[cb_hash_strings(lvls) == as.integer(el$value)]
      if (length(level) != 1) {
        cli::cli_abort(
          "Cannot find the level of {.field {col}} used in a split; does
           {.arg data} contain the training set levels?",
          call = call
        )
      }
      return(list(kind = "exact", column = col, level = level, levels = lvls))
    }
    cli::cli_abort(
      "Unknown {.pkg catboost} CTR element {.val {type}}.",
      call = call
    )
  })
}

cb_axis_size <- function(axis) {
  if (axis$kind == "cat") {
    return(length(axis$levels))
  }
  2L
}

# All combinations of states, as integer indices (one column per axis)
cb_ctr_grid <- function(axes) {
  states <- lapply(axes, function(a) seq_len(cb_axis_size(a)))
  names(states) <- paste0("axis_", seq_along(axes))
  expand.grid(states, KEEP.OUT.ATTRS = FALSE)
}

cb_unseen_level <- function(levels) {
  level <- "lorax_unseen_level"
  while (level %in% levels) {
    level <- paste0(level, "_")
  }
  level
}

# One row per state combination plus a final row where every categorical
# axis has a level that was not in the training set. An axis can share its
# column with another axis (e.g., two borders for the same numeric
# predictor), so the values are chosen per column and `feasible` marks the
# combinations that can actually occur.
cb_probe_frame <- function(axes, grid, pred_data) {
  states <- rbind(grid, rep(1L, length(axes)))
  n <- nrow(states)
  probe <- pred_data[rep(1L, n), , drop = FALSE]
  rownames(probe) <- NULL
  columns <- vapply(axes, function(a) a$column, character(1))

  for (col in unique(columns)) {
    idx <- which(columns == col)
    kinds <- vapply(axes[idx], function(a) a$kind, character(1))
    if (all(kinds == "float")) {
      probe[[col]] <- cb_probe_numeric(axes[idx], states[, idx, drop = FALSE])
    } else {
      values <- cb_probe_levels(axes[idx], states[, idx, drop = FALSE])
      # The last row has unseen levels for categorical axes
      if (any(kinds == "cat")) {
        values[n] <- cb_unseen_level(
          axes[idx][[which(kinds == "cat")[1]]]$levels
        )
      }
      probe[[col]] <- factor(values)
    }
  }

  actual <- lapply(axes, function(a) cb_axis_states(a, probe[[a$column]]))
  feasible <- rep(TRUE, n - 1L)
  for (i in seq_along(axes)) {
    same <- actual[[i]][-n] == states[[i]][-n]
    feasible <- feasible & !is.na(same) & same
  }
  list(probe = probe, feasible = feasible)
}

# A value inside the interval implied by the numeric borders (NA if empty)
cb_probe_numeric <- function(axes, states) {
  borders <- vapply(axes, function(a) a$border, numeric(1))
  vapply(
    seq_len(nrow(states)),
    function(r) {
      above <- states[r, ] == 2L
      lower <- max(c(-Inf, borders[above]))
      upper <- min(c(Inf, borders[!above]))
      if (lower >= upper) {
        return(NA_real_)
      }
      if (is.infinite(lower) && is.infinite(upper)) {
        return(0)
      }
      if (is.infinite(lower)) {
        return(upper - abs(upper) * 1e-4 - 1e-4)
      }
      if (is.infinite(upper)) {
        return(lower + abs(lower) * 1e-4 + 1e-4)
      }
      (lower + upper) / 2
    },
    numeric(1)
  )
}

# Levels for categorical and matching/not-matching axes on one column
cb_probe_levels <- function(axes, states) {
  kinds <- vapply(axes, function(a) a$kind, character(1))
  all_levels <- axes[[1]]$levels
  vapply(
    seq_len(nrow(states)),
    function(r) {
      if (any(kinds == "cat")) {
        i <- which(kinds == "cat")[1]
        return(axes[[i]]$levels[states[r, i]])
      }
      matches <- states[r, ] == 2L
      if (any(matches)) {
        return(axes[[which(matches)[1]]]$level)
      }
      exact <- vapply(axes, function(a) a$level, character(1))
      other <- setdiff(all_levels, exact)
      if (length(other) == 0) {
        return(cb_unseen_level(all_levels))
      }
      other[1]
    },
    character(1)
  )
}

# State of each value for an axis (NA for unseen levels or missing values)
cb_axis_states <- function(axis, values) {
  if (axis$kind == "cat") {
    return(match(as.character(values), axis$levels))
  }
  if (axis$kind == "float") {
    return(1L + (values > axis$border))
  }
  1L + (as.character(values) == axis$level)
}

# Predict leaf indices from a model containing only the given splits
cb_probe_leaves <- function(json, splits, probe) {
  n_leaves <- 2^length(splits)
  n_dim <- length(json$scale_and_bias[[2]])

  model <- json
  model$trees <- NULL
  model$oblivious_trees <- list(list(
    splits = unname(splits),
    leaf_values = as.list(rep(seq_len(n_leaves) - 1, each = n_dim)),
    leaf_weights = as.list(rep(1, n_leaves))
  ))
  model$scale_and_bias <- list(1, as.list(rep(0, n_dim)))

  path <- tempfile(fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  jsonlite::write_json(
    model,
    path,
    auto_unbox = TRUE,
    digits = NA,
    null = "null"
  )

  cl <- rlang::call2(
    "catboost.load_model",
    .ns = "catboost",
    model_path = quote(path),
    file_format = "json"
  )
  probe_model <- rlang::eval_bare(cl)

  cl <- rlang::call2(
    "catboost.load_pool",
    .ns = "catboost",
    data = quote(probe)
  )
  pool <- rlang::eval_bare(cl)

  cl <- rlang::call2(
    "catboost.predict",
    .ns = "catboost",
    model = quote(probe_model),
    pool = quote(pool),
    prediction_type = "RawFormulaVal"
  )
  pred <- rlang::eval_bare(cl)
  as.integer(round(as.matrix(pred)[, 1]))
}

# Condition for a set of states of one axis (NULL means no restriction)
cb_axis_cond <- function(axis, states) {
  states <- sort(unique(states))
  col <- rlang::sym(axis$column)
  if (axis$kind == "cat") {
    lvls <- axis$levels[states]
    if (length(lvls) == 1) {
      return(rlang::call2("==", col, lvls))
    }
    return(rlang::call2("%in%", col, lvls))
  }
  if (length(states) == 2) {
    return(NULL)
  }
  if (axis$kind == "float") {
    if (states == 1L) {
      return(rlang::call2("<=", col, axis$border))
    }
    return(rlang::call2(">", col, axis$border))
  }
  if (states == 1L) {
    return(rlang::call2("!=", col, axis$level))
  }
  rlang::call2("==", col, axis$level)
}

cb_is_call_to <- function(x, fn) {
  is.call(x) && identical(x[[1]], rlang::sym(fn))
}

cb_paren <- function(x) {
  rlang::call2("(", x)
}

# Expression for a set of state combinations (rows of the grid). States of
# the first axis with the same combinations of the remaining axes are grouped
# to keep the expression short.
cb_side_expr <- function(rows, axes) {
  first <- rows[[1]]
  axis <- axes[[1]]
  if (length(axes) == 1) {
    return(cb_axis_cond(axis, first))
  }

  rest <- rows[, -1, drop = FALSE]
  states <- sort(unique(first))
  keys <- vapply(
    states,
    function(s) {
      r <- rest[first == s, , drop = FALSE]
      paste(sort(do.call(paste, c(r, sep = ","))), collapse = ";")
    },
    character(1)
  )
  groups <- split(states, factor(keys, levels = unique(keys)))

  terms <- lapply(groups, function(g) {
    rest_expr <- cb_side_expr(rest[first == g[1], , drop = FALSE], axes[-1])
    if (cb_is_call_to(rest_expr, "|")) {
      rest_expr <- cb_paren(rest_expr)
    }
    parts <- list(cb_axis_cond(axis, g), rest_expr)
    parts <- parts[!vapply(parts, is.null, logical(1))]
    if (length(parts) == 0) {
      return(NULL)
    }
    combine_rule_elements(parts)
  })

  if (any(vapply(terms, is.null, logical(1)))) {
    return(NULL)
  }
  if (length(terms) == 1) {
    return(terms[[1]])
  }
  terms <- lapply(terms, function(x) {
    if (cb_is_call_to(x, "&")) {
      x <- cb_paren(x)
    }
    x
  })
  combine_rule_elements(unname(terms), operator = "|")
}

cb_ctr_expr <- function(split, direction) {
  goes_right <- direction == "right"
  # Unseen levels can't be listed, so their side is the negation of the other
  if (identical(split$unseen_right, goes_right)) {
    other <- split$grid[split$right != goes_right, , drop = FALSE]
    res <- cb_side_expr(other, split$axes)
    if (is.null(res)) {
      return(rlang::expr(FALSE))
    }
    return(rlang::call2("!", cb_paren(res)))
  }
  rows <- split$grid[split$right == goes_right, , drop = FALSE]
  res <- cb_side_expr(rows, split$axes)
  if (is.null(res)) {
    return(rlang::expr(TRUE))
  }
  if (cb_is_call_to(res, "|")) {
    res <- cb_paren(res)
  }
  res
}

# For as.party(): the variable to split on and its levels (one per grid row)
cb_ctr_party_info <- function(axes, grid) {
  if (length(axes) == 1) {
    return(list(column = axes[[1]]$column, levels = axes[[1]]$levels))
  }
  axis_names <- vapply(
    axes,
    function(a) {
      if (a$kind == "float") {
        return(paste0(a$column, ">", format(signif(a$border, 7))))
      }
      if (a$kind == "exact") {
        return(paste0(a$column, "==", a$level))
      }
      a$column
    },
    character(1)
  )
  state_labels <- lapply(axes, function(a) {
    if (a$kind == "cat") {
      return(a$levels)
    }
    if (a$kind == "float") {
      border <- format(signif(a$border, 7))
      return(paste0(a$column, c("<=", ">"), border))
    }
    paste0(a$column, c("!=", "=="), a$level)
  })
  labels <- lapply(seq_along(axes), function(i) state_labels[[i]][grid[[i]]])
  list(
    column = paste(axis_names, collapse = ":"),
    levels = do.call(paste, c(labels, sep = ":"))
  )
}

# Derived factor of feature combinations for a CTR split
cb_combination_factor <- function(ctr, pred_data) {
  states <- lapply(ctr$axes, function(a) {
    cb_axis_states(a, pred_data[[a$column]])
  })
  row_key <- do.call(paste, c(states, sep = ","))
  grid_key <- do.call(paste, c(ctr$grid, sep = ","))
  idx <- match(row_key, grid_key)
  factor(ctr$party_levels[idx], levels = ctr$party_levels)
}

# ------------------------------------------------------------------------------

#' @rdname num_ensemble_members
#' @export
num_ensemble_members.catboost.Model <- function(x, ...) {
  as.integer(cb_num_trees(cb_model_json(x)))
}
