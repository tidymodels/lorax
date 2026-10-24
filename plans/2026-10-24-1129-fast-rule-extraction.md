# Speed up rule extraction

## Overview

`extract_rules()` is extremely slow for every method that goes through `extract_rules.party()`: ranger, randomForest, C5.0, grf, cforest, and party/ctree itself. Timing on small models (300 rows, 8 predictors) before any change:

| Method | Time |
|---|---|
| ranger (2 trees, ~60 leaves each) | 115 s |
| randomForest (2 trees) | 422 s |
| xgboost, lightgbm, rpart, ctree, C5.0, Cubist | under 0.1 s |

Profiling one ranger tree: `ranger::treeInfo()` takes 0.00 s, `as.party()` takes 0.11 s, and `extract_rules.party()` takes 28 s. The cause is in `R/party.R`. For every leaf, `party_build_node_path()` walks up to the root, and each step calls `party_find_parent()`. That function loops over all internal nodes and calls `partykit::nodeapply()` on each one. The cost is therefore roughly leaves × depth × nodes × `nodeapply` overhead.

## Prototype result

A prototype in the scratchpad (`/private/tmp/claude-501/-Users-max-github-lorax/d4f7d71f-615d-4f30-abf8-9e4ddc39fdd1/scratchpad/proto.R`) replaces the per-leaf path building with a single top-down recursive walk of the `partynode` tree. The walk carries the list of split expressions down to each leaf and then calls `combine_rule_elements()`.

- Output is `identical()` to the current implementation, on a ranger tree that includes a factor predictor and on a `ctree` fit.
- The 59-leaf tree went from 17.5 s to 0.02 s.
- A 599-node tree takes 0.04 s.

## Checklist

- [x] Replace the body of `extract_rules.party()` in `R/party.R` with the single-pass walk. Reuse `rect_split_to_expr()` and `combine_rule_elements()` so the expressions stay unchanged.
- [x] Remove `party_extract_node_rule()`, `party_build_node_path()`, `party_find_parent()`, and `party_get_split_info()` if nothing else uses them. Grep first, because `tests/testthat/test-party.R` may call them directly.
- [x] Confirm the existing tests and snapshots for party, ranger, randomForest, C5.0, grf, and cforest pass unchanged.
- [x] Add a test that checks every training row matches exactly one rule and that the rule's id equals `predict(type = "node")`, on a tree with numeric and factor splits. The existing single-node test covers rule `TRUE`.
- [x] Make the all-trees case the benchmark target, because for ensembles users will usually want every tree. Time `extract_rules(x, tree = seq_len(num_ensemble_members(x)))` for each ensemble method.
- [x] Skip the fitted-value computation when extracting rules from ranger and randomForest. `compute_fitted_node_ids()` and `traverse_to_terminal()` in `R/helpers_party.R` classify one row at a time, so every tree pays nrow × depth. In the prototype, `as.party()` took 1.9 s for a single 6,000-row tree, which would be about 15 minutes for 500 trees. `ranger_extract_rules_one()` and the randomForest equivalent don't use the fitted values, so build the `partynode` tree and walk it directly.
- [x] For xgboost and lightgbm, make one `xgb.model.dt.tree()` call (or the lightgbm equivalent) for the whole `tree` vector and split the result by tree. Right now each tree triggers its own dump.
- [x] Check that `extract_rules.xgb.Booster()` and `extract_rules.lgb.Booster()` accept a vector `tree`, and add that if they don't. Both currently validate `length(tree) == 1`.
- [x] Replace the repeated `dplyr::bind_rows()` and `arrange()` over per-tree results with a single pass, and confirm it doesn't dominate at 500+ trees.
- [ ] Apply the same single-pass idea to the other per-leaf `*_find_parent` implementations in `R/xgb.Booster.R`, `R/ObliqueForest.R`, `R/lgb.Booster.R`, `R/bart.R`, and `R/rpart.R`. They are fast on small models but quadratic in the number of nodes. Benchmark with deep trees first and change only the ones that are measurably slow.
- [x] Add a `NEWS.md` bullet for the speedup. It is user-facing, so it should name `extract_rules()`.
- [x] Run `air format .` and `devtools::test()`.

## Details

- The ID order must stay the same. The current code sorts by `id`, and the prototype sorts the collected IDs the same way.
- Keep the `rule_set_party` / `rule_set` tibble class and the `maybe_add_rule_statistics()` call.
- Benchmarks should go in the scratchpad rather than the package. If the user wants a lasting benchmark script, put it under `inst/` or `tests/` only after asking.
- No commits or pushes without a direct request.

## Progress notes

- 20 trees, 2,000 rows: ranger 115 s → 1.7 s (extrapolated from the earlier 2-tree run), randomForest 422 s → 1.7 s. `ranger_build_partynode_from_info()` now uses `match()` instead of subsetting the data frame per node.
- `test-party.R` is still skipped ("TOOOO LONG") because the tests fit `ctree` on the full `wa_trees` data. The new test sits above the skip and runs.
- xgboost and lightgbm now take a vector `tree`, dump the model once, and walk each tree top-down. Output is `identical()` to the old per-tree calls. 50 lightgbm trees: 6.8 s → 0.25 s. 40 xgboost trees: 1.2 s → 0.19 s.
- `bind_rows()` is called once per extraction and was not a bottleneck, so I left it.
- Benchmarked and fixed the remaining methods. All outputs are `identical()` to the old code unless noted.
  - rpart (430-leaf tree): 4.1 s → 0.12 s. The splits-matrix row for each node is now precomputed.
  - grf (10 trees, 1,000 rows): 661 s → 0.25 s. It now skips fitted values like ranger. This also fixes an existing error for matrices without column names, which the old code could not handle, so that case has no old output to compare against.
  - bart (100 trees × 2 chains): 7.6 s → 0.19 s. Takes a vector `tree` and calls `getTrees()` once.
  - catboost (100 trees, symmetric and depthwise, with categorical splits): 0.6–1.1 s → 0.17 s. Takes a vector `tree` and exports the model once.
  - aorsf/ObliqueForest (20 trees): 1.5 s → 0.39 s. Takes a vector `tree` and caches the slow R6 accessors.
- C5.0 and Cubist were fast in the first benchmark and are unchanged.
- Remaining: aorsf is still the slowest per leaf, because building each scaled linear-combination expression is costly.
- Added `check_tree_type()` and `check_tree_range()` in `R/helpers.R`, used by the `extract_rules()` methods for ranger, randomForest, grf, aorsf, lightgbm, xgboost, bart, and catboost. The message now states the upper limit and lists the out-of-range values. ranger, randomForest, grf, and aorsf take N from `num_ensemble_members()`. The grf fallback of 1000 trees is gone. lightgbm, bart, and catboost reuse the count from the dump they already read. xgboost calls `num_ensemble_members()` only on the error path, to avoid an extra full dump.
- `active_predictors()` methods still use their own "values must be between 1 and N, not X" messages.
- Every ensemble class has a `num_ensemble_members()` method. rpart and party are single trees and have none by design. All tree counts in the package now come from the method, or from an internal `lgb_num_trees()`, `xgb_num_trees()`, or `bart_num_trees()` helper that the method also calls. Those helpers let `as.party()` and `active_predictors()` reuse the dump they already read instead of dumping the model a second time. C5.0, cforest, and Cubist also use the shared range check.
