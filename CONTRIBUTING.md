# Contributing to FlixyGo

First off, thank you for considering contributing to FlixyGo! 🎉

## 🤝 How Can I Contribute?

### Reporting Bugs 🐛

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** to demonstrate the steps
- **Describe the behavior you observed** and what you expected
- **Include screenshots or GIFs** if possible
- **Specify your environment:**
  - OS: Android 14, Windows 11, etc.
  - Flutter version: `flutter --version`
  - Device specs

### Suggesting Features 💡

Feature suggestions are welcome! Please provide:

- **Clear and descriptive title**
- **Detailed description** of the proposed feature
- **Use cases** - explain why this would be useful
- **Mockups or examples** if applicable

### Pull Requests 🔧

1. **Fork the repo** and create your branch from `main`:
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make your changes:**
   - Follow the existing code style
   - Add comments for complex logic
   - Update documentation if needed

3. **Test your changes:**
   ```bash
   flutter test
   flutter analyze
   ```

4. **Commit your changes:**
   ```bash
   git commit -m "Add amazing feature"
   ```

5. **Push to your fork:**
   ```bash
   git push origin feature/amazing-feature
   ```

6. **Open a Pull Request** with:
   - Clear title and description
   - Reference related issues
   - Screenshots for UI changes

## 📝 Coding Standards

### Flutter/Dart Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter format` before committing
- Run `flutter analyze` and fix warnings
- Keep functions small and focused
- Use meaningful variable names

### File Organization

```
lib/
├── models/       # Data models
├── pages/        # UI screens
├── services/     # Business logic
├── theme/        # Styling
└── main.dart
```

### Commit Messages

Use clear and descriptive commit messages:

```
✅ Good:
- "Add fullscreen video player controls"
- "Fix login authentication bug"
- "Update README with Android instructions"

❌ Bad:
- "fix stuff"
- "update"
- "changes"
```

### Code Comments

```dart
// ✅ Good
/// Fetches user's watch history from Supabase
/// Returns a list of [WatchHistoryItem] or null if error
Future<List<WatchHistoryItem>?> fetchWatchHistory(String userId) async {
  // Implementation
}

// ❌ Bad
// get history
Future<List<WatchHistoryItem>?> fetchWatchHistory(String userId) async {
  // Implementation
}
```

## 🧪 Testing

- Write tests for new features
- Ensure existing tests pass
- Test on both Android and Windows if possible

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/auth_test.dart
```

## 🎨 UI/UX Guidelines

- Follow Material Design principles
- Maintain consistent spacing (multiples of 4 or 8)
- Use app theme colors from `app_theme.dart`
- Ensure responsive design for different screen sizes
- Test dark mode compatibility

## 📚 Documentation

- Update README.md for new features
- Add inline code documentation
- Update API documentation if backend changes
- Include examples for complex features

## 🚀 Development Workflow

1. **Check existing issues** before starting work
2. **Create an issue** to discuss major changes
3. **Work on a feature branch**, not main
4. **Keep commits focused** - one logical change per commit
5. **Sync with main** regularly:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

## ⚠️ Important Notes

### Don't Include

- ❌ Supabase keys or API credentials
- ❌ Personal information
- ❌ Large binary files
- ❌ Generated files (build/, .dart_tool/)

### Always Include

- ✅ Clear commit messages
- ✅ Updated documentation
- ✅ Tests for new features
- ✅ Screenshots for UI changes

## 🔍 Code Review Process

All PRs will be reviewed for:

- **Functionality** - Does it work as intended?
- **Code quality** - Is it maintainable?
- **Performance** - Is it efficient?
- **Design** - Does it match app aesthetics?
- **Tests** - Are there adequate tests?

## 📞 Getting Help

- **Questions?** Open a GitHub issue with the `question` label
- **Stuck?** Check existing issues or ask the team
- **Email:** Digitalaegis12@gmail.com

## 🎉 Recognition

Contributors will be:
- Added to contributors list
- Credited in release notes
- Mentioned in the README (for significant contributions)

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for making FlixyGo better! 🙏

**- Digital Aegis Team**
