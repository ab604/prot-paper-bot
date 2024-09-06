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

## Part 1: read RSS feed
now <- today()
yesterday <- now - 1 


pubmed_feeds <- c("https://pubmed.ncbi.nlm.nih.gov/rss/search/1jsI3JGQCWWBHeHK4cUErWUE19BvzlvyZfNdMmdXcysd7rmgww/?limit=15&utm_campaign=pubmed-2&fc=20240902141654",
                  "https://pubmed.ncbi.nlm.nih.gov/rss/search/1RKSf0HH9l2s1BIME29OLF8W10zHSLgJVuDXmjq8ihvd8F3Aro/?limit=100&utm_campaign=pubmed-2&fc=20240902141801",
                  "https://pubmed.ncbi.nlm.nih.gov/rss/search/1RKSf0HH9l2s1BIME29OLF8W10zHSLgJVuDXmjq8ihvd8F3Aro/?limit=100&utm_campaign=pubmed-2&fc=20240902141801"
                  )

pubmed_df <- map_df(pubmed_feeds, tidyfeed) 

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

brv <- map_df(brv_feeds, tidyfeed)

brv_filt <- brv |> 
  filter(str_detect(item_title, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)") |
         str_detect(item_description, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)")) |> 
  mutate(link = str_extract(item_link,"^.*?[^?]*"))

pubmed_filt <- pubmed_df |> 
  filter(str_detect(item_title, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)") |
           str_detect(item_description, "[Ii]mmunopep*|[Pp]eptidomi*|[Pp]eptidome|HDX-MS|([Pp]roteogenomics & [Nn]eoantigen)"),
         item_pub_date >= today() - 1) |> 
  mutate(link = str_extract(item_link,"^.*?[^?]*"))


# Filter posts
rss_posts <- bind_rows(brv_filt |> select(item_title,item_description,link),
                       pubmed_filt |> select(item_title,item_description,link)) |> 
  distinct(item_title, .keep_all = T)  

## Part 2: create posts from feed
posts <- rss_posts |>
  # measure length of title and link and truncate description
  mutate(desc_preview_len = 294 - nchar(item_title) - nchar(link),
         desc_preview = map2_chr(item_title, abs(desc_preview_len), function(x, y) str_trunc(x, y)),
         post_text = glue("{item_title} {link}"),
         timestamp = now())
  
## Part 3: get already posted updates and de-duplicate
Sys.setenv(BSKY_TOKEN = "papers_token.rds")
pw <- Sys.getenv("ATR_PW")

auth(user = "protpapers.bsky.social",
     password = pw,
     overwrite = TRUE)
old_posts <- get_skeets_authored_by("protpapers.bsky.social", limit = 5000L)
posts_new <- posts |>
  filter(!post_text %in% old_posts$text)


## Part 4: Post skeets!
for (i in seq_len(nrow(posts_new))) {
  # if people upload broken preview images, this fails
  resp <- try(post_skeet(text = posts_new$post_text[i],
                         created_at = posts_new$timestamp[i]))
  if (methods::is(resp, "try-error")) post_skeet(text = posts_new$post_text[i],
                                                 created_at = posts_new$timestamp[i],
                                                 preview_card = FALSE)
}
