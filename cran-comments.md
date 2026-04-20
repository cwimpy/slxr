# cran-comments

## Resubmission

This is a resubmission of `slxr` (version 0.1.1). In response to CRAN
feedback on the initial submission, this version makes the following
changes:

- Added `\value` sections to all exported methods. Specifically,
  `man/slx-tidiers.Rd` now documents the tibble columns returned by
  `tidy.slx()` and `glance.slx()`, and `man/slx_sensitivity.Rd`
  documents that the stub is currently called only for its side
  effect of signalling an error, with a note on the planned future
  return value.
- Removed all uses of `\dontrun{}` from examples. Examples that can
  execute in under 5 seconds have been unwrapped and now run against
  the bundled `defense_burden` dataset (in `slx-tidiers`,
  `slx_effects`, `slx_plot_effects`, and `slx_plot_shock`). The
  `slx_weights` example now includes a runnable custom-matrix
  example, and the optional `sf`-based contiguity example is wrapped
  in `\donttest{}` and guarded by `requireNamespace()`.

## Original submission notes

`slxr` implements Spatial-X (SLX) regression models following Wimpy,
Whitten, and Williams (2021) <doi:10.1086/710089>.

## R CMD check results

0 errors | 0 warnings | 1 note

- Maintainer: 'Cameron Wimpy <cwimpy@astate.edu>'
- New submission
- Possibly misspelled words in DESCRIPTION: 'SLX', 'TSLS', 'Whitten'.
  These are technical acronyms (Spatial-X, temporally-lagged spatial
  lag) and a co-author surname.

## Test environments

- local macOS 15.4, R 4.5.0
- GitHub Actions:
  - macOS-latest,   R release
  - windows-latest, R release
  - ubuntu-latest,  R devel, R release, R oldrel-1
- win-builder (devel)

All environments return 0 errors and 0 warnings. The single NOTE on
win-builder is the new-submission/spell-check message documented
above.

## Downstream dependencies

This is a new package with no reverse dependencies.
