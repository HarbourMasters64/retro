import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_storm/flutter_storm.dart';
import 'package:flutter_storm/flutter_storm_defines.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as path;
import 'package:retro/models/texture_manifest_entry.dart';
import 'package:retro/otr/resource.dart';
import 'package:retro/otr/resource_type.dart';
import 'package:retro/otr/types/background.dart';
import 'package:retro/otr/types/texture.dart';
import 'package:retro/utils/log.dart';
import 'package:retro/utils/path.dart' as p;
import 'package:tuple/tuple.dart';

enum CreateReplacementTexturesStep { question, selectFolder, selectOTR }

typedef ProcessedFilesInFolder = List<Tuple2<File, TextureManifestEntry>>;

class CreateReplaceTexturesViewModel extends ChangeNotifier {
  CreateReplacementTexturesStep currentStep =
      CreateReplacementTexturesStep.question;
  String? selectedFolderPath;
  List<String> selectedOTRPaths = [];
  bool isProcessing = false;
  HashMap<String, dynamic> processedFiles = HashMap();

  String fontData = 'assets/FontData';
  String fontTLUT = 'assets/FontTLUT[%d].png';
  String fontTextureName = 'textures/font/sGfxPrintFontData';

  reset() {
    currentStep = CreateReplacementTexturesStep.question;
    selectedFolderPath = null;
    selectedOTRPaths = [];
    isProcessing = false;
    processedFiles = HashMap();
    notifyListeners();
  }

  onUpdateStep(CreateReplacementTexturesStep step) {
    currentStep = step;
    notifyListeners();
  }

  onSelectFolder() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      selectedFolderPath = p.normalize(selectedDirectory);
      isProcessing = true;
      notifyListeners();

      final processedFiles = await compute(processFolder, selectedFolderPath!);
      if (processedFiles == null) {
        // TODO: Handle this error.
        log('Error processing folder: $selectedFolderPath');
      } else {
        this.processedFiles = processedFiles;
      }

      isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> onSelectOTR() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['otr'],
    );
    if (result != null && result.files.isNotEmpty) {
      // save paths filtering out nulls
      selectedOTRPaths = result.paths.whereType<String>().toList();
      if (selectedOTRPaths.isEmpty) {
        // TODO: Handle this error
        return;
      }

      notifyListeners();
    }
  }

  Future<void> onProcessOTR() async {
    if (selectedOTRPaths.isEmpty) {
      // TODO: Handle this error
      return;
    }
    final otrNameForOutputDirectory =
        selectedOTRPaths[0].split(Platform.pathSeparator).last.split('.').first;

    // Ask for output folder
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      return;
    }

    isProcessing = true;
    notifyListeners();

    // Process OTR
    final otrFiles =
        await compute(processOTR, Tuple2(selectedOTRPaths, selectedDirectory));
    if (otrFiles == null) {
      // TODO: Handle this error.
    } else {
      processedFiles = otrFiles;
    }

    // Dump font
    await dumpFont('$selectedDirectory/$otrNameForOutputDirectory',
        (TextureManifestEntry entry) {
      processedFiles[fontTextureName] = entry;
    });

    // Write out the processed files to disk
    String? manifestOutputPath =
        '$selectedDirectory/$otrNameForOutputDirectory/manifest.json';
    final manifestFile = File(manifestOutputPath);
    await manifestFile.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final dataToWrite = encoder.convert(processedFiles);
    await manifestFile.writeAsString(dataToWrite);

    isProcessing = false;
    notifyListeners();
  }

  Future<void> dumpFont(String outputPath, Function onProcessed) async {
    final fontImage = Image(width: 16 * 4, height: 256, numChannels: 4);

    final tex = Texture.empty();
    final data = await rootBundle.load(fontData);
    tex.open(data.buffer.asUint8List());
    for (var id = 0; id < 4; id++) {
      final tlut = Texture.empty();
      tex.tlut = tlut;
      tlut.textureType = TextureType.RGBA32bpp;
      final data =
          await rootBundle.load(fontTLUT.replaceAll('%d', id.toString()));
      final pngImage = decodePng(data.buffer.asUint8List())!;
      tlut.fromRawImage(pngImage);
      compositeImage(
        fontImage,
        decodePng(await tex.toPNGBytes())!,
        dstX: id * 16,
        dstY: 0,
      );
    }

    final textureFile = File(path.join(outputPath, '$fontTextureName.png'));
    final pngBytes = encodePng(fontImage);
    await textureFile.create(recursive: true);
    await textureFile.writeAsBytes(pngBytes);
    final hash = sha256.convert(pngBytes).toString();
    onProcessed(
      TextureManifestEntry(
        hash,
        tex.textureType,
        fontImage.width,
        fontImage.height,
      ),
    );
  }
}

