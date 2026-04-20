# Changelog

## slxr 0.1.1

CRAN resubmission addressing feedback from the initial submission.

- Added `\value` sections to `slx-tidiers.Rd` (documenting the tibble
  columns returned by
  [`tidy.slx()`](https://cwimpy.github.io/slxr/reference/slx-tidiers.md)
  and
  [`glance.slx()`](https://cwimpy.github.io/slxr/reference/slx-tidiers.md))
  and `slx_sensitivity.Rd` (documenting that the stub is called for its
  side effect of signalling an error, with a note on the planned future
  return value).
- Removed all `\dontrun{}` blocks from examples. Examples in
  `slx-tidiers`, `slx_effects`, `slx_plot_effects`, and `slx_plot_shock`
  are now unwrapped and run against the bundled `defense_burden`
  dataset. The `slx_weights` example now runs a custom-matrix case by
  default; the optional `sf`-based contiguity example is wrapped in
  `\donttest{}` and guarded by
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html).

## slxr 0.1.0

Initial CRAN release.

### Core

- [`slx()`](https://cwimpy.github.io/slxr/reference/slx.md) fits
  Spatial-X regression models of the form
  `y = X*beta + WX*theta + epsilon` via OLS on an augmented design
  matrix, with a formula interface and first-class support for
  variable-specific weights matrices.
- [`slx_weights()`](https://cwimpy.github.io/slxr/reference/slx_weights.md)
  constructs `slx_W` weights objects from `sf` input (`contiguity`,
  `rook`, `knn`, `distance`) or from a user-supplied matrix (`custom`).
- [`slx_effects()`](https://cwimpy.github.io/slxr/reference/slx_effects.md)
  returns a tidy tibble with direct, indirect, and total effects and
  their standard errors.
- Higher-order spatial lags (`order = 1:k`) supported.

### Panel support

- `id` and `time` arguments turn
  [`slx()`](https://cwimpy.github.io/slxr/reference/slx.md) into a panel
  estimator. Weights matrices can be time-invariant or supplied as named
  year-keyed lists. Unbalanced panels are handled automatically.
- `time_lag = k` implements the temporally-lagged spatial lag (TSLS,
  equation 7 of Wimpy, Whitten, and Williams 2021).

### Interpretation and visualization

- [`slx_compare()`](https://cwimpy.github.io/slxr/reference/slx_compare.md)
  produces side-by-side fit statistics for `lm` and `slx` objects, with
  optional Moran’s I on residuals.
- [`slx_plot_effects()`](https://cwimpy.github.io/slxr/reference/slx_plot_effects.md),
  [`slx_plot_decay()`](https://cwimpy.github.io/slxr/reference/slx_plot_decay.md),
  [`slx_plot_shock()`](https://cwimpy.github.io/slxr/reference/slx_plot_shock.md),
  and
  [`slx_plot_W()`](https://cwimpy.github.io/slxr/reference/slx_plot_W.md)
  return `ggplot` objects that can be further customized with
  `+ geom_*()` / `+ theme_*()`.
- [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) methods
  for compatibility with the `broom` and `modelsummary` ecosystems.

### Data

- `defense_burden`: 1995 cross-section of 179 countries with three
  sparse weights matrices (contiguity, alliance, defense pact).
- `defense_burden_panel`: 1951-2008 panel (7,661 observations) with
  year-specific sparse weights matrices.

Both datasets are drawn from the replication archive for Wimpy, Whitten,
and Williams (2021), *Journal of Politics* 83(2): 722-739.
