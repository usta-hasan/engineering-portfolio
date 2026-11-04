# Fotoelektrik tizimlar monitoringi va diagnostikasi

**Tadqiqotchi:** Sayfiyev Hasan Olim o‘g‘li.  
**Ilmiy rahbar:** Maxmudov Maxsud Idrisovich.  
**Ixtisoslik:** 05.05.06 — Qayta tiklanuvchi energiya qurilmalari.  
**Mavzu:** Fotoelektrik batareyalarining energetik parametrlarini monitoring va diagnostika tizimini ishlab chiqish.  
**OAK ro‘yxati:** B2024.1.PhD/T4467 — [2024-yil 1-son, 185-bet](https://oak.uz/userfiles/files/2024-1-son.pdf).

## Tadqiqot mazmuni

Fotoelektrik modul va stringlarning ishchi parametrlarini o‘lchash, ma’lumotlarni markaziy kontrollerga uzatish va dastur orqali kuzatish. O‘lchash bloklarida kuchlanish, tok, harorat va yoritilish ko‘rsatkichlari olinadi. Tadqiqotda tashqi muhit, changlanganlik va haroratning fotoelektrik modul ishiga ta’siri o‘rganiladi.

```mermaid
flowchart LR
  A[PV modul va sensorlar] --> B[Modul kontrolleri]
  B --> C[String kontrolleri]
  C --> D[Markaziy ma’lumot yig‘ish]
  D --> E[Kompyuter monitoring dasturi]
```

## Texnik tarkib

- Arduino Mega 2560 va ATtiny85 mikrokontrollerlari.
- DS18B20 harorat sensori, BH1750 yoritilish sensori.
- Tok va kuchlanish o‘lchash uchun shunt, LM358 va moslashtirish zanjirlari.
- I²C va RS-485 orqali aloqa.
- Delphi dasturi orqali ma’lumot yig‘ish va monitoring.
- MATLAB/Simulink orqali PV xarakteristikalari va tashqi omillarni modellashtirish.

## Joriy etish

Zarangari Transgazstroy va Buxoro davlat pedagogika instituti maydonlaridagi ishlar bo‘yicha 20.10.2025 sanali dalolatnomalar mavjud. Energetika vazirligining 26.06.2026 sanali 02-11-3300 xati joriy etish bilan bog‘liq ma’lumotlarni qayd etadi.

## Ilmiy nashrlar

- PV monitoring va diagnostika qurilmasi: [Fan va texnologiyalar taraqqiyoti, 2/2025](https://journal.bstu.uz/public/article/84/).
- Quyosh intensivligini kuzatish qurilmasi: [Fan va texnologiyalar taraqqiyoti, 1/2025](https://journal.bstu.uz/public/article/31/).
- Yorug‘lik nurlanishi intensivligi: [IJARSET, 2024](https://www.ijarset.com/upload/2024/december/4-hasansoftware-03-revised.pdf).
- Quyosh elektr stansiyasida aktiv va reaktiv quvvat balansi: [AIP Conference Proceedings, 2025](https://doi.org/10.1063/5.0306232).

[16 ta nashrning to‘liq ro‘yxati](PUBLICATIONS.md).

## Dastur guvohnomalari va talabnoma

| Hujjat | Mazmun | Hasan Sayfiyevning ishtiroki |
|---|---|---|
| DGU 27454, 13.09.2023 | Quyosh panellari xususiyatlarini o‘lchovchi va ma’lumotlarni yig‘uvchi dastur | Huquq egasi; Maxmudov M.I. bilan hammuallif |
| DGU 27455, 13.09.2023 | Quyosh panellarining nazoratini monitoring tizimi uchun dasturiy ta’minoti | Huquq egasi; guvohnomada muallif Maxmudov M.I. |
| IAP 20240362, 25.06.2024 | Quyosh elektr stansiyalari parametrlarini diagnostika va monitoring qilish tizimi | Patent talabnomasi; 14.03.2025 ekspertiza yozishmasi mavjud |
