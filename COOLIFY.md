# Putting ahmad-zaven.io live with Coolify

How it works: your code goes to GitHub. Coolify (on your VPS) pulls it, builds the `Dockerfile` into a small Nginx container, and puts it behind its proxy with free HTTPS. After that, every `git push` updates the live site.

```
Your PC ──git push──▶ GitHub ──webhook──▶ Coolify on VPS ──▶ https://ahmad-zaven.io
```

You need: a VPS (Ubuntu 22.04 or 24.04, at least 2 GB RAM, 2 CPU, 30 GB disk), the domain, and a GitHub account.

---

## Step 0. Fill in your contact details

Open `public/index.html`, search for `const CONTACT`, and fill in:

```js
const CONTACT = { whatsapp:"9639XXXXXXXX", email:"you@example.com", instagram:"username", telegram:"username" };
```

- WhatsApp: digits only, with the country code and no `+` (e.g. `963912345678`).
- Instagram and Telegram: the username without `@`.
- Any value left empty hides that button.

---

## Step 1. DNS: point the domain at the VPS

1. Get your VPS **IPv4 address** from your hosting panel (e.g. `203.0.113.10`).
2. Log in where you bought **ahmad-zaven.io** and open **DNS / DNS Records / Manage DNS**.
3. **Delete** any existing `A`, `AAAA` or `CNAME` records on `@` and `www` (parking pages, "website builder" records). **Don't touch `MX` or `TXT` records** if you have email set up.
4. Add these records:

| Type | Name / Host | Value / Points to | TTL |
|------|-------------|-------------------|-----|
| A | `@` | your VPS IP | 300 (or Auto) |
| A | `www` | your VPS IP | 300 (or Auto) |
| A | `coolify` | your VPS IP | 300 (or Auto) |

`coolify.ahmad-zaven.io` will be the address of your Coolify dashboard (optional, but nicer and safer than `IP:8000`).

**If your DNS is on Cloudflare:** set each record to **DNS only (grey cloud)** for now. You can turn the orange cloud on later, but then set Cloudflare **SSL/TLS → Full (strict)**.

5. Check it worked (in PowerShell on your PC):

```powershell
nslookup ahmad-zaven.io 1.1.1.1
nslookup www.ahmad-zaven.io 1.1.1.1
```

Both must show your VPS IP. This usually takes 5–30 minutes, occasionally a few hours. You can do steps 2–4 while waiting.

---

## Step 2. Install Coolify on the VPS

> Coolify needs ports 80 and 443 for itself. **Don't install Nginx, Apache or certbot on the server.** If the VPS already runs Nginx/Apache or other sites, stop here and ask first. Installing Coolify on a server with existing sites will conflict with them.

1. Connect from PowerShell on your PC:

```powershell
ssh root@YOUR_VPS_IP
```

(or `ssh youruser@YOUR_VPS_IP` if you use a non-root user with sudo)

2. Update the server:

```bash
sudo apt update && sudo apt upgrade -y
```

3. Install Coolify (official one-line installer, takes 2–5 minutes):

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash
```

4. Open the firewall ports (if `ufw` is on):

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp
sudo ufw status
```

(Your hosting provider may also have a firewall in its web panel; open the same ports there.)

5. **Immediately** open `http://YOUR_VPS_IP:8000` in your browser and create the admin account. The first person to open this page becomes the admin, so don't leave it unclaimed. Use a strong password and save it in a password manager.

6. In the setup wizard choose **Localhost** (deploy on this same server).

---

## Step 3. Give the Coolify dashboard its own domain (recommended)

1. In Coolify: **Settings → General → Instance's Domain** → enter `https://coolify.ahmad-zaven.io` → **Save**.
2. Wait a minute, then open `https://coolify.ahmad-zaven.io`. It should load with a padlock.
3. Once that works, close port 8000:

```bash
sudo ufw delete allow 8000/tcp
```

4. Turn on **two-factor login**: click your profile (bottom left) → **Two-factor authentication**.

---

## Step 4. Put the project on GitHub

1. On https://github.com → **New repository**
   - Name: `ahmad-zaven-portfolio`
   - **Private**
   - Do **not** tick "Add a README" (the repo must be empty)
   - **Create repository**
2. In PowerShell on your PC:

```powershell
cd C:\Users\user\Downloads\zaven-ahmad-portfolio
git init
git add .
git commit -m "Portfolio site"
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/ahmad-zaven-portfolio.git
git push -u origin main
```

If Git asks you to log in, a browser window opens. Sign in to GitHub there.

3. Refresh the GitHub page. You should see `public/`, `deploy/`, `Dockerfile`, `COOLIFY.md`.

