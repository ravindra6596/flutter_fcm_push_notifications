import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/utils/locale_controller.dart';
import 'package:push_notification/utils/strings.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Chapter {
  final int? chapter;
  final int? verse;
  final String? text;
  final String? reference;
  final String? meaning;
  final String? explanation;

  Chapter({
    this.chapter,
    this.verse,
    this.text,
    this.reference,
    this.meaning,
    this.explanation,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      chapter: json['chapter'],
      verse: json['verse'],
      text: json['text'],
      reference: json['reference'],
      meaning: json['meaning'],
      explanation: json['explanation'],
    );
  }
}

abstract class LanguageEvent {
  const LanguageEvent();

  List<Object> get props => [];
}

class LoadLanguage extends LanguageEvent {
  final String language; // 'marathi', 'hindi', 'english'

  const LoadLanguage(this.language);

  @override
  List<Object> get props => [language];
}

abstract class LanguageState {
  const LanguageState();

  List<Object> get props => [];
}

class LanguageInitial extends LanguageState {}

class LanguageLoading extends LanguageState {}

class LanguageLoaded extends LanguageState {
  final List<Chapter> chapters;
  final String language;

  const LanguageLoaded({required this.chapters, required this.language});

  @override
  List<Object> get props => [chapters, language];
}

class LanguageError extends LanguageState {
  final String message;

  const LanguageError(this.message);

  @override
  List<Object> get props => [message];
}

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  LanguageBloc() : super(LanguageInitial()) {
    on<LoadLanguage>(_onLoadLanguage);
  }

  Future<void> _onLoadLanguage(
      LoadLanguage event, Emitter<LanguageState> emit) async {
    emit(LanguageLoading());
    try {
      String path = '';

      final data = await rootBundle.loadString(path);
      final jsonResult = json.decode(data);
      final List<Chapter> chapters = (jsonResult['BhagavadGitaChapter'] as List)
          .map((e) => Chapter.fromJson(e))
          .toList();

      emit(LanguageLoaded(chapters: chapters, language: event.language));
    } catch (e) {
      emit(LanguageError(e.toString()));
    }
  }
}

class LanguageApp extends StatelessWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LanguageBloc()..add(LoadLanguage(appLocale.value.languageCode)),
      child: ChapterListScreen(),
    );
  }
}

// ----------------- Models -----------------
class ChapterMeta {
  final int chapter;
  final String name;
  final int totalShlokas;
  ChapterMeta({required this.chapter, required this.name,required this.totalShlokas});

  factory ChapterMeta.fromJson(Map<String, dynamic> json) =>
      ChapterMeta(chapter: json['chapter'], name: json['name'],totalShlokas:json['totalShlokas']);
}

class Sloka {
  final int chapter;
  final int verse;
  final String text;
  final String reference;
  final String meaning;
  final String explanation;
  final String chapterName;
  final int isFavourite;
  bool isRead;

  Sloka({
    required this.chapter,
    required this.verse,
    required this.text,
    this.reference = '',
    required this.meaning,
    required this.explanation,
    required this.chapterName,
    this.isFavourite = 0,
    this.isRead = false,
  });

  factory Sloka.fromJson(Map<String, dynamic> json) => Sloka(
    chapter: json['chapter'],
    verse: json['verse'],
    text: json['text'],
    reference: json['reference'] ?? '',
    meaning: json['meaning'],
    explanation: json['explanation'],
    chapterName: '',
    isRead: false,
  );
}

// ----------------- BLoC -----------------
abstract class GitaEvent {}

class LoadChapters extends GitaEvent {}

class LoadChapterProgress extends GitaEvent {
  final String language;
  final List<ChapterMeta> chapters;

  LoadChapterProgress(this.language, this.chapters);
}
class LoadSlokas extends GitaEvent {
  final int chapter;
  final int? initialIndex;
  LoadSlokas(this.chapter, {this.initialIndex});
}

class SelectSloka extends GitaEvent {
  final int slokaIndex;
  SelectSloka(this.slokaIndex);
}

class ChangeLanguage extends GitaEvent {
  final String lang;
  ChangeLanguage(this.lang);
}
class ToggleFavorite extends GitaEvent {
  final Sloka sloka;
  final String language;
  final String chapterName;
  ToggleFavorite({required this.sloka, required this.language,required this.chapterName});
}

