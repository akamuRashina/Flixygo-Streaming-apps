import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/movie_item.dart';
import '../models/api_models.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../services/bookmark_service.dart';
import '../services/watch_history_service.dart';
import '../services/profile_photo_service.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'movie_detail_page.dart';
import 'anime_kdrama_detail_page.dart';
import 'collection_page.dart';
import 'login_page.dart';

// Re-export so every other page that does `import 'home_page.dart'` still
// gets MovieItem/ContentType without needing its own import of the model file.
export '../models/movie_item.dart';

// ──────────────────────────────────────────────
//  HOME PAGE WITH STANDALONE FLOATING NAVBAR & SLIDE TRANSITION
// ──────────────────────────────────────────────

class HomePage extends StatefulWidget {
  final int initialIndex;

  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedGenre = '';
  late int _selectedNavIndex;
  late int _previousNavIndex;
  bool _isSearchBarExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  // ── REAL DATA STATE ──
  HomeFeed? _feed;
  bool _homeLoading = true;
  String? _homeError;
  List<String> _genreChips = [];

  bool _isLoggedIn = false;
  String? _username;
  String? _photoUrl;

  List<MovieItem> _recentlyWatched = [];
  List<MovieItem> _fullHistory = [];
  bool _historyLoading = false;

  List<MovieItem> _favorites = [];
  bool _favoritesLoading = false;