---

## Step 5. Connect GitHub to Coolify (one time)

1. Coolify → **Sources** → **+ Add** → **GitHub App**.
2. Give it a name (e.g. `my-github`) → **Continue** → **Register Now**. GitHub opens.
3. On GitHub, approve creating the app, then **Install** it. Choose **Only select repositories** → pick `ahmad-zaven-portfolio` → **Install**.
4. You land back in Coolify; the source now shows as connected.

---

## Step 6. Create the site in Coolify

1. **Projects** → **+ Add** → name it `Portfolio` → open it → open the **production** environment.
2. **+ New** (New Resource) → **Private Repository (with GitHub App)**.
3. Pick your GitHub App → pick the repo `ahmad-zaven-portfolio` → branch `main`.
4. **Build Pack: `Dockerfile`** (important: not Nixpacks, not Static).
   - Base Directory: `/`
   - Dockerfile location: `/Dockerfile`
   - **Continue**
5. On the app's **General / Configuration** page set:
   - **Domains:** `https://ahmad-zaven.io,https://www.ahmad-zaven.io`
     (comma, no spaces, both with `https://`. The `https://` is what makes Coolify get the SSL certificate.)
   - **Ports Exposes:** `80`
   - If you see a **Direction** / **Redirect** option, choose **Redirect to non-www** so `www.ahmad-zaven.io` forwards to `ahmad-zaven.io`.
   - **Save**
6. Click **Deploy** (top right). Open **Logs / Deployments** to watch it. The first build takes about 1 minute. It's done when it shows **Finished / Running (healthy)**.
7. Open **https://ahmad-zaven.io**. You should see the site with a padlock.

> If the padlock is missing or you get a certificate warning, DNS probably wasn't pointing at the server yet when it deployed. Wait until `nslookup` shows your IP (Step 1), then click **Redeploy** (or **Restart**). Coolify will request the certificate again.

---

## Step 7. Check everything

- [ ] `https://ahmad-zaven.io` loads with the padlock.
- [ ] `https://www.ahmad-zaven.io` loads (or redirects to the non-www address).
- [ ] `http://ahmad-zaven.io` redirects to `https://`.
- [ ] Switch the language to Arabic and open a few projects.
- [ ] Contact buttons open WhatsApp, Telegram, Instagram and email correctly.
- [ ] `https://ahmad-zaven.io/nothing-here` shows the 404 page.
- [ ] Paste the link into a WhatsApp chat with yourself: the preview image should appear. (Or test on https://www.opengraph.xyz)
- [ ] From Git Bash on your PC: `bash deploy/health_check.sh ahmad-zaven.io`

---

## Updating the site later

Edit files in `public/`, then:

```powershell
cd C:\Users\user\Downloads\zaven-ahmad-portfolio
git add .
git commit -m "Describe what changed"
git push
```

Coolify sees the push and redeploys automatically (about 1 minute). If it doesn't, check the app's **Advanced → Auto Deploy** is on, or click **Deploy** by hand.

**Undo a bad update:** in Coolify open the app → **Deployments**, pick an earlier successful one, and use **Rollback**. Or on your PC, run `git revert HEAD` then `git push`.

---

## After launch

- **Google:** add the site in https://search.google.com/search-console (choose "Domain", verify with the TXT record it gives you in your DNS) and submit `https://ahmad-zaven.io/sitemap.xml`.
- **Email @ahmad-zaven.io:** Coolify doesn't handle email. Free options are **Zoho Mail** (real mailbox) or **Cloudflare Email Routing** (forwards to your Gmail). They give you `MX` and `TXT` records to add in DNS. Don't delete the A records from Step 1.
- **Coolify updates:** Coolify shows a notice in the dashboard when an update is out. Update from there.
- **Server backups:** turn on your VPS provider's snapshots/backups. The website itself is safe on GitHub anyway.

## Troubleshooting

| Problem | Fix |
|---|---|
| Can't open `IP:8000` | Port 8000 is closed in the provider's firewall or ufw (Step 2.4). |
| Build fails "Dockerfile not found" | Build Pack must be **Dockerfile**, Base Directory `/`. |
| "Bad Gateway" / 502 | **Ports Exposes** must be `80`. Save, then Redeploy. |
| "No available server" / 404 from Traefik | The domain in **Domains** doesn't exactly match what you typed in the browser. Check spelling, `https://`, and include `www`. |
| Certificate warning | DNS not pointing at the server yet. Fix DNS, wait, then Redeploy. On Cloudflare use grey cloud or SSL mode Full (strict). |
| Site shows old version | Hard refresh (Ctrl+F5). Check the latest deployment finished in Coolify. |
