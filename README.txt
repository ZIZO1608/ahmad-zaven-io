Zaven & Ahmad Builds — static website for https://ahmad-zaven.io

public/         the website (index.html, img/, icons, og.jpg share image, robots.txt, sitemap.xml, 404.html)
Dockerfile      Coolify builds this (Nginx container serving public/)
deploy/         nginx config for the container, health check
COOLIFY.md      step-by-step: DNS, Coolify install, GitHub, go live, updates
deploy/without-coolify/   alternative: plain Nginx on the server, no Coolify

No build step, no database. Fonts load from Google Fonts.
Contact buttons: edit `const CONTACT` near the top of the <script> in public/index.html.
Publish changes:  git add . && git commit -m "..." && git push   (Coolify redeploys automatically)
Open one project directly: ahmad-zaven.io/#og-system
