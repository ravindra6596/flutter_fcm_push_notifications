import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/utils/locale_controller.dart';
import 'package:push_notification/utils/strings.dart';

class Chapter {
  final int? chapter;
  final int? verse;
  final String? text;
  final String? meaning;
  final String? explanation;

  Chapter({
    this.chapter,
    this.verse,
    this.text,
    this.meaning,
    this.explanation,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      chapter: json['chapter'],
      verse: json['verse'],
      text: json['text'],
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
  final String meaning;
  final String explanation;
  final String chapterName;
  final int isFavourite;
  bool isRead;

  Sloka({
    required this.chapter,
    required this.verse,
    required this.text,
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
  LoadSlokas(this.chapter);
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
  ChaptersLoaded(this.chapters);
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
      List<ChapterMeta> chapters =
      jsonData.map((e) => ChapterMeta.fromJson(e)).toList();
      emit(ChaptersLoaded(chapters));
    });

    on<LoadSlokas>((event, emit) async {
      emit(GitaLoading());
      currentChapter = event.chapter;
      String folder = langFolderMap[currentLang] ?? appLocale.value.languageCode;
      String data = await rootBundle.loadString('assets/$folder/chapter$currentChapter.json');
      List jsonData = json.decode(data)['BhagavadGitaChapter'];
      currentSlokas = jsonData.map((e) => Sloka.fromJson(e)).toList();
      selectedIndex = 0;
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
        // Reload slokas in new language
        add(LoadSlokas(currentChapter));
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

        progressMap[chapter.chapter] = percent;
        totalRead += readCount;
        totalShlokas += chapter.totalShlokas;
      }

      double overallPercent =
      totalShlokas == 0 ? 0 : (totalRead / totalShlokas) * 100;

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
        final updatedSlokas = currentState.slokas.map((s) {
          if (s.chapter == sloka.chapter && s.verse == sloka.verse) {
            return Sloka(
              chapter: s.chapter,
              verse: s.verse,
              text: s.text,
              meaning: s.meaning,
              explanation: s.explanation,
              isFavourite: newFavValue,
              chapterName: s.chapterName,  // Preserve chapterName
            );
          }
          return s;
        }).toList();

        // If unfavoring, remove from list (for favorites screen; chapter screen keeps all)
        if (newFavValue == 0) {
          updatedSlokas.removeWhere((s) => s.chapter == sloka.chapter && s.verse == sloka.verse);
        }

        // Adjust selectedIndex if out of bounds
        int newSelectedIndex = currentState.selectedIndex;
        if (newSelectedIndex >= updatedSlokas.length) {
          newSelectedIndex = updatedSlokas.isNotEmpty ? 0 : 0;
        }

        emit(SlokasLoaded(updatedSlokas, newSelectedIndex));
      }
    });

    on<LoadFavorites>((event, emit) async {
      emit(GitaLoading());

      // Load fav slokas from DB
      final favMaps = await DatabaseHelper().getFavs(language: event.language);

      final favSlokas = favMaps.map((e) => Sloka(
        chapter: e['chapter'],
        verse: e['verse'],
        text: e['text'],
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
              return ListView.builder(
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
                      onTap: () {
                        Navigator.push(
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
                      }

                  );
                },
              );
            }
            return SizedBox.shrink();
          },
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              child: Icon(Icons.clear),
              onPressed: () {
                showClearTablesPopup(context);
            },),
            FloatingActionButton(
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
                                    initialIndex: index  ,
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

class SlokaListScreen extends StatelessWidget {
  final String chapterName;
  final int chapter;
  final String language;
  final int initialIndex;
  const SlokaListScreen({required this.chapterName,required this.chapter,required this.language,this.initialIndex = 0,});


  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GitaBloc()..currentLang = language..add(LoadSlokas(chapter))..add(SelectSloka(initialIndex)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(chapterName),
          backgroundColor: Colors.blue,
          actions: [
            BlocBuilder<GitaBloc, GitaState>(
              builder: (context, state) {
                if (state is SlokasLoaded) {
                  final current = state.slokas[state.selectedIndex];
                  bool isFav = current.isFavourite == 1;
                  return IconButton(
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red),
                    onPressed: () {
                      context.read<GitaBloc>().add(
                        ToggleFavorite(sloka: current, language: language,chapterName: chapterName),
                      );
                    },
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
              int index = state.selectedIndex;
              DatabaseHelper().markSlokaRead(chapter, state.slokas[index].verse, chapterName, language);
              DatabaseHelper().getReadCount(language, chapter);
              return Column(
                children: [
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.slokas.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => BlocProvider.of<GitaBloc>(context).add(SelectSloka(index)),
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
                  ),
                  Expanded(
                    child: SlokaDetail(state.slokas[state.selectedIndex],state.slokas.length),
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


class SlokaDetail extends StatelessWidget {
  final Sloka sloka;
  final int allShloka;
    SlokaDetail(this.sloka, this.allShloka);
  int selectedIndex = 0;
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
                    //श्लोक , अर्थ , स्पष्टीकरण
                    Text(AppLocalizations.of(context)?.text ?? text, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sloka.text, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text(AppLocalizations.of(context)?.meaning ?? meaning, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sloka.meaning, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text(AppLocalizations.of(context)?.explanation ?? explanation, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sloka.explanation, style: TextStyle(fontSize: 16)),
                  ],
                ),
              )),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Visibility(
                visible: selectedIndex !=0,
                child: IconButton(
                    onPressed: () {
                      final bloc = BlocProvider.of<GitaBloc>(context);
                      final state = bloc.state;
                      if (state is SlokasLoaded && state.selectedIndex > 0) {
                        bloc.add(SelectSloka(state.selectedIndex - 1));
                      }
                    },
                    icon: Icon(Icons.arrow_circle_left_outlined,size: 35)),
              ),
              Text('${sloka.verse} / $allShloka', style: TextStyle(fontSize: 16)),
              Visibility(
                visible: selectedIndex != allShloka - 1,
                child: IconButton(
                    onPressed: () {
                      final bloc = BlocProvider.of<GitaBloc>(context);
                      final state = bloc.state;
                      if (state is SlokasLoaded &&
                          state.selectedIndex < state.slokas.length - 1) {
                        bloc.add(SelectSloka(state.selectedIndex + 1));
                      }
                    },
                    icon: Icon(Icons.arrow_circle_right_outlined,size: 35,)),
              ),
            ],
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
                          ),
                        ),
                      );
                      /*Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (_) => GitaBloc()
                              ..currentLang = language
                              ..add(LoadSlokas(sloka.chapter))
                              ..add(SelectSloka(sloka.verse)),
                            child: Material(
                              child: SlokaDetail(sloka, 0),
                            ),
                          ),
                        ),
                      );*/
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
