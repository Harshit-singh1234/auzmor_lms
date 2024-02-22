# Artifact generate with node module
FROM mhart/alpine-node:10
RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh
WORKDIR /usr/src/app
RUN yarn global add firebase-tools
ENV GENERATE_SOURCEMAP=false
ENV CI=true
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
COPY . ./
# RUN yarn install-functions
# RUN yarn test
ARG PR=false
RUN if [ "$PR" = "true" ] ; then yarn build; fi
CMD yarn build && firebase functions:config:set api.base_url=$apiUrl --token $token --project $project --non-interactive && firebase deploy --except functions --token $token --project $project --non-interactive
