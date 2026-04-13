# Defense burden data, 1995 cross-section

A 179-country cross-section of defense spending and conflict indicators
for 1995, drawn from the replication archive of Wimpy, Whitten, and
Williams (2021). Three row-standardized spatial weights matrices connect
the units through different channels: contiguity, alliance, and defense
pact.

## Usage

``` r
defense_burden
```

## Format

A named list with four elements:

- `data`:

  A tibble with 179 rows and 12 variables, arranged by Correlates of War
  country code (`ccode`). Variables:

  - `ccode` - Correlates of War country code.

  - `year` - Calendar year (1995).

  - `ch_milex` - Change in military expenditures (outcome).

  - `milex_tm1` - Lagged military expenditures.

  - `log_pop_tm1` - Lagged log population.

  - `civilwar_tm1` - Lagged civil war indicator.

  - `total_wars_tm1` - Lagged count of interstate wars.

  - `alliance_us` - Alliance with the United States.

  - `ch_milex_us` - Change in U.S. military expenditures.

  - `ch_milex_ussr` - Change in Soviet/Russian military expenditures.

  - `region` - Integer region code (1-5).

  - `region_name` - Factor: Europe, N Africa/Middle East, Africa,
    Asia/Oceania, Americas.

- `W_contig`:

  A 179 x 179 row-standardized sparse `dgCMatrix` encoding geographic
  contiguity.

- `W_alliance`:

  A 179 x 179 row-standardized sparse `dgCMatrix` encoding alliance
  ties.

- `W_defense`:

  A 179 x 179 row-standardized sparse `dgCMatrix` encoding mutual
  defense pacts.

## Source

Wimpy, Whitten, and Williams (2021) replication archive, Journal of
Politics Dataverse. [doi:10.1086/710089](https://doi.org/10.1086/710089)

## Details

This cross-section is intended for pedagogical demonstration of
variable-specific SLX specifications. The original paper estimates a
pooled panel SLX across 1950-2008 with year-specific weights matrices;
that full-panel replication requires block-diagonal W support, which is
planned for `slxr` v0.2.

## References

Wimpy, C., Whitten, G. D., & Williams, L. K. (2021). X Marks the Spot:
Unlocking the Treasure of Spatial-X Models. *Journal of Politics*,
83(2), 722-739.

## Examples

``` r
data(defense_burden)
dim(defense_burden$data)
#> [1] 179  12
dim(defense_burden$W_contig)
#> Loading required namespace: Matrix
#> NULL
```
