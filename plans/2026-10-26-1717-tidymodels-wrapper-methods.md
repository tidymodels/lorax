# Tidymodels wrapper methods (`model_fit`, `workflow`)

## Overview

Context: lorax defines five generics with per-engine S3 methods: `extract_rules()`, `active_predictors()`, `num_ensemble_members()` (lorax), `as.party()` (partykit, first arg `obj`), and `var_imp()` (generics, first arg `object`). Users with parsnip `model_fit` or `workflow` objects must currently call `extract_fit_engine()` by hand. Add methods for both classes on all five generics that unwrap with `generics::extract_fit_engine()` and re-dispatch on the engine object.

Design: use two small internal helpers and one-line methods that forward `...`. Every engine-specific argument (`tree`, `chain`, `committee`, `add_statistics`, `data`, `nthread`, `complete`, ...) already flows through `...`, so no argument duplication is needed and engine methods keep owning validation. Only the first-argument name differs per generic (`x`, `obj`, `object`).

Notes:
- `generics` is already in Imports, so `extract_fit_engine` is available without a new dependency. `parsnip` is already in Suggests; add `workflows` to Suggests (tests only).
- `workflow` objects must be fitted; `extract_fit_engine.workflow()` errors otherwise, which is the desired behavior.
- `as.party()` for xgboost/lightgbm/catboost/C5.0/etc. requires `data`; the user supplies it via `...` (for workflows this is the baked/processed data, documented in the roxygen note).
- Single-tree engines still have no `num_ensemble_members` method, so the unwrapped dispatch gives the normal "no applicable method" error.

## Checklist

- [ ] Copy this plan to `plans/2026-10-26-{hhmm}-tidymodels-wrapper-methods.md` in the repo (per CLAUDE.md naming; plan mode blocked writing there)
- [ ] Create `R/tidymodels.R` with helper `extract_engine(x)` (calls `generics::extract_fit_engine(x)`, no inline conditionals) and `@export` methods: `extract_rules.model_fit`, `extract_rules.workflow`, `active_predictors.model_fit`, `active_predictors.workflow`, `num_ensemble_members.model_fit`, `num_ensemble_members.workflow`, `as.party.model_fit`, `as.party.workflow`, `var_imp.model_fit`, `var_imp.workflow`
- [ ] Each method body: `UseGeneric(extract_engine(x), ...)`, e.g. `extract_rules.model_fit <- function(x, ...) extract_rules(extract_engine(x), ...)`; `as.party` uses `obj`, `var_imp` uses `object`
- [ ] Roxygen: one shared `@rdname` topic (e.g. `tidymodels-methods`) with `@inheritParams`, a short description, and an example guarded by `rlang::is_installed(c("parsnip", "rpart"))`; add topic to `_pkgdown.yml`
- [ ] DESCRIPTION: add `workflows` to Suggests
- [ ] `devtools::document()`; confirm NAMESPACE gains the 10 `S3method()` lines
- [ ] Tests in `tests/testthat/test-tidymodels.R`: for a parsnip `decision_tree`/`rand_forest` (ranger) `model_fit` and a fitted `workflow`, check each generic equals the result on `extract_fit_engine(fit)`, that `tree`/`add_statistics` pass through, and use `expect_snapshot(error = TRUE)` for an unfitted workflow; skip if parsnip/workflows/engines not installed
- [ ] NEWS.md bullet (no function name → place at top, unwrapped line)
- [ ] `air format .`, `pkgdown::check_pkgdown()`
- [ ] Run `devtools::test(filter = "tidymodels")` then full `devtools::test()`
- [ ] Leave all work uncommitted (no commit/push/PR without explicit request)

## Critical files

- `R/generics.R` (generic definitions, signature reference)
- `R/tidymodels.R` (new)
- `tests/testthat/test-tidymodels.R` (new)
- `DESCRIPTION`, `NEWS.md`, `_pkgdown.yml`, `NAMESPACE` (generated)

## Verification

```
Rscript -e "devtools::document()"
Rscript -e "devtools::test(filter = 'tidymodels')"
Rscript -e "devtools::test()"
Rscript -e "pkgdown::check_pkgdown()"
```

Manual: fit `parsnip::rand_forest() |> set_engine("ranger") |> set_mode("regression") |> fit(mpg ~ ., mtcars)`, wrap in a workflow, and call `extract_rules(x, tree = 2)`, `active_predictors()`, `num_ensemble_members()`, `var_imp()` on both.
