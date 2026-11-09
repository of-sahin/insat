using System;
using System.IO;
using System.Collections.Generic;
using System.Device.Location;
using System.Web.Script.Serialization;

public sealed class InsatPosition {
    public string Status;
    public double Latitude, Longitude, AccuracyMeters;
}

public sealed class InsatPositionReader : IDisposable {
    private GeoCoordinateWatcher watcher;
    public void Start() {
        Dispose();
        watcher = new GeoCoordinateWatcher(GeoPositionAccuracy.Default);
        watcher.Start(false);
    }
    public InsatPosition Poll() {
        if (watcher == null) return new InsatPosition { Status = "Unavailable" };
        if (watcher.Permission == GeoPositionPermission.Denied) return new InsatPosition { Status = "Denied" };
        var position = watcher.Position;
        if (!position.Location.IsUnknown && (DateTimeOffset.UtcNow - position.Timestamp).TotalMinutes <= 10) {
            return new InsatPosition {
                Status = "Ready", Latitude = position.Location.Latitude,
                Longitude = position.Location.Longitude, AccuracyMeters = position.Location.HorizontalAccuracy
            };
        }
        return new InsatPosition { Status = watcher.Status == GeoPositionStatus.Disabled ? "Unavailable" : "Waiting" };
    }
    public void Dispose() {
        if (watcher != null) { watcher.Stop(); watcher.Dispose(); watcher = null; }
    }
}

public sealed class InsatRegion {
    public string Province;
    public string District;
}

// Yerel il/ilçe sınırları içinde nokta araması; internet isteği yapmaz.
public sealed class InsatGeoDatabase {
    private sealed class Point { public double X, Y; }
    private sealed class Feature {
        public string Name;
        public double MinX = double.MaxValue, MinY = double.MaxValue, MaxX = double.MinValue, MaxY = double.MinValue;
        public List<List<Point[]>> Polygons = new List<List<Point[]>>();
        private static bool InRing(Point[] ring, double x, double y) {
            bool inside = false;
            for (int i = 0, j = ring.Length - 1; i < ring.Length; j = i++) {
                var a = ring[i]; var b = ring[j];
                if ((a.Y > y) != (b.Y > y) && x < (b.X - a.X) * (y - a.Y) / (b.Y - a.Y) + a.X) inside = !inside;
            }
            return inside;
        }
        public bool Contains(double x, double y) {
            if (x < MinX || x > MaxX || y < MinY || y > MaxY) return false;
            foreach (var polygon in Polygons) {
                if (polygon.Count == 0 || !InRing(polygon[0], x, y)) continue;
                bool hole = false;
                for (int i = 1; i < polygon.Count; i++) if (InRing(polygon[i], x, y)) { hole = true; break; }
                if (!hole) return true;
            }
            return false;
        }
    }
    private readonly List<Feature> provinces, districts;
    public InsatGeoDatabase(string provincePath, string districtPath) {
        provinces = Load(provincePath); districts = Load(districtPath);
    }
    private static List<Feature> Load(string path) {
        var json = new JavaScriptSerializer { MaxJsonLength = 20000000, RecursionLimit = 100 };
        var root = (Dictionary<string, object>)json.DeserializeObject(File.ReadAllText(path));
        var result = new List<Feature>();
        foreach (Dictionary<string, object> item in (object[])root["features"]) {
            var properties = (Dictionary<string, object>)item["properties"];
            var geometry = (Dictionary<string, object>)item["geometry"];
            var feature = new Feature { Name = Convert.ToString(properties["shapeName"]) };
            var coordinates = (object[])geometry["coordinates"];
            object[] polygons;
            if ((string)geometry["type"] == "Polygon") polygons = new object[] { coordinates };
            else if ((string)geometry["type"] == "MultiPolygon") polygons = coordinates;
            else throw new InvalidDataException("Desteklenmeyen sınır geometrisi.");
            foreach (object[] polygon in polygons) {
                var rings = new List<Point[]>();
                foreach (object[] ring in polygon) {
                    var points = new List<Point>();
                    foreach (object[] pair in ring) {
                        var p = new Point { X = Convert.ToDouble(pair[0]), Y = Convert.ToDouble(pair[1]) };
                        points.Add(p);
                        feature.MinX = Math.Min(feature.MinX, p.X); feature.MaxX = Math.Max(feature.MaxX, p.X);
                        feature.MinY = Math.Min(feature.MinY, p.Y); feature.MaxY = Math.Max(feature.MaxY, p.Y);
                    }
                    if (points.Count < 3) throw new InvalidDataException("Eksik sınır halkası.");
                    rings.Add(points.ToArray());
                }
                feature.Polygons.Add(rings);
            }
            result.Add(feature);
        }
        return result;
    }
    public InsatRegion Lookup(double latitude, double longitude) {
        if (double.IsNaN(latitude) || double.IsNaN(longitude) || double.IsInfinity(latitude) || double.IsInfinity(longitude) ||
            latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) throw new ArgumentException("Geçersiz koordinat.");
        string province = null, district = null;
        foreach (var f in provinces) if (f.Contains(longitude, latitude)) { province = f.Name; break; }
        if (province == null) throw new InvalidOperationException("Konum Türkiye sınır verisinde bulunamadı. İl ve ilçeyi elle seçebilirsin.");
        foreach (var f in districts) if (f.Contains(longitude, latitude)) { district = f.Name; break; }
        return new InsatRegion { Province = province, District = district };
    }
}
