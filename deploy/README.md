# GridPop — Ubuntu (AWS EC2) dağıtımı

GridPop **tamamen istemci tarafında** çalışır: skorlar, coinler ve ayarlar
tarayıcının `localStorage`'ında tutulur. Sunucuda PHP, Node, veritabanı veya
Docker gerekmez — ihtiyacın olan tek şey `build/web` klasörünü servis eden bir
nginx. Bu yüzden **t3.micro (1 vCPU / 1 GB) fazlasıyla yeterli**.

```
PC: flutter build web  ──►  build/web/  ──rsync/scp──►  EC2:nginx  ──►  tarayıcı
```

> **Önemli:** derlemeyi sunucuda değil kendi bilgisayarında yap. `t3.micro`'nun
> 1 GB RAM'i Flutter web derlemesine yetmez (derleyici 2–3 GB ister). Sunucu
> sadece statik dosya dağıtır.

---

## 1. EC2 örneğini hazırla

1. AWS Console → EC2 → **Launch instance**
2. **AMI:** Ubuntu Server 24.04 LTS (64-bit x86)
3. **Instance type:** `t3.micro`
4. **Key pair:** yeni oluştur (`gridpop.pem`) ve indir; `chmod 400 gridpop.pem`
5. **Storage:** 8 GB gp3 yeterli (build ~41 MB)
6. **Security group** (yalnızca bunlar):

   | Tür | Port | Kaynak |
   |---|---|---|
   | SSH | 22 | **Kendi IP'n** (`My IP`) |
   | HTTP | 80 | Anywhere (0.0.0.0/0) |
   | HTTPS | 443 | Anywhere (0.0.0.0/0) |

7. **Elastic IP** ayır ve örneğe bağla — aksi halde örneği durdurup açtığında
   IP değişir ve tarayıcıdaki `localStorage` (yani oyuncunun ilerlemesi) kaybolur.

Bağlan:

```bash
ssh -i gridpop.pem ubuntu@<ELASTIC_IP>
```

---

## 2. Sunucuya nginx kur

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx

# Sadece SSH + web trafiği açık kalsın
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Otomatik güvenlik güncellemeleri
sudo apt install -y unattended-upgrades
```

Web kökünü oluştur:

```bash
sudo mkdir -p /var/www/gridpop
sudo chown -R $USER:$USER /var/www/gridpop
```

---

## 3. Siteyi yayına al

Bu depodaki hazır config'i kullanacağız (`deploy/nginx/gridpop.conf`).

**Yerelde** config'i sunucuya gönder:

```powershell
scp -i gridpop.pem deploy\nginx\gridpop.conf ubuntu@<IP>:/tmp/gridpop.conf
```

**Sunucuda** yerine koy ve etkinleştir:

```bash
sudo mv /tmp/gridpop.conf /etc/nginx/sites-available/gridpop
sudo ln -sf /etc/nginx/sites-available/gridpop /etc/nginx/sites-enabled/gridpop
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

---

## 4. Derle (kendi bilgisayarında)

```bash
flutter build web --release --pwa-strategy=none --no-web-resources-cdn
```

- `--no-web-resources-cdn` **zorunlu**: CanvasKit yerelden gelir, aksi halde
  `web/index.html` içindeki katı CSP (yalnızca `'self'`) yüzünden oyun açılmaz.
- `--pwa-strategy=none`: service worker üretilmez; her yayında kullanıcı yeni
  sürümü alır (cache tuzağı yok).

## 5. Yükle

**Windows (PowerShell, ek araç gerekmez):**

```powershell
.\deploy\deploy.ps1 -Server ubuntu@<IP> -KeyPath $HOME\.ssh\gridpop.pem
```

**WSL / macOS / Linux (rsync + gzip ön sıkıştırma):**

```bash
HOST=ubuntu@<IP> KEY=~/.ssh/gridpop.pem ./deploy/deploy.sh
```

Script önce `nginx -t` çalıştırır, config bozuksa siteyi düşürmez; sonra
`systemctl reload nginx` ile kesintisiz devreye alır.

**Elle (tek seferlik):**

```powershell
scp -i gridpop.pem -r build\web\* ubuntu@<IP>:/var/www/gridpop/
```

---

## 6. Doğrula