class LoadFavorites extends GitaEvent {
  final String language;
  LoadFavorites( this.language );
}
abstract class GitaState {}

class GitaLoading extends GitaState {}

class ChaptersLoaded extends GitaState {
  final List<ChapterMeta> chapters;
  final Map<String, dynamic>? lastReadSloka;
  ChaptersLoaded(this.chapters,{this.lastReadSloka});
}
class ChaptersLoadProgress extends GitaState {
  final List<ChapterMeta> chapters;
  final Map<int, double> progress;
  final double overallPercent;

  ChaptersLoadProgress(this.chapters, {this.progress = const {},this.overallPercent = 0.0,});
}
class SlokasLoaded extends GitaState {
  final List<Sloka> slokas;
  final int selectedIndex;
  SlokasLoaded(this.slokas, this.selectedIndex);
}
class FavoritesLoaded extends GitaState {
  final List<Sloka> favorites;
  FavoritesLoaded(this.favorites);
}

class FavoriteUpdated extends GitaState {
  final bool isFav;
  final Sloka sloka;
  FavoriteUpdated({required this.sloka, required this.isFav});
}
class GitaBloc extends Bloc<GitaEvent, GitaState> {
  String currentLang = appLocale.value.languageCode;
  int currentChapter = 1;
  List<Sloka> currentSlokas = [];
  int selectedIndex = 0;
  bool isShowingFavorites = false;
  final Map<String, String> langFolderMap = {
    'en': 'english',
    'hi': 'hindi',
    'mr': 'marathi',
  };

