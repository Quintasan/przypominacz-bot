FROM ruby:3.2.2-alpine as base
WORKDIR /app
ENV BUNDLE_WITHOUT=development BUNDLE_PATH=/app/vendor/bundle BUNDLE_BIN=/app/vendor/bundle/bin BUNDLE_DEPLOYMENT=1

FROM base AS build
COPY . .
RUN apk add --no-cache git build-base ruby-dev && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

FROM base
COPY --from=build /app /app
RUN addgroup app && \
    adduser app --home /app --shell /bin/bash --ingroup app --disabled-password && \
    mkdir -p /app/data && \
    chown -R app:app /app
VOLUME /app/data
USER app
CMD ["ruby", "main.rb"]