```bash
curl -I http://<IP>/                     # 200 + Content-Security-Policy
curl -I http://<IP>/main.dart.js         # 200, Cache-Control: no-cache
curl -I http://<IP>/canvaskit/canvaskit.wasm
```

Tarayıcıda `http://<IP>/` → menü açılmalı, konsol temiz olmalı.
Güncelleme sonrası **Ctrl+F5** (hard refresh) yap.

---

## 7. Domain + HTTPS (önerilir)

Let's Encrypt bir IP'ye sertifika vermez; kısa bir domain gerekiyor.

1. Domainde `A` kaydı: `game.ornek.com → <ELASTIC_IP>`
2. Sunucuda:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo sed -i 's/server_name _;/server_name game.ornek.com;/' /etc/nginx/sites-available/gridpop
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d game.ornek.com --redirect
sudo certbot renew --dry-run
```

Certbot 443 bloğunu kendisi ekler, HTTP→HTTPS yönlendirmesini kurar ve
yenileme zamanlayıcısını (`systemd timer`) etkinleştirir.

Domain almak istemiyorsan alternatifler: **DuckDNS** ücretsiz alt alan adı veya
**Cloudflare Tunnel** (sunucuda 80/443 açmadan HTTPS).

---

## 8. Güncelleme akışı

```bash
flutter test && flutter analyze                       # 207 test, 0 hata
flutter build web --release --pwa-strategy=none --no-web-resources-cdn
.\deploy\deploy.ps1 -Server ubuntu@<IP> -KeyPath $HOME\.ssh\gridpop.pem
```

Yeni build'i görmek için tarayıcıda Ctrl+F5. `index.html`, `main.dart.js` ve
`flutter_bootstrap.js` bilinçli olarak `no-cache`; geri kalan varlıklar 30 gün
önbelleklenir.

---

## 9. Sorun giderme

| Belirti | Sebep / çözüm |
|---|---|
| `403 Forbidden` | `index.html` yok veya izinler yanlış: `sudo chown -R www-data:www-data /var/www/gridpop` |
| Boş / gri ekran, konsolda `main.dart.js 404` | Dosyalar yanlış dizine gitti; `root /var/www/gridpop;` ile yüklenen yer aynı olmalı |
| Konsolda CSP ihlali | CDN'li build yüklenmiş; `--no-web-resources-cdn` ile yeniden derle |
| `WebAssembly` / MIME hatası | nginx < 1.21 `application/wasm` bilmez; Ubuntu 24.04 (nginx 1.24) ile sorun yok |
| Eski sürüm açılıyor | Ctrl+F5; ayrıca `--pwa-strategy=none` ile derlendiğinden emin ol |
| `nginx -t` hata veriyor | Deploy script reload etmez, site ayakta kalır; hatayı düzelt ve tekrar çalıştır |
| SSH "permissions are too open" | `chmod 400 gridpop.pem` |
| Site yavaş açılıyor | İlk yükleme ~41 MB (CanvasKit). `deploy.sh` `.gz` üretir; CloudFront/S3 ile CDN eklenebilir |

---

## 10. Maliyet / performans notları

- `t3.micro` çoğu hesapta 12 ay ücretsiz kapsamda (750 saat/ay). 7/24 açık
  bırakırsan saatlik ücretlendirme başlar; Elastic IP, örneğe **bağlıyken**
  ücretsizdir.
- İlk açılış ~41 MB (asıl yük `canvaskit.wasm` 7 MB + `main.dart.js` 2,4 MB).
  Sonraki açılışlar önbellekten gelir.
- Trafik büyürse en kolay ölçekleme: `build/web`'i **S3 + CloudFront**'a koymak
  (sunucu bakımı sıfır). Oyun statik olduğu için tek satır kod değişmez.
- Sunucuda derlemek zorunda kalırsan 2 GB swap ekle:

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 11. Güvenlik kontrol listesi

- [ ] Security group'ta SSH yalnızca kendi IP'ne açık, 80/443 dünya
- [ ] `PasswordAuthentication no` (EC2 Ubuntu imajında varsayılan)
- [ ] `unattended-upgrades` açık
- [ ] `.pem` dosyası depoya **girmiyor** (`.gitignore`)
- [ ] HTTPS + `certbot renew --dry-run` başarılı
- [ ] `curl -I` çıktısında `Content-Security-Policy`, `X-Frame-Options: DENY`,
      `X-Content-Type-Options: nosniff` görünüyor
