# Remove directly executable catboost code for CRAN

## Overview

\pkg{catboost} is not on CRAN, so R CMD check on CRAN must not see any static `catboost::fun()` call in code it scans (R code, examples, tests). Calls built with `rlang::call2(..., .ns = "catboost")` plus `rlang::eval_bare()` are fine. Non-test code in `R/` already follows this pattern. The remaining direct calls are in the roxygen examples and in the tests. The examples will move to an Rmd file included in the Details section, so the code is shown but never run by check.

## Checklist

- [x] Create `man/_rmd/catboost.Rmd` with the two example workflows (rules and party) and static prose
- [x] Replace the `@examples` blocks in `R/catboost.Model.R` (lines ~58-77 and ~165-) with `@includeRmd man/_rmd/catboost.Rmd` in `@details`
- [x] Add `^man/_rmd$` to `.Rbuildignore`
- [x] Reword the prose at `R/catboost.Model.R:149` so `catboost::catboost.save_model()` is not inside `\code{}` as a call (e.g. "`catboost.save_model()` from \pkg{catboost}")
- [x] Add a test helper (e.g. `cb_call()` in `tests/testthat/helper-catboost.R`) that wraps `rlang::call2(fn, ..., .ns = "catboost")` and `rlang::eval_bare()`
- [x] Replace the direct `catboost::` calls in `helper-catboost.R` (lines 5, 14, 64, 69) and `test-catboost.Model.R:293` with the helper
- [x] Confirm `knitr`/`rmarkdown` are available for `devtools::document()` (already in or add to Suggests/`Config/Needs`)
- [x] Re-document, then check that `man/*.Rd` has no `\examples` for catboost and no `catboost::` outside `\code{}` text
- [x] CI: keep catboost install for R-CMD-check and test-coverage (tests still use it); the pkgdown workflow no longer needs it because the Rmd output is pre-rendered
- [x] Verify with catboost uninstalled (see Verification)

## Details

### Findings

- No `catboost` in DESCRIPTION (no Suggests, Remotes, or Additional_repositories) and no `importFrom(catboost, ...)` in NAMESPACE. Keep it that way.
- `R/catboost.Model.R`: the executable references are the two `@examples` blocks (`catboost.load_pool`, `catboost.train`) and the generated copies in `man/extract_rules.catboost.Model.Rd` and `man/as.party.catboost.Model.Rd`. The helper code at lines ~305, 442, 1117-1132 and the `:::` hash call at 782-787 are already built with `call2()`.
- Tests: `helper-catboost.R` and `test-catboost.Model.R:293` use `catboost::` directly. R CMD check scans tests for undeclared dependencies, so these need the same indirection.
- `skip_if_not_installed("catboost")` and `rlang::check_installed("catboost")` take strings and are fine.

### Rmd file

- Chunks run at `devtools::document()` time, so the maintainer needs catboost installed locally. Output is embedded in the Rd, so users and CRAN never run it.
- Use a fixed seed and `logging_level = "Silent"`, `allow_writing_files = FALSE` as in the current examples.
- One file, two sections (rules, party), included from both methods. If duplicating the whole file in both help pages is too long, split into two Rmd files instead.
- roxygen2 8.1.0 (already in DESCRIPTION) supports `@includeRmd`; markdown is already enabled.

### Other areas that need to change

- `.Rbuildignore`: add `^man/_rmd$` so the Rmd source is not in the tarball.
- `_pkgdown.yml`: no change needed; the reference topics already exist.
- `NEWS.md`: no bullet needed (no user-facing behavior change). Optional note if the examples are called out.
- `README.md`: keep the support table; consider noting catboost must be installed from GitHub.
- `inst/WORDLIST`: add any new words the Rmd introduces (spelling test).
- `cran-comments.md`: mention that catboost is not on CRAN and all use is guarded and indirect.

## Verification

1. `Rscript -e "devtools::document()"` with catboost installed, then inspect the Details sections of both help pages.
2. `grep -rn "catboost::" R tests man vignettes` returns only prose or the Rmd source (none in `R/` code, tests, or `\examples`).
3. Uninstall or hide catboost (e.g. a temporary library path without it) and run `devtools::check()`; expect no "unstated dependencies" or "'::' import not declared" notes and the catboost tests skipped.
4. Run `devtools::test(filter = "catboost")` with catboost installed to confirm the helper change preserves results and snapshots.
5. `R CMD build` and confirm `man/_rmd` is absent from the tarball.
6. `air format .` and `pkgdown::check_pkgdown()`.
