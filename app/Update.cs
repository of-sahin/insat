using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;

public sealed class InsatUpdateResult {
    public int Year, Days;
    public string SourceUrl;
}

public static class InsatDiyanetData {
    public const string ReferenceUrl = "https://namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-namaz-vakitleri";
    private static readonly RegexOptions Flags = RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.CultureInvariant;
    private static string Text(string html) {
        return Regex.Replace(WebUtility.HtmlDecode(Regex.Replace(html, "<[^>]*>", " ")), @"\s+", " ").Trim();
    }
    public static void ValidateLocation(string html, string districtId) {
        foreach (Match link in Regex.Matches(html, @"<link\b[^>]*>", Flags)) {
            if (!Regex.IsMatch(link.Value, "\\brel\\s*=\\s*[\"']canonical[\"']", Flags)) continue;
            var href = Regex.Match(link.Value, "\\bhref\\s*=\\s*[\"']([^\"']+)[\"']", Flags);
            Uri uri;
            if (href.Success && Uri.TryCreate(WebUtility.HtmlDecode(href.Groups[1].Value), UriKind.Absolute, out uri) &&
                uri.Scheme == "https" && uri.Host == "namazvakitleri.diyanet.gov.tr" &&
                (uri.AbsolutePath.Equals("/tr-TR/" + districtId, StringComparison.OrdinalIgnoreCase) ||
                 uri.AbsolutePath.StartsWith("/tr-TR/" + districtId + "/", StringComparison.OrdinalIgnoreCase))) return;
        }
        throw new InvalidDataException("Diyanet sayfası seçili konumla eşleşmiyor; mevcut CSV korundu.");
    }
    public static SortedDictionary<DateTime, string[]> ParseYear(string html, int year) {
        if (year < 2000 || year > 2100) throw new ArgumentException("Yıl 2000–2100 arasında olmalı.");
        var table = Regex.Match(html, "<table\\b[^>]*\\bid\\s*=\\s*[\"']yourTable[\"'][^>]*>(.*?)</table\\s*>", Flags);
        if (!table.Success) throw new InvalidDataException("Diyanet yıllık tablosu bulunamadı. Sayfa biçimi değişmiş olabilir; mevcut veri korundu.");
        var result = new SortedDictionary<DateTime, string[]>();
        foreach (Match row in Regex.Matches(table.Groups[1].Value, @"<tr\b[^>]*>(.*?)</tr\s*>", Flags)) {
            var cells = Regex.Matches(row.Groups[1].Value, @"<td\b[^>]*>(.*?)</td\s*>", Flags);
            if (cells.Count == 0) continue;
            if (cells.Count != 8) throw new InvalidDataException("Diyanet yıllık tablosunda beklenmeyen sütun sayısı.");
            DateTime date;
            if (!DateTime.TryParseExact(Text(cells[0].Groups[1].Value), new[] { "dd MMMM yyyy dddd", "d MMMM yyyy dddd" },
                CultureInfo.GetCultureInfo("tr-TR"), DateTimeStyles.None, out date)) throw new InvalidDataException("Yıllık tabloda tarih okunamadı.");
            if (date.Year != year) continue;
            var times = new string[6];
            int previous = -1;
            for (int i = 0; i < 6; i++) {
                times[i] = Text(cells[i + 2].Groups[1].Value);
                if (!Regex.IsMatch(times[i], @"^([01][0-9]|2[0-3]):[0-5][0-9]$")) throw new InvalidDataException("Diyanet tablosunda geçersiz saat.");
                int minutes = Int32.Parse(times[i].Substring(0, 2), CultureInfo.InvariantCulture) * 60 + Int32.Parse(times[i].Substring(3, 2), CultureInfo.InvariantCulture);
                if (minutes <= previous) throw new InvalidDataException("Namaz vakitlerinin sırası geçersiz.");
                previous = minutes;
            }
            if (result.ContainsKey(date)) throw new InvalidDataException("Diyanet tablosunda tekrarlı tarih var.");
            result.Add(date, times);
        }
        int days = DateTime.IsLeapYear(year) ? 366 : 365;
        if (result.Count != days) throw new InvalidDataException(year + " için tam yıl verisi bulunamadı (" + result.Count + "/" + days + "). Henüz yayımlanmamış olabilir; mevcut CSV değiştirilmedi.");
        for (var date = new DateTime(year, 1, 1); date.Year == year; date = date.AddDays(1))
            if (!result.ContainsKey(date)) throw new InvalidDataException("Yıllık tabloda eksik gün var.");
        return result;
    }
    private static string Csv(string value) {
        return value.IndexOfAny(new[] { ',', '"', '\r', '\n' }) >= 0 ? "\"" + value.Replace("\"", "\"\"") + "\"" : value;
    }
    public static InsatUpdateResult BuildCsv(string html, int year, string city, string district, string existingPath, string outputPath, CancellationToken token) {
        var annual = ParseYear(html, year);
        string cityKey = EzanCsv.Key(city), districtKey = EzanCsv.Key(district);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)));
        try {
            using (var writer = new StreamWriter(outputPath, false, new UTF8Encoding(true))) {
                writer.WriteLine(EzanCsv.Header);
                if (File.Exists(existingPath)) {
                    using (var reader = new StreamReader(existingPath, Encoding.UTF8, true)) {
                        if (reader.ReadLine() != EzanCsv.Header) throw new InvalidDataException("Mevcut CSV başlığı geçersiz.");
                        string line;
                        while ((line = reader.ReadLine()) != null) {
                            token.ThrowIfCancellationRequested();
                            if (String.IsNullOrWhiteSpace(line)) continue;
                            var fields = EzanCsv.Parse(line);
                            if (EzanCsv.Key(fields[0]) == cityKey && EzanCsv.Key(fields[1]) == districtKey && fields[2].StartsWith(year.ToString(CultureInfo.InvariantCulture) + "-", StringComparison.Ordinal)) continue;
                            writer.WriteLine(line);
                        }
                    }
                }
                foreach (var pair in annual) {
                    token.ThrowIfCancellationRequested();
                    var fields = new List<string> { city, district, pair.Key.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) };
                    fields.AddRange(pair.Value);
                    writer.WriteLine(String.Join(",", fields.ConvertAll(Csv).ToArray()));
                }
            }
            token.ThrowIfCancellationRequested();
            // Bütün dosyanın tekrar okunabildiğini doğrula; canlı dosya burada değiştirilmez.
            EzanCsv.Inspect(outputPath);
            return new InsatUpdateResult { Year = year, Days = annual.Count };
        }
        catch { if (File.Exists(outputPath)) File.Delete(outputPath); throw; }
    }
}

