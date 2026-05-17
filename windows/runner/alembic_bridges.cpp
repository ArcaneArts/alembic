#include "alembic_bridges.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <windowsx.h>

#include <algorithm>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "alembic_backdrop.h"

namespace {

constexpr wchar_t kInputWindowClass[] = L"AlembicInputDialog";
constexpr wchar_t kCustomWindowClass[] = L"AlembicCustomDialog";

std::wstring Widen(const std::string& s) {
  if (s.empty()) {
    return std::wstring();
  }
  int size = ::MultiByteToWideChar(
      CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), nullptr, 0);
  std::wstring result(size, 0);
  ::MultiByteToWideChar(
      CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), result.data(), size);
  return result;
}

std::string Narrow(const std::wstring& s) {
  if (s.empty()) {
    return std::string();
  }
  int size = ::WideCharToMultiByte(
      CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), nullptr, 0, nullptr,
      nullptr);
  std::string result(size, 0);
  ::WideCharToMultiByte(
      CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), result.data(), size,
      nullptr, nullptr);
  return result;
}

const flutter::EncodableValue* FindInMap(
    const flutter::EncodableMap* map, const std::string& key) {
  if (map == nullptr) {
    return nullptr;
  }
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return nullptr;
  }
  return &(it->second);
}

std::string ExtractString(
    const flutter::EncodableMap* map, const std::string& key,
    const std::string& fallback = std::string()) {
  const flutter::EncodableValue* value = FindInMap(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const std::string* s = std::get_if<std::string>(value)) {
    return *s;
  }
  return fallback;
}

bool ExtractBool(
    const flutter::EncodableMap* map, const std::string& key,
    bool fallback = false) {
  const flutter::EncodableValue* value = FindInMap(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const bool* b = std::get_if<bool>(value)) {
    return *b;
  }
  return fallback;
}

bool DetectSystemDarkMode() {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(
          HKEY_CURRENT_USER,
          L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
          0, KEY_READ, &key) != ERROR_SUCCESS) {
    return false;
  }
  DWORD value = 1;
  DWORD size = sizeof(value);
  DWORD type = REG_DWORD;
  LSTATUS status = ::RegQueryValueExW(
      key, L"AppsUseLightTheme", nullptr, &type,
      reinterpret_cast<LPBYTE>(&value), &size);
  ::RegCloseKey(key);
  if (status != ERROR_SUCCESS) {
    return false;
  }
  return value == 0;
}

std::string MaterialToWire(AlembicBackdropMaterial material) {
  switch (material) {
    case AlembicBackdropMaterial::Mica:
      return "mica";
    case AlembicBackdropMaterial::MicaAlt:
      return "mica_alt";
    case AlembicBackdropMaterial::Acrylic:
      return "acrylic";
    case AlembicBackdropMaterial::AcrylicLegacy:
      return "acrylic_legacy";
    case AlembicBackdropMaterial::Solid:
      return "solid";
  }
  return "solid";
}

AlembicBackdropMaterial WireToMaterial(const std::string& wire) {
  if (wire == "mica") {
    return AlembicBackdropMaterial::Mica;
  }
  if (wire == "mica_alt") {
    return AlembicBackdropMaterial::MicaAlt;
  }
  if (wire == "acrylic") {
    return AlembicBackdropMaterial::Acrylic;
  }
  if (wire == "acrylic_legacy") {
    return AlembicBackdropMaterial::AcrylicLegacy;
  }
  if (wire == "solid") {
    return AlembicBackdropMaterial::Solid;
  }
  return AlembicBackdrop::Detect();
}

}  // namespace

struct InputDialogState {
  std::wstring title;
  std::wstring description;
  std::wstring placeholder;
  std::wstring confirm_label;
  std::wstring cancel_label;
  std::wstring value;
  bool secure = false;
  bool multiline = false;
  bool confirmed = false;
};

