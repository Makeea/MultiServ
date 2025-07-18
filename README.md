# MultiServ
Multi Stream Server
# Build Your Own Restream Server (Ubuntu 24.04, No-Nonsense Edition)

Tired of paying monthly for flaky multistream services? Ready to tell Restream.io and Castr to pound sand? Stop losing sleep over random disconnects and missing features. Put your streams back under your control, keep your wallet shut, and run everything from a dirt-cheap VPS or a spare box at home.

This guide shows you how to launch a full-featured, rock-solid restream server on Ubuntu 24.04 in under an hour. You get the latest versions, zero bloat, total transparency, and every push goes exactly where you want: Twitch, YouTube, Facebook, Trovo, Kick, Telegram, Rumble, and more. Plug in your keys, open the firewall, and you are live everywhere you want, all the time.

You do not need to be a Linux wizard. Every step is spelled out, every gotcha called out. No hype. No outdated nonsense. No "just install from source because my blog was last updated in 2019."

The result: one server, infinite outputs, 24/7 reliability, no surprises, no middlemen, and no more "why did my stream drop at 2AM again?" headaches.

If you want your streams stable and your setup simple, get started below.

---

## Why Do This?

Stream to multiple sites at once, 24/7, without random drops or service fees\
Complete control, minimal resource usage\
Supports both RTMP and RTMPS targets (Kick, Telegram, YouTube, Twitch, Facebook Live, Trovo, VKplay, etc)\
Fully open source, no black boxes

---