public sealed class InsatUpdateJob : IDisposable {
    private readonly CancellationTokenSource cancellation = new CancellationTokenSource();
    private readonly string outputPath;
    public readonly Task<InsatUpdateResult> Task;
    public volatile string Status = "Diyanet yıllık tablosu indiriliyor…";
    public InsatUpdateJob(int year, string city, string district, string districtId, string existingPath, string pendingPath) {
        if (!Regex.IsMatch(districtId, @"^[0-9]+$")) throw new ArgumentException("Diyanet konum kimliği geçersiz.");
        outputPath = pendingPath;
        string url = districtId == "9541" ? InsatDiyanetData.ReferenceUrl : "https://namazvakitleri.diyanet.gov.tr/tr-TR/" + districtId;
        Task = System.Threading.Tasks.Task.Factory.StartNew(() => {
            cancellation.Token.ThrowIfCancellationRequested();
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            var request = (HttpWebRequest)WebRequest.Create(url);
            request.UserAgent = "Insat/1.0 (Windows prayer-time updater)";
            request.Timeout = 30000; request.ReadWriteTimeout = 30000;
            string html;
            using (cancellation.Token.Register(request.Abort))
            using (var response = (HttpWebResponse)request.GetResponse()) {
                if (response.ResponseUri.Scheme != "https" || response.ResponseUri.Host != "namazvakitleri.diyanet.gov.tr") throw new InvalidDataException("Beklenmeyen veri kaynağına yönlendirme.");
                using (var reader = new StreamReader(response.GetResponseStream(), Encoding.UTF8)) {
                    var text = new StringBuilder(); var buffer = new char[8192]; int count;
                    while ((count = reader.Read(buffer, 0, buffer.Length)) > 0) {
                        cancellation.Token.ThrowIfCancellationRequested();
                        text.Append(buffer, 0, count);
                        if (text.Length > 4000000) throw new InvalidDataException("Diyanet yanıtı beklenenden büyük.");
                    }
                    html = text.ToString();
                }
            }
            cancellation.Token.ThrowIfCancellationRequested();
            InsatDiyanetData.ValidateLocation(html, districtId);
            Status = "Yılın bütün günleri doğrulanıyor; CSV hazırlanıyor…";
            var result = InsatDiyanetData.BuildCsv(html, year, city, district, existingPath, pendingPath, cancellation.Token);
            result.SourceUrl = url;
            return result;
        }, cancellation.Token, TaskCreationOptions.LongRunning, TaskScheduler.Default);
    }
    public void Cancel() { cancellation.Cancel(); }
    public void Dispose() {
        if (!Task.IsCompleted) cancellation.Cancel();
        Task.ContinueWith(t => {
            // Başarısız veya iptal edilmiş işin benzersiz geçici çıktısını bırakma.
            if (File.Exists(outputPath)) { try { File.Delete(outputPath); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
            cancellation.Dispose();
        }, TaskScheduler.Default);
    }
}
