import 'dart:collection';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image hide Texture;
import 'package:flutter_storm/bridge/errors.dart';
import 'package:flutter_storm/flutter_storm.dart';
import 'package:flutter_storm/bridge/flags.dart';
import 'package:image/image.dart';
import 'package:retro/models/texture_manifest_entry.dart';
import 'package:retro/otr/types/background.dart';
import 'package:retro/otr/types/sequence.dart';
import 'package:retro/models/app_state.dart';
import 'package:retro/models/stage_entry.dart';
import 'package:retro/otr/types/texture.dart';
import 'package:retro/utils/log.dart';
import 'package:retro/utils/tex_utils.dart';
import 'package:tuple/tuple.dart';

class CreateFinishViewModel with ChangeNotifier {
  late BuildContext context;
  AppState currentState = AppState.none;
  HashMap<String, StageEntry> entries = HashMap();
  bool isEphemeralBarExpanded = false;
  bool isGenerating = false;
  int filesProcessed = 0;

  final List<String> blacklistPatterns = [];

  String displayState() {
    bool hasStagedFiles = entries.isNotEmpty;
    return "${currentState.name}${hasStagedFiles && currentState != AppState.changesStaged ? ' (staged)' : ''}";
  }

  void toggleEphemeralBar() {
    isEphemeralBarExpanded = !isEphemeralBarExpanded;
    notifyListeners();
  }

  void reset() {
    currentState = AppState.none;
    filesProcessed = 0;
    entries.clear();
    notifyListeners();
  }

  // Stage Management
  void onAddCustomStageEntry(List<File> files, String path) {
    if (entries.containsKey(path) && entries[path] is CustomStageEntry) {
      (entries[path] as CustomStageEntry).files.addAll(files);
    } else if (entries.containsKey(path)) {
      throw Exception("Cannot add custom stage entry to existing entry");
    } else {
      entries[path] = CustomStageEntry(files);
    }

    currentState = AppState.changesStaged;
    notifyListeners();
  }

  void onAddCustomSequenceEntry(List<Tuple2<File, File>> pairs, String path) {
    if (entries.containsKey(path) && entries[path] is CustomSequencesEntry) {
      (entries[path] as CustomSequencesEntry).pairs.addAll(pairs);
    } else if (entries.containsKey(path)) {
      throw Exception("Cannot add custom sequence entry to existing entry");
    } else {
      entries[path] = CustomSequencesEntry(pairs);
    }

    currentState = AppState.changesStaged;
    notifyListeners();
  }

  onAddCustomTextureEntry(
      HashMap<String, List<Tuple2<File, TextureManifestEntry>>>
          replacementMap) {
    for (var entry in replacementMap.entries) {
      if (entries.containsKey(entry.key) &&
          entries[entry.key] is CustomTexturesEntry) {
        (entries[entry.key] as CustomTexturesEntry).pairs.addAll(entry.value);
      } else if (entries.containsKey(entry.key)) {
        throw Exception("Cannot add custom texture entry to existing entry");
      } else {
        entries[entry.key] = CustomTexturesEntry(entry.value);
      }
    }

    currentState = AppState.changesStaged;
    notifyListeners();
  }

  void onRemoveFile(File file, String path) {
    if (entries.containsKey(path) && entries[path] is CustomStageEntry) {
      (entries[path] as CustomStageEntry).files.remove(file);
    } else if (entries.containsKey(path) &&
        entries[path] is CustomSequencesEntry) {
      (entries[path] as CustomSequencesEntry).pairs.removeWhere((pair) =>
          pair.item1.path == file.path || pair.item2.path == file.path);
    } else if (entries.containsKey(path) &&
        entries[path] is CustomTexturesEntry) {
      (entries[path] as CustomTexturesEntry)
          .pairs
          .removeWhere((pair) => pair.item1.path == file.path);
    } else {
      throw Exception("Cannot remove file from non-existent entry");
    }

    if (entries[path]?.iterables.isEmpty == true) {
      entries.remove(path);
    }

    if (entries.isEmpty) {
      currentState = AppState.none;
    }

    notifyListeners();
  }

