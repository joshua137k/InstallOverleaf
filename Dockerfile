FROM sharelatex/sharelatex:latest

ENV TEXLIVE_ROOT=/usr/local/texlive/2025
ENV PATH="${TEXLIVE_ROOT}/bin/x86_64-linux:${PATH}"

RUN curl -L https://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.sh \
      -o /tmp/update-tlmgr-latest.sh && \
    sh /tmp/update-tlmgr-latest.sh

RUN tlmgr update --self --all && \
 tlmgr install \
      lineno pgf-umlsd \
      memoir caption xpatch pdfpages morewrites \
      minted fvextra upquote \
      lm \
      mathtools physics cancel tensor siunitx amsfonts \
      pgf pgfplots xcolor eso-pic wrapfig subfig \
      booktabs multirow colortbl microtype geometry setspace fancyhdr titlesec enumitem csquotes \
      todonotes eurosym acronym pdfcomment bookmark comment float lipsum placeins \
      tools \
      biblatex biber natbib \
      babel-portuguese \
      hyperref cleveref \
      datetime2 tracklang collection-fontsrecommended zref marginnote soulpos \
      biblatex-ieee bigfoot hyphen-portuguese datetime2-english datetime2-portuguese xstring