static LRESULT CALLBACK InputDialogProc(
    HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

static std::wstring ShowInputDialog(
    HWND owner, const InputDialogState& initial, bool* out_confirmed);

static int ShowConfirmDialog(
    HWND owner, const std::wstring& title, const std::wstring& description,
    const std::wstring& confirm_label, const std::wstring& cancel_label,
    bool destructive);

static void ShowInfoDialog(
    HWND owner, const std::wstring& title, const std::wstring& description,
    const std::wstring& close_label);

AlembicBridges& AlembicBridges::Instance() {
  static AlembicBridges instance;
  return instance;
}

void AlembicBridges::Attach(
    flutter::BinaryMessenger* messenger, HWND host_window) {
  host_window_ = host_window;
  AttachWindowChannel(messenger);
  AttachModalsChannel(messenger);
  AttachMenusChannel(messenger);
}

void AlembicBridges::Detach() {
  window_channel_.reset();
  modals_channel_.reset();
  menus_channel_.reset();
  host_window_ = nullptr;
}

void AlembicBridges::OnThemeChanged(bool is_dark) {
  if (window_channel_ == nullptr) {
    return;
  }
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("theme")] =
      flutter::EncodableValue(is_dark ? "dark" : "light");
  window_channel_->InvokeMethod(
      "onThemeChanged",
      std::make_unique<flutter::EncodableValue>(payload));
}

bool AlembicBridges::IsHideOnBlurSuspended() const {
  return hide_on_blur_suspend_count_ > 0;
}

