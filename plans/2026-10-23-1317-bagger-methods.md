# Methods for baguette bagged trees (CART and C5.0)

## Overview

baguette fits bagged trees through `parsnip::bag_tree()` (engines "rpart" and "C5.0"). `baguette::bagger()` is an S3 generic, not the spec constructor. The fitted engine object (`fit$fit`) has class `c("bagger", "hardhat_model", "hardhat_scalar")`. lorax dispatches only on raw engine classes, so the new methods are `*.bagger` and take the engine object, not the parsnip `model_fit`.

Structure of a `bagger` object (verified locally with baguette, rpart and C50 installed):

- `model_df`: tibble with list column `model`, one row per member. Each element is a parsnip `model_fit`, and `$fit` is a butchered `rpart` or `C5.0` object.
- `imp`: tibble with `term`, `value`, `std.error`, `used`.
- `base_model`: `c("CART", <mode>)` or `c("C5.0", <mode>)`, which tells the engines apart.
- Each C5.0 member has `trials["Actual"] == 1`.
- Butchered rpart keeps `frame` and `splits`, but `xlevels` is an attribute, not a list element, and `call$data` is a dummy.

Members are single trees, so the `tree` argument is the member index, as for `randomForest`.

## Checklist

- [x] Copy this plan to `plans/2026-10-23-{hhmm}-bagger-methods.md` in the repo (plan mode only lets me write the auto-named file) and reference it in the issue
- [x] Fix `rpart_get_factor_levels()` in `R/rpart.R` to also read `attr(x, "xlevels")`
- [x] Add `R/bagger.R` with `num_ensemble_members.bagger`, `active_predictors.bagger`, `extract_rules.bagger`, `var_imp.bagger`
- [x] Add `baguette` and `parsnip` to Suggests in `DESCRIPTION`
- [x] Add tests in `tests/testthat/test-bagger.R` (snapshots) and a rpart categorical-xlevels test in `test-rpart.R`
- [x] Add a `NEWS.md` bullet and any new words to `inst/WORDLIST`
- [x] `devtools::document()`, `air format .`, run tests, `devtools::check()`

## Details

### `R/bagger.R`

Internal helpers:

- `bagger_members(x)`: `x$model_df$model`.
- `bagger_member_fit(x, i)`: `x$model_df$model[[i]]$fit`.
- `bagger_check_tree(tree, x)`: same validation as `extract_rules.randomForest` (integer-valued, within `1:num_ensemble_members(x)`), using `cli::cli_abort`.
- `bagger_engine(x)`: `x$base_model[1]`, either `"CART"` or `"C5.0"`. Abort for anything else.

Methods (each with `rlang::check_installed("baguette")` and roxygen via `@rdname`, no new topics):

- `num_ensemble_members.bagger`: `nrow(x$model_df)` as an integer. Update the roxygen description of the generic in `R/generics.R` to mention bagged trees.
- `active_predictors.bagger(x, tree = 1L, ...)`: for each requested member call `active_predictors()` on the member fit (rpart or C5.0 method) and rebuild with `new_active_predictors(vars, tree = i)`, following `rf_extract_one`. Check what `new_active_predictors()` accepts before reusing the single-tree result.
- `extract_rules.bagger(x, tree = 1L, add_statistics = FALSE, ...)`: call `extract_rules()` on each member fit, set the `tree` column to the member index (C5.0 already has one, rpart does not), `bind_rows`, arrange by `tree` then `id`, then `maybe_add_rule_statistics()`. Keep the engine-specific `rule_set_*` class in addition to `rule_set`, matching what the per-engine method returns.
- `var_imp.bagger(object, complete = TRUE, ...)`: use `object$imp` (`term`, `value` renamed to `estimate`), and complete over predictor names from `object$blueprint` when `complete = TRUE`. Check how `complete_results()` and `terms_predictor_names()` work to choose the predictor source, since there is no `terms` object.

Out of scope: `as.party.bagger` (no `as.party` for rpart in lorax) and methods on the parsnip `model_fit`.

### `R/rpart.R` fix

`rpart_get_factor_levels()` checks `x$xlevels`, which is NULL for real rpart objects and falls through to a data lookup that fails for butchered models. Add `attr(x, "xlevels")` as the first source. This also fixes categorical splits for plain `rpart` fits with a dummy call.

### Tests

- Use `skip_on_cran()` and `skip_if_not_installed()` for `baguette`, `parsnip`, `rpart`, `C50`, per existing files.
- Fit small models (`times = 3`) with `set.seed()`. Use mixed-type data (`get_wa_trees_data()`) so categorical splits are covered, plus a regression fit.
- Use `expect_snapshot()` for rule output and `expect_snapshot(error = TRUE)` for bad `tree` values (no `expect_error()`), per CLAUDE.md.
- Cover: `num_ensemble_members` equals `times`, multi-tree `extract_rules` has the right `tree` values, `add_statistics`, `active_predictors` for a vector of trees, `var_imp` with and without `complete`, and both engines.

### Docs and housekeeping

- `NEWS.md`: one bullet under "lorax (development version)", placed alphabetically by function name (the new methods mention `extract_rules()` and others), no line wrapping, with the issue number.
- `_pkgdown.yml` has no reference index, so no change.
- Per CLAUDE.md, no commit, push or PR unless explicitly asked.

## Verification

- `Rscript -e "devtools::test(filter = '^bagger')"` and `filter = '^rpart'`
- `Rscript -e "devtools::test()"` for the full suite
- Check by hand that `extract_rules(bag_fit$fit, tree = 1:2)` for both engines matches `extract_rules()` on the member fits
- `Rscript -e "devtools::document()"`, `air format .`, `Rscript -e "devtools::check()"`

## Follow-up (2026-10-23)

- [x] Add `as.party.bagger()` (rpart members use `partykit::as.party.rpart()` after rebuilding the model frame and node assignments from user-supplied `data`; C5.0 members delegate to `as.party.C5.0()`)
- [x] Drop `var_imp.bagger()`: baguette already registers a `var_imp.bagger` method (returns `object$imp`), and lorax's version overwrote it on load
