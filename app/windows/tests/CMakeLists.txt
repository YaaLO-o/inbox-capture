add_executable(inbox_native_tests
  "platform_channels_test.cpp"
  "../runner/platform_channels.cpp"
  "../runner/system_tray.cpp"
  "../runner/utils.cpp"
  "../runner/win32_window.cpp"
)
apply_standard_settings(inbox_native_tests)
target_compile_options(inbox_native_tests PRIVATE /utf-8)
target_compile_definitions(inbox_native_tests PRIVATE NOMINMAX
  FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}
  FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}
  FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH})
target_include_directories(inbox_native_tests PRIVATE "../runner")
target_link_libraries(inbox_native_tests PRIVATE flutter flutter_wrapper_app
  gdiplus ole32 shell32 dwmapi)
add_custom_command(TARGET inbox_native_tests POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" "$<TARGET_FILE_DIR:inbox_native_tests>")
add_dependencies(inbox_native_tests flutter_assemble)
add_test(NAME inbox_native_tests COMMAND inbox_native_tests)