## 1. Update System and Prep Dependencies

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev git curl ffmpeg libnginx-mod-rtmp nginx
```

Installs all build tools, dependencies, Nginx, Nginx RTMP, and FFmpeg (for RTMPS targets like Kick/Telegram). No, you don't need to build from source unless you need bleeding edge features. Ubuntu 24.04 repo version is up to date and stable.

---

## 2. Nginx Service Basics (Command Breakdown)

Nginx installs as a system service and starts automatically. Here’s what each command does and why you care:

```bash
sudo systemctl status nginx
```

Shows if nginx is running, stopped, or crashed. Check this after every config change or if you think nginx is misbehaving.

```bash
sudo systemctl restart nginx
```

Stops then starts nginx. Use after major config changes or if the service is buggy. This disconnects all clients.

```bash
sudo systemctl reload nginx
```

Reloads config files without dropping active connections. Use this after editing nginx.conf or rtmp blocks. Running streams keep going.

```bash
sudo systemctl stop nginx
```

Kills nginx instantly. All active streams drop. Only use for maintenance or shutdown.

```bash
sudo systemctl start nginx
```

Manually starts nginx if it’s stopped or after a reboot. Only needed if nginx isn’t running already.

---

## 3. Nginx RTMP Config: Multi Platform Restreaming (Copy Paste Ready)

Edit the config:

```bash
sudo nano /etc/nginx/nginx.conf
```

Add this at the bottom (don't break the existing config):

```nginx
rtmp {
	server {
		listen 1935;
		chunk_size 4096;
		# Lock down who can send streams in
		allow publish 127.0.0.1;             # Always allow local
		allow publish <your_home_public_ip>; # Replace with your WAN IP (see notes below)
		# allow publish <other_location_ip>; # Add as needed
		# allow publish all;                 # Not safe! See security warning below.
		deny publish all;

		application live {
			live on;
			record off;
			# Twitch (RTMP)
			push rtmp://jfk.contribute.live-video.net/app/<TWITCH_STREAM_KEY>;
			# YouTube (RTMP)
			push rtmp://a.rtmp.youtube.com/live2/<YOUTUBE_STREAM_KEY>;
			# Trovo (RTMP)
			# push rtmp://livepush.trovo.live/live/<TROVO_STREAM_KEY>;
			# VKplay (RTMP)
			# push rtmp://vsu.mycdn.me/app/<VKPLAY_STREAM_KEY>;
			# AfreecaTV (RTMP)
			# push rtmp://live.afreecatv.com/app/<AFREECA_STREAM_KEY>;
			# GoodGame.ru (RTMP)
			# push rtmp://secure.goodgame.ru:1935/live/<GOODGAME_STREAM_KEY>;
			# DLive (RTMP)
			# push rtmp://rtmp.dlive.tv/live/<DLIVE_STREAM_KEY>;
			# Picarto.tv (RTMP)
			# push rtmp://live.picarto.tv/golive/<PICARTO_STREAM_KEY>;
			# Mixcloud Live (RTMP)
			# push rtmp://rtmp.mixcloud.com/live/<MIXCLOUD_KEY>;
			# Rumble (RTMP)
			# push rtmp://live.rumble.com/broadcast/<RUMBLE_STREAM_KEY>;
			# Bilibili (RTMP)
			# push rtmp://broadcast.live.bilibili.com/live-bvc/<BILIBILI_KEY>;

			# Kick (RTMPS via FFmpeg)
			# exec_push /usr/bin/ffmpeg -re -i "rtmp://127.0.0.1/live/$name" -c copy -f flv "rtmps://global-contribute.live-video.net/app/<KICK_STREAM_KEY>";
			# Telegram (RTMPS via FFmpeg)
			# exec_push /usr/bin/ffmpeg -re -i "rtmp://127.0.0.1/live/$name" -c copy -f flv "rtmps://dc.rtmp.t.me/s/<TELEGRAM_STREAM_KEY>";
			# Facebook Live (RTMPS via FFmpeg, key expires fast)
			# exec_push /usr/bin/ffmpeg -re -i "rtmp://127.0.0.1/live/$name" -c copy -f flv "rtmps://live-api-s.facebook.com:443/rtmp/<FB_STREAM_KEY>";

			# Instagram Live (third party tools only, key changes every stream)
			# push rtmp://rtmp-upload.instagram.com:80/rtmp/<INSTAGRAM_STREAM_KEY>;
			# TikTok Live (requires official stream key, most users do not have access)
			# push rtmp://push-rtmp.tiktok.com/live/<TIKTOK_STREAM_KEY>;
		}
	}
}
```

Anything not in the config above was already removed from the rest of the guide for clarity. All supported platforms are listed here as push or exec\_push lines, just uncomment and fill in your stream key for any you want to enable.

**Instagram and TikTok Restreaming: Know the Risks**

Instagram Live: No official RTMP support. Third party tools like Yellow Duck, Streamon, Loola.tv, Instafeed provide temporary keys, but use at your own risk. You must get a new key every session. Instagram can block, throttle, or ban your account. Not recommended for business or critical streams.\
TikTok Live: RTMP is only available to select accounts (big creators, brands, or via agency invite). If you don’t have official access, browser hacks or key generators are not supported and are risky. Unauthorized use can result in a ban or shadowban.

Do not automate Instagram or TikTok restreaming unless you understand and accept these risks.

---

### How to Add a New RTMP or RTMPS Platform

1. Get the RTMP or RTMPS stream URL and your stream key from the destination platform. It will look something like rtmp\://example.com/app/ or rtmps\://example.com/live/.
2. RTMP platforms: Add a new push line in your application block:
   ```nginx
   push rtmp://yourplatform.com/live/<YOUR_STREAM_KEY>;
   ```
3. RTMPS platforms: Add a new exec\_push line, using ffmpeg to wrap the stream (change endpoint and key as needed):
   ```nginx
   exec_push /usr/bin/ffmpeg -re -i "rtmp://127.0.0.1/live/$name" -c copy -f flv "rtmps://yourplatform.com/live/<YOUR_STREAM_KEY>";
   ```
4. Save, then test your nginx config:
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```
5. Watch for any errors in your logs. Each push or exec\_push is independent.

---

## 4. Open Firewall Ports

Before you start poking holes in your firewall, don’t get clever and lock yourself out. The bare minimum you must allow:

- SSH (port 22) or your custom SSH port. If you lose SSH, you’re toast.
- HTTPS (port 443) for any web dashboard, nginx web server, or future SSL.
- HTTP (port 80) if you want to serve plain web pages or ACME (Let’s Encrypt) challenges.
- RTMP (port 1935) for ingest.
- Stats (port 8080) if you actually want the RTMP stats page, otherwise skip.

Example to keep yourself safe:

```bash
sudo ufw allow 22/tcp          # SSH (or your custom SSH port)
sudo ufw allow 443/tcp         # HTTPS
sudo ufw allow 80/tcp          # HTTP (optional, but needed for Let's Encrypt and ACME)
sudo ufw allow 1935/tcp        # RTMP ingest
sudo ufw allow 8080/tcp        # RTMP stats (optional)
```

If you want only your home IP to stream in, but keep web and SSH open to the world:

