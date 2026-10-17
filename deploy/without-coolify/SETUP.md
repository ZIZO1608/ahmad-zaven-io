# Putting ahmad-zaven.io live (plain Nginx, without Coolify)

Use this only if you are NOT using Coolify. With Coolify, follow ../../COOLIFY.md instead.

Folder layout:

```
public/          the website (everything here is uploaded)
deploy/          server files: nginx config, deploy script, health check
```

## 1. Fill in your contact details

Open `public/index.html`, search for `const CONTACT`, and fill in the four values:

```js
const CONTACT = { whatsapp:"9639XXXXXXXX", email:"you@example.com", instagram:"username", telegram:"username" };
```

WhatsApp is digits only, with the country code. Instagram and Telegram are usernames without the `@`. A button stays hidden while its value is empty.

## 2. Point the domain at the server

At your domain registrar's DNS settings, add these records (replace the IP with your VPS IP):

| Type | Name  | Value          |
|------|-------|----------------|
| A    | @     | YOUR.VPS.IP    |
| A    | www   | YOUR.VPS.IP    |
| AAAA | @/www | (only if the VPS has IPv6) |

Delete any old A, AAAA or CNAME records on `@` and `www`. Check it worked with `nslookup ahmad-zaven.io`. This usually takes a few minutes, sometimes up to a few hours.

## 3. One-time server setup

SSH alias on your computer (`~/.ssh/config`):

```
Host vps
  HostName YOUR.VPS.IP
  User YOUR_USER
  IdentityFile ~/.ssh/id_ed25519
```

On the server:

```bash
sudo mkdir -p /var/www/ahmad-zaven.io/releases
sudo chown -R $USER:$USER /var/www/ahmad-zaven.io
```

From your computer, copy the nginx config up and enable it:

```bash
scp deploy/without-coolify/ahmad-zaven.io.conf vps:/tmp/
ssh vps 'sudo mv /tmp/ahmad-zaven.io.conf /etc/nginx/sites-available/ahmad-zaven.io \
  && sudo ln -sfn /etc/nginx/sites-available/ahmad-zaven.io /etc/nginx/sites-enabled/ahmad-zaven.io \
  && sudo nginx -t && sudo systemctl reload nginx'
```

## 4. Deploy

```bash
bash deploy/without-coolify/deploy.sh
```

## 5. HTTPS (once DNS points at the server)

```bash
ssh vps 'sudo certbot --nginx -d ahmad-zaven.io -d www.ahmad-zaven.io --redirect'
```

Certbot renews the certificate automatically.

## Everyday use

| Do this | Command |
|---|---|
| Publish changes | `bash deploy/without-coolify/deploy.sh` |
| Undo the last deploy | `bash deploy/without-coolify/deploy.sh --rollback` |
| See releases | `bash deploy/without-coolify/deploy.sh --list` |
| Check site and SSL | `bash deploy/health_check.sh ahmad-zaven.io` |

## After launch

- Test the share preview by pasting the link into WhatsApp, or use https://www.opengraph.xyz.
- Add the site to Google Search Console and submit `https://ahmad-zaven.io/sitemap.xml`.
- Email at `@ahmad-zaven.io` needs mail hosting (for example Zoho Mail free, or Cloudflare Email Routing to forward to Gmail). It isn't handled by this server.
