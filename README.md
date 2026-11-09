# Insat v1.0.0

Windows için küçük, çevrimdışı ezan vakti ses kontrol uygulaması.
**Python, Node.js veya ek paket indirme gerektirmez.** Windows 10/11 ile gelen
Windows PowerShell 5.1, .NET Framework ve Windows Forms kullanılır.

## Başlatma

1. ZIP paketini bir klasöre çıkarın; ZIP içinden çalıştırmayın.
2. **`Kur.cmd`** dosyasına çift tıklayın ve **Kur** düğmesine basın.
   **Masaüstüne Insat kısayolu oluştur** seçeneği varsayılan olarak açıktır.
3. Masaüstündeki **Insat** kısayolundan uygulamayı açın.
4. İl ve vakit bölgenizi seçin. Konumu değiştirmek için önce **Takibi durdur**, sonra
   **Takibi başlat** düğmesini kullanın. İlk açılış İstanbul / İstanbul için takibi başlatır.

Kurulum yalnızca geçerli kullanıcı içindir; yönetici izni istemez. Uygulama
`%LOCALAPPDATA%\Programs\Insat` klasörüne kopyalanır. Masaüstüne ve Başlat menüsüne
kısayollar eklenir. Kurulumdan sonra ZIP'i çıkardığınız klasörü silebilirsiniz.
Kaldırmak için **Başlat → Insat → Insat kaldır** seçeneğini kullanın. Kişisel
ayarlar korunur. Güncelleme/onarım için yeni paketten tekrar `Kur.cmd` çalıştırın.

Kurulum yapmadan taşınabilir kullanmak isterseniz `Baslat.cmd` dosyasını açın ve
o klasörü kalıcı bir yerde tutun. Giriş betiğinin adı **`insat.ps1`** dosyasıdır.

Vakit takibi çevrimdışı çalışır; yalnızca **Vakitleri güncelle** işlemi internet
bağlantısı kullanır. Bir konsol penceresi açık tutmanız gerekmez.
Windows internetten indirilen ZIP'i engellediyse ZIP'in Özellikler bölümündeki
**Engellemeyi kaldır** seçeneğini kullanıp yeniden çıkarın. Kurumsal uygulama
çalıştırma ilkeleri ayrıca geçerli olabilir.

## Bilgisayar konumundan il/ilçe seçme

Takibi ve varsa elle testi durdurup il/ilçe alanlarının yanındaki **Konumumu kullan**
bağlantısına tıklayın. Windows'tan konum istenir; en fazla 30 saniye beklenir.
Gerekirse **Windows konum ayarlarını aç** bağlantısından konum hizmetlerini ve
masaüstü uygulamaları için konum erişimini etkinleştirin.

Bulunan il/ilçe ve önerilen vakit bölgesi gösterilir. **Bu konumu kullan** ile
onaylayınca seçim kaydedilir; ardından **Takibi başlat** düğmesine basın. Eşleşen
ilçe vakit listesinde ayrı yoksa il merkezi önerisi açıkça belirtilir. Konum ve
öneriyi kontrol edin; özellikle ilçe sınırlarında elle düzeltme gerekebilir.

Konum izni verilmezse, konum çok belirsizse, Türkiye dışında kalırsa veya veri
eşleşmezse mevcut ayarlar korunur. **Vazgeç** de hiçbir ayarı değiştirmez.

Koordinatlar harici bir adres servisine gönderilmez ve kaydedilmez. Eşleştirme,
pakete dahil il/ilçe sınırlarıyla bilgisayarda yapılır. Yalnızca onayladığınız il ve
vakit bölgesi saklanır. Otomatik başlangıçta yeniden konum istenmez; düğmeye
bastığınızda tek sefer alınır. Windows'un kendi konum sağlayıcısı internet bağlantısı
gerektirebilir; konum alınamayan bilgisayarlarda elle seçim her zaman kullanılabilir.

Sınır verisi: **© OpenStreetMap contributors / geoBoundaries**, 2021 verisinin
sadeleştirilmiş dağıtımı. Ayrıntılar ve kaynak lisansları [coğrafi veri açıklamasında](data/geography/README.md).

## Arka planda çalışma ve kontrol

Sağ üstteki **Hakkında** bağlantısında uygulama sürümü, vakit verisinin tarih
kapsamı, kaydedilen bölge, veri kaynakları ve gizlilik bilgileri bulunur.
Aynı pencereye tepsi menüsünden erişebilir, kullanım kılavuzunu da buradan açabilirsiniz.

Destek: **of.sahin@outlook.com**.

