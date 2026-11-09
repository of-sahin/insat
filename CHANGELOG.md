# Sürüm geçmişi

## 1.0.0 — 2026-11-09

- Sabah ezanı için ayarlanabilir yaz/kış başlangıçları (13 Mart / 7 Kasım); yazın güneşten bir saat önce, kışın imsak.
- Ses kısılmadan 15 saniye önce geri sayımlı uyarı ve bu seferlik iptal düğmesi.
- Ses kısılması ezan vaktinden bir dakika önce başlar; ezan süresi asıl vakitten sayılır.
- Diyanet resmi yıllık tablosundan seçili il/ilçe için CSV güncelleme aksiyonu.
- İstanbul için resmi referans sayfası; il/ilçe kataloğu doğrudan Diyanet'ten yeniden oluşturuldu. Güncellemede GitHub bağımlılığı yok.
- Yıl bağımsız CSV adı ve `diyanet_csv_guncelle.py`; ek Python paketi gerektirmez.
- Güncellemede tam yıl/saat doğrulaması, atomik değiştirme ve önceki dosya yedeği.
- Hakkında penceresi: sürüm, veri kapsamı, kaynak/lisans bilgileri ve gizlilik.
- Windows konumuyla il/ilçe önerisi, yerel sınır eşleştirmesi ve kullanıcı onayı.
- Sağlanan minare görseli pencere, tepsi, kurulum ve kısayol ikonu olarak eklendi.
- Ürün adı Insat; giriş betiği `insat.ps1` olarak düzenlendi.
- İsteğe bağlı kullanıcı kurulumu; masaüstü/Başlat menüsü kısayolları ve kaldırıcı.
- Elle saat girerek tek seferlik ses testi planlama ve iptal etme.
- Ezan/test sırasında aşama rehberi, kalan süreler ve canlı ilerleme çubuğu.
- Kurulum ve ek indirme gerektirmeyen taşınabilir Windows uygulaması.
- İl/ilçe seçimi, günlük beş vakit, sıradaki vakit ve çalışma durumu.
- Sistem tepsisinde arka plan takibi; yeniden açınca çalışan kontrol paneline erişim.
- Tek örnek çalışma, takibi başlat/durdur ve tamamen çıkma.
- Kullanıcıya özel, isteğe bağlı Windows oturum açılışında otomatik başlatma.
- Ayarlanabilir ezan/kısılma süreleri ve 30 saniyede ses geri açılması.
- Durdurmada önceki sesi geri yükleme, günlük veri yenileme, kalıcı ayarlar.
- 2026 Diyanet kaynaklı Türkiye vakit verisi pakete dahil.
