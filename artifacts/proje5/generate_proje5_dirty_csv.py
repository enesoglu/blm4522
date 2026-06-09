from __future__ import annotations

import csv
import random
from datetime import date, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "proje5" / "dirty_customers.csv"

FIRST_NAMES = [
    "Enes", "Ayse", "Mehmet", "Zeynep", "Ali", "Elif", "Murat", "Selin",
    "Can", "Deniz", "Ece", "Burak", "Derya", "Kerem", "Seda", "Yusuf",
]
LAST_NAMES = [
    "Yildiz", "Kara", "Demir", "Ak", "Veli", "Celik", "Can", "Oz",
    "Sahin", "Arslan", "Aydin", "Koc", "Kaya", "Yilmaz", "Erdem", "Polat",
]
CITIES = ["Ankara", "Istanbul", "Izmir", "Bursa", "Konya", "Antalya", "Eskisehir", "Adana"]


def messy_name(value: str, idx: int) -> str:
    if idx % 17 == 0:
        return f"  {value.upper()}  "
    if idx % 23 == 0:
        return value.lower()
    return value


def messy_email(first: str, last: str, idx: int) -> str:
    base = f"{first.lower()}.{last.lower()}{idx}@example.com"
    if idx % 31 == 0:
        return ""
    if idx % 37 == 0:
        return base.replace("@", "[at]")
    if idx % 41 == 0:
        return base.upper()
    if idx % 53 == 0:
        return f"{first.lower()}.{last.lower()}{idx}@"
    return base


def messy_phone(idx: int) -> str:
    local = f"5{idx % 90 + 10:02d}{idx % 9000000:07d}"
    if idx % 29 == 0:
        return ""
    if idx % 43 == 0:
        return "abc-phone"
    if idx % 5 == 0:
        return f"+90 {local[:3]} {local[3:6]} {local[6:]}"
    if idx % 7 == 0:
        return f"0{local[:3]}-{local[3:6]}-{local[6:]}"
    if idx % 11 == 0:
        return f"({local[:3]}) {local[3:6]}-{local[6:]}"
    return local


def messy_age(idx: int) -> str:
    if idx % 67 == 0:
        return "-4"
    if idx % 71 == 0:
        return "156"
    if idx % 83 == 0:
        return "yas"
    return str(18 + (idx % 55))


def messy_city(idx: int) -> str:
    city = CITIES[idx % len(CITIES)]
    if idx % 19 == 0:
        return ""
    if idx % 13 == 0:
        return city.upper()
    if idx % 17 == 0:
        return f"  {city.lower()} "
    return city


def messy_date(base_date: date, idx: int) -> str:
    value = base_date + timedelta(days=idx % 180)
    if idx % 47 == 0:
        return value.strftime("%d/%m/%Y")
    if idx % 59 == 0:
        return value.strftime("%d.%m.%Y")
    if idx % 89 == 0:
        return "2026/31/05"
    return value.strftime("%Y-%m-%d")


def build_row(idx: int) -> dict[str, str]:
    first = FIRST_NAMES[idx % len(FIRST_NAMES)]
    last = LAST_NAMES[(idx * 3) % len(LAST_NAMES)]
    quantity = 1 + (idx % 5)
    price = round(25 + (idx % 200) * 1.37, 2)
    if idx % 79 == 0:
        price = -12.0
    if idx % 97 == 0:
        quantity = 0
    return {
        "first_name": messy_name(first, idx),
        "last_name": messy_name(last, idx + 5),
        "email": messy_email(first, last, idx),
        "phone": messy_phone(idx),
        "age": messy_age(idx),
        "city": messy_city(idx),
        "country": "TR" if idx % 9 else "Turkey",
        "order_date": messy_date(date(2026, 1, 1), idx),
        "product_id": str(100 + (idx % 60)),
        "quantity": str(quantity),
        "unit_price": f"{price:.2f}",
    }


def main() -> None:
    random.seed(4522)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rows = [build_row(i) for i in range(1, 5001)]

    # Add deterministic duplicates by copying earlier rows and changing only harmless spacing/case.
    for target in range(250, 5001, 250):
        source = rows[target - 125].copy()
        source["first_name"] = f" {source['first_name'].strip().upper()} "
        source["last_name"] = source["last_name"].strip().lower()
        rows[target - 1] = source

    with OUT.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(OUT)


if __name__ == "__main__":
    main()