  GitaBloc() : super(GitaLoading()) {
    on<LoadChapters>((event, emit) async {
      emit(GitaLoading());
      String folder = langFolderMap[currentLang] ?? appLocale.value.languageCode;
      String data = await rootBundle.loadString('assets/$folder/chapters.json');
      List jsonData = json.decode(data);
      List<ChapterMeta> chapters = jsonData.map((e) => ChapterMeta.fromJson(e)).toList();
      // GET LAST READ SLOKA FROM DB
      final lastRead = await DatabaseHelper().getLastReadSloka(appLocale.value.languageCode);
      emit(ChaptersLoaded(chapters,lastReadSloka: lastRead));
    });

    on<LoadSlokas>((event, emit) async {
      emit(GitaLoading());
      isShowingFavorites = false;
      currentChapter = event.chapter;
      String folder = langFolderMap[currentLang] ?? appLocale.value.languageCode;
      String data = await rootBundle.loadString('assets/$folder/chapter$currentChapter.json');
      List jsonData = json.decode(data)['BhagavadGitaChapter'];
      List<Sloka> tempSlokas = jsonData.map((e) => Sloka.fromJson(e)).toList();
      
      // Get all favorites for current language and chapter at once for efficiency
      final favMaps = await DatabaseHelper().getFavs(language: currentLang);
      final favMap = <String, Map<String, dynamic>>{};
      for (var fav in favMaps) {
        if (fav['chapter'] == currentChapter) {
          final key = '${fav['chapter']}_${fav['verse']}';
          favMap[key] = fav;
        }
      }
      
      // Get chapter name from chapters.json
      String chapterName = '';
      try {
        String chaptersData = await rootBundle.loadString('assets/$folder/chapters.json');
        List chaptersJson = json.decode(chaptersData);
        try {
          final chapterMeta = chaptersJson.firstWhere(
            (e) => e['chapter'] == currentChapter,
          );
          chapterName = chapterMeta['name'] ?? '';
        } catch (e) {
          // Chapter not found in list, use empty string
        }
      } catch (e) {
        log('Error loading chapter name: $e');
      }
      
      // Check favorite status for each sloka and create new instances
      List<Sloka> loadedSlokas = [];
      for (var sloka in tempSlokas) {
        final key = '${sloka.chapter}_${sloka.verse}';
        final isFav = favMap.containsKey(key);
        final favData = favMap[key];
        
        // Use chapter name from favorite if available, otherwise use from chapters.json
        String slokaChapterName = favData?['chapterName'] ?? chapterName;
        
        loadedSlokas.add(Sloka(
          chapter: sloka.chapter,
          verse: sloka.verse,
          text: sloka.text,
          reference: sloka.reference,
          meaning: sloka.meaning,
          explanation: sloka.explanation,
          chapterName: slokaChapterName,
          isFavourite: isFav ? 1 : 0,
          isRead: sloka.isRead,
        ));
      }
      
      currentSlokas = loadedSlokas;
      selectedIndex = event.initialIndex ?? 0;
      // Ensure selectedIndex is within bounds
      if (selectedIndex >= currentSlokas.length) {
        selectedIndex = currentSlokas.isNotEmpty ? currentSlokas.length - 1 : 0;
      }
      emit(SlokasLoaded(currentSlokas, selectedIndex));
    });

    on<SelectSloka>((event, emit) {
      selectedIndex = event.slokaIndex;
      emit(SlokasLoaded(currentSlokas, selectedIndex));
    });

    on<ChangeLanguage>((event, emit) async {
      currentLang = event.lang;
      if (currentSlokas.isNotEmpty) {
        log('currentLang $currentLang');
        // Reload slokas in new language, preserve current selectedIndex
        add(LoadSlokas(currentChapter, initialIndex: selectedIndex));
      } else {
        // Reload chapters in new language
        add(LoadChapters());
      }
    });


    // This event is for PROGRESS screen
    on<LoadChapterProgress>((event, emit) async {
      emit(GitaLoading());

      String folder = langFolderMap[currentLang] ?? appLocale.value.languageCode;
      String data = await rootBundle.loadString('assets/$folder/chapters.json');
      List jsonData = json.decode(data);
      List<ChapterMeta> chapters =
      jsonData.map((e) => ChapterMeta.fromJson(e)).toList();

      Map<int, double> progressMap = {};
      int totalRead = 0;
      int totalShlokas = 0;

      for (final chapter in chapters) {
        int readCount =
        await DatabaseHelper().getReadCount(event.language, chapter.chapter);
        double percent = chapter.totalShlokas == 0
            ? 0
            : (readCount / chapter.totalShlokas) * 100;
        // Fix floating errors (like 99.9999999 → 100.0)
        percent = double.parse(percent.toStringAsFixed(1));

        // Clamp after formatting for safety
        percent = percent.clamp(0, 100);
        progressMap[chapter.chapter] = percent;
        totalRead += readCount;
        totalShlokas += chapter.totalShlokas;
      }

      double overallPercent = totalShlokas == 0 ? 0 : (totalRead / totalShlokas) * 100;
      overallPercent = double.parse(overallPercent.toStringAsFixed(1));
      overallPercent = overallPercent.clamp(0, 100);
      emit(ChaptersLoadProgress(
        chapters,
        progress: progressMap,
        overallPercent: overallPercent,
      ));
    });
    on<ToggleFavorite>((event, emit) async {
      final sloka = event.sloka;
      final language = event.language;
      final chapterName = event.chapterName;

      // Determine new favorite value
      final newFavValue = sloka.isFavourite == 1 ? 0 : 1;

      // Update database
      if (newFavValue == 1) {
        await DatabaseHelper().addFav(sloka, language, chapterName);
      } else {
        await DatabaseHelper().removeFav(
          chapter: sloka.chapter,
          verse: sloka.verse,
          language: language,
        );
      }

      // Update current state if SlokasLoaded
      if (state is SlokasLoaded) {
        final currentState = state as SlokasLoaded;
        
        // Check if we're currently showing only favourites
        final isFavoritesScreen = isShowingFavorites;
        
        // If in favorites screen and removing favorite, reload favorites list
        if (isFavoritesScreen && newFavValue == 0) {
          add(LoadFavorites(language));
          return;
        }
        
        // Update slokas list with new favorite status
        final updatedSlokas = currentState.slokas.map((s) {
          if (s.chapter == sloka.chapter && s.verse == sloka.verse) {
            return Sloka(
              chapter: s.chapter,
              verse: s.verse,
              text: s.text,
              reference: s.reference,
              meaning: s.meaning,
              explanation: s.explanation,
              isFavourite: newFavValue,
              chapterName: s.chapterName,  // Preserve chapterName
            );
          }
          return s;
        }).toList();

        // Update the bloc's currentSlokas to preserve favorite status when selecting different slokas
        currentSlokas = updatedSlokas;

        // Adjust selectedIndex if out of bounds
        int newSelectedIndex = currentState.selectedIndex;
        if (updatedSlokas.isEmpty) {
          newSelectedIndex = 0;
        } else if (newSelectedIndex >= updatedSlokas.length) {
          newSelectedIndex = updatedSlokas.length - 1;
        } else if (newSelectedIndex < 0) {
          newSelectedIndex = 0;
        }

        emit(SlokasLoaded(updatedSlokas, newSelectedIndex));
      }
    });

    on<LoadFavorites>((event, emit) async {
      emit(GitaLoading());
      isShowingFavorites = true;

      // Load fav slokas from DB
      final favMaps = await DatabaseHelper().getFavs(language: event.language);

      final favSlokas = favMaps.map((e) => Sloka(
        chapter: e['chapter'],
        verse: e['verse'],
        text: e['text'],
        reference: e['reference'] ?? '',
        meaning: e['meaning'],
        explanation: e['explanation'],
        isFavourite: 1,  // Always 1 for loaded favorites
        chapterName: e['chapterName'],  // Added: From DB
      )).toList();

      currentSlokas = favSlokas;
      selectedIndex = 0;

      emit(SlokasLoaded(favSlokas, selectedIndex));
    });


  }
}

