# Use a tiny Nginx image (only ~5MB)
FROM nginx:alpine

# Copy the pre-built web files from your local 'build/web' folder
COPY build/web /usr/share/nginx/html

# Copy your custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
