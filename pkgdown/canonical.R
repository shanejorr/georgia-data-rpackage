# Add <link rel="canonical"> and the Markdown link to every page of the
# built site.
#
# The site is deployed to GitHub Pages and served at
# https://georgiacivicdata.org/r/ through a rewrite in the main site; the
# canonical links tell search engines to prefer that address over the
# github.io copy. pkgdown 2.2 writes canonical links only on redirect
# pages, so the deploy workflow runs this after pkgdown::build_site().
#
# pkgdown also writes a Markdown copy of each page (`page.md` beside
# `page.html`) for LLM agents; a <link rel="alternate" type="text/markdown">
# names it, so an agent reading the HTML can find it.
#
#   Rscript pkgdown/canonical.R [site directory, default "docs"]

args <- commandArgs(trailingOnly = TRUE)
site <- if (length(args)) args[[1]] else "docs"
base <- "https://georgiacivicdata.org/r/"

pages <- list.files(site, pattern = "\\.html$", recursive = TRUE)
canonical <- 0L
markdown <- 0L
for (page in pages) {
  path <- file.path(site, page)
  html <- readLines(path, warn = FALSE, encoding = "UTF-8")
  head_end <- grep("</head>", html, fixed = TRUE)[1]
  if (is.na(head_end)) {
    next
  }
  links <- character()
  if (!any(grepl('rel="canonical"', html, fixed = TRUE))) {
    links <- c(links, sprintf('<link rel="canonical" href="%s%s">', base, page))
    canonical <- canonical + 1L
  }
  md <- sub("\\.html$", ".md", page)
  if (file.exists(file.path(site, md)) &&
      !any(grepl('type="text/markdown"', html, fixed = TRUE))) {
    links <- c(links, sprintf(
      '<link rel="alternate" type="text/markdown" href="%s" title="Markdown">',
      basename(md)
    ))
    markdown <- markdown + 1L
  }
  if (length(links)) {
    writeLines(append(html, links, after = head_end - 1), path, useBytes = TRUE)
  }
}
message(
  "Added canonical links to ", canonical, " and Markdown links to ",
  markdown, " of ", length(pages), " pages."
)
