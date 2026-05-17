#ifndef RUNNER_ALEMBIC_BRIDGES_H_
#define RUNNER_ALEMBIC_BRIDGES_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

class AlembicBridges {
 public:
  static AlembicBridges& Instance();

  void Attach(flutter::BinaryMessenger* messenger, HWND host_window);

  void Detach();

  void OnThemeChanged(bool is_dark);

  bool IsHideOnBlurSuspended() const;

 private:
  AlembicBridges() = default;
  AlembicBridges(const AlembicBridges&) = delete;
  AlembicBridges& operator=(const AlembicBridges&) = delete;

  void AttachWindowChannel(flutter::BinaryMessenger* messenger);
  void AttachModalsChannel(flutter::BinaryMessenger* messenger);
  void AttachMenusChannel(flutter::BinaryMessenger* messenger);

  HWND host_window_ = nullptr;
  int hide_on_blur_suspend_count_ = 0;
  std::vector<std::pair<std::string, flutter::EncodableValue>> theme_tokens_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      modals_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      menus_channel_;
};

#endif  // RUNNER_ALEMBIC_BRIDGES_H_
