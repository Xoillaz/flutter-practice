import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WordSearchState(),
      child: MaterialApp(
        title: 'Dictionary',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 82, 54, 132)),
        ),
        home: const MainLayout(),
      ),
    );
  }
}

class Word {
  final String entry;
  final String explain;

  const Word({
    required this.entry,
    required this.explain,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      entry: json['entry'] ?? 'Unknown',
      explain: json['explain'] ?? 'No explanation available',
    );
  }
}

class WordSearchState extends ChangeNotifier {
  final List<Word> _history = [];
  final List<Word> _favorites = [];
  final GlobalKey<AnimatedListState> historyListKey = GlobalKey();

  List<Word> get history => _history;
  List<Word> get favorites => _favorites;

  void addToHistory(Word word) {
    _history.insert(0, word);
    historyListKey.currentState?.insertItem(0);
    notifyListeners();
  }

  void toggleFavorite(Word word) {
    if (_favorites.contains(word)) {
      _favorites.remove(word);
    } else {
      _favorites.add(word);
    }
    notifyListeners();
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNarrowScreen = MediaQuery.of(context).size.width < 450;

    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = const SearchPage();
        break;
      case 1:
        page = const FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $_selectedIndex');
    }

    final mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (isNarrowScreen) {
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search),
                        label: 'Search',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.favorite),
                        label: 'Favorites',
                      ),
                    ],
                    currentIndex: _selectedIndex,
                    onTap: (value) => setState(() => _selectedIndex = value),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.search),
                      label: Text('Search'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) => setState(() => _selectedIndex = value),
                ),
              ),
              Expanded(child: mainArea),
            ],
          );
        },
      ),
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: HistoryListView(),
          ),
          SizedBox(height: 10),
          WordSearchCard(),
          SizedBox(height: 10),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}

class WordSearchCard extends StatefulWidget {
  const WordSearchCard({super.key});

  @override
  State<WordSearchCard> createState() => _WordSearchCardState();
}

class _WordSearchCardState extends State<WordSearchCard> {
  final TextEditingController _controller = TextEditingController();
  Word? _currentWord;

  Future<void> _searchWord(String query) async {
    if (query.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('https://dict.youdao.com/suggest?q=$query&num=1&doctype=json'),
      );

      if (response.statusCode == 200) {
        final data = Word.fromJson(json.decode(response.body)['data']['entries']);
        setState(() => _currentWord = data);
        context.read<WordSearchState>().addToHistory(data);
      } else {
        setState(() => _currentWord = Word(
          entry: 'Error',
          explain: 'Failed to fetch translation',
        ));
      }
    } catch (e) {
      setState(() => _currentWord = Word(
        entry: 'Error',
        explain: e.toString(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            cursorColor: theme.colorScheme.onPrimary,
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              labelText: 'Enter word to search',
              labelStyle: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            onSubmitted: _searchWord,
          ),
          const SizedBox(height: 20.0),
          if (_currentWord != null)
            Text(
              _currentWord!.explain,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<WordSearchState>();

    if (state.favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have ${state.favorites.length} favorites:'),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 400 / 80,
            ),
            itemCount: state.favorites.length,
            itemBuilder: (context, index) {
              final word = state.favorites[index];
              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: theme.colorScheme.primary,
                  onPressed: () => state.toggleFavorite(word),
                ),
                title: Text(
                  word.entry,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  word.explain,
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HistoryListView extends StatelessWidget {
  const HistoryListView({super.key});

  static const _maskingGradient = LinearGradient(
    colors: [Colors.transparent, Colors.black],
    stops: [0.0, 0.5],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WordSearchState>();

    return ShaderMask(
      shaderCallback: (bounds) => _maskingGradient.createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: AnimatedList(
        key: state.historyListKey,
        reverse: true,
        padding: const EdgeInsets.only(top: 100),
        initialItemCount: state.history.length,
        itemBuilder: (context, index, animation) {
          final word = state.history[index];
          return SizeTransition(
            sizeFactor: animation,
            child: Center(
              child: TextButton.icon(
                onPressed: () => state.toggleFavorite(word),
                icon: state.favorites.contains(word)
                    ? const Icon(Icons.favorite, size: 12)
                    : const SizedBox(),
                label: Text(word.entry),
              ),
            ),
          );
        },
      ),
    );
  }
}