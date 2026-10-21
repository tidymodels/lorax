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
#'   This is only required when the tree contains one-hot encoded categorical
#'   splits since \pkg{catboost} stores hashed values instead of the factor
#'   levels.
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
#' Categorical predictors are supported when \pkg{catboost} uses one-hot
#' splits (see the `one_hot_max_size` parameter). Splits based on target
#' statistics (CTRs) cannot be expressed as rules and produce an error.
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
  nested <- cb_tree_to_nested(json, tree, features)
  lvls <- cb_decode_levels(nested, features, data)

  leaves <- cb_collect_rules(nested, features, lvls)
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
#' child. Splits based on target statistics (CTRs) are not supported.
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
  var_names <- features$all$name

  if (any(features$all$unnamed)) {
    if (ncol(data) < nrow(features$all)) {
      cli::cli_abort(
        "{.arg data} must have at least {nrow(features$all)} columns."
      )
    }
    pred_data <- data[, features$all$flat_index + 1L, drop = FALSE]
    names(pred_data) <- var_names
    response_cols <- names(data)[-(features$all$flat_index + 1L)]
  } else {
    if (!all(var_names %in% names(data))) {
      missing_vars <- setdiff(var_names, names(data))
      cli::cli_abort(
        "{.arg data} must contain features: {.field {missing_vars}}."
      )
    }
    pred_data <- data[, var_names, drop = FALSE]
    response_cols <- setdiff(names(data), var_names)
  }

  if (length(response_cols) == 0) {
    cli::cli_abort(
      "{.arg data} must contain the response variable in addition to predictors."
    )
  }
  response_name <- response_cols[1]

  for (col in features$cat$name) {
    if (!is.factor(pred_data[[col]])) {
      pred_data[[col]] <- factor(pred_data[[col]])
    }
  }

  orig_data <- pred_data
  orig_data[[response_name]] <- data[[response_name]]

  nested <- cb_tree_to_nested(json, tree, features)
  lvls <- cb_decode_levels(nested, features, pred_data)

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
cb_parse_split <- function(split, features, call = rlang::caller_env()) {
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
    cli::cli_abort(
      c(
        "Splits based on categorical target statistics (CTRs) cannot be
         converted to rules.",
        i = "Increase {.code one_hot_max_size} when training so that
             categorical predictors use one-hot splits."
      ),
      call = call
    )
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
  call = rlang::caller_env()
) {
  if (!is.null(json$oblivious_trees)) {
    splits <- lapply(
      json$oblivious_trees[[tree]]$splits,
      cb_parse_split,
      features = features,
      call = call
    )
    return(cb_expand_oblivious(splits, level = 1L, leaf = 0L, state = list()))
  }
  cb_convert_nonsymmetric(json$trees[[tree]], features, list(), 1L, call)$node
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
cb_convert_nonsymmetric <- function(node, features, state, next_id, call) {
  if (is.null(node$split)) {
    return(list(node = list(leaf = next_id), next_id = next_id + 1L))
  }
  split <- cb_parse_split(node$split, features, call = call)
  feasible <- cb_feasible(split, state)

  left <- cb_convert_nonsymmetric(
    node$left,
    features,
    cb_update_state(split, state, "left"),
    next_id,
    call
  )
  right <- cb_convert_nonsymmetric(
    node$right,
    features,
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
# features or the known (non-)matching hashes for categorical features.
cb_feasible <- function(split, state) {
  current <- state[[split$column]]
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
  if (split$type == "float") {
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

cb_has_one_hot <- function(node) {
  if (!is.null(node$leaf)) {
    return(FALSE)
  }
  node$split$type == "one_hot" ||
    cb_has_one_hot(node$left) ||
    cb_has_one_hot(node$right)
}

# Map hashed one-hot values back to factor levels using the training data
cb_decode_levels <- function(
  nested,
  features,
  data,
  call = rlang::caller_env()
) {
  if (!cb_has_one_hot(nested)) {
    return(list())
  }
  if (is.null(data) || !is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame when the tree contains categorical
       splits.",
      call = call
    )
  }

  res <- list()
  for (i in seq_len(nrow(features$cat))) {
    name <- features$cat$name[i]
    if (features$cat$unnamed[i]) {
      col <- data[[features$cat$flat_index[i] + 1L]]
    } else {
      if (!name %in% names(data)) {
        cli::cli_abort(
          "{.arg data} must contain features: {.field {name}}.",
          call = call
        )
      }
      col <- data[[name]]
    }
    if (is.factor(col)) {
      lvls <- levels(col)
    } else {
      lvls <- sort(unique(as.character(col)))
    }
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

cb_collect_rules <- function(node, features, lvls, conditions = list()) {
  if (!is.null(node$leaf)) {
    if (length(conditions) == 0) {
      rule <- rlang::expr(TRUE)
    } else {
      rule <- combine_rule_elements(conditions)
    }
    return(list(list(id = node$leaf, rule = rule)))
  }

  split <- node$split
  left <- cb_split_info(split, lvls, "left")
  right <- cb_split_info(split, lvls, "right")

  c(
    cb_collect_rules(
      node$left,
      features,
      lvls,
      c(conditions, list(rect_split_to_expr(left)))
    ),
    cb_collect_rules(
      node$right,
      features,
      lvls,
      c(conditions, list(rect_split_to_expr(right)))
    )
  )
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
