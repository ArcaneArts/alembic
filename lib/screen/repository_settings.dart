import 'package:alembic/util/extensions.dart';
import 'package:arcane/arcane.dart';
import 'package:arcane/generated/arcane_shadcn/src/components/menu/dropdown_menu.dart';
import 'package:github/github.dart';

import '../util/repo_config.dart';

class RepositorySettings extends StatelessWidget {
  const RepositorySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final Repository repository = context.repository;

    return ArcaneScreen(
      header: Bar(titleText: "Settings", subtitleText: repository.fullName),
      child: Collection(
        children: [
          Section(
            subtitleText: "Tools",
            child: Collection(
              children: [
                _WorkspaceDirectoryTile(repository: repository),
                _EditorToolTile(repository: repository),
                _GitToolTile(repository: repository),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDirectoryTile extends StatefulWidget {
  final Repository repository;

  const _WorkspaceDirectoryTile({required this.repository});

  @override
  State<_WorkspaceDirectoryTile> createState() => _WorkspaceDirectoryTileState();
}

class _WorkspaceDirectoryTileState extends State<_WorkspaceDirectoryTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: getRepoConfig(widget.repository).openDirectory);
    _controller.addListener(_save);
  }

  void _save() {
    setRepoConfig(widget.repository, getRepoConfig(widget.repository)..openDirectory = _controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_save);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tile(
      leading: const Icon(Icons.folder_fill),
      title: const Text("Workspace Directory"),
      subtitle: const Text("The subdirectory to open the project in with tools"),
      trailing: SizedBox(
        width: 200,
        child: TextField(controller: _controller),
      ),
    );
  }
}

class _EditorToolTile extends StatefulWidget {
  final Repository repository;

  const _EditorToolTile({required this.repository});

  @override
  State<_EditorToolTile> createState() => _EditorToolTileState();
}

class _EditorToolTileState extends State<_EditorToolTile> {
  late ApplicationTool _value;

  @override
  void initState() {
    super.initState();
    _value = getRepoConfig(widget.repository).editorTool ?? ApplicationTool.intellij;
  }

  @override
  Widget build(BuildContext context) {
    return Tile(
      leading: const Icon(Icons.app_window),
      title: const Text("Editor Tool"),
      subtitle: const Text("Overrides the default IDE to use for opening projects"),
      trailing: OutlineButton(
        onPressed: () {
          showDropdown(
            context: context,
            builder: (BuildContext dropdownContext) {
              return DropdownMenu(
                children: ApplicationTool.values.map((v) {
                  return MenuButton(
                    child: Text(v.displayName).withTooltip(v.help ?? ""),
                    onPressed: () {
                      setState(() {
                        _value = v;
                      });
                      setRepoConfig(
                        widget.repository,
                        getRepoConfig(widget.repository)..editorTool = v,
                      );
                      Navigator.of(dropdownContext).pop();
                    },
                  );
                }).toList(),
              );
            },
          );
        },
        child: Row(
          children: [
            Text(_value.displayName),
            const Icon(Icons.arrow_down),
          ],
        ),
      ),
    );
  }
}

class _GitToolTile extends StatefulWidget {
  final Repository repository;

  const _GitToolTile({required this.repository});

  @override
  State<_GitToolTile> createState() => _GitToolTileState();
}

class _GitToolTileState extends State<_GitToolTile> {
  late GitTool _value;

  @override
  void initState() {
    super.initState();
    _value = getRepoConfig(widget.repository).gitTool ?? GitTool.gitkraken;
  }

  @override
  Widget build(BuildContext context) {
    return Tile(
      leading: const Icon(Icons.git_branch),
      title: const Text("Git Tool"),
      subtitle: const Text("Overrides the default tool to use for opening repositories"),
      trailing: OutlineButton(
        onPressed: () {
          showDropdown(
            context: context,
            builder: (BuildContext dropdownContext) {
              return DropdownMenu(
                children: GitTool.values.map((v) {
                  return MenuButton(
                    child: Text(v.displayName),
                    onPressed: () {
                      setState(() {
                        _value = v;
                      });
                      setRepoConfig(
                        widget.repository,
                        getRepoConfig(widget.repository)..gitTool = v,
                      );
                      Navigator.of(dropdownContext).pop();
                    },
                  );
                }).toList(),
              );
            },
          );
        },
        child: Row(
          children: [
            Text(_value.displayName),
            const Icon(Icons.arrow_down),
          ],
        ),
      ),
    );
  }
}