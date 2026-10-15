# Nightball

Haxball tarzı, aynı Wi‑Fi'daki cihazlar arasında oynanan 2D futbol oyunu. libGDX + Java.
Sunucu gerekmez: bir cihaz odayı kurar (host), diğerleri ağda odayı bulup katılır.

## Modüller

| Modül | İçerik |
|---|---|
| `core` | Oyunun tamamı: fizik, maç kuralları, ağ, arayüz |
| `lwjgl3` | Masaüstü başlatıcı (Windows / Linux / macOS) |
| `android` | Android başlatıcı. Sadece Android SDK tanımlıysa derlenir. |

## Masaüstü

```bash
./gradlew lwjgl3:run                      # oyunu aç
./gradlew lwjgl3:jar                      # tek dosya: lwjgl3/build/libs/Nightball-0.1.0.jar
```

Aynı bilgisayarda iki pencereyle test:

```bash
java -jar lwjgl3/build/libs/Nightball-0.1.0.jar --host --start --name Ali
java -jar lwjgl3/build/libs/Nightball-0.1.0.jar --join 127.0.0.1 --name Veli
```

`--start`, ikinci oyuncu katılınca maçı kendiliğinden başlatır.

## Windows paketi (Java kurmadan çalışır)

```bash
./gradlew lwjgl3:packageWinX64            # dist/Nightball-winX64.zip
```

Zip'i açıp `Nightball.exe`'ye çift tıklamak yeterli; içinde küçültülmüş bir Java 21 var.
Paketi [Construo](https://github.com/fourlastor-alexandria/construo) üretir. jlink derleme
makinesindeki JDK ile çalıştığı için `lwjgl3/build.gradle` içindeki Windows JDK sürümü,
derlemede kullanılan JDK ile aynı ana sürümde (21) olmalı.

İlk açılışta Windows Güvenlik Duvarı ağ izni sorar: aynı ağdaki oyuncuların odayı bulabilmesi
için "Özel ağlar" için izin verin. İmzasız bir exe olduğundan SmartScreen "Bilinmeyen yayımcı"
uyarısı gösterebilir ("Ek bilgi" → "Yine de çalıştır").

Kontroller: ok tuşları / WASD ile hareket, X veya Space ile şut.

## Android

`local.properties` içine `sdk.dir=/Android/SDK/yolu` yazın (ya da `ANDROID_HOME` tanımlayın), sonra:

```bash
./gradlew android:assembleDebug           # android/build/outputs/apk/debug/android-debug.apk
./gradlew android:installDebug            # bağlı telefona yükle
```

Kontroller: ekranın sol yarısı joystick (parmağın değdiği yerde belirir), sağ yarısına basılı tutmak şut.

## Dosyaları ağda paylaşma

```bash
cp android/build/outputs/apk/debug/android-debug.apk dist/Nightball-0.1.0.apk
python3 serve_dist.py            # dist/ klasörünü http://<bu-bilgisayarın-IP'si>:8000/ adresinde sunar
```

Aynı Wi‑Fi'daki telefon ve bilgisayarlar bu adresi tarayıcıda açıp APK'yı veya Windows zip'ini
indirebilir. APK'yı kurmak için telefonda "bilinmeyen kaynaklardan yükleme" izni gerekir.

## Testler

```bash
./gradlew core:test
```

Fizik ve maç kurallarını, ayrıca bu makinede gerçek UDP üzerinden bir host ile iki client'ın
lobi, maç ve çıkış akışını test eder.

## Ağ

- Oda arama: UDP 47777 (broadcast). Oyun: UDP 47778 (dolu ise rastgele port).
- Host otoriterdir: fizik sadece host'ta 60 Hz çalışır. Client'lar girdilerini yollar, host her
  tick'te durumu gönderir. Client'lar 3 tick geriden ve aradaki konumları yumuşatarak çizer.
- Oda listesinde görünmüyorsa: host ekranındaki IP adresiyle "join by address" kullanın.
  Misafir ağlar ve "AP isolation" açık olan modemler cihazların birbirini görmesini engeller.

## Fizik

`core/.../physics` ve `game/Match.java`, Haxball'un `game-min.js` dosyasından çıkarılan
formülleri kullanır. Haxball'daki gibi her tick'te önce hareket, sonra sürtünme
(`v = (v + g) * damping`) uygulanır, ardından çarpışmalar çözülür. Sekme katsayısı iki
cismin `bCoef` değerlerinin çarpımıdır. Oyuncu ve top varsayılanları Haxball'ınkiyle aynıdır.

## iOS

Henüz yok. Kod Java 8 seviyesinde tutuldu, böylece bir Mac'te gdx-liftoff ile RoboVM `ios`
modülü eklenebilir. iOS'ta otomatik oda bulma için Apple'ın multicast izni gerekir; o olmadan
IP ile katılma çalışır.
