# Precompute the vignettes.
#
# They call the live Georgia Civic Data API, which CRAN and CI builds must
# not, so each vignettes/<name>.Rmd.orig is knitted here, locally, into
# vignettes/<name>.Rmd with its output and figures baked in as Markdown.
# Run from the package root after changing a .Rmd.orig:
#
#   Rscript vignettes/precompile.R
#
# See https://ropensci.org/blog/2019/12/08/precompute-vignettes/

if (!file.exists("DESCRIPTION")) {
  stop("Run this from the package root.", call. = FALSE)
}
pkgload::load_all(".", quiet = TRUE)

old <- setwd("vignettes")
on.exit(setwd(old), add = TRUE)

for (src in list.files(pattern = "\\.Rmd\\.orig$")) {
  out <- sub("\\.orig$", "", src)
  name <- sub("\\.Rmd$", "", out)
  unlink(list.files(pattern = paste0("^", name, "-.*\\.png$")))
  message("Knitting ", src, " -> ", out)
  knitr::knit(src, out, quiet = TRUE, envir = new.env())
}
