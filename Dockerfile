FROM nginx:alpine

COPY app/index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
EXPOSE 8081
