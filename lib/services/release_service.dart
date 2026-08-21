import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../models/release.dart';
import 'executable_service.dart';
import 'log_service.dart';
import 'settings_service.dart';

class ReleaseService extends GetxService {
  ReleaseService(this.settings, this.logs, this.executables, this.client);

  final SettingsService settings;
  final LogService logs;
  final ExecutableService executables;
  final dio.Dio client;
  final releases = <BotRelease>[].obs;
  final downloading = false.obs;
  final downloadProgress = 0.0.obs;
  final downloadLabel = ''.obs;
  final error = RxnString();

  Future<List<BotRelease>> fetchReleases() async {
    error.value = null;
    final uri = Uri.https(
      'api.github.com',
      '/repos/${SettingsService.repositoryOwner}/${SettingsService.repositoryName}/releases',
      {'per_page': '1'},
    );
    logs.info('正在获取 GitHub 发布列表', {'url': '$uri'});
    late final dio.Response<dynamic> response;
    try {
      response = await client.getUri<dynamic>(
        uri,
        options: dio.Options(
          headers: const {'Accept': 'application/vnd.github+json'},
          validateStatus: (_) => true,
        ),
      );
    } on dio.DioException catch (exception) {
      logs.error('GitHub API 请求失败', {'error': '$exception'});
      throw HttpException(_dioErrorMessage(exception, '连接 GitHub API'));
    }
    final statusCode = response.statusCode ?? 0;
    logs.info('GitHub API 已响应', {'status_code': statusCode});
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub API 返回 $statusCode：${_errorMessage(response.data)}',
      );
    }
    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (decoded is! List) throw const FormatException('GitHub release 响应格式错误');
    final result = decoded.whereType<Map>().map(_parseRelease).take(1).toList();
    releases.assignAll(result);
    logs.info('发布列表加载完成', {'release_count': result.length});
    return result;
  }

  Future<String> download(
    BotRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final asset = _selectAsset(release);
    if (asset == null) {
      throw StateError('当前平台不支持此版本：仅支持架构匹配的 tar.gz 发布包');
    }
    logs.info('已选择发布文件', {'version': release.tagName, 'asset': asset.name});
    final root = Directory(
      path.join(settings.dataDirectory.value, 'releases', release.tagName),
    );
    downloading.value = true;
    downloadProgress.value = 0;
    downloadLabel.value = asset.name;
    try {
      await root.create(recursive: true);
      final destination = File(path.join(root.path, asset.name));
      late final dio.Response<dio.ResponseBody> response;
      try {
        response = await client.get<dio.ResponseBody>(
          asset.downloadUrl,
          options: dio.Options(
            receiveTimeout: const Duration(minutes: 5),
            responseType: dio.ResponseType.stream,
            headers: const {HttpHeaders.acceptEncodingHeader: 'identity'},
            validateStatus: (_) => true,
          ),
        );
      } on dio.DioException catch (exception) {
        throw HttpException(_dioErrorMessage(exception, '下载连接'));
      }
      if (response.statusCode != 200) {
        await response.data?.stream.drain<void>();
        throw HttpException(
          '下载失败（HTTP ${response.statusCode ?? 0}）：${response.statusMessage ?? '未知错误'}',
        );
      }
      final body = response.data;
      if (body == null) throw const HttpException('下载响应没有文件内容');
      await _writeDownload(
        body,
        destination,
        asset.size,
        onProgress: onProgress,
      );
      downloadProgress.value = 1;
      onProgress?.call(1);
      logs.info('发布文件下载完成', {
        'path': destination.path,
        'bytes': await destination.length(),
      });
      final executable = await _prepareAsset(destination, root);
      settings.selectedVersion.value = release.tagName;
      settings.executablePath.value = executable;
      await settings.alignConfigPathWithExecutable();
      await settings.persist();
      logs.info('内核安装完成', {'executable': executable});
      return executable;
    } catch (exception) {
      logs.error('内核安装失败', {'error': '$exception'});
      rethrow;
    } finally {
      downloading.value = false;
      downloadLabel.value = '';
    }
  }

  Future<void> _writeDownload(
    dio.ResponseBody body,
    File destination,
    int assetSize, {
    void Function(double progress)? onProgress,
  }) async {
    final partial = File('${destination.path}.part');
    if (await partial.exists()) await partial.delete();
    final output = await partial.open(mode: FileMode.write);
    final expected = body.contentLength > 0 ? body.contentLength : assetSize;
    final updateTimer = Stopwatch()..start();
    var received = 0;
    var hasReported = false;
    try {
      await for (final chunk in body.stream) {
        await output.writeFrom(chunk);
        received += chunk.length;
        final shouldReport =
            !hasReported ||
            updateTimer.elapsed >= const Duration(milliseconds: 50) ||
            (expected > 0 && received >= expected);
        if (shouldReport) {
          _reportDownloadProgress(received, expected, onProgress);
          hasReported = true;
          updateTimer.reset();
          await Future<void>.delayed(Duration.zero);
        }
      }
      await output.flush();
      _reportDownloadProgress(received, expected, onProgress);
    } catch (_) {
      await output.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    await output.close();
    if (await destination.exists()) await destination.delete();
    await partial.rename(destination.path);
  }

  void _reportDownloadProgress(
    int received,
    int expected,
    void Function(double progress)? onProgress,
  ) {
    if (expected <= 0) return;
    final progress = (received / expected).clamp(0.0, 1.0).toDouble();
    downloadProgress.value = progress;
    onProgress?.call(progress);
  }

  ReleaseAsset? _selectAsset(BotRelease release) {
    final architecture = _architecture();
    final operatingSystem = Platform.isAndroid
        ? 'android'
        : Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
        ? 'darwin'
        : 'linux';
    final platformAssets = release.assets.where((asset) {
      final name = asset.name.toLowerCase();
      return name.contains(operatingSystem) && _isTarGz(asset);
    }).toList();
    final architectureNames = architecture == 'amd64'
        ? const ['amd64', 'x86_64']
        : [architecture];
    final architectureAssets = platformAssets.where((asset) {
      final name = asset.name.toLowerCase();
      return architectureNames.any(name.contains);
    }).toList();

    return architectureAssets.isEmpty ? null : architectureAssets.first;
  }

  bool _isTarGz(ReleaseAsset asset) {
    return asset.name.toLowerCase().endsWith('.tar.gz');
  }

  Future<String> _prepareAsset(File downloaded, Directory root) async {
    final name = downloaded.path.toLowerCase();
    if (!name.endsWith('.tar.gz')) {
      throw StateError('当前版本不支持：仅支持 tar.gz 发布包');
    }
    final bytes = await downloaded.readAsBytes();
    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    String? executable;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final output = File(path.join(root.path, entry.name));
      await output.parent.create(recursive: true);
      await output.writeAsBytes(entry.content as List<int>, flush: true);
      if (executable == null && _isKernelExecutable(output.path)) {
        executable = output.path;
      }
    }
    if (executable == null) {
      throw StateError('发布包中没有找到可执行文件');
    }
    await executables.prepare(executable);
    return executable;
  }

  bool _isKernelExecutable(String filePath) {
    final fileName = path.basename(filePath).toLowerCase();
    return fileName == 'atri-bot' || fileName == 'atri-bot.exe';
  }

  String _architecture() {
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) {
      return 'arm64';
    }
    if (version.contains('x64') || version.contains('amd64')) return 'amd64';
    if (!Platform.isAndroid) {
      try {
        final result = Process.runSync('uname', ['-m']);
        final machine = '${result.stdout}'.toLowerCase();
        if (machine.contains('arm64') || machine.contains('aarch64')) {
          return 'arm64';
        }
      } catch (_) {}
    }
    return 'arm64';
  }

  BotRelease _parseRelease(Map release) {
    final assets = (release['assets'] as List? ?? const [])
        .whereType<Map>()
        .map((asset) {
          return ReleaseAsset(
            name: '${asset['name']}',
            downloadUrl: '${asset['browser_download_url']}',
            size: asset['size'] is int ? asset['size'] as int : 0,
          );
        })
        .toList();
    return BotRelease(
      tagName: '${release['tag_name']}',
      title: '${release['name'] ?? release['tag_name']}',
      publishedAt: DateTime.tryParse('${release['published_at']}'),
      prerelease: release['prerelease'] == true,
      assets: assets,
    );
  }

  String _errorMessage(dynamic body) {
    try {
      final decoded = body is String ? jsonDecode(body) : body;
      if (decoded is Map && decoded['message'] != null) {
        return '${decoded['message']}';
      }
    } catch (_) {}
    return '请检查仓库地址和网络连接';
  }

  String _dioErrorMessage(dio.DioException exception, String action) {
    switch (exception.type) {
      case dio.DioExceptionType.connectionTimeout:
      case dio.DioExceptionType.sendTimeout:
      case dio.DioExceptionType.receiveTimeout:
        return '$action超时，请检查网络或系统代理设置';
      case dio.DioExceptionType.connectionError:
        return '$action失败，请检查网络或系统代理设置：${exception.message}';
      case dio.DioExceptionType.cancel:
        return '$action已取消';
      default:
        return '$action失败：${exception.message}';
    }
  }
}
