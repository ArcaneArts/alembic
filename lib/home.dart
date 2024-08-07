import 'package:fast_log/fast_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:toxic/toxic.dart';
import 'package:github/github.dart';

class AlembicHome extends StatefulWidget {
  final GitHub github;

  const AlembicHome({super.key, required this.github});

  @override
  State<AlembicHome> createState() => _AlembicHomeState();
}

class _AlembicHomeState extends State<AlembicHome> {
  late Future<List<Repository>> repos;

  @override
  void initState() {
    repos = widget.github.repositories
        .listRepositories()
        .map((i) {
          print(i.name);
          return i;
        })
        .toList()
        .catchError((e, es) {
          error(e);
          error(es);
        })
        .then((i) {
          print("Got ${i.length}");
          return i;
        });
    super.initState();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
          child: FutureBuilder<List<Repository>>(
        future: repos,
        builder: (context, snap) => !snap.hasData
            ? Center(
                child: Text("No Data"),
              )
            : ListView.builder(
                itemCount: snap.data!.length,
                itemBuilder: (context, index) => CupertinoListTile(
                  title: Text(snap.data![index].fullName),
                  subtitle: Text(snap.data![index].description),
                ),
              ),
      ));
}
