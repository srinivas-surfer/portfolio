FROM nginx:alpine

COPY . /usr/share/nginx/html

COPY nginx-main.conf /etc/nginx/nginx.conf
COPY nginx-server.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
