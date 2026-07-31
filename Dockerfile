ARG ruby_version=3.4
ARG base_image=ghcr.io/publishing-platform/publishing-platform-ruby-base:$ruby_version
ARG builder_image=ghcr.io/publishing-platform/publishing-platform-ruby-builder:$ruby_version


FROM $builder_image AS builder

ENV JWT_AUTH_SECRET=unused_yet_required \
    SECRET_KEY_BASE=unused_yet_required

WORKDIR $APP_HOME
COPY Gemfile* .ruby-version ./
RUN bundle install
COPY package.json yarn.lock ./
RUN yarn install
COPY . .
RUN bootsnap precompile --gemfile .
RUN rails assets:precompile && rm -fr log


FROM $base_image

ENV PUBLISHING_PLATFORM_APP_NAME=fact-check-manager

WORKDIR $APP_HOME
COPY --from=builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=builder $APP_HOME .

USER app
CMD ["puma"]