using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Globalization;

public sealed class EzanDataInfo {
    public string[] Locations;
    public string FirstDate;
    public string LastDate;
    public int RowCount;
}

public static class EzanCsv {
    internal const string Header = "il,ilce,tarih,imsak,gunes,ogle,ikindi,aksam,yatsi";

    // Veri satırları tek satırdır; tırnaklı alanları ve kaçırılmış tırnakları destekler.
    internal static string[] Parse(string line) {
        var fields = new List<string>();
        var field = new StringBuilder();
        bool quoted = false;
        for (int i = 0; i < line.Length; i++) {
            char c = line[i];
            if (c == '"') {
                if (quoted && i + 1 < line.Length && line[i + 1] == '"') { field.Append('"'); i++; }
                else quoted = !quoted;
            }
            else if (c == ',' && !quoted) { fields.Add(field.ToString()); field.Clear(); }
            else field.Append(c);
        }
        if (quoted) throw new InvalidDataException("CSV satırında kapanmamış tırnak var.");
        fields.Add(field.ToString());
        if (fields.Count != 9) throw new InvalidDataException("CSV satırında 9 sütun bekleniyor.");
        return fields.ToArray();
    }

    public static string Key(string value) {
        var result = new StringBuilder();
        foreach (char c in value.Trim().Replace('\u0131', 'i').Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) result.Append(c);
        return result.ToString().ToUpperInvariant();
    }

    private static StreamReader Open(string path) {
        var reader = new StreamReader(path, Encoding.UTF8, true);
        if (reader.ReadLine() != Header) { reader.Dispose(); throw new InvalidDataException("CSV başlıkları beklenen biçimde değil."); }
        return reader;
    }

    public static EzanDataInfo Inspect(string path) {
        var locations = new SortedSet<string>(StringComparer.Create(new CultureInfo("tr-TR"), false));
        var info = new EzanDataInfo();
        using (var reader = Open(path)) {
            string line;
            while ((line = reader.ReadLine()) != null) {
                if (String.IsNullOrWhiteSpace(line)) continue;
                var row = Parse(line);
                DateTime date;
                if (!DateTime.TryParseExact(row[2], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out date))
                    throw new InvalidDataException("CSV'de geçersiz tarih: " + row[2]);
                locations.Add(row[0] + "|" + row[1]);
                if (info.FirstDate == null || String.CompareOrdinal(row[2], info.FirstDate) < 0) info.FirstDate = row[2];
                if (info.LastDate == null || String.CompareOrdinal(row[2], info.LastDate) > 0) info.LastDate = row[2];
                info.RowCount++;
            }
        }
        if (info.RowCount == 0) throw new InvalidDataException("CSV boş.");
        info.Locations = new List<string>(locations).ToArray();
        return info;
    }

    public static string[] GetRow(string path, string city, string district, string date) {
        string[] found = null;
        string cityKey = Key(city), districtKey = Key(district);
        using (var reader = Open(path)) {
            string line;
            while ((line = reader.ReadLine()) != null) {
                if (String.IsNullOrWhiteSpace(line)) continue;
                // Alanları yalnızca ilgili tarihi içeren satırlarda ayrıştır.
                if (line.IndexOf(date, StringComparison.Ordinal) < 0) continue;
                var row = Parse(line);
                if (row[2] != date || Key(row[0]) != cityKey || Key(row[1]) != districtKey) continue;
                if (found != null) throw new InvalidDataException("Aynı konum ve tarih için birden fazla kayıt var.");
                found = row;
            }
        }
        if (found == null) throw new InvalidDataException(city + " / " + district + " için " + date + " kaydı yok. Konumu ve veri yılını kontrol edin.");
        return found;
    }
}
