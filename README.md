
Last Updated on 2024-09-06

# Prot papers bot

This is the bot for @prot_papers.bsky.social that was inspired and
developed from bots created by https://github.com/roblanf/phypapers and
https://github.com/JBGruber/r-bloggers-bluesky.

The bot runs once a day to post new papers from PubMed and bioRxiv for
subjects that are of interest to me, namely HLA immunopeptidomics,
neoantigens and HDX-MS.

It’s written in R and uses Github Actions and YML file to run workflow.

Here’s what I did if you want to fork this and make your own.

## 1. Set-up Bluesky

Follow these instructions from the `phypapers` readme:

\*Obviously you need an account to post to. This part gets you set up on
Bluesky, whether you have an existing personal account or not.

    If you don't have a Bluesky account: Go to https://bsky.app/, and click 'Sign Up'
    If you do have a Bluesky account, log in then go to Settings and click Add Account
    Leave the hosting provider as Bluesky Social
    Fill out your details to set up your new account:
        Protip: If you already use your gmail address for your account, you can just append to it to create a new account. E.g. if your personal account is porcelain.crab@gmail.com, you could use porcelain.crab+phypapers@gmail.com (the '+' stays). This helps keep mail separate.
    Decide on a handle. Following flypapers' lead, I suggest a short prefix followed immediately by papers, e.g. flypapers, phypapers, etc. This means we all know it when we see a literature bot.
    Click on your new profile, go to Edit Profile
        Username: I suggest making this prefix_papers e.g. fly_papers or phy_papers. As above, this helps everyone know what's a literature bot
        Description: pretty obvious, but it's always nice to know the human who runs it, so good to put your name there if you want to. It would be great if you could also put a link to these instructions on your literature bot - that way anyone who sees yours can also make their own. On my profile I just wrote: "Make your own literature bot with these instructions: https://github.com/roblanf/phypapers"*

There’s another step to set-up and get the app password and token, but
we do that with the `atrrr` package:
https://jbgruber.github.io/atrrr/index.html later on.

## RSS feeds

## Adapt the R script

## Adapt the YML for Github Workflow

Next
