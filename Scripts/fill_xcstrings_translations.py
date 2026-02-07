#!/usr/bin/env python3
"""
Fill missing localizations in an Xcode String Catalog (.xcstrings).

This script is designed for InferX:
- Source language is English (the key itself).
- Supported locales match `InferX/Compenents/Language.swift`.
- Locale variants are filled by copying from their base locale when possible:
  - fr-CA  -> fr
  - es-419 -> es
  - zh-HK  -> zh-Hant
  - en-AU/en-GB/en-IN -> English source (key itself)

For missing entries, machine translations are generated via the unofficial
Google Translate endpoint used by many open-source tools:
  https://translate.googleapis.com/translate_a/single

Notes:
- Existing translations are never overwritten.
- Format placeholders like `%@`, `%lld`, `%.2f` are protected during translation.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


# Base locales we translate directly (xcstrings locale -> Google TL code).
BASE_LOCALES: Dict[str, str] = {
    "ar": "ar",
    "ca": "ca",
    "hr": "hr",
    "cs": "cs",
    "da": "da",
    "de": "de",
    "el": "el",
    "es": "es",
    "fi": "fi",
    "fr": "fr",
    "he": "he",
    "hi": "hi",
    "hu": "hu",
    "id": "id",
    "it": "it",
    "ja": "ja",
    "ko": "ko",
    "ms": "ms",
    "nb": "nb",
    "nl": "nl",
    "pl": "pl",
    "pt-PT": "pt-PT",
    "pt-BR": "pt-BR",
    "ro": "ro",
    "ru": "ru",
    "sk": "sk",
    "sv": "sv",
    "th": "th",
    "tr": "tr",
    "uk": "uk",
    "vi": "vi",
    "zh-Hans": "zh-CN",
    "zh-Hant": "zh-TW",
}

# Locale variants we fill by copying from a base locale's translation.
COPY_LOCALES: Dict[str, str] = {
    "fr-CA": "fr",
    "es-419": "es",
    "zh-HK": "zh-Hant",
}

# English variants: we fill with the key itself (English source).
EN_VARIANTS: List[str] = ["en-AU", "en-GB", "en-IN"]

# Locales we aim to have filled in the catalog (excluding base "en").
SUPPORTED_LOCALES: List[str] = (
    list(BASE_LOCALES.keys())
    + list(COPY_LOCALES.keys())
    + EN_VARIANTS
)


PLACEHOLDER_RE = re.compile(r"%(?:\\d+\\$)?[-+0# ]*(?:\\d+)?(?:\\.\\d+)?[a-zA-Z@]+")
# Match CJK Unified Ideographs (roughly common Han characters).
HAN_RE = re.compile(r"[\u4e00-\u9fff]")
ASCII_ALPHA_RE = re.compile(r"[A-Za-z]")


def _get_string_unit_value(localization_entry: Any) -> Optional[str]:
    if not isinstance(localization_entry, dict):
        return None
    string_unit = localization_entry.get("stringUnit")
    if not isinstance(string_unit, dict):
        return None
    value = string_unit.get("value")
    return value if isinstance(value, str) else None


def _set_string_unit(localizations: Dict[str, Any], locale: str, value: str) -> None:
    localizations[locale] = {
        "stringUnit": {
            "state": "translated",
            "value": value,
        }
    }


def _protect_placeholders(text: str) -> Tuple[str, List[str]]:
    placeholders = PLACEHOLDER_RE.findall(text)
    protected = text
    for i, ph in enumerate(placeholders):
        protected = protected.replace(ph, f"__PH{i}__")
    return protected, placeholders


def _restore_placeholders(text: str, placeholders: List[str]) -> str:
    restored = text
    for i, ph in enumerate(placeholders):
        restored = restored.replace(f"__PH{i}__", ph)
    return restored


def _translate_google(text: str, tl: str, sl: str = "en", timeout_s: int = 15) -> str:
    params = {
        "client": "gtx",
        "sl": sl,
        "tl": tl,
        "dt": "t",
        "q": text,
    }
    url = "https://translate.googleapis.com/translate_a/single?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=timeout_s) as resp:
        raw = resp.read().decode("utf-8")
    data = json.loads(raw)
    # data[0] = [[translated, original, ...], ...]
    return "".join(seg[0] for seg in data[0] if seg and isinstance(seg[0], str))


def translate_text(text: str, tl: str, *, sl: str = "en", retries: int = 4) -> str:
    protected, placeholders = _protect_placeholders(text)
    last_err: Optional[Exception] = None
    for attempt in range(retries):
        try:
            translated = _translate_google(protected, tl=tl, sl=sl)
            return _restore_placeholders(translated, placeholders)
        except Exception as e:  # noqa: BLE001
            last_err = e
            # simple exponential backoff
            time.sleep(min(8, 2**attempt))
    raise RuntimeError(f"Translation failed after {retries} retries: {last_err}")


def should_skip_key(key: str, *, translate_non_english: bool) -> bool:
    if key is None:
        return True
    if key == "" or key.strip() == "":
        return True
    if key == "\n":
        return True
    # If key contains Han characters (Chinese), assume it's a legacy key.
    # By default we skip it to avoid generating lots of irrelevant translations.
    if (not translate_non_english) and HAN_RE.search(key):
        return True
    return False


def is_copy_only_key(key: str) -> bool:
    """
    Return True for keys that are mostly placeholders/punctuation and don't need translation.

    Examples: "%lld/%lld", "%@", "...", " %.2f MB"
    """
    candidate = key.strip()
    if candidate in ("...",):
        return True
    # Remove printf-style placeholders and see if any ASCII letters remain.
    without_placeholders = PLACEHOLDER_RE.sub("", candidate)
    return ASCII_ALPHA_RE.search(without_placeholders) is None


def main() -> int:
    parser = argparse.ArgumentParser(description="Fill missing translations in a .xcstrings file.")
    parser.add_argument("--xcstrings", default="InferX/Localizable.xcstrings", help="Path to .xcstrings")
    parser.add_argument("--workers", type=int, default=8, help="Number of concurrent translation workers")
    parser.add_argument(
        "--translate-non-english",
        action="store_true",
        help="Also translate non-English keys (uses sl=auto). Default: skip keys with Han characters.",
    )
    args = parser.parse_args()

    xcstrings_path = Path(args.xcstrings)
    data: Dict[str, Any] = json.loads(xcstrings_path.read_text(encoding="utf-8"))
    strings: Dict[str, Any] = data.get("strings") or {}

    # Collect missing translation tasks.
    tasks: List[Tuple[str, str]] = []  # (key, locale)
    copied = 0
    english_filled = 0

    for key, entry in strings.items():
        if should_skip_key(key, translate_non_english=args.translate_non_english):
            continue

        if not isinstance(entry, dict):
            continue

        localizations = entry.get("localizations")
        if not isinstance(localizations, dict):
            localizations = {}
            entry["localizations"] = localizations

        # Fill English variants directly with the key.
        for loc in EN_VARIANTS:
            if not _get_string_unit_value(localizations.get(loc)):
                _set_string_unit(localizations, loc, key)
                english_filled += 1

        # Copy locale variants from base locale (if base exists later we will copy after base translations).
        for loc, base in COPY_LOCALES.items():
            if _get_string_unit_value(localizations.get(loc)):
                continue
            base_val = _get_string_unit_value(localizations.get(base))
            if base_val:
                _set_string_unit(localizations, loc, base_val)
                copied += 1

        # For copy-only keys, fill all locales with the key itself (no translation calls).
        if is_copy_only_key(key):
            for loc in BASE_LOCALES.keys():
                if not _get_string_unit_value(localizations.get(loc)):
                    _set_string_unit(localizations, loc, key)
            continue

        # Translate base locales if missing.
        for loc, google_tl in BASE_LOCALES.items():
            if _get_string_unit_value(localizations.get(loc)):
                continue
            tasks.append((key, loc))

    print(f"Keys in catalog: {len(strings)}")
    print(f"Missing base-locale translations to generate: {len(tasks)}")
    print(f"Pre-filled English variants: {english_filled}")
    print(f"Pre-copied locale variants: {copied}")

    # Execute translations concurrently.
    def _do_translate(task: Tuple[str, str]) -> Tuple[str, str, str]:
        key, loc = task
        sl = "auto" if (args.translate_non_english and HAN_RE.search(key)) else "en"
        google_tl = BASE_LOCALES[loc]
        translated = translate_text(key, tl=google_tl, sl=sl)
        return key, loc, translated

    completed = 0
    failed = 0
    # Batch updates in-memory; write after all.
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futures = [ex.submit(_do_translate, t) for t in tasks]
        for fut in as_completed(futures):
            try:
                key, loc, translated = fut.result()
                entry = strings.get(key)
                if not isinstance(entry, dict):
                    continue
                localizations = entry.get("localizations")
                if not isinstance(localizations, dict):
                    localizations = {}
                    entry["localizations"] = localizations
                if not _get_string_unit_value(localizations.get(loc)):
                    _set_string_unit(localizations, loc, translated)
                completed += 1
                if completed % 200 == 0:
                    print(f"Translated {completed}/{len(tasks)} ...")
            except Exception as e:  # noqa: BLE001
                failed += 1
                if failed <= 20:
                    print(f"Translation failed: {e}")

    # Second pass: copy locale variants now that base locales are filled.
    copied2 = 0
    for key, entry in strings.items():
        if should_skip_key(key, translate_non_english=args.translate_non_english):
            continue
        if not isinstance(entry, dict):
            continue
        localizations = entry.get("localizations")
        if not isinstance(localizations, dict):
            continue
        for loc, base in COPY_LOCALES.items():
            if _get_string_unit_value(localizations.get(loc)):
                continue
            base_val = _get_string_unit_value(localizations.get(base))
            if base_val:
                _set_string_unit(localizations, loc, base_val)
                copied2 += 1

    print(f"Translations completed: {completed}/{len(tasks)} (failed: {failed})")
    print(f"Copied locale variants after translation: {copied2}")

    # Write a backup and then overwrite in a deterministic JSON format.
    backup_path = xcstrings_path.with_suffix(xcstrings_path.suffix + ".bak")
    shutil.copy2(xcstrings_path, backup_path)
    xcstrings_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote updated file: {xcstrings_path}")
    print(f"Backup saved at: {backup_path}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())

