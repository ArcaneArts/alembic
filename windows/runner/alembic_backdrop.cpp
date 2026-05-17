#include "alembic_backdrop.h"

#include <dwmapi.h>
#include <windows.h>

#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

#ifndef DWMWA_MICA_EFFECT
#define DWMWA_MICA_EFFECT 1029
#endif

#ifndef DWMWA_USE_HOSTBACKDROPBRUSH
#define DWMWA_USE_HOSTBACKDROPBRUSH 17
#endif

enum DWM_SYSTEMBACKDROP_TYPE_INTERNAL {
  DWMSBT_AUTO_INTERNAL = 0,
  DWMSBT_NONE_INTERNAL = 1,
  DWMSBT_MAINWINDOW_INTERNAL = 2,
  DWMSBT_TRANSIENTWINDOW_INTERNAL = 3,
  DWMSBT_TABBEDWINDOW_INTERNAL = 4,
};

enum ACCENT_STATE_INTERNAL {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_ENABLE_HOSTBACKDROP = 5,
};

struct ACCENT_POLICY_INTERNAL {
  DWORD AccentState;
  DWORD AccentFlags;
  DWORD GradientColor;
  DWORD AnimationId;
};

struct WINCOMPATTRDATA_INTERNAL {
  DWORD Attribute;
  PVOID Data;
  SIZE_T SizeOfData;
};

typedef BOOL(WINAPI* SetWindowCompositionAttributeFn)(HWND,
                                                     WINCOMPATTRDATA_INTERNAL*);

static SetWindowCompositionAttributeFn ResolveSetWindowCompositionAttribute() {
  static SetWindowCompositionAttributeFn cached = nullptr;
  static bool resolved = false;
  if (resolved) {
    return cached;
  }
  resolved = true;
  HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
  if (!user32) {
    return cached;
  }
  cached = reinterpret_cast<SetWindowCompositionAttributeFn>(
      ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
  return cached;
}

static bool BuildNumberAtLeast(DWORD min_build) {
  HMODULE ntdll = ::GetModuleHandleW(L"ntdll.dll");
  if (!ntdll) {
    return false;
  }
  typedef LONG(WINAPI * RtlGetVersionFn)(PRTL_OSVERSIONINFOW);
  RtlGetVersionFn rtl_get_version =
      reinterpret_cast<RtlGetVersionFn>(::GetProcAddress(ntdll, "RtlGetVersion"));
  if (!rtl_get_version) {
    return false;
  }
  RTL_OSVERSIONINFOW info{};
  info.dwOSVersionInfoSize = sizeof(info);
  if (rtl_get_version(&info) != 0) {
    return false;
  }
  if (info.dwMajorVersion > 10) {
    return true;
  }
  if (info.dwMajorVersion < 10) {
    return false;
  }
  return info.dwBuildNumber >= min_build;
}

bool AlembicBackdrop::IsWindows11OrGreater() {
  return BuildNumberAtLeast(22000);
}

bool AlembicBackdrop::IsWindows11Build22621OrGreater() {
  return BuildNumberAtLeast(22621);
}

AlembicBackdropMaterial AlembicBackdrop::Detect() {
  if (IsWindows11Build22621OrGreater()) {
    return AlembicBackdropMaterial::Mica;
  }
  if (IsWindows11OrGreater()) {
    return AlembicBackdropMaterial::Acrylic;
  }
  if (ResolveSetWindowCompositionAttribute() != nullptr) {
    return AlembicBackdropMaterial::AcrylicLegacy;
  }
  return AlembicBackdropMaterial::Solid;
}

void AlembicBackdrop::ExtendFrameIntoClient(HWND hwnd) {
  MARGINS margins = {-1, -1, -1, -1};
  ::DwmExtendFrameIntoClientArea(hwnd, &margins);
}

static bool ApplyMicaModern(HWND hwnd, AlembicBackdropMaterial material) {
  int value = material == AlembicBackdropMaterial::MicaAlt
                  ? DWMSBT_TABBEDWINDOW_INTERNAL
                  : DWMSBT_MAINWINDOW_INTERNAL;
  HRESULT hr = ::DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &value,
                                       sizeof(value));
  return SUCCEEDED(hr);
}

static bool ApplyAcrylicModern(HWND hwnd) {
  int value = DWMSBT_TRANSIENTWINDOW_INTERNAL;
  HRESULT hr = ::DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &value,
                                       sizeof(value));
  return SUCCEEDED(hr);
}

static bool ApplyAcrylicLegacy(HWND hwnd) {
  SetWindowCompositionAttributeFn setter =
      ResolveSetWindowCompositionAttribute();
  if (!setter) {
    return false;
  }
  ACCENT_POLICY_INTERNAL accent{};
  accent.AccentState = ACCENT_ENABLE_ACRYLICBLURBEHIND;
  accent.AccentFlags = 2;
  accent.GradientColor = 0x00000000;
  accent.AnimationId = 0;
  WINCOMPATTRDATA_INTERNAL data{};
  data.Attribute = 19;
  data.Data = &accent;
  data.SizeOfData = sizeof(accent);
  return setter(hwnd, &data) == TRUE;
}

bool AlembicBackdrop::Apply(HWND hwnd, AlembicBackdropMaterial material) {
  if (!hwnd) {
    return false;
  }
  ExtendFrameIntoClient(hwnd);
  switch (material) {
    case AlembicBackdropMaterial::Mica:
    case AlembicBackdropMaterial::MicaAlt:
      if (ApplyMicaModern(hwnd, material)) {
        return true;
      }
      if (ApplyAcrylicModern(hwnd)) {
        return true;
      }
      return ApplyAcrylicLegacy(hwnd);
    case AlembicBackdropMaterial::Acrylic:
      if (ApplyAcrylicModern(hwnd)) {
        return true;
      }
      return ApplyAcrylicLegacy(hwnd);
    case AlembicBackdropMaterial::AcrylicLegacy:
      return ApplyAcrylicLegacy(hwnd);
    case AlembicBackdropMaterial::Solid:
    default:
      return true;
  }
}

bool AlembicBackdrop::ApplyDetected(HWND hwnd) {
  return Apply(hwnd, Detect());
}
