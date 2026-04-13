# Heatmap of a spatial weights matrix

A quick visual check on the structure of a weights matrix. For large `n`
the heatmap becomes noisy; use the `max_n` argument to subsample.

## Usage

``` r
slx_plot_W(W, max_n = NULL, labels = NULL)
```

## Arguments

- W:

  An `slx_W` object.

- max_n:

  Optional integer; if `nrow(W) > max_n`, a random sample of
  rows/columns is plotted. Default `NULL` (plot everything).

- labels:

  Optional character vector of row/column labels.

## Value

A `ggplot` object.