- Pencerenin **×** düğmesi uygulamayı sistem tepsisine gizler; takip devam eder.
- **Insat** kısayolunu veya `Baslat.cmd` dosyasını yeniden açınca **aynı çalışan uygulamanın kontrol paneli** görünür.
  Aynı Windows oturumunda ikinci bir takip örneği oluşturulmaz.
- Tepsi simgesine çift tıklayarak da kontrol panelini açabilirsiniz. Simge Windows'un
  gizli simgeler alanında olabilir.
- **Takibi durdur**, takibi durdurur ve değiştirilmiş sesi hemen eski seviyesine getirir.
- **Tamamen çık**, sesi geri yükleyip uygulamayı sonlandırır. Aynı seçenekler tepsi
  simgesinin sağ tık menüsünde de bulunur.
- Başlatma/durdurma tercihi kaydedilir. Durdurulmuş uygulama yeniden açıldığında
  takip durdurulmuş kalır; **Takibi başlat** ile etkinleştirin.

## Bilgisayar açıldığında otomatik başlatma

**Bilgisayar açıldığında otomatik başlat** kutusunu işaretleyin. Uygulama yalnızca
geçerli Windows kullanıcısı oturum açınca, sistem tepsisinde başlar. Yönetici izni gerekmez.
Kutuyu kaldırınca başlangıç kaydı silinir. Son kaydedilen takip durumu korunur.
Takibin otomatik devam etmesi için uygulamayı **Takip açık** durumunda bırakın.

Bu seçenek Windows Başlangıç klasöründe `Insat.lnk` oluşturur.
Uygulamanın klasörünü taşıyacaksanız önce kutuyu kaldırın; taşıdıktan sonra yeni
konumdan açıp yeniden işaretleyin. Kurulu sürümde kaldırıcı başlangıç kısayolunu
da temizler. Taşınabilir sürümü kaldırmak için kutuyu kaldırın, **Tamamen çık**
ile kapatın ve uygulama klasörünü silin.

## Ses davranışı

- Ses kısılmasına 15 saniye kala geri sayımlı bir pencere açılır; uygulama tepsideyken de görünür.
  **Bu seferlik iptal et** yalnızca yaklaşan vakti veya elle planlanan testi atlar.
  Sonraki vakitlerin takibi devam eder; işlem başlayınca pencere otomatik kapanır.
- Sabah saati varsayılan olarak **13 Mart–6 Kasım: güneşten 1 saat önce**,
  **7 Kasım–12 Mart: imsak** şeklinde hesaplanır. Öğle, ikindi, akşam ve yatsı CSV'deki saatlerdir.
  Takibi ve varsa testi durdurup **Sabah ezanı ayarları** bağlantısından iki dönemin
  başlangıç günlerini değiştirebilirsiniz; **Kaydet** hemen uygular ve sonraki açılışlar için saklar.
  Başlangıç günleri ilgili döneme dahildir, her yıl tekrarlanır; aynı gün seçilemez.
  Her yıl geçerli olması için 29 Şubat dönem başlangıcı olarak kabul edilmez.
  Bu, kullanıcının belirlediği bir takip kuralıdır; Diyanet CSV'sindeki imsak ve güneş saatleri değiştirilmez.
- Ses, ezan vaktinden **1 dakika önce** kısılmaya başlar; varsayılan **60 saniye**
  kısılma süresiyle vakit geldiğinde tamamen kısılmış olur. Ezan başlangıcından **480 saniye**
  sonra, önceki seviyesine **30 saniyede** döner.
- Ezanın bittiği ayarlanan süreye göre kabul edilir; mikrofon kullanılmaz.
- Ezan ve kısılma süreleri arayüzden değiştirilebilir. Ayarlar **Takibi başlat** ile kaydedilir.
  Bir dakika önce başlama sabittir; kısılma süresi 60 saniyeden uzun seçilirse geçiş vakitten sonra tamamlanır.
  Elle saat testi, girilen saatte başlar; bir dakika öne alınmaz.
- Ses cihazı her ezanın başlangıcında seçilir ve o ezan boyunca korunur.
- Normal durdurma/çıkışta eski ses geri yüklenir. Görev Yöneticisi'nden zorla
  sonlandırma veya elektrik kesilmesi halinde bu garanti edilemez.
- Bilgisayarın yerel saatini Türkiye saat diliminde tutun. Kapalı/uykuda geçen
  vakitler sonradan tetiklenmez. Etkin ezan döngüsü sırasında uykudan dönülürse
  geçen zamana uygun ses seviyesi uygulanır.

## Elle saat girerek test