void AlembicBridges::AttachWindowChannel(flutter::BinaryMessenger* messenger) {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "alembic_window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        const flutter::EncodableMap* args =
            std::get_if<flutter::EncodableMap>(call.arguments());

        if (method == "detectMaterial") {
          AlembicBackdropMaterial material = AlembicBackdrop::Detect();
          result->Success(flutter::EncodableValue(MaterialToWire(material)));
          return;
        }
        if (method == "setMaterial") {
          std::string wire = ExtractString(args, "material", "mica");
          AlembicBackdropMaterial material = WireToMaterial(wire);
          bool ok = AlembicBackdrop::Apply(host_window_, material);
          result->Success(flutter::EncodableValue(ok));
          return;
        }
        if (method == "pushThemeTokens") {
          const flutter::EncodableValue* tokens = FindInMap(args, "tokens");
          theme_tokens_.clear();
          if (tokens != nullptr) {
            if (const flutter::EncodableMap* map =
                    std::get_if<flutter::EncodableMap>(tokens)) {
              for (const auto& entry : *map) {
                if (const std::string* key =
                        std::get_if<std::string>(&entry.first)) {
                  theme_tokens_.emplace_back(*key, entry.second);
                }
              }
            }
          }
          result->Success();
          return;
        }
        if (method == "suspendHideOnBlur") {
          hide_on_blur_suspend_count_++;
          result->Success();
          return;
        }
        if (method == "resumeHideOnBlur") {
          if (hide_on_blur_suspend_count_ > 0) {
            hide_on_blur_suspend_count_--;
          }
          result->Success();
          return;
        }
        if (method == "dumpDiagnostics") {
          flutter::EncodableMap diag;
          diag[flutter::EncodableValue("material")] =
              flutter::EncodableValue(
                  MaterialToWire(AlembicBackdrop::Detect()));
          diag[flutter::EncodableValue("hideOnBlurSuspendCount")] =
              flutter::EncodableValue(hide_on_blur_suspend_count_);
          diag[flutter::EncodableValue("themeTokenCount")] =
              flutter::EncodableValue(
                  static_cast<int>(theme_tokens_.size()));
          diag[flutter::EncodableValue("isDark")] =
              flutter::EncodableValue(DetectSystemDarkMode());
          RECT rect{};
          if (host_window_ != nullptr) {
            ::GetWindowRect(host_window_, &rect);
          }
          flutter::EncodableMap frame;
          frame[flutter::EncodableValue("left")] =
              flutter::EncodableValue(static_cast<int>(rect.left));
          frame[flutter::EncodableValue("top")] =
              flutter::EncodableValue(static_cast<int>(rect.top));
          frame[flutter::EncodableValue("right")] =
              flutter::EncodableValue(static_cast<int>(rect.right));
          frame[flutter::EncodableValue("bottom")] =
              flutter::EncodableValue(static_cast<int>(rect.bottom));
          diag[flutter::EncodableValue("frame")] =
              flutter::EncodableValue(frame);
          result->Success(flutter::EncodableValue(diag));
          return;
        }

        if (method == "showAboutPanel") {
          std::wstring app_name =
              Widen(ExtractString(args, "appName", "Alembic"));
          std::wstring version = Widen(ExtractString(args, "version", ""));
          std::wstring build = Widen(ExtractString(args, "build", ""));
          std::wstring copyright =
              Widen(ExtractString(args, "copyright", ""));
          std::wstring content;
          if (!version.empty()) {
            content += L"Version " + version;
            if (!build.empty()) {
              content += L" (" + build + L")";
            }
            content += L"\n";
          } else if (!build.empty()) {
            content += L"Build " + build + L"\n";
          }
          if (!copyright.empty()) {
            content += L"\n" + copyright;
          }
          TASKDIALOGCONFIG config{};
          config.cbSize = sizeof(config);
          config.hwndParent = host_window_;
          config.dwFlags =
              TDF_ALLOW_DIALOG_CANCELLATION | TDF_SIZE_TO_CONTENT;
          config.pszWindowTitle = L"About";
          config.pszMainInstruction = app_name.c_str();
          config.pszContent = content.c_str();
          TASKDIALOG_BUTTON button{};
          button.nButtonID = IDOK;
          button.pszButtonText = L"OK";
          config.pButtons = &button;
          config.cButtons = 1;
          config.nDefaultButton = IDOK;
          ::TaskDialogIndirect(&config, nullptr, nullptr, nullptr);
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

void AlembicBridges::AttachModalsChannel(flutter::BinaryMessenger* messenger) {
  modals_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "alembic_modals",
          &flutter::StandardMethodCodec::GetInstance());

  modals_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        const flutter::EncodableMap* args =
            std::get_if<flutter::EncodableMap>(call.arguments());

        hide_on_blur_suspend_count_++;
        struct Releaser {
          int* counter;
          ~Releaser() {
            if (*counter > 0) {
              (*counter)--;
            }
          }
        } releaser{&hide_on_blur_suspend_count_};

        if (method == "showInfo") {
          std::wstring title = Widen(ExtractString(args, "title"));
          std::wstring message = Widen(ExtractString(args, "message"));
          std::wstring close_label =
              Widen(ExtractString(args, "closeLabel", "Close"));
          ShowInfoDialog(host_window_, title, message, close_label);
          result->Success();
          return;
        }

        if (method == "showConfirm") {
          std::wstring title = Widen(ExtractString(args, "title"));
          std::wstring description =
              Widen(ExtractString(args, "description"));
          std::wstring confirm_label =
              Widen(ExtractString(args, "confirmLabel", "Continue"));
          std::wstring cancel_label =
              Widen(ExtractString(args, "cancelLabel", "Cancel"));
          bool destructive = ExtractBool(args, "destructive", false);
          int response = ShowConfirmDialog(
              host_window_, title, description, confirm_label, cancel_label,
              destructive);
          result->Success(flutter::EncodableValue(response == IDOK));
          return;
        }

        if (method == "showInput") {
          InputDialogState state;
          state.title = Widen(ExtractString(args, "title"));
          state.description = Widen(ExtractString(args, "description"));
          state.placeholder = Widen(ExtractString(args, "placeholder"));
          state.confirm_label =
              Widen(ExtractString(args, "confirmLabel", "Save"));
          state.cancel_label =
              Widen(ExtractString(args, "cancelLabel", "Cancel"));
          state.value = Widen(ExtractString(args, "initialValue"));
          state.secure = ExtractBool(args, "secure", false);
          state.multiline = ExtractBool(args, "multiline", false);
          bool confirmed = false;
          std::wstring value =
              ShowInputDialog(host_window_, state, &confirmed);
          if (confirmed) {
            result->Success(flutter::EncodableValue(Narrow(value)));
          } else {
            result->Success();
          }
          return;
        }

        if (method == "showCustom") {
          flutter::EncodableMap response;
          response[flutter::EncodableValue("cancelled")] =
              flutter::EncodableValue(true);
          response[flutter::EncodableValue("buttonId")] =
              flutter::EncodableValue();
          response[flutter::EncodableValue("values")] =
              flutter::EncodableValue(flutter::EncodableMap{});
          result->Success(flutter::EncodableValue(response));
          return;
        }

        result->NotImplemented();
      });
}

