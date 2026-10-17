# Coolify builds this: a tiny Nginx container serving public/ on port 80.
# Coolify's proxy (Traefik) in front of it handles the domain and HTTPS.
FROM nginx:1.27-alpine

COPY deploy/nginx-container.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