  List<MovieItem> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String _selectedSearchFilter = 'Semua'; // Semua, Film, K-Drama, Anime
  int _searchRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = widget.initialIndex;
    _previousNavIndex = widget.initialIndex;
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _isLoggedIn = await AuthService.instance.isLoggedIn();
    _username = await AuthService.instance.getUsername();
    _photoUrl = await ProfilePhotoService.instance.getPhotoUrl();
    if (mounted) setState(() {});
    await _loadHome();
    if (_isLoggedIn) {
      _loadHistoryAndFavorites();
    }
  }

  Future<void> _loadHome() async {
    setState(() {
      _homeLoading = true;
      _homeError = null;
    });
    try {
      final feed = await ContentService.instance.getHome();
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _genreChips = _computeGenres(feed);
        _homeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _homeError = e.toString();
        _homeLoading = false;
      });
    }
  }

  List<String> _computeGenres(HomeFeed feed) {
    final counts = <String, int>{};
    for (final item in [...feed.movies, ...feed.kdrama, ...feed.anime]) {
      for (final g in item.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final sortedGenres = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sortedGenres.take(12).toList();
  }

  Future<void> _loadHistoryAndFavorites() async {
    setState(() {
      _historyLoading = true;
      _favoritesLoading = true;
    });
    try {
      final history = await WatchHistoryService.instance.list();
      if (!mounted) return;
      setState(() {
        _fullHistory = history.map(_historyToMovieItem).toList();
        _recentlyWatched = _fullHistory.take(8).toList();
        _historyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }

    try {
      final bookmarks = await BookmarkService.instance.list();
      if (!mounted) return;
      setState(() {
        _favorites = bookmarks.map(_bookmarkToMovieItem).toList();
        _favoritesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _favoritesLoading = false);
    }
  }

  MovieItem _historyToMovieItem(WatchHistoryItem h) {
    return MovieItem(
      title: h.title,
      imageUrl: h.poster,
      contentType: contentTypeFromApi(h.contentType),
      slug: h.contentSlug,
    );
  }

  MovieItem _bookmarkToMovieItem(BookmarkItem b) {
    return MovieItem(
      title: b.title,
      imageUrl: b.poster,
      contentType: contentTypeFromApi(b.type),
      genres: b.genres,
      slug: b.slug,
      badge: b.badge,
    );
  }

  Future<void> _performSearch(String query) async {
    final token = ++_searchRequestToken;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      var results = await ContentService.instance.search(query);

      if (_selectedSearchFilter != 'Semua') {
        results = results.where((item) {
          if (_selectedSearchFilter == 'Film') return item.contentType == ContentType.movie;
          if (_selectedSearchFilter == 'K-Drama') return item.contentType == ContentType.kdrama;
          if (_selectedSearchFilter == 'Anime') return item.contentType == ContentType.anime;
          return true;
        }).toList();
      }

      if (token != _searchRequestToken || !mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (token != _searchRequestToken || !mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString();
      });
    }
  }

  void _onTabTapped(int index) {
    if (index == 1) {
      // Toggle search bar expansion
      setState(() {
        _isSearchBarExpanded = !_isSearchBarExpanded;
        if (!_isSearchBarExpanded) {
          _searchController.clear();
          _searchResults = [];
        }
      });
      return;
    }

    if (index == _selectedNavIndex) return;
    setState(() {
      _previousNavIndex = _selectedNavIndex;
      _selectedNavIndex = index;
      _isSearchBarExpanded = false; // Close search bar when switching tabs
      _searchController.clear();
    });

    if (index == 2 || index == 3) {
      if (_isLoggedIn && !_historyLoading && !_favoritesLoading) {
        _loadHistoryAndFavorites();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildSlidingBodyContent(),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildFloatingNavBar(),
            ),
          ),
        ],
      ),
    );
  }

  // ── SLIDING ANIMATION BETWEEN PAGES ──
  Widget _buildSlidingBodyContent() {
    final bool isMovingRight = _selectedNavIndex >= _previousNavIndex;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        if ((child.key as ValueKey).value == 'search_results' ||
            (child.key as ValueKey).value == _selectedNavIndex) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.03),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        }

        final isIncoming = (child.key as ValueKey<dynamic>).value == _selectedNavIndex;
        final Offset beginOffset;
        if (isIncoming) {
          beginOffset = isMovingRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
        } else {
          beginOffset = isMovingRight ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
        }
        return SlideTransition(
          position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
          child: child,
        );
      },
      child: KeyedSubtree(
        key: _isSearchBarExpanded
            ? const ValueKey<String>('search_results')
            : ValueKey<int>(_selectedNavIndex),
        child: _getPageForIndex(_selectedNavIndex),
      ),
    );
  }

  Widget _getPageForIndex(int index) {
    if (_isSearchBarExpanded) {
      return _buildSearchResultsView();
    }

    switch (index) {
      case 0:
        return _buildHomeView();
      case 2:
        return _buildHistoryView();
      case 3:
        return _buildFavoriteView();
      default:
        return _buildHomeView();
    }
  }

  // ──────────────────────────────────────────────
  //  1. HOME VIEW
  // ──────────────────────────────────────────────
  Widget _buildHomeView() {
    if (_homeLoading && _feed == null) {
      return _buildCenteredState(
        child: const CircularProgressIndicator(color: AppColors.homeTextCream),
      );
    }

    if (_homeError != null && _feed == null) {
      return _buildCenteredState(
        child: _buildErrorRetry(_homeError!, _loadHome),
      );
    }

    final feed = _feed ?? HomeFeed.empty;

    return Stack(
      children: [
        Positioned(
          top: -50,
          left: -40,
          child: _buildAmbientGlow(const Color(0xFFDA8C35), 200, 100),
        ),
        Positioned(
          top: 350,
          right: -60,
          child: _buildAmbientGlow(const Color(0xFF8B5E2B), 250, 110),
        ),
        Positioned(
          bottom: 100,
          left: -50,
          child: _buildAmbientGlow(const Color(0xFFCE8733), 220, 100),
        ),
        SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFDE903A),
            backgroundColor: const Color(0xFF2A2018),
            onRefresh: () async {
              await _loadHome();
              if (_isLoggedIn) await _loadHistoryAndFavorites();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildGlassHeader()),

                SliverToBoxAdapter(child: _buildSectionHeader('Terakhir ditonton')),
                SliverToBoxAdapter(child: _buildRecentlyWatchedSection()),

                SliverToBoxAdapter(child: _buildSectionHeader('Terbaru')),
                SliverToBoxAdapter(child: _buildGlassMovieSection(feed.latestAll)),

                if (_genreChips.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _buildSectionHeader('Genre')),
                  SliverToBoxAdapter(child: _buildGlassGenreSection()),
                ],

                SliverToBoxAdapter(child: _buildSectionHeader('Film', showArrow: true, onArrowTap: () {
                  final title = _selectedGenre.isEmpty ? 'Film' : 'Film ($_selectedGenre)';
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(
                    title: title,
                    items: _getFilteredMovies(feed.movies),
                  )));
                })),
                SliverToBoxAdapter(child: _buildGlassMovieSection(_getFilteredMovies(feed.movies))),

                SliverToBoxAdapter(child: _buildSectionHeader('K-Drama', showArrow: true, onArrowTap: () {
                  final title = _selectedGenre.isEmpty ? 'K-Drama' : 'K-Drama ($_selectedGenre)';
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(
                    title: title,
                    items: _getFilteredMovies(feed.kdrama),
                  )));
                })),
                SliverToBoxAdapter(child: _buildGlassMovieSection(_getFilteredMovies(feed.kdrama))),

                SliverToBoxAdapter(child: _buildSectionHeader('Anime', showArrow: true, onArrowTap: () {
                  final title = _selectedGenre.isEmpty ? 'Anime' : 'Anime ($_selectedGenre)';
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(
                    title: title,
                    items: _getFilteredMovies(feed.anime),
                  )));
                })),
                SliverToBoxAdapter(child: _buildGlassMovieSection(_getFilteredMovies(feed.anime))),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyWatchedSection() {
    if (!_isLoggedIn) {
      return _buildInlineLoginPrompt('Masuk untuk melihat riwayat tontonanmu di sini.');
    }
    if (_historyLoading && _recentlyWatched.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: AppColors.homeTextCream)),
      );
    }
    if (_recentlyWatched.isEmpty) {
      return _buildInlineEmptyNote('Belum ada tontonan. Yuk mulai nonton!');
    }
    return _buildGlassMovieSection(_recentlyWatched);
  }

  // ──────────────────────────────────────────────
  //  3. HISTORY VIEW ("Riwayat")
  // ──────────────────────────────────────────────
  Widget _buildHistoryView() {
    return Container(
      color: AppColors.homeBg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(color: Color(0xFF1E170E)),
              child: Center(
                child: Text(
                  'Riwayat',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          _buildGoldenDivider(),
          Expanded(child: _buildAuthedGrid(
            isLoggedIn: _isLoggedIn,
            isLoading: _historyLoading,
            items: _fullHistory,
            emptyMessage: 'Belum ada riwayat tontonan.',
            loginMessage: 'Masuk untuk melihat riwayat tontonanmu.',
          )),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  4. FAVORITE VIEW ("Tersimpan")
  // ──────────────────────────────────────────────
  Widget _buildFavoriteView() {
    return Container(
      color: AppColors.homeBg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(color: Color(0xFF1E170E)),
              child: Center(
                child: Text(
                  'Tersimpan',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          _buildGoldenDivider(),
          Expanded(child: _buildAuthedGrid(
            isLoggedIn: _isLoggedIn,
            isLoading: _favoritesLoading,
            items: _favorites,
            emptyMessage: 'Belum ada konten tersimpan.',
            loginMessage: 'Masuk untuk melihat konten favoritmu.',
          )),
        ],
      ),
    );
  }

  Widget _buildAuthedGrid({
    required bool isLoggedIn,
    required bool isLoading,
    required List<MovieItem> items,
    required String emptyMessage,
    required String loginMessage,
  }) {
    if (!isLoggedIn) {
      return _buildCenteredState(child: _buildLoginPromptCard(loginMessage));
    }
    if (isLoading && items.isEmpty) {
      return _buildCenteredState(
        child: const CircularProgressIndicator(color: AppColors.homeTextCream),
      );
    }
    if (items.isEmpty) {
      return _buildCenteredState(
        child: Text(
          emptyMessage,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Text(
              'Total (${items.length})',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGridMovieCard(items[index]),
              childCount: items.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── NAVIGATE TO DETAIL BASED ON CONTENT TYPE ──
  void _navigateToDetail(MovieItem movie) {
    final page = (movie.contentType == ContentType.anime || movie.contentType == ContentType.kdrama)
        ? AnimeKdramaDetailPage(movie: movie)
        : MovieDetailPage(movie: movie);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      // Refresh history/bookmarks in case something changed while away.
      if (_isLoggedIn) _loadHistoryAndFavorites();
    });
  }

  List<MovieItem> _getFilteredMovies(List<MovieItem> movies) {
    if (_selectedGenre.isEmpty) return movies;
    return movies.where((movie) => movie.genres.contains(_selectedGenre)).toList();
  }

  // ──────────────────────────────────────────────
  //  5. SEARCH RESULTS VIEW (When search bar is active)
  // ──────────────────────────────────────────────
  Widget _buildSearchResultsView() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        );
      },
      child: Container(
        color: AppColors.homeBg,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: const BoxDecoration(color: Color(0xFF1E170E)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSearchFilterChip('Semua'),
                      const SizedBox(width: 8),
                      _buildSearchFilterChip('Film'),
                      const SizedBox(width: 8),
                      _buildSearchFilterChip('K-Drama'),
                      const SizedBox(width: 8),
                      _buildSearchFilterChip('Anime'),
                    ],
                  ),
                ),
              ),
            ),
            _buildGoldenDivider(),
            Expanded(child: _buildSearchResultsContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterChip(String label) {
    final bool isSelected = _selectedSearchFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSearchFilter = label);
        _performSearch(_searchController.text);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF865D3B) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF865D3B) : Colors.white.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF865D3B).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: Colors.white,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildSearchResultsContent() {
    if (_searchResults.isEmpty && _searchController.text.isEmpty) {
      return _buildSearchEmptyState(
        icon: Icons.search_rounded,
        title: 'Cari Konten Favoritmu',
        subtitle: 'Ketik judul film, k-drama, atau anime\nyang ingin kamu tonton',
      );
    }

    if (_isSearching && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.homeTextCream));
    }

    if (_searchError != null && _searchResults.isEmpty) {
      return Center(child: _buildErrorRetry(_searchError!, () => _performSearch(_searchController.text)));
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildSearchEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak Ada Hasil',
        subtitle: 'Coba kata kunci lain atau ubah filter',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Text(
              'Hasil Pencarian (${_searchResults.length})',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSearchResultCard(_searchResults[index]),
              childCount: _searchResults.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildSearchEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
              ),
              child: Icon(icon, size: 50, color: Colors.white.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(MovieItem movie) {
    return GestureDetector(
      onTap: () => _navigateToDetail(movie),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  movie.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: movie.fallbackGradient,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie_creation_outlined, color: Colors.white38, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getContentTypeColor(movie.contentType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getContentTypeLabel(movie.contentType),
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  movie.title,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getContentTypeColor(ContentType type) {
    switch (type) {
      case ContentType.movie:
        return const Color(0xFF865D3B);
      case ContentType.kdrama:
        return const Color(0xFFD45F85);
      case ContentType.anime:
        return const Color(0xFF5D6B86);
    }
  }

  String _getContentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.movie:
        return 'FILM';
      case ContentType.kdrama:
        return 'K-DRAMA';
      case ContentType.anime:
        return 'ANIME';
    }
  }

  // ── GRID MOVIE CARD FOR HISTORY & FAVORITE PAGES ──
  Widget _buildGridMovieCard(MovieItem movie) {
    return GestureDetector(
      onTap: () => _navigateToDetail(movie),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  movie.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: movie.fallbackGradient,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 32),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.92),
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  movie.title,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientGlow(Color color, double size, double blur) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.18),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.22), blurRadius: blur, spreadRadius: 30),
        ],
      ),
    );
  }

  // ── LIQUID GLASS HEADER ──
  Widget _buildGlassHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.homeTextCream.withOpacity(0.5), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.avatarBlue,
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 24)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _isLoggedIn ? (_username ?? 'Pengguna') : 'Tamu',
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.homeTextCream,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildGlassIconButton(
                  Icons.account_circle_outlined,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) {
                      _bootstrap();
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildGlassIconButton(
                  Icons.settings_outlined,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(IconData icon, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: IconButton(
        onPressed: onTap ?? () {},
        icon: Icon(icon, color: AppColors.homeTextCream, size: 24),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ── SECTION HEADER ──
  Widget _buildSectionHeader(String title, {bool showArrow = false, VoidCallback? onArrowTap}) {
    final bool isFiltered = _selectedGenre.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.homeTextCream),
                    ),
                    if (showArrow) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onArrowTap,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.homeTextCream, size: 14),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isFiltered && (title == 'Film' || title == 'K-Drama' || title == 'Anime'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDA8C35).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDA8C35).withOpacity(0.6), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_alt, size: 12, color: AppColors.homeTextCream),
                              const SizedBox(width: 4),
                              Text(
                                'Genre: $_selectedGenre',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.homeTextCream),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── GLASS MOVIE SECTION ──
  Widget _buildGlassMovieSection(List<MovieItem> movies) {
    if (movies.isEmpty) {
      return _buildInlineEmptyNote('Belum ada konten di sini.');
    }

    final displayMovies = movies.take(10).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: SizedBox(
              height: 185,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: displayMovies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _buildGlassMovieCard(displayMovies[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── GLASS MOVIE CARD ──
  Widget _buildGlassMovieCard(MovieItem movie) {
    return GestureDetector(
      onTap: () => _navigateToDetail(movie),
      child: Container(
        width: 115,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.8),
          child: Stack(
            children: [
              Image.network(
                movie.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: movie.fallbackGradient,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie_creation_outlined, color: Colors.white70, size: 36),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.95),
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  movie.title,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── GLASS GENRE SECTION (built from real, fetched genres) ──
  Widget _buildGlassGenreSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _genreChips.map((genre) {
                final isSelected = _selectedGenre == genre;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedGenre = isSelected ? '' : genre);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFDA8C35).withOpacity(0.35) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF3EBA7) : Colors.white.withOpacity(0.2),
                        width: isSelected ? 1.6 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFDA8C35).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      genre,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.homeTextCream : AppColors.homeTextWhite,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── SMALL SHARED HELPERS ──
  Widget _buildGoldenDivider() {
    return Container(
      height: 2.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF8B6914),
            Color(0xFFD4A83C),
            Color(0xFFF3D673),
            Color(0xFFD4A83C),
            Color(0xFF8B6914),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredState({required Widget child}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: child,
      ),
    );
  }

  Widget _buildErrorRetry(String message, VoidCallback onRetry) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 44),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDE903A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text('Coba lagi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildInlineEmptyNote(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        message,
        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
      ),
    );
  }

  Widget _buildInlineLoginPrompt(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: _buildLoginPromptCard(message),
    );
  }

  Widget _buildLoginPromptCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              _bootstrap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDE903A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Masuk',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  STANDALONE FLOATING BOTTOM NAVIGATION BAR
  // ──────────────────────────────────────────────
  Widget _buildFloatingNavBar() {
    if (_isSearchBarExpanded) {
      return _buildSearchNavBar();
    }

    const double navWidth = 350.0;
    const double topOffset = 22.0;
    const double totalHeight = 80.0;
    const double bumpWidth = 34.0;
    const double cornerRadius = 28.0;

    return CustomPaint(
      painter: _NavbarPainter(topOffset: topOffset, cornerRadius: cornerRadius, bumpWidth: bumpWidth),
      child: ClipPath(
        clipper: _NavbarClipper(topOffset: topOffset, cornerRadius: cornerRadius, bumpWidth: bumpWidth),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: navWidth,
            height: totalHeight,
            color: const Color(0xFF1E1712).withOpacity(0.68),
            child: Stack(
              children: [
                Positioned(
                  top: topOffset,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _isSearchBarExpanded ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _buildNavBarItemsRow(),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  left: (navWidth - 44) / 2,
                  child: AnimatedScale(
                    scale: _isSearchBarExpanded ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: GestureDetector(
                      onTap: () => _onTabTapped(1),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchNavBar() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: SizedBox(
        width: 350,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1712).withOpacity(0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF865D3B).withOpacity(0.6), width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF865D3B).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search_rounded, color: Color(0xFF865D3B), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Cari film, k-drama, anime...',
                        hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.4), fontSize: 15, fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _performSearch,
                      onChanged: _performSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearchBarExpanded = false;
                        _searchController.clear();
                        _searchResults = [];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItemsRow() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedNavIndex),
        child: _buildNavBarItemsContent(),
      ),
    );
  }

  Widget _buildNavBarItemsContent() {
    if (_selectedNavIndex == 0) {
      return Row(
        key: const ValueKey<int>(0),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavPillTab(index: 0, icon: Icons.home_outlined, label: 'Beranda'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavIconButton(index: 2, icon: Icons.access_time_rounded),
              const SizedBox(width: 10),
              _buildNavIconButton(index: 3, icon: Icons.bookmark_rounded),
            ],
          ),
        ],
      );
    } else if (_selectedNavIndex == 2) {
      return Row(
        key: const ValueKey<int>(2),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavIconButton(index: 0, icon: Icons.home_outlined),
              const SizedBox(width: 10),
              _buildNavIconButton(index: 3, icon: Icons.bookmark_rounded),
            ],
          ),
          _buildNavPillTab(index: 2, icon: Icons.access_time_rounded, label: 'Riwayat'),
        ],
      );
    } else if (_selectedNavIndex == 3) {
      return Row(
        key: const ValueKey<int>(3),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavIconButton(index: 0, icon: Icons.home_outlined),
              const SizedBox(width: 10),
              _buildNavIconButton(index: 2, icon: Icons.access_time_rounded),
            ],
          ),
          _buildNavPillTab(index: 3, icon: Icons.bookmark_rounded, label: 'Simpan'),
        ],
      );
    } else {
      return Row(
        key: const ValueKey<int>(1),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavIconButton(index: 0, icon: Icons.home_outlined),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavIconButton(index: 2, icon: Icons.access_time_rounded),
              const SizedBox(width: 10),
              _buildNavIconButton(index: 3, icon: Icons.bookmark_rounded),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildNavPillTab({required int index, required IconData icon, required String label}) {
    final bool isSelected = _selectedNavIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF865D3B).withOpacity(0.95) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.12),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF865D3B).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavIconButton({required int index, required IconData icon}) {
    final bool isSelected = _selectedNavIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF865D3B).withOpacity(0.95) : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.15),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF865D3B).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  CUSTOM NAVBAR CLIPPER & PAINTER FOR DOME BUMP