Ezan veya test başladığında üstteki durum kartı üç aşamayı canlı gösterir:
**1/3 Ses kısılıyor → 2/3 Ezan süresi bekleniyor → 3/3 Ses geri açılıyor**.
O aşamanın kalan süresi, işlemin toplam kalan süresi ve yüzdeli ilerleme çubuğu
otomatik güncellenir. Durdurma/iptal sonrasında gösterge kapanır.

Ana ekranda günlük vakitlerin yanındaki **Elle test saati…** bağlantısını açın.
Saati `HH:mm:ss` biçiminde girip **Testi planla** düğmesine basın. Test tek sefer
çalışır; ana ekrandaki ezan ve kısılma sürelerini kullanır, sesi 30 saniyede geri açar.
Hızlı deneme için takip dururken ezan süresini örneğin **10**, kısılma süresini **2**
saniye yapıp bir dakika sonrasını seçebilirsiniz.

Geçmiş bir saat seçilirse test ertesi güne planlanır; ana ekranda tam tarih ve saat
gösterilir. Test, normal takip durdurulmuşken de çalışır. **Testi iptal et** ile
bekleyen/çalışan testi iptal edebilirsiniz; ses değişmişse hemen eski seviyesine döner.
**Takibi durdur** da testi iptal eder. Normal vakit listesi ve takip tercihi korunur;
test uygulama yeniden açıldığında hatırlanmaz. Uyku nedeniyle bir dakikadan fazla
kaçırılan test sonradan çalıştırılmaz.

## Vakit verisini güncelleme

1. **Takibi durdur** düğmesine basın ve varsa testi iptal edin.
2. Güncellemek istediğiniz il ve vakit bölgesini seçin.
3. Sağ üstteki **Vakitleri güncelle** bağlantısını açın. Tepsi menüsünde de bulunur.
4. Yılı kontrol edip **Güncelle** düğmesine basın; varsayılan yıl bilgisayarın yılıdır.
5. İşlem tamamlanınca **Takibi başlat** ile devam edin.