  Future<Uint8List?> processJPEG(pair, String textureName) async {
    Uint8List imageData = await pair.item1.readAsBytes();
    Image image = decodeJpg(imageData)!;
    Texture texture = Texture.empty();
    texture.textureType = TextureType.RGBA32bpp;
    texture.setTextureFlags(LOAD_AS_RAW);
    double hByteScale = (image.width / pair.item2.textureWidth) *
        (texture.textureType.pixelMultiplier /
            TextureType.RGBA16bpp.pixelMultiplier);
    double vPixelScale = (image.height / pair.item2.textureHeight);
    texture.setTextureScale(hByteScale, vPixelScale);
    texture.fromPNGImage(image);
    return texture.build();
  }

  Future<Uint8List?> processPNG(
      Tuple2<File, TextureManifestEntry> pair, String textureName) async {
    print("Processing ${pair.item1.path}");
    Command cmd = Command()
      ..decodePngFile(pair.item1.path)
      ..generateTexture(pair.item2);
    return await cmd.getBytesThread();
  }

  void onGenerateOTR(Function onCompletion) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'generated.otr',
    );

    if (outputFile == null) {
      return;
    }

    File mpqOut = File(outputFile);
    if (mpqOut.existsSync()) {
      mpqOut.deleteSync();
    }

    try {
      String? mpqHandle = await SFileCreateArchive(
          outputFile, MPQ_CREATE_SIGNATURE | MPQ_CREATE_ARCHIVE_V2, 12288);

      isGenerating = true;
      notifyListeners();

      for (var entry in entries.entries) {
        if (entry.value is CustomStageEntry) {
          for (var file in (entry.value as CustomStageEntry).files) {
            String fileName = "${entry.key}/${file.uri.pathSegments.last}";
            String? fileHandle = await SFileCreateFile(
                mpqHandle!, fileName, file.lengthSync(), MPQ_FILE_COMPRESS);
            await SFileWriteFile(fileHandle!, file.readAsBytesSync(),
                file.lengthSync(), MPQ_COMPRESSION_ZLIB);
            await SFileFinishFile(fileHandle);
          }
        } else if (entry.value is CustomSequencesEntry) {
          for (var pair in (entry.value as CustomSequencesEntry).pairs) {
            Sequence sequence = Sequence.fromSeqFile(pair);
            String fileName = "${entry.key}/${sequence.path}";
            Uint8List data = sequence.build();
            String? fileHandle = await SFileCreateFile(
                mpqHandle!, fileName, data.length, MPQ_FILE_COMPRESS);
            await SFileWriteFile(
                fileHandle!, data, data.length, MPQ_COMPRESSION_ZLIB);
            await SFileFinishFile(fileHandle);
          }
        } else if (entry.value is CustomTexturesEntry) {
          for (var pair in (entry.value as CustomTexturesEntry).pairs) {
            String textureName =
                pair.item1.path.split("/").last.split(".").first;
            Uint8List? data =
                await (pair.item2.textureType == TextureType.JPEG32bpp
                    ? processJPEG
                    : processPNG)(pair, textureName);

            if (data != null) {
              String fileName = "${entry.key}/$textureName";
              String? fileHandle = await SFileCreateFile(
                  mpqHandle!, fileName, data.length, MPQ_FILE_COMPRESS);
              await SFileWriteFile(
                  fileHandle!, data, data.length, MPQ_COMPRESSION_ZLIB);
              await SFileFinishFile(fileHandle);
            } else {
              presentErrorSnackbar("Failed to process $textureName");
            }
          }
        }

        filesProcessed++;
        notifyListeners();
      }

      await SFileCloseArchive(mpqHandle!);
      isGenerating = false;
      notifyListeners();

      reset();
      onCompletion();
    } on StormException catch (e) {
      log(e.message);
    }
  }

  void presentErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.red,
      ),
    );
  }
}
