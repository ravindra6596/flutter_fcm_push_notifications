import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bhagavad Gita'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              context.read<LanguageBloc>().add(LoadLanguage(value));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'marathi', child: Text('Marathi')),
              PopupMenuItem(value: 'hindi', child: Text('Hindi')),
              PopupMenuItem(value: 'english', child: Text('English')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<LanguageBloc, LanguageState>(
        builder: (context, state) {
          if (state is LanguageLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LanguageLoaded) {
            return ListView.builder(
              itemCount: state.chapters.length,
              itemBuilder: (context, index) {
                final chapter = state.chapters[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chapter ${chapter.chapter}, Verse ${chapter.verse}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(chapter.text ?? ''),
                        const SizedBox(height: 8),

                        Text(chapter.meaning ?? ''),
                        const SizedBox(height: 8),

                        Text(chapter.explanation ?? ''),
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (state is LanguageError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const Center(child: Text('Select a language'));
        },
      ),
    );
  }
}

class LanguageApp extends StatelessWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LanguageBloc()..add(const LoadLanguage('marathi')),
      child: ChapterListScreen(),
    );
  }
}

// ----------------- Models -----------------
class ChapterMeta {
  final int chapter;
  final String name;
  ChapterMeta({required this.chapter, required this.name});

  factory ChapterMeta.fromJson(Map<String, dynamic> json) =>
      ChapterMeta(chapter: json['chapter'], name: json['name']);
}

class Sloka {
  final int chapter;
  final int verse;
  final String text;
  final String meaning;
  final String explanation;

  Sloka({
    required this.chapter,
    required this.verse,
    required this.text,
    required this.meaning,
    required this.explanation,
  });

  factory Sloka.fromJson(Map<String, dynamic> json) => Sloka(
    chapter: json['chapter'],
    verse: json['verse'],
    text: json['text'],
    meaning: json['meaning'],
    explanation: json['explanation'],
  );
}

// ----------------- BLoC -----------------
abstract class GitaEvent {}

class LoadChapters extends GitaEvent {}

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

abstract class GitaState {}

class GitaLoading extends GitaState {}

class ChaptersLoaded extends GitaState {
  final List<ChapterMeta> chapters;
  ChaptersLoaded(this.chapters);
}

class SlokasLoaded extends GitaState {
  final List<Sloka> slokas;
  final int selectedIndex;
  SlokasLoaded(this.slokas, this.selectedIndex);
}

class GitaBloc extends Bloc<GitaEvent, GitaState> {
  String currentLang = 'marathi';
  int currentChapter = 1;
  List<Sloka> currentSlokas = [];
  int selectedIndex = 0;

  GitaBloc() : super(GitaLoading()) {
    on<LoadChapters>((event, emit) async {
      emit(GitaLoading());
      String data = await rootBundle
          .loadString('assets/$currentLang/chapters.json');
      List jsonData = json.decode(data);
      List<ChapterMeta> chapters =
      jsonData.map((e) => ChapterMeta.fromJson(e)).toList();
      emit(ChaptersLoaded(chapters));
    });

    on<LoadSlokas>((event, emit) async {
      emit(GitaLoading());
      currentChapter = event.chapter;
      String data = await rootBundle
          .loadString('assets/$currentLang/chapter$currentChapter.json');
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

  }
}

// ----------------- UI -----------------


class ChapterListScreen extends StatefulWidget {
  const ChapterListScreen({super.key});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {


  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:(context) => GitaBloc()..add(LoadChapters()),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: Text('Chapters'),
          actions: [
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
                      title: Text('${chapter.chapter}. ${chapter.name}'),
                      onTap: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SlokaListScreen(
                              chapterName: chapter.name,
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
      ),
    );
  }
}

class SlokaListScreen extends StatelessWidget {
  final String chapterName;
  final int chapter;
  final String language;
  const SlokaListScreen({required this.chapterName,required this.chapter,required this.language,});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GitaBloc()..currentLang = language..add(LoadSlokas(chapter)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(chapterName),
          backgroundColor: Colors.blue,
          actions: [
            LanguageDropdown(),
          ],
        ),
        body: BlocBuilder<GitaBloc, GitaState>(
          builder: (context, state) {
            if (state is GitaLoading) return Center(child: CircularProgressIndicator());
            if (state is SlokasLoaded) {
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
                            child: Center(child: Text('Sloka ${state.slokas[index].verse}', style: TextStyle(color: Colors.white))),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: SlokaDetail(state.slokas[state.selectedIndex]),
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
  const SlokaDetail(this.sloka);

  @override
  Widget build(BuildContext context) {
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
                    Text('Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sloka.text, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text('Meaning:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sloka.meaning, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 12),
                    Text('Explanation:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sloka.explanation, style: TextStyle(fontSize: 16)),
                  ],
                ),
              )),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  onPressed: () {
                    final bloc = BlocProvider.of<GitaBloc>(context);
                    final state = bloc.state;
                    if (state is SlokasLoaded && state.selectedIndex > 0) {
                      bloc.add(SelectSloka(state.selectedIndex - 1));
                    }
                  },
                  icon: Icon(Icons.arrow_left)),
              IconButton(
                  onPressed: () {
                    final bloc = BlocProvider.of<GitaBloc>(context);
                    final state = bloc.state;
                    if (state is SlokasLoaded &&
                        state.selectedIndex < state.slokas.length - 1) {
                      bloc.add(SelectSloka(state.selectedIndex + 1));
                    }
                  },
                  icon: Icon(Icons.arrow_right)),
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
    return DropdownButton<String>(
      value: BlocProvider.of<GitaBloc>(context).currentLang,
      dropdownColor: Colors.blue,
      underline: SizedBox(),
      icon: Icon(Icons.language, color: Colors.white),
      items: [
        DropdownMenuItem(value: 'marathi', child: Text('Marathi', style: TextStyle(color: Colors.white))),
        DropdownMenuItem(value: 'hindi', child: Text('Hindi', style: TextStyle(color: Colors.white))),
        DropdownMenuItem(value: 'english', child: Text('English', style: TextStyle(color: Colors.white))),
      ],
      onChanged: (value) {
        if (value != null) BlocProvider.of<GitaBloc>(context).add(ChangeLanguage(value));
      },
    );
  }
}