// ----------------- UI -----------------


class ChapterListScreen extends StatefulWidget {
  const ChapterListScreen({super.key});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {

  final tables = [
    {"name": "sloka_read_status", "label": "Read Status"},
    {"name": "fav_slokas", "label": "Favourites"},
  ];

  void showClearTablesPopup(BuildContext context) {
    final selectedTables = ValueNotifier<List<String>>([]);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Clear Table Data"),
          content: SizedBox(
            width: 300,
            height: 100,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: selectedTables,
              builder: (context, selected, _) {
                return ListView(
                  children: tables.map((table) {
                    return CheckboxListTile(
                      title: Text(table["label"]!),
                      value: selected.contains(table["name"]),
                        onChanged: (val) {
                          final copy = List<String>.from(selectedTables.value);
                          if (val == true) {
                            copy.add(table["name"]!);
                          } else {
                            copy.remove(table["name"]!);
                          }
                          selectedTables.value = copy; // works because it's List<String>
                        }
                    );
                  }).toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                for (String table in selectedTables.value) {
                  await DatabaseHelper().clearTable(table);
                }
                Navigator.pop(context);
              },
              child: Text("Clear Selected"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:(context) => GitaBloc()..add(LoadChapters()),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: Text(AppLocalizations.of(context)?.chaptersList ?? chaptersList),
          actions: [
            IconButton(
              onPressed: () async {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProgressScreen(),));
              },
              icon: Icon(Icons.preview),
            ),
            LanguageDropdown(),
          ],
        ),
        body: BlocBuilder<GitaBloc, GitaState>(
          builder: (context, state) {
            if (state is GitaLoading) return Center(child: CircularProgressIndicator());
            if (state is ChaptersLoaded) {
              final last = state.lastReadSloka;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (last != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Last Read Verse
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.black, fontSize: 16),
                            children: [
                              TextSpan(
                                text: '${AppLocalizations.of(context)?.lastReadVerse ?? lastReadVerse} ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '(${last['chapter']}:${last['verse']})',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        // Chapter Name
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.black, fontSize: 16),
                            children: [
                              TextSpan(
                                text: "${AppLocalizations.of(context)?.chapterText ?? chapterText} : ",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: "${last['chapterName']}\n",
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              TextSpan(
                                text: "${AppLocalizations.of(context)?.text ?? text} : ",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: "${last['shlok']}",
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  ),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = state.chapters[index];
                        return ListTile(
                            title: Text('${AppLocalizations.of(context)?.chapterText ?? chapterText} ${chapter.chapter} : ${chapter.name}'),
                            subtitle: Row(
                              children: [
                                Icon(Icons.list),
                                Text('${chapter.totalShlokas} ${AppLocalizations.of(context)?.text ?? text}'),
                              ],
                            ),
                            onTap: () async{
                             await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  // builder: (_) => SlokaListScreen(
                                  builder: (_) => AllSlokaListScreen(
                                    chapterMeta: chapter,
                                    chapter: chapter.chapter,
                                    language: context.read<GitaBloc>().currentLang, // pass current language
                                  ),
                                ),
                              );
                              // refresh when returned
                              context.read<GitaBloc>().add(LoadChapters());
                            }

                        );
                      },
                    ),
                  ),
                ],
              );
            }
            return SizedBox.shrink();
          },
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "clear",
              child: Icon(Icons.clear),
              onPressed: () {
                showClearTablesPopup(context);
            },),
            FloatingActionButton(
              heroTag: "fav",
              child: Icon(Icons.favorite),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FavoriteSlokasScreen(language: appLocale.value.languageCode),));
            },),
          ],
        ),
      ),
    );
  }
}

