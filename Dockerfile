FROM rocker/shiny:4.4.1

RUN install2.r --error --skipinstalled \
    bslib plotly DT jsonlite dplyr forecast \
    && rm -rf /tmp/downloaded_packages

WORKDIR /app
COPY app.R ./
COPY R ./R
COPY www ./www

ENV WDE_CACHE_DIR=/tmp/wde-cache
EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 3838)"]
