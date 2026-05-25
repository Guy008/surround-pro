# 📋 Decision Log — surround-pro

יומן החלטות תכנוניות. כל החלטה משמעותית — מה הוחלט, מתי, ולמה.

---

## v1.0 — 2026-05-25 (Public Release)

### [D-031] Multi-OS auto-install (pacman/apt/dnf/zypper)
- **החלטה:** `lib/install-deps.sh` refactored — generic `ensure_cmd` ו-`run_pkg_install` שמזהים את ה-package manager ופועלים בהתאם. yt-dlp תמיד דרך pip ב-non-Arch (גרסת apt/dnf ישנה מדי).
- **למה:** v1.0 = שחרור ציבורי. אסור להגביל ל-Arch. משתמשי Ubuntu/Fedora מקבלים אוטו-התקנה זהה.
- **Limitation:** ROCm install עדיין רק ב-Arch. במערכות אחרות מודיעים למשתמש איך להתקין ידנית, או שהוא משתמש ב-Docker.

### [D-032] LICENSE: MIT
- **החלטה:** LICENSE קובץ עם MIT (Copyright 2026 Guy Levi). מציין גם רישיונות של ספריות חיצוניות (Demucs, BS-RoFormer, UVR, audio-separator).
- **למה:** רישיון המקובל ביותר לפרויקטי אודיו open-source. מתיר שימוש מסחרי תוך הגנה מינימלית.

### [D-033] README דו-לשוני
- **החלטה:** README שומר את התוכן בעברית, אבל מוסיף intro באנגלית + quickstart ל-Docker בראש.
- **למה:** המטרה היא שחרור ציבורי. רוב המשתמשים בעולם קוראים אנגלית. quickstart ב-Docker = כל אחד יכול להתחיל ב-2 פקודות בלי לקרוא הכל.

### [D-034] AI enhancement deferred to post-v1.0
- **החלטה:** AudioSR / Resemble Enhance לא נכללים ב-v1.0.
- **למה:** איכות הפלט ב-v0.3 כבר משביעה רצון של גיא. הוספת AI enhancement = +5 דק' זמן עיבוד, dependency נוסף, ויתרון איכותי שולי שתלוי בשיר. עדיף לשחרר v1.0 stable ולשקול enhance ב-v1.1+.

---

## v0.4 — 2026-05-25

### [D-027] Docker — Ubuntu 24.04, CPU-only ראשון
- **החלטה:** ה-Docker image הראשון הוא CPU-only על Ubuntu 24.04. ללא תמיכת GPU מובנית.
- **למה:** GPU ב-Docker דורש variant נפרד לכל vendor (NVIDIA cuda base, AMD rocm base). לבצע את זה כפול image = הרבה זמן. CPU עובד על כולם, מהווה baseline.
- **עתיד:** v0.5+ ייתן variants ל-GPU.

### [D-028] yt-dlp מ-pip ולא מ-apt ב-Docker
- **החלטה:** במקום `apt install yt-dlp`, משתמשים ב-`pip3 install --break-system-packages yt-dlp`.
- **למה:** Ubuntu 24.04 apt = yt-dlp ישן (חודשים אחורה). YouTube משנה את ה-API שלהם הרבה, ו-yt-dlp ישן נחסם עם `HTTP 400 Bad Request`. הגרסה מ-pip תמיד עדכנית.

### [D-029] build-essential ב-Docker
- **החלטה:** מוסיפים `build-essential` + `python3-dev` ל-Dockerfile.
- **למה:** `diffq` (תלות של audio-separator) הוא C extension שדורש compilation בהתקנה. ללא gcc → `error: command 'cc' failed: No such file or directory`. ההוספה עולה ~150MB אבל הכרחית.

### [D-030] OUTPUT_DIR override-able דרך env var
- **החלטה:** `OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"` במקום קשיח.
- **למה:** Docker רוצה `/output` (volume mount). במקום sed או patch על הקוד, פשוט env var override.

---

## v0.3 — 2026-05-25

