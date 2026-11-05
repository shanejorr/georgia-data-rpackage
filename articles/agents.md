# For LLM agents

This site is built to be read by language-model agents as well as
people.

## Markdown pages

Every HTML page has a Markdown copy at the same address with `.md` in
place of `.html`:

| Page | Markdown |
|----|----|
| `https://georgiacivicdata.org/r/index.html` | `https://georgiacivicdata.org/r/index.md` |
| `https://georgiacivicdata.org/r/articles/analysis.html` | `https://georgiacivicdata.org/r/articles/analysis.md` |
| `https://georgiacivicdata.org/r/reference/gcd_rows.html` | `https://georgiacivicdata.org/r/reference/gcd_rows.md` |

Each HTML page also names its Markdown copy in its `<head>`:

``` html
<link rel="alternate" type="text/markdown" href="analysis.md">
```

The Markdown pages hold the same text, code and output as the HTML
pages.

## llms.txt

[`llms.txt`](https://georgiacivicdata.org/r/llms.txt) follows
<https://llmstxt.org>. It holds the home page, then links to the
Markdown page of every function and article. The pages to read first:

- [Get
  started](https://georgiacivicdata.org/r/articles/georgiacivicdata.md):
  the catalog, names and filters, and the rules of the data.
- [Analyzing Georgia
  data](https://georgiacivicdata.org/r/articles/analysis.md): joining
  two datasets and pooling rates from counts.
- [School zones and
  places](https://georgiacivicdata.org/r/articles/school-zones.md):
  maps, zone status and locating points and addresses.
- [Reference](https://georgiacivicdata.org/r/reference/index.md): every
  function, grouped by task.

## Writing code with the package

- Install it with `pak::pak("shanejorr/georgia-data-rpackage")` and load
  it with
  [`library(georgiacivicdata)`](https://georgiacivicdata.org/r/). There
  is no API key.
- Find a dataset with `gcd_search("plain words")` or
  [`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md),
  read it with `gcd_describe(name)` and `gcd_columns(name)`, then get
  rows with `gcd_rows(name, ...)`.
- Filters are arguments named after the API’s parameters;
  `gcd_describe(name)$filters` lists every one with its values.
- Results are tibbles typed from the dataset’s schema: codes are
  character, so leading zeros survive, and rates are proportions on the
  0-1 scale.
- A missing metric usually means the value was suppressed for privacy,
  not zero. Never add the `all` total to its subgroups, and pool rates
  from their counts instead of averaging them.
- The API itself is documented at <https://georgiacivicdata.org/docs>,
  and Georgia Civic Data also runs an MCP server for agents; see the
  main site.
