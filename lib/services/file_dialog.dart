import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

String? showOpenJsonDialog() {
  if (!Platform.isWindows) return null;
  final fileBuffer = wsalloc(MAX_PATH);
  final filter = 'JSON 文件\u0000*.json\u0000所有文件\u0000*.*\u0000\u0000'.toPwstr();
  final title = '导入学习内容'.toPwstr();
  final dialog = calloc<OPENFILENAME>();
  try {
    dialog.ref
      ..lStructSize = sizeOf<OPENFILENAME>()
      ..hwndOwner = GetActiveWindow()
      ..lpstrFilter = filter
      ..nFilterIndex = 1
      ..lpstrFile = fileBuffer
      ..nMaxFile = MAX_PATH
      ..lpstrTitle = title
      ..Flags = OPEN_FILENAME_FLAGS(
        OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR,
      );
    if (!GetOpenFileName(dialog)) return null;
    return fileBuffer.toDartString();
  } finally {
    calloc.free(dialog);
    free(fileBuffer);
    free(filter);
    free(title);
  }
}

String? showSaveJsonDialog({required String suggestedName}) {
  if (!Platform.isWindows) return null;
  final fileBuffer = wsalloc(MAX_PATH)..setString(suggestedName);
  final filter = 'JSON 文件\u0000*.json\u0000所有文件\u0000*.*\u0000\u0000'.toPwstr();
  final title = '导出学习内容'.toPwstr();
  final extension = 'json'.toPwstr();
  final dialog = calloc<OPENFILENAME>();
  try {
    dialog.ref
      ..lStructSize = sizeOf<OPENFILENAME>()
      ..hwndOwner = GetActiveWindow()
      ..lpstrFilter = filter
      ..nFilterIndex = 1
      ..lpstrFile = fileBuffer
      ..nMaxFile = MAX_PATH
      ..lpstrDefExt = extension
      ..lpstrTitle = title
      ..Flags = OPEN_FILENAME_FLAGS(
        OFN_EXPLORER |
            OFN_OVERWRITEPROMPT |
            OFN_PATHMUSTEXIST |
            OFN_NOCHANGEDIR,
      );
    if (!GetSaveFileName(dialog)) return null;
    return fileBuffer.toDartString();
  } finally {
    calloc.free(dialog);
    free(fileBuffer);
    free(filter);
    free(title);
    free(extension);
  }
}