### [D-025] Multi-format MKV — קובץ סופי יחיד עם כל הפורמטים
- **החלטה:** במקום `*_7.1.flac` ו-`*_7.1.mkv` נפרדים, יוצרים MKV יחיד `*_surround.mkv` שמכיל 5 פסי שמע: 7.1, 5.1(side), 2.1, Stereo, Mono. אם הקלט וידאו — גם הוידאו המקורי. ffmpeg עושה הכל ב-pass יחיד עם `asplit=5` + 4 pan filters.
- **למה:** חזון של גיא — "קובץ סופי אחד עם כל האפשרויות". המשתמש בוחר ב-player. גם משתמשים בלי 7.1 מקבלים תוצאה בלי שצריך לחשוב.
- **טכני:** ffmpeg's 5.1 default = back layout (BL/BR). לשמירת עקביות עם המפה המקורית 7.1 → 5.1 נכון, צריך `5.1(side)` כך שיש SL/SR.
- **Trade-off:** הקובץ גדול יותר (5 streams לעומת 1), אבל FLAC compressed → לא דרמטי.

### [D-026] Search-by-name
- **החלטה:** אם הקלט אינו URL/קובץ/תיקייה, מנסים `yt-dlp --default-search ytsearch1 "$input"` ולוקחים את התוצאה הראשונה.
- **למה:** משתמש שרוצה רק לשמוע "הדג נחש - הכאפה המצלצלת" — מקליד שם, מקבל קובץ. לא צריך לחפש URL ידני.
- **Quality:** ytsearch1 לרוב מחזיר את הקליפ הרשמי. אם לא — המשתמש יראה את ה-URL ויכול להריץ שוב עם URL מדויק.

---

## v0.2 — 2026-05-25

### [D-020] Demucs htdemucs_ft → htdemucs_6s
- **החלטה:** מודל ההפרדה מ-`htdemucs_ft` (4 stems, bag of 4) ל-`htdemucs_6s` (6 stems כולל guitar + piano, single model).
- **למה:** v0.2 דורש routing לפי כלי. htdemucs_6s הוא היחיד שמפצל גיטרה ופסנתר מ"other".
- **Trade-offs:**
  - SDR drums יורד מ-10.0 ל-8.5
  - SDR bass יורד מ-12.0 ל-10.1
  - piano stem ידוע bleeding/artifacts (Meta)
  - **חיובי:** אין bag → מהיר יותר.
- **fallback:** אם בעתיד נצטרך איכות גבוהה יותר ב-stems הקיימים, ניתן לתת flag להחזיר ל-_ft.

### [D-021] מיפוי 7.1 לפי כלי (v0.2)
- **החלטה:**
  - FC = dry vocal *(נעול)*
  - FL/FR = drums highpass>100Hz + echo × 0.4
  - LFE = drums lowpass<120Hz + bass
  - SL/SR = piano + other × 0.3
  - BL/BR = guitar + other × 0.7
- **למה:** העדפה אומנותית של גיא — piano בצדדים, guitar אחורה. ה"other" מפוצל 30/70 כך שאף ערוץ לא ישתוק בשירים בלי piano/guitar.
- **טכני:** ffmpeg filter עם `asplit=2` ל"other" כדי לפצל לזרמים זהים לצדדים ולאחור (ffmpeg לא מאפשר לעשות שימוש כפול ב-labeled output).

### [D-022] drums highpass: 250Hz → 100Hz
- **החלטה:** ה-highpass שמכין FL/FR יורד מ-250Hz ל-100Hz.
- **למה:** ב-250Hz נכלא רק מצילות+attack. ב-100Hz נכנס גם snare body + tom body (האלמנטים שמייצרים את "הקצב"). גיא ציין שב-v0.1 חסרו תופים חשובים.

### [D-023] echo weight ב-FL/FR: 1.0 → 0.4
- **החלטה:** ה-echo_tail מקבל weight=0.4 (-8dB) ב-amix עם drums.
- **למה:** ב-v0.1 ה-echo גבר על התופים. -8dB מאזן — הוא נשמע אבל לא דומיננטי.