class AllSlokaListScreen extends StatefulWidget {
  final ChapterMeta? chapterMeta;
  final int? chapter;
  final String? language;
  const AllSlokaListScreen(  {super.key,   this.chapterMeta,  this.chapter,  this.language, });

  @override
  State<AllSlokaListScreen> createState() => _AllSlokaListScreenState();
}

class _AllSlokaListScreenState extends State<AllSlokaListScreen> {
  List<int> readVerses = [];


  Future<void> _loadReadVerses() async {
    readVerses = await DatabaseHelper().getReadSlokaVerses(widget.language ?? 'mr', widget.chapter ?? 0);
   }
  @override
  void initState() {
    super.initState();
    _loadReadVerses(); // load once when opened
  }
  Future<void> _reloadWhenBack(BuildContext context) async {
    // called after returning from details
    await _loadReadVerses();
    final bloc = context.read<GitaBloc>();
    if (bloc.state is SlokasLoaded) {
      final current = bloc.state as SlokasLoaded;
      bloc.emit(SlokasLoaded(current.slokas, current.selectedIndex));
    }
  }
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GitaBloc()..currentLang = widget.language!..add(LoadSlokas(widget.chapter!)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.chapterMeta?.name ?? ''),
          backgroundColor: Colors.blue,
        ),
        body: BlocConsumer <GitaBloc, GitaState>(
          listenWhen: (prev, curr) => curr is SlokasLoaded,
          listener: (context, state) async {
            if (state is SlokasLoaded) {
              await _loadReadVerses();
            }
          },
          builder: (context, state) {
            if (state is GitaLoading) return Center(child: CircularProgressIndicator());
            if (state is SlokasLoaded) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(widget.chapterMeta?.name ?? ''),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4,
                        childAspectRatio: 2,
                        crossAxisSpacing: 2,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: state.slokas.length,
                        itemBuilder: (context, index) {
                          final verse = state.slokas[index].verse;
                          final isRead =  readVerses.contains(verse);
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SlokaListScreen(
                                    chapterName: widget.chapterMeta?.name ?? '',
                                    chapter: widget.chapter ?? 0,
                                    language: context.read<GitaBloc>().currentLang,
                                    initialIndex: index,
                                    isFrom: 'allList',
                                  ),
                                ),
                              // ).then((value) => context.read<GitaBloc>().add(LoadSlokas(widget.chapter ?? 0)),);
                              ).then((value) => _reloadWhenBack(context));
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.all(8),
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isRead ? Colors.green.shade100 : Colors.red.shade100),
                              ),
                              child: Text('${AppLocalizations.of(context)?.text ?? text} ${state.slokas[index].verse}', ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
            return SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class SlokaListScreen extends StatefulWidget {
  final String chapterName;
  final int chapter;
  final String language;
  final int initialIndex;
  final String isFrom;
  const SlokaListScreen({required this.chapterName,required this.chapter,required this.language,this.initialIndex = 0,this.isFrom = ''});

  @override
  State<SlokaListScreen> createState() => _SlokaListScreenState();
}

class _SlokaListScreenState extends State<SlokaListScreen> {
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
  }

  void _scrollToSelected(int index) {
    if (!scrollController.hasClients) return;

    final double itemWidth = 70; // adjust based on your UI
    final double targetOffset = itemWidth * index;

    scrollController.animateTo(
      targetOffset,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GitaBloc()..currentLang = widget.language..add(LoadSlokas(widget.chapter, initialIndex: widget.initialIndex)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.chapterName),
          backgroundColor: Colors.blue,
          actions: [

            BlocBuilder<GitaBloc, GitaState>(
              builder: (context, state) {
                if (state is SlokasLoaded && state.slokas.isNotEmpty) {
                  final current = state.slokas[state.selectedIndex];
                  bool isFav = current.isFavourite == 1;
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red),
                        onPressed: () {
                          context.read<GitaBloc>().add(
                            ToggleFavorite(sloka: current, language: widget.language,chapterName: widget.chapterName),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon( Icons.share,color: Colors.white),
                        onPressed: () {
                          const String appPackageName = 'com.unicornwings.quiz_sprint'; // replace with your actual package name
                          final String playStoreLink = 'https://play.google.com/store/apps/details?id=$appPackageName';
                          SharePlus.instance.share(
                            ShareParams(
                              title: '',
                              subject: '${current.text}}',
                              text: '${AppLocalizations.of(context)?.chapterText ?? chapterText} : ${current.chapter} ${AppLocalizations.of(context)?.text ?? text} : ${current.verse}'
                                  '\n\n${AppLocalizations.of(context)?.chapterText ?? chapterText} : ${current.chapterName}'
                                  '\n\n${AppLocalizations.of(context)?.text ?? text} : ${current.text}'
                                  '\n\n${AppLocalizations.of(context)?.reference ?? reference} : ${current.reference}'
                                  '\n\n${AppLocalizations.of(context)?.meaning ?? meaning} :${current.meaning}'
                                  '\n\n${AppLocalizations.of(context)?.explanation ?? explanation} :${current.explanation}'
                                  '\n\n${AppLocalizations.of(context)?.appInstallIns ?? appInstallIns}\n$playStoreLink',
                              excludedCupertinoActivities: [CupertinoActivityType.airDrop],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocBuilder<GitaBloc, GitaState>(
          builder: (context, state) {
            if (state is GitaLoading) return Center(child: CircularProgressIndicator());
            if (state is SlokasLoaded) {
              if (state.slokas.isEmpty) {
                return Center(child: Text("No slokas available"));
              }
              // Ensure selectedIndex is within bounds
              int safeIndex = state.selectedIndex;
              if (safeIndex < 0 || safeIndex >= state.slokas.length) {
                safeIndex = 0;
              }
              int index = safeIndex;
              // Ensure index is within bounds
              if (index >= 0 && index < state.slokas.length) {
                DatabaseHelper().markSlokaRead(widget.chapter, state.slokas[index].verse, widget.chapterName, state.slokas[index].text, widget.language);
                DatabaseHelper().getReadCount(widget.language, widget.chapter);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToSelected(state.selectedIndex);
              });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.isFrom == 'allList'
                  ? SizedBox(
                    height: 50,
                    child: ListView.builder(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: state.slokas.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            BlocProvider.of<GitaBloc>(context).add(SelectSloka(index));
                            _scrollToSelected(index);
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                                color: index == state.selectedIndex ? Colors.blue : Colors.grey,
                                borderRadius: BorderRadius.circular(5)),
                            child: Center(child: Text('${AppLocalizations.of(context)?.text ?? text} ${state.slokas[index].verse}', style: TextStyle(color: Colors.white))),
                          ),
                        );
                      },
                    ),
                  )
                      : Container(
                    alignment: Alignment.center,
                    height: 50,
                    width: 200,
                    padding: EdgeInsets.symmetric(horizontal: 3,vertical: 10),
                    margin: EdgeInsets.symmetric(horizontal: 3,vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10)
                    ),
                    child: Text('${AppLocalizations.of(context)?.chapterText ?? chapterText}${state.slokas[safeIndex].chapter},${AppLocalizations.of(context)?.text ?? text}${state.slokas[safeIndex].verse}'),
                  ) ,
                  Expanded(
                    child: SlokaDetail(state.slokas[safeIndex],state.slokas.length,widget.isFrom),
                  ),
                ],
              );
            }
            return SizedBox.shrink();
          },
        ),
      ),
    );
  }
}


