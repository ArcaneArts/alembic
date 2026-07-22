import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/screen/splash.dart';
import 'package:arcane/arcane.dart';

class AlembicRoot extends StatelessWidget {
  const AlembicRoot({super.key});

  @override
  Widget build(BuildContext context) => ArcaneApp(
        debugShowCheckedModeBanner: false,
        title: 'Alembic',
        theme: buildAlembicTheme(),
        home: const SplashScreen(),
      );
}
