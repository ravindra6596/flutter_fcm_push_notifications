import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

class Item {
  final int id;
  final String title;

  Item({required this.id, required this.title});
}

class FavoriteItem {
  final int id;
  final String title;

  FavoriteItem({
    required this.id,
    required this.title,
  });

  factory FavoriteItem.fromMap(Map<String, dynamic> map) {
    return FavoriteItem(
      id: map['id'],
      title: map['title'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
    };
  }
}

class FavDB {
  static final FavDB instance = FavDB._internal();
  FavDB._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final path = await getDatabasesPath();
    return openDatabase(
      "$path/fav.db",
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY,
            title TEXT
          );
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return db.query("favorites");
  }

  Future<int> addFavorite(FavoriteItem item) async {
    final db = await database;
    return db.insert("favorites", item.toMap());
  }

  Future<int> removeFavorite(int id) async {
    final db = await database;
    return db.delete("favorites", where: "id = ?", whereArgs: [id]);
  }
}

class FavoriteRepository {
  final db = FavDB.instance;

  Future<List<FavoriteItem>> getFavorites() async {
    final res = await db.getFavorites();
    return res.map((e) => FavoriteItem.fromMap(e)).toList();
  }

  Future<void> addFavorite(Item item) async {
    await db.addFavorite(FavoriteItem(id: item.id, title: item.title));
  }

  Future<void> removeFavorite(int id) async {
    await db.removeFavorite(id);
  }
}

abstract class FavEvent {}

class LoadFav extends FavEvent {}

class AddFav extends FavEvent {
  final Item item;
  AddFav(this.item);
}

class RemoveFav extends FavEvent {
  final int id;
  RemoveFav(this.id);
}

abstract class FavState {}

class FavLoading extends FavState {}

class FavLoaded extends FavState {
  final List<FavoriteItem> items;
  FavLoaded(this.items);
}

class FavBloc extends Bloc<FavEvent, FavState> {
  final FavoriteRepository repo;

  FavBloc(this.repo) : super(FavLoading()) {
    on<LoadFav>(_load);
    on<AddFav>(_add);
    on<RemoveFav>(_remove);
  }

  Future<void> _load(LoadFav event, Emitter<FavState> emit) async {
    final favs = await repo.getFavorites();
    emit(FavLoaded(favs));
  }

  Future<void> _add(AddFav event, Emitter<FavState> emit) async {
    await repo.addFavorite(event.item);
    add(LoadFav());
  }

  Future<void> _remove(RemoveFav event, Emitter<FavState> emit) async {
    await repo.removeFavorite(event.id);
    add(LoadFav());
  }
}

class FavHomeScreen extends StatelessWidget {
  final items = List.generate(
    10,
    (i) => Item(id: i, title: "Item $i"),
  );

  FavHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Simple List")),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            title: Text(item.title),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<FavBloc>(),
                    child: DetailScreen(item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Item item;

  DetailScreen(this.item);

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FavBloc>();

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FavoriteScreen(),
                    ));
              },
              icon: Icon(Icons.list))
        ],
      ),
      body: Center(
        child: BlocBuilder<FavBloc, FavState>(
          builder: (context, state) {
            if (state is FavLoaded) {
              final isFav = state.items.any((e) => e.id == item.id);

              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 40,
                ),
                onPressed: () {
                  if (isFav) {
                    bloc.add(RemoveFav(item.id));
                  } else {
                    bloc.add(AddFav(item));
                  }
                },
              );
            }
            return CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}

class FavoriteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FavBloc(FavoriteRepository())..add(LoadFav()),
      child: Scaffold(
        appBar: AppBar(title: Text("Favorites")),
        body: BlocBuilder<FavBloc, FavState>(
          builder: (context, state) {
            if (state is FavLoading) {
              return Center(child: CircularProgressIndicator());
            }

            if (state is FavLoaded) {
              if (state.items.isEmpty) {
                return Center(child: Text("No Favorites yet"));
              }

              return ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (_, i) {
                  final fav = state.items[i];

                  return ListTile(
                    title: Text(fav.title),
                    trailing: Icon(Icons.favorite, color: Colors.red),

                    // ← OPEN DETAILS WITH SAME BLOCBLOC
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<FavBloc>(),
                            child: DetailScreen(
                              Item(id: fav.id, title: fav.title),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }

            return SizedBox();
          },
        ),
      ),
    );
  }
}
