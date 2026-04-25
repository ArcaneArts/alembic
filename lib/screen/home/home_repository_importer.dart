import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/screen/home/home_controller.dart';
import 'package:alembic/util/repository_catalog.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

class HomeRepositoryImporter {
  final HomeController controller;
  final Future<void> Function() onReload;
  final ValueChanged<HomeTab> onTabSelected;

  const HomeRepositoryImporter({
    required this.controller,
    required this.onReload,
    required this.onTabSelected,
  });

  Future<void> import(BuildContext context) async {
    String? rawInput = await _promptForLink(context);
    if (rawInput == null) {
      return;
    }
    RepositoryRef? ref = parseRepositoryRef(rawInput);
    if (ref == null) {
      if (!context.mounted) {
        return;
      }
      await _notifyInvalidRepository(context);
      return;
    }
    await addManualRepoRef(ref);
    await onReload();
    Repository? resolved = await _resolveRepository(ref);
    if (!context.mounted) {
      return;
    }
    if (resolved == null) {
      await _notifyRepositorySaved(context, ref);
      return;
    }
    bool cloneNow = await _confirmClone(context, resolved);
    if (!cloneNow || !context.mounted) {
      return;
    }
    await _cloneRepository(context, resolved);
  }

  Future<String?> _promptForLink(BuildContext context) async {
    String? rawInput = await showAlembicInputDialog(
      context,
      title: 'Clone Repository Link',
      description: 'Paste a GitHub URL or owner/repo value.',
      placeholder: 'https://github.com/owner/repo or owner/repo',
      confirmText: 'Clone',
    );
    if (rawInput == null || rawInput.trim().isEmpty) {
      return null;
    }
    return rawInput;
  }

  Future<void> _notifyInvalidRepository(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    await showAlembicInfoDialog(
      context,
      title: 'Invalid Repository',
      message: 'Enter a valid GitHub repository URL or owner/repo value.',
    );
  }

  Future<Repository?> _resolveRepository(RepositoryRef ref) async {
    Repository? resolved = await controller.resolveRepositoryRef(ref);
    if (resolved != null) {
      return resolved;
    }
    return controller.localFallbackRepository(ref);
  }

  Future<void> _notifyRepositorySaved(
    BuildContext context,
    RepositoryRef ref,
  ) async {
    await showAlembicInfoDialog(
      context,
      title: 'Repository Saved',
      message:
          'Saved ${ref.fullName}. Metadata is unavailable right now, but the repository remains in your catalog.',
    );
  }

  Future<bool> _confirmClone(BuildContext context, Repository resolved) {
    return showAlembicConfirmDialog(
      context,
      title: 'Clone ${resolved.fullName}?',
      description: 'The repository has been saved. Clone it now?',
      confirmText: 'Clone',
      cancelText: 'Later',
    );
  }

  Future<void> _cloneRepository(
    BuildContext context,
    Repository resolved,
  ) async {
    ArcaneRepository repository = controller.repositoryFor(resolved);
    try {
      await repository.ensureRepositoryActive(
        controller.githubForRepository(resolved),
      );
      await onReload();
      onTabSelected(HomeTab.active);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Clone Failed',
        message: '$e',
      );
    }
  }
}
