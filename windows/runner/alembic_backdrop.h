#ifndef RUNNER_ALEMBIC_BACKDROP_H_
#define RUNNER_ALEMBIC_BACKDROP_H_

#include <windows.h>

enum class AlembicBackdropMaterial {
  Mica,
  MicaAlt,
  Acrylic,
  AcrylicLegacy,
  Solid,
};

class AlembicBackdrop {
 public:
  static AlembicBackdropMaterial Detect();

  static bool Apply(HWND hwnd, AlembicBackdropMaterial material);

  static bool ApplyDetected(HWND hwnd);

  static void ExtendFrameIntoClient(HWND hwnd);

  static bool IsWindows11OrGreater();

  static bool IsWindows11Build22621OrGreater();
};

#endif
