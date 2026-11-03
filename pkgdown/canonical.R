# Add <link rel="canonical"> to every page of the built site.
#
# The site is deployed to GitHub Pages and served at
# https://georgiacivicdata.org/r/ through a rewrite in the main site; the
# canonical links tell search engines to prefer that address over the
# github.io copy. pkgdown 2.2 writes canonical links only on redirect
# pages, so the deploy workflow runs this after pkgdown::build_site().
#
#   Rscript pkgdown/canonical.R [site directory, default "docs"]

args <- commandArgs(trailingOnly = TRUE)
site <- if (length(args)) args[[1]] else "docs"
base <- "https://georgiacivicdata.org/r/"

pages <- list.files(site, pattern = "\\.html$", recursive = TRUE)
added <- 0L
for (page in pages) {
  path <- file.path(site, page)
  html <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (any(grepl('rel="canonical"', html, fixed = TRUE))) {
    next
  }
  head_end <- grep("</head>", html, fixed = TRUE)[1]
  if (is.na(head_end)) {
    next
  }
  link <- sprintf('<link rel="canonical" href="%s%s">', base, page)
  writeLines(append(html, link, after = head_end - 1), path, useBytes = TRUE)
  added <- added + 1L
}
message("Added canonical links to ", added, " of ", length(pages), " pages.")
