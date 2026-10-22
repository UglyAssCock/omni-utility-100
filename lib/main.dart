import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_strings.dart';
import 'registry/tool_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(OmniApp(prefs: prefs));
}

class OmniApp extends StatefulWidget {
  final SharedPreferences prefs;
  const OmniApp({super.key, required this.prefs});

  static OmniAppState of(BuildContext context) =>
      context.findAncestorStateOfType<OmniAppState>()!;

  @override
  State<OmniApp> createState() => OmniAppState();
}

class OmniAppState extends State<OmniApp> {
  late bool isDark;
  late bool isArabic;
  late int gridColumns;
  late List<String> favorites;

  @override
  void initState() {
    super.initState();
    isDark = widget.prefs.getBool('is_dark') ?? true;
    isArabic = widget.prefs.getBool('is_arabic') ?? false;
    AppStrings.isArabic = isArabic;
    gridColumns = widget.prefs.getInt('grid_columns') ?? 2;
    favorites = widget.prefs.getStringList('favorites') ??
        ['pdf_viewer', 'qr_scanner', 'calc_scientific', 'phone_flashlight'];
  }

  void toggleTheme([bool? value]) {
    setState(() {
      isDark = value ?? !isDark;
      widget.prefs.setBool('is_dark', isDark);
    });
  }

  void toggleLanguage([bool? arabic]) {
    setState(() {
      isArabic = arabic ?? !isArabic;
      AppStrings.isArabic = isArabic;
      widget.prefs.setBool('is_arabic', isArabic);
    });
  }

  void setGridColumns(int cols) {
    setState(() {
      gridColumns = cols.clamp(2, 4);
      widget.prefs.setInt('grid_columns', gridColumns);
    });
  }

  void toggleFavorite(String toolId) {
    setState(() {
      if (favorites.contains(toolId)) {
        favorites.remove(toolId);
      } else {
        favorites.add(toolId);
      }
      widget.prefs.setStringList('favorites', favorites);
    });
  }

  void reloadFromPrefs() {
    setState(() {
      isDark = widget.prefs.getBool('is_dark') ?? true;
      isArabic = widget.prefs.getBool('is_arabic') ?? false;
      AppStrings.isArabic = isArabic;
      gridColumns = widget.prefs.getInt('grid_columns') ?? 2;
      favorites = widget.prefs.getStringList('favorites') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omni 100 Tools',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0284C7),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF38BDF8),
        brightness: Brightness.dark,
      ),
      locale: isArabic ? const Locale('ar') : const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final List<String> _categories = const [
    'all',
    'fav',
    'pdf',
    'scanner',
    'qr',
    'units',
    'files',
    'random',
    'time',
    'calc',
    'phone',
    'text',
    'app',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = OmniApp.of(context);
    final cs = Theme.of(context).colorScheme;

    final filtered = ToolRegistry.allTools.where((tool) {
      if (_selectedCategory == 'fav' && !appState.favorites.contains(tool.id)) {
        return false;
      } else if (_selectedCategory != 'all' &&
          _selectedCategory != 'fav' &&
          tool.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return tool.titleEn.toLowerCase().contains(q) ||
            tool.titleAr.contains(q) ||
            tool.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.tr('Omni 100 All-in-One', 'أومني 100 أداة شاملة'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.tr('Language (AR/EN)', 'تغيير اللغة'),
            icon: const Icon(Icons.translate),
            onPressed: () => appState.toggleLanguage(),
          ),
          IconButton(
            tooltip: AppStrings.tr('Dark/Light Mode', 'الوضع الليلي'),
            icon: Icon(appState.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => appState.toggleTheme(),
          ),
          PopupMenuButton<int>(
            tooltip: AppStrings.tr('Grid Columns', 'أعمدة الشبكة'),
            icon: const Icon(Icons.grid_view),
            onSelected: appState.setGridColumns,
            itemBuilder: (_) => [
              PopupMenuItem(value: 2, child: Text(AppStrings.tr('2 Columns', 'عمودين (2)'))),
              PopupMenuItem(value: 3, child: Text(AppStrings.tr('3 Columns', '3 أعمدة'))),
              PopupMenuItem(value: 4, child: Text(AppStrings.tr('4 Columns', '4 أعمدة'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: AppStrings.tr(
                  'Search all 100 tools (PDF, QR, BMI, OCR...)',
                  'ابحث في 100 أداة (PDF، QR، حاسبة، تحويل...)',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final catId = _categories[i];
                final selected = _selectedCategory == catId;
                return ChoiceChip(
                  label: Text(AppStrings.cat(catId)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = catId),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.tr('No matching tools found', 'لا توجد أدوات مطابقة'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: appState.gridColumns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: appState.gridColumns == 2
                          ? 1.35
                          : (appState.gridColumns == 3 ? 0.95 : 0.8),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tool = filtered[index];
                      final isFav = appState.favorites.contains(tool.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => tool.builder()),
                          ).then((_) => setState(() {}));
                        },
                        child: Card(
                          elevation: 0,
                          color: cs.surfaceContainerHighest.withOpacity(0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: tool.color.withOpacity(0.35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: tool.color.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(tool.icon, color: tool.color, size: 24),
                                    ),
                                    InkWell(
                                      onTap: () => appState.toggleFavorite(tool.id),
                                      child: Icon(
                                        isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: isFav ? Colors.amber : cs.onSurfaceVariant,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  AppStrings.tr(tool.titleEn, tool.titleAr),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