```bash
sudo ufw allow from <your_home_ip> to any port 1935
```

If you have a custom SSH port (e.g., 2222), swap 22 for your number. Double check all rules with:

```bash
sudo ufw status
```

You can always adjust later, but do not close SSH on yourself. If you want to block web (80/443) after setup, go for it, but you need at least one way in for management.

---

## 5. (Optional) RTMP Stats Page (Modern Fix)

Ubuntu 24.04 no longer includes the stats stylesheet in the package. Fetch it directly:

Create the stats site config:

```bash
sudo nano /etc/nginx/sites-available/rtmp
```

Paste:

```nginx
server {
	listen 8080;
	server_name _;

	location /stat {
		rtmp_stat all;
		rtmp_stat_stylesheet stat.xsl;
	}
	location /stat.xsl {
		root /var/www/html/rtmp;
	}
	location /control {
		rtmp_control all;
	}
}
```

Symlink:

```bash
sudo ln -s /etc/nginx/sites-available/rtmp /etc/nginx/sites-enabled/rtmp
```

Now grab the stylesheet directly from GitHub:

```bash
sudo mkdir -p /var/www/html/rtmp
sudo curl -o /var/www/html/rtmp/stat.xsl https://raw.githubusercontent.com/arut/nginx-rtmp-module/master/stat.xsl
```

Reload Nginx:

```bash
sudo systemctl reload nginx
```

Go to:

```
http://<your_server_ip>:8080/stat
```

---

## 6. Testing Your Setup

### 1. Test Local RTMP with OBS

Open OBS (or your encoder of choice).\
Set “Custom…” as the service.\
Server: rtmp\://\<your\_server\_ip>/live\
Stream key: anything you want (unless you built auth).\
Hit “Start Streaming”.\
On the server, check nginx status:

```bash
sudo systemctl status nginx
tail -F /var/log/nginx/error.log
# or, for RTMP events
tail -F /var/log/nginx/access.log
# some RTMP activity will show in error.log by default
```

### 2. Check Stream Push to Endpoints

Open your Twitch or YouTube dashboard, look for an active incoming stream.\
If you used exec\_push for RTMPS (Kick, Telegram, Facebook Live), check their dashboards too.

If you see the preview go live, your relay is working.

### 3. Test Stream Lockdown

Try streaming from a machine not on your allowed list (different public IP). It should be rejected. No stream gets through, OBS will error out.\
Check logs for “publish denied”.

### 4. RTMP Stats Page

Visit http\://\<your\_server\_ip>:8080/stat in a browser (if you enabled the stats page).\
You’ll see connected streams, bitrate, and client info.

### 5. Troubleshooting

If you don’t see the stream on any endpoint, check logs for typos in your config (stream key, RTMP URL).\
Check for firewall issues (ufw status).\
Test direct with ffplay or VLC:

```bash
ffplay rtmp://<your_server_ip>/live/test
# or
vlc rtmp://<your_server_ip>/live/test
```

You should see your stream live.

If it’s still not working, triple check:\
Your firewall and publish IPs\
That your OBS or encoder is actually hitting the right address\
The endpoint URLs or keys in nginx.conf are accurate

---

## 7. Done

Stream from OBS or whatever to rtmp\://your\_server\_ip/live\
Twitch, YouTube, Trovo, VKplay, AfreecaTV, GoodGame, DLive, Picarto, Mixcloud, Rumble, Bilibili, Kick, Telegram, Facebook Live, Instagram, TikTok, and more. All at once (where supported).\
To add or remove platforms, just edit the config, reload, done.

## 8. Troubleshooting or Notes

To stream to RTMPS endpoints, you need ffmpeg and exec\_push. The default push directive only supports RTMP.\
If you want true stream key auth, use nginx rtmp access modules or restrict publish to specific IPs only.\
All edits require nginx reload, not restart.\
If you run into permissions issues with ffmpeg, try: sudo chmod 755 /usr/bin/ffmpeg

---

## Resources

- [Official Nginx RTMP wiki](https://github.com/arut/nginx-rtmp-module/wiki)
- [libnginx-mod-rtmp Ubuntu package](https://packages.ubuntu.com/noble/libnginx-mod-rtmp)
- [Twitch Ingests List (Official)](https://stream.twitch.tv/ingests/)
- [DigitalOcean original guide (2023)](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-video-streaming-server-using-nginx-rtmp-on-ubuntu-20-04)