class SlokaDetail extends StatefulWidget {
  final Sloka sloka;
  final int allShloka;
  final String isFrom;
    SlokaDetail(this.sloka, this.allShloka,this.isFrom);

  @override
  State<SlokaDetail> createState() => _SlokaDetailState();
}

class _SlokaDetailState extends State<SlokaDetail> {
  int selectedIndex = 0;
  FlutterTts flutterTts = FlutterTts();
  Map? currentVoice;
  List<Map> voiceList = [];
  @override
  void initState() {
    initTTS();
    super.initState();
  }

  void initTTS() {
    flutterTts.getVoices.then(
      (value) {
        try {
          voiceList = List<Map>.from(value);
          log(voiceList.toString());
          setState(() {
          voiceList = voiceList.where((element) => element['name'].contains('hi')).toList();
            currentVoice = voiceList.first;
            setVoice(currentVoice!);
          });
        } catch (e) {
          log(e.toString());
        }
      },
    );
  }

  void setVoice(Map voice){
    flutterTts.setVoice({'name':voice['name'],'local':voice['local']});
  }

  @override
  Widget build(BuildContext context) {
    final state = BlocProvider.of<GitaBloc>(context).state;
    if (state is SlokasLoaded) {
      selectedIndex = state.selectedIndex;
    }
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(onPressed: (){
                      flutterTts.speak(widget.sloka.explanation);
                    }, icon: Icon(Icons.speaker)),
                    //श्लोक , अर्थ , स्पष्टीकरण
                    Text(AppLocalizations.of(context)?.text ?? text, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.sloka.text, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text(AppLocalizations.of(context)?.reference ?? reference, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    Text(widget.sloka.reference, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text(AppLocalizations.of(context)?.meaning ?? meaning, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.sloka.meaning, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text(AppLocalizations.of(context)?.explanation ?? explanation, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.sloka.explanation, style: TextStyle(fontSize: 16)),
                  ],
                ),
              )),
          Visibility(
            visible: widget.isFrom == 'allList',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    onPressed: selectedIndex == 0 ? null :  () {
                      final bloc = BlocProvider.of<GitaBloc>(context);
                      final state = bloc.state;
                      if (state is SlokasLoaded && state.selectedIndex > 0) {
                        bloc.add(SelectSloka(state.selectedIndex - 1));
                      }
                    },
                    icon: Icon(Icons.arrow_circle_left_outlined,size: 35)),
                Text('${widget.sloka.verse} / ${widget.allShloka}', style: TextStyle(fontSize: 16)),
                IconButton(
                    onPressed: selectedIndex == widget.allShloka - 1 ? null :  () {
                      final bloc = BlocProvider.of<GitaBloc>(context);
                      final state = bloc.state;
                      if (state is SlokasLoaded &&
                          state.selectedIndex < state.slokas.length - 1) {
                        bloc.add(SelectSloka(state.selectedIndex + 1));
                      }
                    },
                    icon: Icon(Icons.arrow_circle_right_outlined,size: 35,)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
        valueListenable: appLocale, // 👈 Listen for changes to current app locale
        builder: (context, locale, _) {

        return DropdownButton<String>(
          // value: BlocProvider.of<GitaBloc>(context).currentLang,
          value: locale.languageCode,
          dropdownColor: Colors.blue,
          underline: SizedBox(),
          icon: Icon(Icons.language, color: Colors.white),
          items: [
            DropdownMenuItem(value: 'mr', child: Text('Marathi', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(value: 'hi', child: Text('Hindi', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white))),
          ],
          onChanged: (value) async {
            if (value != null) {
              BlocProvider.of<GitaBloc>(context).add(ChangeLanguage(value));
              final newLanguage = Locale(value);
              appLocale.value = newLanguage;
              await LocaleManager.saveLocale(newLanguage);
            }
          },
        );
      }
    );
  }
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
      GitaBloc()..add(LoadChapterProgress(appLocale.value.languageCode, [])),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Progress'),
        ),
        body: BlocBuilder<GitaBloc, GitaState>(
          builder: (context, state) {
            if (state is GitaLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ChaptersLoadProgress) {
              final progress = state.progress;
              final overallPercent = state.overallPercent;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: overallPercent/100,
                            strokeWidth: 8,
                            color: Colors.green,
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        Text(
                          '${overallPercent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: state.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = state.chapters[index];
                        final percent = (progress[chapter.chapter] ?? 0) / 100;

                        return Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 15),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                child: Text(
                                  '${AppLocalizations.of(context)?.chapterText ?? chapterText} ${chapter.chapter}\n${chapter.name}',
                                  maxLines: 3,
                                ),
                              ),
                              // Text('${chapter.totalShlokas}'),
                              SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 15),
                                  child: LinearProgressIndicator(
                                    value: percent,
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              // Text('${(percent * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class FavoriteSlokasScreen extends StatelessWidget {
  final String language;
  const FavoriteSlokasScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GitaBloc()..currentLang = language..add(LoadFavorites(language)),
      child: Scaffold(
        appBar: AppBar(title: Text("Favourites"), backgroundColor: Colors.blue),
        body: BlocBuilder<GitaBloc, GitaState>(
          builder: (context, state) {
            if (state is GitaLoading) return Center(child: CircularProgressIndicator());
            if (state is SlokasLoaded) {
              final slokas = state.slokas;
              if (slokas.isEmpty) return Center(child: Text("No favourites found"));

              return ListView.builder(
                itemCount: slokas.length,
                itemBuilder: (context, index) {
                  final sloka = slokas[index];
                  return ListTile(
                    title: Text("${sloka.chapter}:${sloka.verse} - ${sloka.text}"),
                    // subtitle: Text(sloka.meaning),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // remove from fav
                        context.read<GitaBloc>().add(
                          ToggleFavorite(sloka: sloka, language: language,chapterName: sloka.chapterName),
                        );
                      },
                    ),
                    onTap: () {
                      // open SlokaDetail if needed
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SlokaListScreen(
                            chapterName: sloka.chapterName,
                            chapter: sloka.chapter,
                            language: language,
                            initialIndex: sloka.verse - 1,
                            isFrom: 'Fav',
                          ),
                        ),
                      ).then((value) {
                        // Reload favorites when returning from details screen
                        context.read<GitaBloc>().add(LoadFavorites(language));
                      });
                    },
                  );
                },
              );
            }
            return SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

////// for notification display
// in send button
/*
    SendNotificationService.sendPushNotification(
      token!,
      titleController.text,
      bodyController.text,
      {'type': 'home','language':'en'},
    );
*/
//// for display notification language wise

/*
firebaseInitMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log(
          'Title - ${message.notification?.title}, Body - ${message.notification?.body} Type - ${message.data['type']}');
      final String? receivedLang = message.data['language'];      // from notification
      final String appLang = appLocale.value.languageCode;        // your app language

      log("App Lang: $appLang  |  Received Lang: $receivedLang");

      // ❌ If language does NOT match → no DB insert, no count, no notification
      if (receivedLang != null && receivedLang != appLang) {
        log("❌ Language does NOT match. Notification suppressed.");
        return; // stop here
      }
      if (Platform.isIOS) {
        iosForegroundMessage();
      } else {
        initItNotificationInfo();
        // handleRouting(message);
      }
      log('notification payload  : ${message.data}');
      log('notificationId ${message.messageId}');
      await DatabaseHelper().insertNotifications(
        message.messageId ?? '',
        message.notification?.title ?? '',
        message.notification?.body ?? '',
        message.data['type'] ?? ''
      );
      int count = await DatabaseHelper().getNotificationCount();
      NotificationCountNotifier.updateCount(count);
      log('Count $count');
      // show notifications when the some data has missing
      final String? type = message.data['type'];

      if ((type != null && type.isNotEmpty) &&
          ((message.messageId != null && message.messageId!.isNotEmpty) ||
              (message.notification?.title != null &&
                  message.notification!.title!.isNotEmpty) ||
              (message.notification?.body != null &&
                  message.notification!.body!.isNotEmpty) ||
              message.data.isNotEmpty)) {
        showNotification(message);
      }
    });
  }
*/