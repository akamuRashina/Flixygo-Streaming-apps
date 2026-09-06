# 📸 How to Add Team Profile Photos

## Current Setup

The app now tries to fetch Instagram profile photos using a third-party service (`https://instadp.io/fullsize/USERNAME`).

**⚠️ Warning:** This service may not always work or could become unavailable.

---

## ✅ Recommended: Use Local Profile Photos (More Reliable)

### Step 1: Save Profile Photos

1. Download profile photos from Instagram
2. Save them as:
   - `assets/images/team/luthfi.jpg` (for @lxthfyy_)
   - `assets/images/team/abhi.jpg` (for @_noctyr)

### Step 2: Update `pubspec.yaml`

Add this line:
```yaml
assets:
  - assets/images/
  - assets/images/team/  # Add this line
  - assets/design/
```

### Step 3: Update `about_app_page.dart`

Replace the `_getInstagramProfilePhotoUrl` method:

```dart
/// Get profile photo - uses local assets (more reliable)
String _getProfilePhotoPath(String username) {
  // Map usernames to local asset paths
  switch (username) {
    case 'lxthfyy_':
      return 'assets/images/team/luthfi.jpg';
    case '_noctyr':
      return 'assets/images/team/abhi.jpg';
    default:
      return ''; // Will use fallback icon
  }
}
```

Then in `_buildContactCard`, change:
```dart
// OLD:
Image.network(profilePhotoUrl, ...)

// NEW:
Image.asset(
  _getProfilePhotoPath(instagramUsername),
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) => Icon(...),
)
```

---

## 🔄 Current Behavior

**With Internet Connection:**
- ✅ Tries to load profile photo from Instagram
- ⏳ Shows loading spinner while fetching
- ❌ Falls back to icon if it fails

**Without Internet or Service Down:**
- ❌ Shows default person icon immediately

**With Local Photos (Recommended):**
- ✅ Always works offline
- ⚡ Loads instantly (no network delay)
- 🎯 100% reliable
- 💾 Small file size (just 2 profile photos)

---

## 📁 Folder Structure

```
flixygo/
├── assets/
│   ├── images/
│   │   ├── icon.png
│   │   └── team/              # Create this folder
│   │       ├── luthfi.jpg     # Add Luthfi's photo
│   │       └── abhi.jpg       # Add Abhipraya's photo
│   └── design/
└── lib/
```

---

## 🎨 Photo Guidelines

- **Format:** JPG or PNG
- **Size:** 500x500 pixels (square)
- **File size:** < 200KB each
- **Style:** Professional profile photo

---

## 🚀 Benefits of Local Photos

✅ **Reliable** - Works offline, always  
✅ **Fast** - No network delay  
✅ **Private** - No external service dependency  
✅ **Professional** - Better quality control  
✅ **Free** - No API costs or rate limits  

---

Choose the approach that works best for you! 🎯