### [D-024] drum sub-stem (kick/snare/cymbals) — דחוי
- **החלטה:** לא משלבים LarsNet/DrumSep ב-v0.2. ממשיכים עם DSP bandpass.
- **למה:** audio-separator לא תומך native ב-drum sub-stem. LarsNet זמין כ-repo נפרד (562MB מודל) — אינטגרציה לא קלה. תינתן עדיפות אחרי שאר הפיצ'רים.

---

## v0.1 — 2026-05-25

### [D-001] בחירת פורמט פרויקט: סקריפט bash יחיד, TUI בלבד
- **החלטה:** אין Docker. סקריפט bash מודולרי שרץ ישירות על המארח.
- **למה:** גיא ביקש v0.1 בסיסית — להשתמש בכלי המארח, פחות סיבוכים. Docker יישקל בעתיד.

### [D-002] מבנה מודולרי תחת `lib/`
- **החלטה:** entry point יחיד (`surround-pro.sh`) שמטעין מודולים מ-`lib/` באמצעות `source`.
- **למה:** קל לתחזוקה, כל שלב מבודד, אפשר להחליף יישום בודד בלי לשבור את השאר.

### [D-003] ללא הערות בקוד
- **החלטה:** קבצי `.sh` נשארים נקיים — בלי שורות `# comment`. הסברים בקבצי docs נפרדים.
- **למה:** העדפה אישית של גיא — קוד שדובר בעד עצמו, תיעוד נפרד.

### [D-004] מפת ערוצים — זהה ל-V3 הישן
- **החלטה:** משתמשים בדיוק בפילטר של `surround_71_v3.sh` הקודם:
  - FL/FR = drums highpass>250Hz (L/R split)
  - FC = vocals mono
  - LFE = drums lowpass<120Hz + bass mono
  - SL/SR = other (L/R split)
  - BL/BR = other (כפילות של SL/SR)
- **למה:** עובד, נבדק. מפה חדשה תוצע רק אחרי שיש בסיס יציב.

### [D-005] Demucs htdemucs (בסיסי), לא htdemucs_ft
- **החלטה:** ב-v0.1 משתמשים ב-`htdemucs` הרגיל (לא ה-fine-tuned).
- **למה:** מהיר יותר, פחות זיכרון GPU, איכות מספיק טובה ל-baseline. `htdemucs_ft` ייבחן בגרסה עתידית.

### [D-006] הורדת מודלים מותנית בחומרה
- **החלטה:** ה-script מזהה GPU ובוחר את `torch` המתאים (CUDA / ROCm / Intel xpu / CPU). הורדה ראשונה מבוצעת ע"י `uv` בזמן ריצה.
- **למה:** אין סיבה להוריד torch+CUDA על מכונת CPU. גיא ירצה לבדוק את הסקריפט על מספר מכשירים שונים.

### [D-007] לא מבצעים L/R-split לפני Demucs
- **החלטה:** Demucs מקבל את הקלט הסטריאו המלא (לא מפצלים L ו-R לעיבוד נפרד).
- **למה:** Demucs מאומן על stereo ומשתמש ב-cues בין הערוצים להפרדה. פיצול ל-mono ירע את האיכות. ה-stereo imaging מושג עם `channelsplit` ב-ffmpeg *אחרי* Demucs.
- **מקור:** דיון ב-`v0.1.txt` (2026-05-25).

### [D-008] תיקיית `claude/` לא ב-git
- **החלטה:** `claude/character.md`, `rules.md`, `setting.md`, `brief.md` — `.gitignore`d.
- **למה:** קבצי הוראות פנימיים בין גיא לסמית', לא חלק מהפרויקט הציבורי.

### [D-009] שמירה על תכונות מהסקריפט הדוגמה
- **החלטה:** `--cookies-from-browser`, תמיכה בעברית, unique filename, `$RANDOM` ב-WORK_DIR, batch של תיקייה — כל אלה נשמרים.
- **למה:** אומתו בעבר, אין סיבה להמציא מחדש.

