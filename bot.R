# Bot script adapted from https://github.com/JBGruber/r-bloggers-bluesky bot.r
# A.Bailey 2024-09-10

## packages
library(tidyRSS)
library(atrrr)
library(anytime)
library(lubridate)
library(dplyr)
library(stringr)
library(glue)
library(purrr)
library(xml2)

library(httr)

safe_tidyfeed <- function(url) {
  tryCatch(
    {
      # Add delay to prevent rate limiting
      Sys.sleep(2)

      # Custom GET request with proper headers
      response <- GET(
        url,
        user_agent("R RSS Reader/1.0"),
        add_headers(
          "Accept" = "application/rss+xml, application/xml",
          "Connection" = "keep-alive"
        )
      )

      if (status_code(response) != 200) {
        warning(paste("HTTP Error:", status_code(response), "for URL:", url))
        return(data.frame())
      }

      # Convert response to text
      content <- rawToChar(response$content)

      # Process with tidyfeed
      result <- tidyfeed(content)
      return(result)
    },
    error = function(e) {
      warning(paste("Error processing feed", url, ":", e$message))
      return(data.frame())
    }
  )
}


## Part 1: read RSS feed

# Vector of Pubmed feeds from search terms:
# immunopeptidom*[tiab]
# hdx-ms[tiab]
# immunopeptidom*[tiab] AND neoantigen*[tiab]
pubmed_feeds <- c("https://pubmed.ncbi.nlm.nih.gov/rss/search/1jsI3JGQCWWBHeHK4cUErWUE19BvzlvyZfNdMmdXcysd7rmgww/?limit=100",
                  "https://pubmed.ncbi.nlm.nih.gov/rss/search/1RKSf0HH9l2s1BIME29OLF8W10zHSLgJVuDXmjq8ihvd8F3Aro/?limit=100",
                  "https://pubmed.ncbi.nlm.nih.gov/rss/search/1RKSf0HH9l2s1BIME29OLF8W10zHSLgJVuDXmjq8ihvd8F3Aro/?limit=100")

# Read all the PubMed feeds
# pubmed_df <- map_df(pubmed_feeds, tidyfeed)

# Vector of feeds of possible interest from bioRxiv, yields the last 30 days
brv_feeds <- c("http://connect.biorxiv.org/biorxiv_xml.php?subject=biochemistry",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=bioinformatics",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=biophysics",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=cancer_biology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=cell_biology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=developmental_biology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=genetics",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=genomics",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=immunology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=microbiology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=molecular_biology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=neuroscience",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=pharmacology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=physiology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=synthetic_biology",
               "http://connect.biorxiv.org/biorxiv_xml.php?subject=systems_biology")

# Read all the bioRxiv feeds
# brv <- map_df(brv_feeds, tidyfeed)

# Read all the PubMed feeds
pubmed_df <- map_df(pubmed_feeds, safe_tidyfeed)

# Read all the bioRxiv feeds
brv <- map_df(brv_feeds, safe_tidyfeed)

# After reading feeds, check if we got any data
if (nrow(pubmed_df) == 0) {
  warning("No data retrieved from PubMed feeds")
}
if (nrow(brv) == 0) {
  warning("No data retrieved from bioRxiv feeds")
}

# Filter for biorxiv feed keywords and trim the link
brv_filt <- brv |>
  filter(str_detect(item_title, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)") |
         str_detect(item_description, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)")) |>
  mutate(link = str_extract(item_link,"^.*?[^?]*"))

# Filter for Pubmed feed for keywords and publication of no earlier than last 30 days and trim link
pubmed_filt <- pubmed_df |>
  filter(str_detect(item_title, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)") |
           str_detect(item_description, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)"),
         item_pub_date >= today() - 29) |>
  mutate(link = str_extract(item_link,"^.*?[^?]*"))


# Filter posts for unique titles
rss_posts <- bind_rows(brv_filt |> select(item_title,item_description,link),
                       pubmed_filt |> select(item_title,item_description,link)) |>
  distinct(item_title, .keep_all = T)

## Part 2: create posts from feed using paper title and link
posts <- rss_posts |>
  mutate(post_text = glue("{item_title} {link}"), # Needs to be <300 characters
         timestamp = now()) # Add timestamp

## Part 3: get already posted updates and de-duplicate
Sys.setenv(BSKY_TOKEN = "papers_token.rds")
pw <- Sys.getenv("ATR_PW")

auth(user = "protpapers.bsky.social",
     password = pw,
     overwrite = TRUE)

# Check for existing posts
old_posts <- get_skeets_authored_by("protpapers.bsky.social", limit = 5000L)
# Filter to post only new stuff
posts_new <- posts |>
  filter(!post_text %in% old_posts$text)

## Part 4: Post skeets. preview_card = FALSE means no images.
for (i in seq_len(nrow(posts_new))) {
  # if people upload broken preview images, this fails
  resp <- try(post_skeet(text = posts_new$post_text[i],
                         created_at = posts_new$timestamp[i], preview_card = FALSE))
  if (methods::is(resp, "try-error")) post_skeet(text = posts_new$post_text[i],
                                                 created_at = posts_new$timestamp[i],
                                                 preview_card = FALSE)
}