Future<HashMap<String, ProcessedFilesInFolder>?> processFolder(
  String folderPath,
) async {
  final processedFiles = HashMap<String, ProcessedFilesInFolder>();

  // search for and load manifest.json
  final manifestPath = p.normalize('$folderPath/manifest.json');
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    return null;
  }

  final manifestContents = await manifestFile.readAsString();
  Map<String, dynamic> manifest = jsonDecode(manifestContents);

  // find all images in folder
  final supportedExtensions = <String>['.png', '.jpeg', '.jpg'];
  final files = Directory(folderPath).listSync(recursive: true);
  final texFiles = files
      .where((file) => supportedExtensions.contains(path.extension(file.path)))
      .toList();

  // for each tex image, check if it's in the manifest
  for (final rawFile in texFiles) {
    final texFile = File(p.normalize(rawFile.path));
    final texPathRelativeToFolder =
        p.normalize(texFile.path.split('$folderPath/').last.split('.').first);
    if (manifest.containsKey(texPathRelativeToFolder)) {
      final manifestEntry =
          TextureManifestEntry.fromJson(manifest[texPathRelativeToFolder]);
      // if it is, check if the file has changed
      final texFileBytes = await texFile.readAsBytes();
      final texFileHash = sha256.convert(texFileBytes).toString();
      if (manifestEntry.hash != texFileHash) {
        // if it has, add it to the processed files list
        log('Found file with changed hash: $texPathRelativeToFolder');

        final pathWithoutFilename = p.normalize(
          texPathRelativeToFolder
              .split('/')
              .sublist(0, texPathRelativeToFolder.split('/').length - 1)
              .join('/'),
        );
        if (processedFiles.containsKey(pathWithoutFilename)) {
          processedFiles[pathWithoutFilename]!
              .add(Tuple2(texFile, manifestEntry));
        } else {
          processedFiles[pathWithoutFilename] = [
            Tuple2(texFile, manifestEntry)
          ];
        }
      }
    } else {
      log('Found file not present in manifest: $texPathRelativeToFolder');
    }
  }

  return processedFiles;
}

Future<HashMap<String, TextureManifestEntry>?> processOTR(
  Tuple2<List<String>, String> params,
) async {
  try {
    var fileFound = false;
    final processedFiles = HashMap<String, TextureManifestEntry>();

    // just use the first otr in the list for the  directory name
    final otrNameForOutputDirectory =
        params.item1[0].split(Platform.pathSeparator).last.split('.').first;

    // if folder we'll export to exists, delete it
    final dir = Directory('${params.item2}/$otrNameForOutputDirectory');
    if (dir.existsSync()) {
      log('Deleting existing folder: ${params.item2}/$otrNameForOutputDirectory');
      await dir.delete(recursive: true);
    }

    for (final otrPath in params.item1) {
      log('Processing OTR: $otrPath');
      MPQArchive? mpqArchive = MPQArchive.open(otrPath, 0, MPQ_OPEN_READ_ONLY);

      final hFind = FileFindResource();
      mpqArchive.findFirstFile('*', hFind, null);

      // process first file
      final fileName = hFind.fileName();
      await processFile(fileName!, mpqArchive,
          '${params.item2}/$otrNameForOutputDirectory/$fileName',
          (TextureManifestEntry entry) {
        processedFiles[fileName] = entry;
      });

      do {
        try {
          mpqArchive.findNextFile(hFind);
          fileFound = true;

          final fileName = hFind.fileName();
          if (fileName == null ||
              fileName == SIGNATURE_NAME ||
              fileName == LISTFILE_NAME ||
              fileName == ATTRIBUTES_NAME) {
            continue;
          }

          log('Processing file: $fileName');
          final processed = await processFile(fileName, mpqArchive,
              '${params.item2}/$otrNameForOutputDirectory/$fileName',
              (TextureManifestEntry entry) {
            processedFiles[fileName] = entry;
          });

          if (!processed) {
            continue;
          }
        } on StormLibException catch (e) {
          log('Got a StormLib error: ${e.message}');
          fileFound = false;
        } on Exception catch (e) {
          log('Got an error: $e');
          fileFound = false;
        }
      } while (fileFound);

      hFind.close();
      mpqArchive.close();
    }

    return processedFiles;
  } on StormLibException catch (e) {
    log('Failed to find next file: ${e.message}');
    return null;
  }
}

Future<bool> processFile(
  String fileName,
  MPQArchive mpqArchive,
  String outputPath,
  Function onProcessed,
) async {
  try {
    final file = mpqArchive.openFileEx(fileName, 0);
    final fileSize = file.size();
    final fileData = file.read(fileSize);

    final resource = Resource.empty();
    resource.rawLoad = true;
    resource.open(fileData);

    if (![ResourceType.texture, ResourceType.sohBackground]
        .contains(resource.resourceType)) {
      return false;
    }

    String? hash;

    switch (resource.resourceType) {
      case ResourceType.texture:
        final texture = Texture.empty();
        texture.open(fileData);

        final pngBytes = await texture.toPNGBytes();
        final textureFile = File('$outputPath.png');
        await textureFile.create(recursive: true);
        await textureFile.writeAsBytes(pngBytes);
        final textureBytes = await textureFile.readAsBytes();
        hash = sha256.convert(textureBytes).toString();
        onProcessed(
          TextureManifestEntry(
            hash,
            texture.textureType,
            texture.width,
            texture.height,
          ),
        );
        break;
      case ResourceType.sohBackground:
        final background = Background.empty();
        background.open(fileData);

        log('Found JPEG background: $fileName!');
        final textureFile = File('$outputPath.jpg');
        final image = decodeJpg(background.texData)!;
        await textureFile.create(recursive: true);
        await textureFile.writeAsBytes(background.texData);
        hash = sha256.convert(background.texData).toString();
        onProcessed(
          TextureManifestEntry(
            hash,
            TextureType.JPEG32bpp,
            image.width,
            image.height,
          ),
        );
        break;
      default:
        return false;
    }

    return true;
  } on StormLibException catch (e) {
    log('Failed to find next file: ${e.message}');
    return false;
  } catch (e) {
    // Not a texture
    print(e);
    return false;
  }
}
