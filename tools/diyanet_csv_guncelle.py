#!/usr/bin/env python3
"""Seçili il/ilçenin Diyanet yıllık tablosunu CSV'ye günceller.

Ek Python paketi gerekmez. Windows'ta uygulamanın ortak PowerShell/C#
güncelleyicisini çağırır. Varsayılan yıl bilgisayarın içinde bulunduğu yıldır.

Örnek:
    python tools/diyanet_csv_guncelle.py --city Istanbul --district Istanbul
    python tools/diyanet_csv_guncelle.py --year 2027 --output vakitler.csv
"""
import argparse
from datetime import date
import os
from pathlib import Path
import subprocess


def build_command(city: str, district: str, year: int, output: Path | None) -> list[str]:
    root = Path(__file__).resolve().parent.parent
    shell = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    command = [str(shell), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
               str(root / "app/Update-Data.ps1"), "-City", city,
               "-District", district, "-Year", str(year)]
    if output is not None:
        command.extend(["-OutputPath", str(output.resolve())])
    return command


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--city", default="Istanbul", help="İl adı")
    parser.add_argument("--district", default="Istanbul", help="Vakit bölgesi / ilçe adı")
    parser.add_argument("--year", type=int, default=date.today().year, help="Veri yılı; varsayılan: bu yıl")
    parser.add_argument("--output", type=Path, help="CSV hedefi; varsayılan: Insat kullanıcı verisi")
    args = parser.parse_args()
    if not 2000 <= args.year <= 2100:
        parser.error("Yıl 2000–2100 arasında olmalı.")
    if os.name != "nt":
        parser.error("Bu araç Windows PowerShell gerektirir.")
    return subprocess.run(build_command(args.city, args.district, args.year, args.output), check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