### [D-010] git init / commit — דחוי
- **החלטה:** לא לעשות `git init` עד שהסקריפט נבדק ועובד על שיר אחד לפחות.
- **למה:** הימנעות מ-commit של קוד שבור. ההיסטוריה הראשונה תהיה "v0.1 — working".

### [D-011] Auto-install של תלויות חסרות
- **החלטה:** הסקריפט מתקין אוטומטית את כל מה שחסר: `uv`, `yt-dlp`, `ffmpeg`, `rocm-hip-runtime` (אם AMD).
- **למה:** דרישת גיא — המשתמשים לא טכניים. שלב 1 ("סריקת חומרה + הכנת המחשב") עושה את ההכנה במלואה.
- **מודול:** `lib/install-deps.sh`. סודו דרוש (`sudo pacman`).

### [D-012] זיהוי דפדפן דינמי ל-cookies
- **החלטה:** במקום `BROWSER_FOR_COOKIES=chrome` קשיח, יש זיהוי אוטומטי בשלב 1: chrome → chromium → brave → firefox → vivaldi → opera. אם אין דפדפן — `yt-dlp` רץ בלי cookies.
- **למה:** משתמשים שונים עם דפדפנים שונים. הסקריפט צריך להסתדר.

### [D-013] Fallback אוטומטי מ-AMD GPU ל-CPU
- **החלטה:** אם טעינת torch+ROCm נכשלת ב-runtime → fallback ל-CPU.
- **למה:** ב-2026-05-25 הריצה הראשונה על מכונת הבדיקה של גיא חשפה בעיה: PyTorch+ROCm wheel מגיע עם `libamdhip64.so` שיש לו executable stack flag.
- **כרגע:** CPU mode עובד תמיד. נשמר כ-fallback אחרי D-014.

### [D-014] תיקון אוטומטי של execstack ב-AMD ROCm libs
- **החלטה:** מתקינים `patchelf` ו-`binutils` (readelf) יחד עם `rocm-hip-runtime`. אחרי שuv מתקין torch+rocm, סורקים את uv cache, מוצאים `libamdhip64.so` ו-`libhiprtc.so` עם דגל `RWE`, ומריצים `patchelf --clear-execstack` להפוך ל-`RW`.
- **למה:** ב-2026-05-25 הוכח לוקלית: אחרי patchelf, `torch.cuda.is_available()` מחזיר True על AMD GPU. הבעיה היא בדגל ELF program header, לא ב-runtime עצמו.
- **טכני:** `RWE` = Read/Write/eXecute. הקרנל החדש דורש W^X (write-xor-execute) עבור shared libs. patchelf מוריד את ה-X.
- **flow:** prefetch_demucs_model מנסה GPU. אם נכשל, מריץ patchelf, מנסה שוב. רק אם זה גם נכשל → CPU fallback (D-013).
- **השלכה ל-v0.2:** אם יום אחד PyTorch ROCm wheels יבואו תקינים, פשוט patchelf לא ימצא RWE libs ויחזיר 0 — לא יזיק.

### [D-017] מודלי audio-separator ב-`~/.cache/` (לא `/tmp/`)
- **החלטה:** `--model_file_dir "$HOME/.cache/audio-separator-models"` (override-able דרך `AUDIO_SEPARATOR_MODEL_DIR`).
- **למה:** ברירת המחדל של audio-separator היא `/tmp/audio-separator-models/`, שנמחק על reboot. ה-models הם 1GB+ — לא נכון להוריד מחדש כל פעם.
- **השלכה:** uv cache + torch models + audio-separator models = הכל ב-`~/.cache/`, שורד reboot.

