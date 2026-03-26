# Internationalization Rules (Extended)

1. Always add ALL 4 CSV columns (en, uk, fr, es) for every new tr() key
2. Always use UPPER_SNAKE_CASE for translation keys
3. Never use string concatenation with tr() — no tr("HELLO") + name
4. Always use plural form variants via tr() where applicable
5. Always test layout with FR translation (+30% text length)
6. Always verify cultural adequacy of food/animal content for all cultures
7. Always maintain RTL readiness for future Arabic support
8. Always verify: grep -r 'tr("' game/scripts/ keys match translations.csv
9. Always use minimum 24px font size for readability across languages
10. Always use Nunito font (supports Latin + Cyrillic character sets)
