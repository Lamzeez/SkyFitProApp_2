# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# 1. Fix the "root" issue: Switch to the built-in 'cirrus' user
USER root
RUN git config --global --add safe.directory /usr/local/flutter
RUN chown -R cirrus:cirrus /usr/local/flutter

# Switch to non-root user for the rest of the build
USER cirrus
WORKDIR /app

# 2. Pre-cache the Web SDK to save memory during the actual build
RUN flutter config --no-analytics
RUN flutter precache --web

# Copy files as the 'cirrus' user
COPY --chown=cirrus:cirrus . .

# ARGs for secrets
ARG OPENWEATHER_API_KEY
ARG FIREBASE_API_KEY
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_APP_ID
ARG FIREBASE_MEASUREMENT_ID
ARG FACEBOOK_APP_ID

# 3. Build Web
RUN flutter pub get
RUN flutter build web --release \
    --dart-define=OPENWEATHER_API_KEY=$OPENWEATHER_API_KEY \
    --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY \
    --dart-define=FIREBASE_AUTH_DOMAIN=$FIREBASE_AUTH_DOMAIN \
    --dart-define=FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID \
    --dart-define=FIREBASE_STORAGE_BUCKET=$FIREBASE_STORAGE_BUCKET \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID \
    --dart-define=FIREBASE_APP_ID=$FIREBASE_APP_ID \
    --dart-define=FIREBASE_MEASUREMENT_ID=$FIREBASE_MEASUREMENT_ID \
    --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
