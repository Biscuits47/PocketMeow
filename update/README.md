# PocketMeow Update Manifest

`钱喵` 现在使用远端版本清单 `latest.json` 检查更新，不再依赖 GitHub Release API。

## Manifest Format

```json
{
  "version": "1.0.1",
  "build": 2,
  "notes": "修复若干问题并优化体验。",
  "apk_url": "https://your-cdn.example.com/PocketMeow.apk",
  "page_url": "https://your-site.example.com/pocketmeow",
  "published_at": "2026-07-01T20:00:00+08:00"
}
```

## Recommended Domestic Hosting

- Tencent COS static website or CDN
- Alibaba Cloud OSS static website or CDN
- Qiniu Kodo / CDN
- Gitee Pages or any domestic static hosting

## App Lookup Order

By default, the app tries these manifest URLs:

- `https://cdn.jsdelivr.net/gh/Biscuits47/PocketMeow@main/update/latest.json`
- `https://fastly.jsdelivr.net/gh/Biscuits47/PocketMeow@main/update/latest.json`
- `https://raw.githubusercontent.com/Biscuits47/PocketMeow/main/update/latest.json`

For domestic deployment, it is recommended to override them at build time:

```bash
flutter build apk --dart-define=POCKETMEOW_UPDATE_MANIFEST_URLS=https://your-cdn.example.com/latest.json
```

You can also provide multiple URLs separated by commas:

```bash
flutter build apk --dart-define=POCKETMEOW_UPDATE_MANIFEST_URLS=https://cdn-a.example.com/latest.json,https://cdn-b.example.com/latest.json
```

## Release Workflow

1. Build a new APK.
2. Upload the APK to your domestic download address.
3. Update `latest.json`.
4. Upload `latest.json` to the same domestic static host.
5. Rebuild the app with your `POCKETMEOW_UPDATE_MANIFEST_URLS` value if needed.