### [D-018] תמיכת multi-OS עתידית: OS detection + הודעות ברורות לא-Arch
- **החלטה:** מוסיפים `detect_os_id` ו-`detect_pkg_manager` ב-`install-deps.sh`. ב-stage 1 מדפיסים את ה-OS. אם זה לא Arch — מתפרסם warning עם רשימת חבילות שצריך להתקין ידנית, אבל הסקריפט ממשיך (אם הכלים כבר שם, יעבוד).
- **למה:** Goal של "globalization" — לא לחסום משתמשים לא-Arch, אבל גם לא לדמיין שאוטו-התקנה תעבוד שם.
- **תוכנית עתידית:** ב-v0.2+ ייתכן `apt-get` / `dnf` paths אמיתיים. כרגע: רק detection + הודעה.

### [D-019] `--help` flag
- **החלטה:** `./surround-pro.sh --help` (ו-`-h`) מדפיס שימוש ויוצא בלי לרוץ.
- **למה:** משתמשים שמסתכלים על הסקריפט בפעם ראשונה — צריכים נקודת כניסה ברורה.

### [D-016] בדיקת GPU compute אמיתית + HSA_OVERRIDE_GFX_VERSION
- **החלטה:** לא מסתפקים ב-`torch.cuda.is_available()` (יחזיר True גם אם הקרנלים לא תואמים). מבצעים compute אמיתי: `torch.zeros(16, device='cuda') + 1` ולוודא שזה מצליח. אם נכשל ב-AMD עם `HIP error: invalid device function` → מנסים `HSA_OVERRIDE_GFX_VERSION=10.3.0`. רק אחרי שגם זה לא עזר → CPU fallback.
- **למה:** ב-2026-05-25 על מכונת הבדיקה (RX 6700 XT, gfx1031) torch קומפיל בלי kernels ל-gfx1031, רק ל-gfx1030 וכו'. HSA_OVERRIDE מורה לדריבר להשתמש ב-gfx1030 kernels — RX 6700 ו-RX 6800 קרובים מספיק שזה עובד.
- **GPUs שצפויים להזדקק ל-override:**
  - Navi 22 (RX 6700/6700 XT/6750 XT, RX 6800M) — gfx1031 → 10.3.0
  - Navi 23 (RX 6600/6600 XT/6650 XT) — gfx1032 → 10.3.0
  - אולי גם Navi 24 (RX 6400/6500 XT) — gfx1034 → 10.3.0
- **השלכה:** האוטומציה עכשיו מטפלת בקפיצת GPU "טוענים אבל לא עובדים" — common case ב-AMD.

### [D-015] Pipeline משולש לאיכות הפרדה: BS-RoFormer → De-Echo → Demucs
- **החלטה:** ההפרדה לא רק Demucs htdemucs_ft — מתחילים ב-audio-separator עם **BS-RoFormer Vocals** (`model_bs_roformer_ep_368_sdr_12.9628.ckpt`) כדי להוציא את כל הזמר ו-effects בנפרד, אחר כך **UVR-DeEcho-DeReverb** על הזמר כדי להפריד dry vocal מ-echo tail, ורק אז Demucs רץ על ה-instrumental.
- **למה:** ב-2026-05-25 גיא ציין שב-htdemucs_ft הזמר עם echo בולט ברמקולים האחוריים — Demucs מזהה את ה-echo ככלי נגינה. BS-RoFormer מאומן ספציפית על שירה אנושית עם effects ומוציא את הזמר נקי, כולל ה-echo. הפרדת De-Echo נוספת מאפשרת לבודד את ה-echo כסטם נפרד.
- **מיפוי 7.1 משופר:**
  - FC = **dry_vocal** (זמר ממורכז, ללא echo)
  - FL/FR = drums highpass (מצילות) **+ echo_tail** (echo מתפזר רחב — מימיק לאפקט המקורי)
  - LFE = drums lowpass + bass (ללא שינוי)
  - SL/SR/BL/BR = other (ללא שינוי, כעת ללא bleed של זמר)
- **תלות:** `audio-separator` + `onnxruntime` (uv installs). מודלים יורדים אוטומטית בריצה ראשונה.
- **עלות:** +~5 דק' עיבוד ב-CPU, +500MB דיסק.