void AlembicBridges::AttachMenusChannel(flutter::BinaryMessenger* messenger) {
  menus_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "alembic_menus",
          &flutter::StandardMethodCodec::GetInstance());

  menus_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        const flutter::EncodableMap* args =
            std::get_if<flutter::EncodableMap>(call.arguments());

        if (method == "showContextMenu") {
          const flutter::EncodableValue* items_v = FindInMap(args, "items");
          const flutter::EncodableList* items =
              items_v != nullptr
                  ? std::get_if<flutter::EncodableList>(items_v)
                  : nullptr;
          if (items == nullptr || items->empty()) {
            result->Success();
            return;
          }

          HMENU menu = ::CreatePopupMenu();
          std::map<UINT, std::string> id_map;
          UINT command_id = 1;

          std::function<void(HMENU, const flutter::EncodableList&)> build;
          build = [&](HMENU parent, const flutter::EncodableList& list) {
            for (const auto& entry : list) {
              const flutter::EncodableMap* item =
                  std::get_if<flutter::EncodableMap>(&entry);
              if (item == nullptr) {
                continue;
              }
              std::string kind = ExtractString(item, "kind", "command");
              if (kind == "separator") {
                ::AppendMenuW(parent, MF_SEPARATOR, 0, nullptr);
                continue;
              }
              std::string id = ExtractString(item, "id");
              std::wstring label = Widen(ExtractString(item, "label"));
              bool enabled = ExtractBool(item, "enabled", true);
              bool checked = ExtractBool(item, "checked", false);

              UINT flags = MF_STRING;
              if (!enabled) flags |= MF_GRAYED;
              if (checked) flags |= MF_CHECKED;

              if (kind == "submenu") {
                HMENU sub = ::CreatePopupMenu();
                const flutter::EncodableValue* children =
                    FindInMap(item, "children");
                if (children != nullptr) {
                  if (const flutter::EncodableList* child_list =
                          std::get_if<flutter::EncodableList>(children)) {
                    build(sub, *child_list);
                  }
                }
                ::AppendMenuW(parent, flags | MF_POPUP,
                              reinterpret_cast<UINT_PTR>(sub), label.c_str());
                continue;
              }

              id_map[command_id] = id;
              ::AppendMenuW(parent, flags, command_id, label.c_str());
              command_id++;
            }
          };

          build(menu, *items);

          POINT cursor;
          ::GetCursorPos(&cursor);

          const flutter::EncodableValue* origin_v =
              FindInMap(args, "origin");
          if (origin_v != nullptr) {
            if (const flutter::EncodableMap* origin =
                    std::get_if<flutter::EncodableMap>(origin_v)) {
              const flutter::EncodableValue* x_v =
                  FindInMap(origin, "x");
              const flutter::EncodableValue* y_v =
                  FindInMap(origin, "y");
              if (x_v != nullptr && y_v != nullptr) {
                double x = 0, y = 0;
                if (const double* xp = std::get_if<double>(x_v)) x = *xp;
                if (const double* yp = std::get_if<double>(y_v)) y = *yp;
                POINT client{
                    static_cast<LONG>(x), static_cast<LONG>(y)};
                if (host_window_ != nullptr) {
                  ::ClientToScreen(host_window_, &client);
                }
                cursor = client;
              }
            }
          }

          ::SetForegroundWindow(host_window_);
          UINT selected = ::TrackPopupMenuEx(
              menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_LEFTALIGN, cursor.x,
              cursor.y, host_window_, nullptr);
          ::DestroyMenu(menu);

          if (selected == 0) {
            result->Success();
            return;
          }
          auto it = id_map.find(selected);
          if (it != id_map.end()) {
            result->Success(flutter::EncodableValue(it->second));
          } else {
            result->Success();
          }
          return;
        }

        if (method == "setApplicationMenu") {
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

void ShowInfoDialog(
    HWND owner, const std::wstring& title, const std::wstring& description,
    const std::wstring& close_label) {
  TASKDIALOGCONFIG config{};
  config.cbSize = sizeof(config);
  config.hwndParent = owner;
  config.dwFlags =
      TDF_ALLOW_DIALOG_CANCELLATION | TDF_SIZE_TO_CONTENT;
  config.pszWindowTitle = L"Alembic";
  config.pszMainInstruction = title.c_str();
  config.pszContent = description.c_str();
  TASKDIALOG_BUTTON button{};
  button.nButtonID = IDOK;
  button.pszButtonText = close_label.c_str();
  config.pButtons = &button;
  config.cButtons = 1;
  config.nDefaultButton = IDOK;
  ::TaskDialogIndirect(&config, nullptr, nullptr, nullptr);
}

int ShowConfirmDialog(
    HWND owner, const std::wstring& title, const std::wstring& description,
    const std::wstring& confirm_label, const std::wstring& cancel_label,
    bool destructive) {
  TASKDIALOGCONFIG config{};
  config.cbSize = sizeof(config);
  config.hwndParent = owner;
  config.dwFlags =
      TDF_ALLOW_DIALOG_CANCELLATION | TDF_SIZE_TO_CONTENT |
      TDF_USE_COMMAND_LINKS_NO_ICON;
  config.pszWindowTitle = L"Alembic";
  config.pszMainInstruction = title.c_str();
  config.pszContent = description.c_str();
  if (destructive) {
    config.pszMainIcon = TD_WARNING_ICON;
  }
  TASKDIALOG_BUTTON buttons[2]{};
  buttons[0].nButtonID = IDOK;
  buttons[0].pszButtonText = confirm_label.c_str();
  buttons[1].nButtonID = IDCANCEL;
  buttons[1].pszButtonText = cancel_label.c_str();
  config.pButtons = buttons;
  config.cButtons = 2;
  config.nDefaultButton = destructive ? IDCANCEL : IDOK;
  int response = 0;
  if (FAILED(::TaskDialogIndirect(&config, &response, nullptr, nullptr))) {
    return IDCANCEL;
  }
  return response;
}

namespace {

constexpr UINT_PTR kInputControlId = 100;
constexpr UINT_PTR kConfirmButtonId = IDOK;
constexpr UINT_PTR kCancelButtonId = IDCANCEL;

bool gInputClassRegistered = false;

LRESULT CALLBACK InputDialogProc(
    HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  InputDialogState* state = reinterpret_cast<InputDialogState*>(
      ::GetWindowLongPtrW(hwnd, GWLP_USERDATA));

  switch (msg) {
    case WM_CREATE: {
      CREATESTRUCTW* cs = reinterpret_cast<CREATESTRUCTW*>(lparam);
      state = reinterpret_cast<InputDialogState*>(cs->lpCreateParams);
      ::SetWindowLongPtrW(
          hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(state));
      ::SetWindowTextW(hwnd, state->title.c_str());

      DWORD edit_style = WS_CHILD | WS_VISIBLE | WS_BORDER | WS_TABSTOP;
      if (state->multiline) {
        edit_style |= ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL;
      } else {
        edit_style |= ES_AUTOHSCROLL;
      }
      if (state->secure) {
        edit_style |= ES_PASSWORD;
      }
      int edit_height = state->multiline ? 100 : 24;
      HWND edit = ::CreateWindowExW(
          0, L"EDIT", state->value.c_str(), edit_style, 12,
          state->description.empty() ? 12 : 44, 360, edit_height, hwnd,
          reinterpret_cast<HMENU>(kInputControlId),
          reinterpret_cast<HINSTANCE>(
              ::GetWindowLongPtrW(hwnd, GWLP_HINSTANCE)),
          nullptr);
      HFONT font = reinterpret_cast<HFONT>(
          ::GetStockObject(DEFAULT_GUI_FONT));
      ::SendMessageW(edit, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);

      if (!state->description.empty()) {
        HWND label = ::CreateWindowExW(
            0, L"STATIC", state->description.c_str(),
            WS_CHILD | WS_VISIBLE, 12, 12, 360, 24, hwnd, nullptr,
            reinterpret_cast<HINSTANCE>(
                ::GetWindowLongPtrW(hwnd, GWLP_HINSTANCE)),
            nullptr);
        ::SendMessageW(
            label, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);
      }

      int buttons_y =
          (state->description.empty() ? 12 : 44) + edit_height + 12;

      HWND ok = ::CreateWindowExW(
          0, L"BUTTON", state->confirm_label.c_str(),
          WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON, 196,
          buttons_y, 88, 28, hwnd,
          reinterpret_cast<HMENU>(kConfirmButtonId),
          reinterpret_cast<HINSTANCE>(
              ::GetWindowLongPtrW(hwnd, GWLP_HINSTANCE)),
          nullptr);
      ::SendMessageW(ok, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);

      HWND cancel = ::CreateWindowExW(
          0, L"BUTTON", state->cancel_label.c_str(),
          WS_CHILD | WS_VISIBLE | WS_TABSTOP, 96, buttons_y, 88, 28, hwnd,
          reinterpret_cast<HMENU>(kCancelButtonId),
          reinterpret_cast<HINSTANCE>(
              ::GetWindowLongPtrW(hwnd, GWLP_HINSTANCE)),
          nullptr);
      ::SendMessageW(
          cancel, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);

      ::SetFocus(edit);
      return 0;
    }
    case WM_COMMAND: {
      WORD id = LOWORD(wparam);
      if (id == kConfirmButtonId || id == kCancelButtonId) {
        if (state != nullptr && id == kConfirmButtonId) {
          state->confirmed = true;
          HWND edit = ::GetDlgItem(hwnd, kInputControlId);
          if (edit != nullptr) {
            int length = ::GetWindowTextLengthW(edit);
            if (length > 0) {
              std::wstring buffer(length + 1, 0);
              ::GetWindowTextW(edit, buffer.data(), length + 1);
              buffer.resize(length);
              state->value = buffer;
            } else {
              state->value.clear();
            }
          }
        }
        ::DestroyWindow(hwnd);
      }
      return 0;
    }
    case WM_CLOSE:
      ::DestroyWindow(hwnd);
      return 0;
    case WM_DESTROY:
      return 0;
  }
  return ::DefWindowProcW(hwnd, msg, wparam, lparam);
}

void EnsureInputClassRegistered(HINSTANCE instance) {
  if (gInputClassRegistered) {
    return;
  }
  WNDCLASSW wc{};
  wc.lpfnWndProc = InputDialogProc;
  wc.hInstance = instance;
  wc.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  wc.lpszClassName = kInputWindowClass;
  ::RegisterClassW(&wc);
  gInputClassRegistered = true;
}

}  // namespace

std::wstring ShowInputDialog(
    HWND owner, const InputDialogState& initial, bool* out_confirmed) {
  HINSTANCE instance = reinterpret_cast<HINSTANCE>(
      owner != nullptr
          ? ::GetWindowLongPtrW(owner, GWLP_HINSTANCE)
          : ::GetModuleHandleW(nullptr));
  EnsureInputClassRegistered(instance);

  InputDialogState state = initial;

  int width = 396;
  int height = state.multiline ? 220 : 156;
  if (!state.description.empty()) {
    height += 24;
  }

  RECT owner_rect{};
  if (owner != nullptr) {
    ::GetWindowRect(owner, &owner_rect);
  }
  int x = owner_rect.left + (owner_rect.right - owner_rect.left) / 2 - width / 2;
  int y = owner_rect.top + (owner_rect.bottom - owner_rect.top) / 2 - height / 2;

  HWND dialog = ::CreateWindowExW(
      WS_EX_DLGMODALFRAME | WS_EX_TOPMOST, kInputWindowClass, state.title.c_str(),
      WS_POPUP | WS_CAPTION | WS_SYSMENU, x, y, width, height, owner, nullptr,
      instance, &state);
  if (dialog == nullptr) {
    if (out_confirmed != nullptr) {
      *out_confirmed = false;
    }
    return std::wstring();
  }

  ::ShowWindow(dialog, SW_SHOW);
  ::UpdateWindow(dialog);
  ::EnableWindow(owner, FALSE);

  MSG msg;
  while (::IsWindow(dialog) && ::GetMessageW(&msg, nullptr, 0, 0) > 0) {
    if (!::IsDialogMessageW(dialog, &msg)) {
      ::TranslateMessage(&msg);
      ::DispatchMessageW(&msg);
    }
    if (msg.message == WM_QUIT) {
      break;
    }
  }

  ::EnableWindow(owner, TRUE);
  if (owner != nullptr) {
    ::SetForegroundWindow(owner);
  }

  if (out_confirmed != nullptr) {
    *out_confirmed = state.confirmed;
  }
  return state.value;
}
