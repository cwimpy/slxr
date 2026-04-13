# Compare OLS, SLX, and other lm-like models side by side

Builds a tidy tibble of fit statistics (observations, coefficient count,
R-squared, adjusted R-squared, residual standard error, AIC, BIC) for
any combination of `lm` and `slx` objects. If a weights matrix is
supplied, also reports Moran's I on each model's residuals - the
standard diagnostic for spatial autocorrelation left unexplained by the
fitted model.

## Usage

``` r
slx_compare(..., W = NULL)
```

## Arguments

- ...:

  Named `lm` or `slx` models. Names are used as the model labels in the
  output.

- W:

  Optional weights matrix to use for Moran's I on residuals. Accepts an
  `slx_W`, a `listw` object from `spdep`, or `NULL` to skip the test. In
  panel mode, supply a list keyed by time value.

## Value

A tibble with one row per model.

## Examples

``` r
data(defense_burden)
W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                 row_standardize = FALSE)
#> Warning: style is M (missing); style should be set to a valid value
#> Warning: neighbour object has 34 sub-graphs
ols <- lm(ch_milex ~ milex_tm1 + civilwar_tm1,
          data = defense_burden$data)
slx_fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
               data = defense_burden$data, W = W,
               lag = "civilwar_tm1")
slx_compare(OLS = ols, SLX = slx_fit, W = W)
#> # A tibble: 2 × 11
#>   model class     n     k r.squared adj.r.squared sigma   AIC   BIC moran_I
#>   <chr> <chr> <int> <int>     <dbl>         <dbl> <dbl> <dbl> <dbl>   <dbl>
#> 1 OLS   lm      179     3     0.404         0.397  1.46  647.  660. -0.0444
#> 2 SLX   slx     179     4     0.404         0.394  1.46  649.  665. -0.0461
#> # ℹ 1 more variable: moran_p <dbl>
```