Seçili bölgenin yıllık tablosu doğrudan **namazvakitleri.diyanet.gov.tr** adresinden
alınır. Referansımız [Diyanet İstanbul namaz vakitleri](https://namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-namaz-vakitleri)
sayfasıdır; diğer bölgeler aynı resmi sitedeki kendi kimlikleriyle alınır.
Güncellemede GitHub veya başka bir aracı veri servisi kullanılmaz.
Diyanet sayfasında istenen yıl yayımlanmamışsa veya 365/366 günün tamamı
doğrulanamıyorsa güncelleme reddedilir; mevcut CSV değiştirilmez. Sayfa biçimi
değişirse de hatalı veri yazmak yerine hata gösterilir. İnternet gerekir; Python,
API hesabı veya ek paket gerekmez. İşlem sırasında pencereyi kapatarak iptal edebilirsiniz.

CSV'nin seçili il/ilçe ve yıl kayıtları yenilenir; diğer kayıtlar korunur.
Güncellenmiş dosya `%LOCALAPPDATA%\Insat\data\diyanet_namaz_vakitleri_turkiye.csv`
konumuna yazılır. Bir önceki dosya `.backup` uzantısıyla korunur. Uygulama sonraki
açılışlarda bu dosyayı kullanır; yeniden kurulum ve kaldırma kişisel veri dosyasını
silmez. Paket içindeki başlangıç CSV'si değiştirilmez. Başka bir bölgeye geçtiğinizde
o bölgenin yılını da güncelleyin; tek güncelleme bütün Türkiye'yi internetten indirmez.

## Veri ve kapsam

Paket içindeki `data/diyanet_namaz_vakitleri_turkiye.csv` başlangıçta **2026** yılını
kapsar. Yeni yıl için uygulamadaki **Vakitleri güncelle** işlemini kullanın.
Veri her gün yerel dosyadan
okunur. O güne ait kayıt yoksa önceki günün saatleri kullanılmaz; durum arayüzde
bildirilir ve dosya 60 saniyede bir yeniden denenir.

Bazı merkez ilçeler ayrı listelenmez; CSV'deki il merkezi/vakit bölgesini seçin.
Yeni güncellemeler Diyanet'in resmi yıllık tablosundan alınır.
İl/ilçe kimlik kataloğu doğrudan Diyanet'in resmi il/ilçe seçim listesinden
yeniden hazırlanmıştır. Bu listeyi yenilemek için geliştirici aracı
`tools/Update-DiyanetLocations.ps1` kullanılır; GitHub'a ihtiyaç duymaz.
Insat, Diyanet'in resmi uygulaması değildir.

CSV sütunları: `il,ilce,tarih,imsak,gunes,ogle,ikindi,aksam,yatsi`.
Tarih `yyyy-MM-dd`, saat `HH:mm`, kodlama UTF-8 olmalıdır.

## Ayarlar ve sorun giderme

Ayarlar kullanıcıya özel `%LOCALAPPDATA%\Insat\settings.json` dosyasındadır;
bir önceki sürüm `settings.backup.json` olarak saklanır. Başlatma hataları aynı
klasördeki `error.log` dosyasına yazılır. Ayarlar bozulursa uygulamayı kapatıp
`settings.json` dosyasını yeniden adlandırarak varsayılanlara dönebilirsiniz.

## Proje düzeni

```text
Kur.cmd                     İsteğe bağlı kullanıcı kurulumu
Baslat.cmd                  Çift tıklayarak açılan giriş
VERSION                     Ürün sürümü
CHANGELOG.md                Sürüm notları
README.md                   Kullanım ve kapsam
insat.ps1                    PowerShell giriş noktası
app/
  App.ps1                   Windows Forms, tepsi, tek örnek kontrolü
  Core.ps1                  Takip motoru, ayarlar, otomatik başlangıç
  Data.cs                   CSV okuyucu ve konum indeksi
  Audio.cs                  Windows Core Audio erişimi
  Setup.ps1                 Küçük kurulum/kaldırma penceresi
  Install.ps1               Dosya yerleşimi ve kısayollar
  Location.ps1              Vakit bölgesi eşleştirmesi
  Location.cs               Windows konumu ve yerel sınır araması
  Update.cs                 Resmi yıllık tablo, doğrulama ve arka plan indirme
  Update.ps1                Veri yolu seçimi ve güvenli dosya değiştirme
  Update-Data.ps1            Komut satırından yıllık CSV güncelleme
assets/
  insat.ico                 Pencere, tepsi, kurulum ve kısayol ikonu (16–256 px)
  insat.png                 Sağlanan orijinal ikon görseli
data/
  diyanet_namaz_vakitleri_turkiye.csv
  diyanet_locations.json     Diyanet il/ilçe kimlikleri
  geography/                Yerel il/ilçe sınırları ve kaynak bilgileri
tests/
  insat.tests.ps1            Gerçek sese dokunmayan davranış testleri
  install.tests.ps1          İzole kurulum ve kaldırma testleri
  location.tests.ps1         Konum eşleştirmesi testleri
  update.tests.ps1           Yıl, tamlık, birleştirme ve geri alma testleri
tools/
  Build-Release.ps1          Bağımlılıksız taşınabilir ZIP oluşturma
  diyanet_csv_guncelle.py     Yıl bağımsız, ek paketsiz CSV güncelleme komutu
release/                    Dağıtım ZIP'i ve SHA-256 özeti
```

`tools/` içindeki geliştirici araçları uygulamanın çalışması için gerekmez;
dağıtım paketine dahil edilmez. Aynı veriyi içeren eski `.xlsx` kopyası kaldırılmıştır.
V1 taşınabilir Windows paketidir;
Microsoft Store yayını ve kod imzalama bu sürüme dahil değildir.

## Geliştirme ve doğrulama

```powershell
# Arayüzü aç
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\insat.ps1

# Ses değiştirmeden bugünün vakitlerini göster
.\insat.ps1 -Sehir Istanbul -Ilce Kucukcekmece -CheckSchedule

# Motor, ayarlar ve test klasöründe başlangıç kısayolu testleri
.\tests\insat.tests.ps1
.\tests\install.tests.ps1
.\tests\location.tests.ps1
.\tests\update.tests.ps1

# Kısa pencere testi; gerçek ses ve gerçek başlangıç kaydını değiştirmez
.\insat.ps1 -SmokeTest -DataDirectory "$PWD\tests\.runtime\ui"

# Dağıtım paketi
.\tools\Build-Release.ps1
```

Geliştirme aracı yeniden adlandırıldı: `tools/diyanet_csv_guncelle.py`.
Windows'ta aynı yerleşik güncelleyiciyi çağırır; `requests` kurulumu gerekmez:

```powershell
python .\tools\diyanet_csv_guncelle.py --city Istanbul --district Istanbul
python .\tools\diyanet_csv_guncelle.py --year 2027 --city Ankara --district Polatli --output .\vakitler.csv
```

Yıl verilmezse mevcut yıl kullanılır. İstenen yılın Diyanet sayfasında yayımlanmış
olması gerekir. Python aracı uygulamanın çalışması için gerekli değildir.

Tek örnek iletişimi Windows oturumuna özeldir. Kod ilk açılışta Windows'un yerleşik
C# derleyicisiyle bellekte derlenir; derleme aracı indirmeniz gerekmez.
