# Direct, indirect, and total effects from an SLX model

For an SLX model the effects decomposition is trivial — no matrix
inversion, no simulation. For each variable \\x\\ that enters both
directly and as a spatial lag, the direct effect is its OLS coefficient
\\\hat\beta\\ and the indirect effect at order \\k\\ is
\\\hat\theta_k\\. Standard errors come straight from
[`vcov()`](https://rdrr.io/r/stats/vcov.html).

## Usage

``` r
slx_effects(object, by_order = FALSE, conf.level = 0.95)
```

## Arguments

- object:

  An `slx` object returned by
  [`slx()`](https://cwimpy.github.io/slxr/reference/slx.md).

- by_order:

  Logical; if `TRUE`, report indirect effects separately by order of W.
  Default `FALSE` sums across orders for a single indirect effect per
  variable–W combination.

- conf.level:

  Confidence level for reported intervals. Default 0.95.

## Value

A tibble with columns `variable`, `w_name`, `order` (when
`by_order = TRUE`), `type` (direct/indirect/total), `estimate`,
`std.error`, `conf.low`, `conf.high`, `p.value`.

## Examples

``` r
data(defense_burden)
W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                 row_standardize = FALSE)
fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
           data = defense_burden$data, W = W, lag = "civilwar_tm1")
slx_effects(fit)
#> # A tibble: 3 × 8
#>   variable     w_name type     estimate std.error conf.low conf.high p.value
#>   <chr>        <chr>  <chr>       <dbl>     <dbl>    <dbl>     <dbl>   <dbl>
#> 1 civilwar_tm1 NA     direct     -1.18      0.571    -2.30   -0.0495  0.0409
#> 2 civilwar_tm1 W      indirect    0.171     0.836    -1.48    1.82    0.839 
#> 3 civilwar_tm1 W      total      -1.01      1.01     -3.00    0.988   0.321 
```
