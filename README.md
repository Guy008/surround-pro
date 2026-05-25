# surround-pro

המרת כל קובץ מדיה (וידאו / שמע / URL) לאודיו **7.1 Surround** עם הפרדה איכותית מבוססת AI.

> **גרסה נוכחית:** v0.1 — סקריפט bash מודולרי, TUI בלבד, ללא Docker.
> נבדק על Arch Linux עם AMD RX 6700 XT ו-NVIDIA RTX 2060 — עובד אוטומטית בשני המקרים.

---

## מה זה עושה

מקבל קובץ מקומי, URL (YouTube וכו'), או תיקייה שלמה — ומפיק קובץ 7.1:

- אם הקלט הוא **שמע** → פלט FLAC 7.1 (`*_7.1.flac`)
- אם הקלט הוא **וידאו** → פלט MKV עם וידאו מקורי + פס קול 7.1 (`*_7.1.mkv`)

הפרדה משולשת מבטיחה איכות ערוצים: הזמר מבודד מהמוזיקה, ה-echo/reverb מבודד מהזמר היבש, וכל אחד הולך למקום המתאים שלו ב-7.1.

---

## דרישות

**הסקריפט מתקין הכל לבד** — לא חייב להתקין שום דבר ידנית. הסקריפט יזהה מה חסר ויתקין דרך `pacman` (סודו ייבקש את הסיסמא פעם אחת).

נדרשים בסיסיים שצריכים להיות כבר על המערכת:
- Arch Linux (התמיכה במערכות אחרות תיווסף בעתיד)
- `bash`, `sudo`
- חיבור לאינטרנט (להורדת חבילות + מודלים בריצה ראשונה)
- דפדפן: Chrome / Chromium / Firefox / Brave / Vivaldi / Opera (לעוגיות YouTube)

הסקריפט מתקין אוטומטית:
- `uv`, `yt-dlp`, `ffmpeg`/`ffprobe`
- `rocm-hip-runtime` + `patchelf` + `binutils` (רק אם זוהה AMD GPU)
- חבילות Python: `torch` (CUDA/ROCm/CPU לפי החומרה), `demucs`, `audio-separator`, `onnxruntime`

---

## הפעלה

### מצב אינטראקטיבי

```bash
./surround-pro.sh
```

הסקריפט ישאל להזין URL / קובץ / תיקייה.

### עם ארגומנט ישיר

```bash
./surround-pro.sh "https://www.youtube.com/watch?v=..."
./surround-pro.sh /path/to/song.mp3
./surround-pro.sh /path/to/folder/        # מעבד את כל הקבצים בתיקייה
```

### עזרה ופרטים

```bash
./surround-pro.sh --help
```

### שינוי דפדפן לעוגיות

הסקריפט מזהה אוטומטית את הדפדפן הראשון שמותקן (chrome → chromium → brave → firefox → vivaldi → opera). לשליטה ידנית:

```bash
BROWSER_FOR_COOKIES=firefox ./surround-pro.sh https://...
```

### שינוי מיקום קאש מודלים

מודלי audio-separator נשמרים ב-`~/.cache/audio-separator-models/` (שורד reboot). לשינוי:

```bash
AUDIO_SEPARATOR_MODEL_DIR=/path/to/cache ./surround-pro.sh ...
```

---

## מבנה הפרויקט

```
surround-pro/
├── surround-pro.sh         # entry point
├── lib/
│   ├── install-deps.sh     # התקנה אוטומטית של pacman packages + patchelf
│   ├── detect-hardware.sh  # זיהוי GPU + פונקציות עזר
│   ├── setup-env.sh        # GPU compute test + הורדת torch + מודל Demucs
│   ├── handle-input.sh     # URL / קובץ / וידאו / שמע
│   ├── separate-stems.sh   # 3-stage: BS-RoFormer + De-Echo + Demucs
│   ├── build-71.sh         # ffmpeg filter_complex ל-7.1
│   └── cleanup.sh          # תיקיות זמניות + unique filenames
├── docs/
│   └── DECISION_LOG.md     # יומן החלטות תכנון
├── input/                  # קבצי קלט (gitignored)
├── output/                 # קבצי פלט (gitignored)
├── README.md
└── CHANGELOG.md
```

---

## הפייפליין (5 שלבים)

1. **סריקת חומרה + הכנה** — זיהוי GPU (NVIDIA / AMD ROCm / Intel / CPU). התקנה אוטומטית של תלויות חסרות. בדיקת GPU compute אמיתית (לא רק `cuda.is_available()`). באמצעות `patchelf --clear-execstack` ו-`HSA_OVERRIDE_GFX_VERSION` לתאימות AMD רחבה.
2. **זיהוי קלט וטעינה** — URL ⇒ yt-dlp / קובץ מקומי ⇒ cp + ffmpeg extract.
3. **הפרדה משולשת:**
   1. **BS-RoFormer Vocals** (audio-separator) ⇒ `vocal_wet.wav` + `instrumental.wav` — מבודד את הזמר עם כל ה-effects שלו מהמוזיקה.
   2. **UVR-DeEcho-DeReverb** ⇒ `dry_vocal.wav` + `echo_tail.wav` — מבודד את ה-echo/reverb של הזמר בנפרד מהזמר היבש.
   3. **Demucs htdemucs_ft** עם `--shifts 4` (GPU) או `1` (CPU) ⇒ `drums.wav`, `bass.wav`, `other.wav` (כולם נקיים לחלוטין מזמר).
4. **מיפוי 7.1 + קידוד FLAC** (ffmpeg filter_complex).
5. **קובץ סופי + ניקוי** של תיקיות זמניות.

---

## מיפוי ערוצי 7.1

| ערוץ | תוכן |
|------|------|
| **FL** | Drums highpass >250Hz (מצילות) **+ echo_tail** של הזמר (שמאל) |
| **FR** | Drums highpass >250Hz (מצילות) **+ echo_tail** של הזמר (ימין) |
| **FC** | **Dry vocal** — זמר ממוקד ויבש, ללא echo |
| **LFE** | Drums lowpass <120Hz + Bass — תופי באס + כלי בס |
| **SL** | Other (גיטרות, מקלדות, סינתים, מיתרים) — שמאל |
| **SR** | Other — ימין |
| **BL** | Other — שמאל (נפח / עומק חדר) |
| **BR** | Other — ימין |

> **למה ה-echo ב-FL/FR?** ה-echo/reverb של הזמר אמור להתפזר רחב במרחב — בדיוק כפי שהמהנדס המקורי התכוון. ה-FC נשמר נקי ויבש, וה-echo מקבל את ה"רוחב" שלו ברמקולים הקדמיים.

---

## תמיכה ב-GPU (תאימות אוטומטית רחבה)

| GPU | Backend | אוטומציה |
|-----|---------|----------|
| NVIDIA | CUDA (cu121) | Native — torch+cu121 פשוט עובד |
| AMD RDNA2 (RX 6800/6900, gfx1030) | ROCm 6.0 | `patchelf --clear-execstack` אוטומטי |
| AMD RDNA2 (RX 6600/6700, gfx1031/1032) | ROCm 6.0 + override | `patchelf` + `HSA_OVERRIDE_GFX_VERSION=10.3.0` אוטומטי |
| AMD אחר | ROCm 6.0 | ניסיון GPU; אם נכשל ⇒ CPU fallback אוטומטי |
| Intel | xpu | בסיסי (לא נבדק עדיין) |
| ללא GPU | CPU | עובד, איטי יותר |

---

## תמיכה בעברית ושמות בעייתיים

- שמות קבצים עם **תווים בעברית** עוברים כפי שהם.
- תווים אסורים במערכת קבצים (`/ \ ? % * : | " < >`) מומרים ל-`_`.
- אם קובץ פלט באותו שם כבר קיים → נוסף סיומת `_1`, `_2`, וכו' (ללא דריסה).

---

## מצב פיתוח

זוהי גרסה v0.1 — איכות מספיקה, מבנה יציב, חוסר תכונות מתקדמות. תכונות מתוכננות לעתיד:

- שיפור AI אופציונלי (AudioSR + Resemble Enhance)
- Re-encoding וידאו עם GPU (nvenc/amf/qsv)
- Docker (אופציונלי)
- אוטו-התקנה גם ב-Debian/Ubuntu (apt) ו-Fedora (dnf)
- מודלי Demucs / audio-separator שניתן להחליף דרך משתנה סביבה
