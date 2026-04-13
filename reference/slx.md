# Fit a Spatial-X (SLX) model

Estimates a Spatial-X regression of the form \$\$y = X\beta + WX\theta +
\varepsilon,\$\$ where `W` is a spatial weights matrix and `X` includes
both the directly-entering regressors and a user-specified subset that
is spatially lagged. SLX estimation is OLS on the augmented design
matrix, which makes estimation, interpretation, and effects
decomposition much simpler than for SAR-family models (Wimpy, Whitten,
and Williams 2021).

## Usage

``` r
slx(
  formula,
  data,
  W = NULL,
  lag = NULL,
  order = 1L,
  spatial = NULL,
  time_lag = 0L,
  id = NULL,
  time = NULL,
  na.action = stats::na.omit
)
```

## Arguments

- formula:

  A standard model formula, e.g. `y ~ x1 + x2 + x3`.

- data:

  A data frame (or `sf` object) whose rows correspond, in order, to the
  rows/columns of `W` (cross-sectional mode) or contain `id` and `time`
  columns (panel mode).

- W:

  An `slx_W` object produced by
  [`slx_weights()`](https://cwimpy.github.io/slxr/reference/slx_weights.md),
  a numeric or sparse matrix, or - in panel mode - a named list of such
  objects keyed by time value. Required when `spatial` is not supplied.

- lag:

  Character vector of variable names from `formula` that should be
  spatially lagged. If `NULL` (default) and `W` is supplied, all
  right-hand-side variables are lagged.

- order:

  Integer vector giving the orders of `W` to include for each lagged
  variable (e.g. `1:2` adds both `Wx` and `W^2 x`). Default `1`.

- spatial:

  Optional named list for variable-specific weights matrices. Names must
  match variables in `formula`. Each element is either an `slx_W`, a
  list of `slx_W`s (multiple channels for one variable), a time-keyed
  list of `slx_W`s (single channel, time- varying), or a named list of
  channels whose values are themselves single or time-keyed `slx_W`s.

- time_lag:

  Integer, number of time periods to lag the spatial terms (TSLS).
  Requires `id` and `time`. Default `0`.

- id, time:

  Column names identifying the panel unit and period. Required for panel
  mode or TSLS. `time` must be numeric.

- na.action:

  How to handle missing values. Defaults to
  [`stats::na.omit`](https://rdrr.io/r/stats/na.fail.html) in
  cross-sectional mode. In panel mode missing values on formula
  variables are dropped; `id` and `time` must never be missing.

## Value

An object of class `slx` with elements:

- `fit`:

  The underlying `lm` object.

- `formula`:

  The expanded model formula.

- `call`:

  The original call.

- `W`:

  The weights matrix (or list thereof) used.

- `lag_terms`:

  A data frame mapping spatial-lag terms to their source variable, W
  matrix, order, and time lag.

- `data`:

  The (possibly augmented) model frame.

- `panel`:

  Logical flag.

## Cross-sectional and panel modes

When `id` and `time` are `NULL`, `slx()` treats the data as a single
cross-section: rows of `data` must correspond, in order, to the rows and
columns of `W`. When both `id` and `time` are supplied, `slx()` enters
panel mode and performs block-wise spatial lagging period by period. In
panel mode the weights matrices must have `dimnames` matching the unit
identifiers in `data[[id]]`; the same units need not appear in every
period (unbalanced panels are supported).

## Time-varying weights

In panel mode, a `W` argument can be either (a) a single `slx_W` object
applied to every period or (b) a named list of `slx_W` objects keyed by
the stringified `time` value (e.g.
`list("1990" = W_90, "1991" = W_91)`). The same options apply to any
entry inside `spatial`.

## Temporally-lagged spatial lag (TSLS)

The `time_lag` argument implements equation 7 of Wimpy, Whitten, and
Williams (2021): it lags every constructed spatial term `W_t x` by
`time_lag` periods within each unit so that the regressor becomes
`W_t x_{t - time_lag}`. The first `time_lag` periods per unit drop out,
mirroring any temporally-lagged variable.

## References

Wimpy, C., Whitten, G. D., & Williams, L. K. (2021). X Marks the Spot:
Unlocking the Treasure of Spatial-X Models. *Journal of Politics*,
83(2), 722-739.

Vega, S. H., & Elhorst, J. P. (2015). The SLX Model. *Journal of
Regional Science*, 55(3), 339-363.

## Examples

``` r
data(defense_burden)
W_c <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                   row_standardize = FALSE)
fit <- slx(ch_milex ~ milex_tm1 + log_pop_tm1 + civilwar_tm1,
           data = defense_burden$data, W = W_c, lag = "civilwar_tm1")
slx_effects(fit)
#> # A tibble: 3 × 8
#>   variable     w_name type     estimate std.error conf.low conf.high p.value
#>   <chr>        <chr>  <chr>       <dbl>     <dbl>    <dbl>     <dbl>   <dbl>
#> 1 civilwar_tm1 NA     direct     -1.21      0.573    -2.34   -0.0774  0.0364
#> 2 civilwar_tm1 W      indirect    0.133     0.838    -1.52    1.79    0.874 
#> 3 civilwar_tm1 W      total      -1.08      1.02     -3.08    0.930   0.291 
```
