# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:3.27.3 AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:alpine

COPY nginx.container.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 18884

CMD ["nginx", "-g", "daemon off;"]