// ──────────────────────────────────────────────

class _NavbarClipper extends CustomClipper<Path> {
  final double topOffset;
  final double cornerRadius;
  final double bumpWidth;

  _NavbarClipper({required this.topOffset, required this.cornerRadius, required this.bumpWidth});

  @override
  Path getClip(Size size) {
    return _getNavbarPath(size, topOffset: topOffset, cornerRadius: cornerRadius, bumpWidth: bumpWidth);
  }

  @override
  bool shouldReclip(covariant _NavbarClipper oldClipper) => false;
}

class _NavbarPainter extends CustomPainter {
  final double topOffset;
  final double cornerRadius;
  final double bumpWidth;

  _NavbarPainter({required this.topOffset, required this.cornerRadius, required this.bumpWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getNavbarPath(size, topOffset: topOffset, cornerRadius: cornerRadius, bumpWidth: bumpWidth);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(path.shift(const Offset(0, 6)), shadowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.40),
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.25),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavbarPainter oldDelegate) => false;
}

Path _getNavbarPath(
  Size size, {
  required double topOffset,
  required double cornerRadius,
  required double bumpWidth,
}) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  final cx = w / 2;

  path.moveTo(cornerRadius, topOffset);
  path.lineTo(cx - bumpWidth - 14, topOffset);

  path.cubicTo(cx - bumpWidth + 2, topOffset, cx - bumpWidth + 6, 0, cx, 0);
  path.cubicTo(cx + bumpWidth - 6, 0, cx + bumpWidth - 2, topOffset, cx + bumpWidth + 14, topOffset);

  path.lineTo(w - cornerRadius, topOffset);
  path.arcToPoint(Offset(w, topOffset + cornerRadius), radius: Radius.circular(cornerRadius));
  path.lineTo(w, h - cornerRadius);
  path.arcToPoint(Offset(w - cornerRadius, h), radius: Radius.circular(cornerRadius));
  path.lineTo(cornerRadius, h);
  path.arcToPoint(Offset(0, h - cornerRadius), radius: Radius.circular(cornerRadius));
  path.lineTo(0, topOffset + cornerRadius);
  path.arcToPoint(Offset(cornerRadius, topOffset), radius: Radius.circular(cornerRadius));
  path.close();
  return path;
}
