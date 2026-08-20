import 'dart:convert';
import 'dart:ffi';
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
      {'per_page': '30'},
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
    final result = decoded.whereType<Map>().map(_parseRelease).where((release) {
      try {
        return release.version.compareTo(
              SemVersion.parse(SettingsService.minimumVersion),
            ) >=
            0;
      } catch (_) {
        return false;
      }
    }).toList()..sort((a, b) => b.version.compareTo(a.version));
    releases.assignAll(result);
    logs.info('发布列表加载完成', {'release_count': result.length});
    return result;
  }

  Future<String> download(
    BotRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final operatingSystem = _operatingSystem();
    final architecture = _architecture();
    final asset = _selectAsset(release, operatingSystem, architecture);
    if (asset == null) {
      final availableAssets = release.assets
          .map((asset) => asset.name)
          .join('、');
      throw StateError(
        '没有找到适合当前设备的发布文件（$operatingSystem / $architecture）。'
        '此版本提供：${availableAssets.isEmpty ? '无发布文件' : availableAssets}',
      );
    }
    logs.info('已选择发布文件', {
      'version': release.tagName,
      'platform': operatingSystem,
      'architecture': architecture,
      'asset': asset.name,
    });
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

  ReleaseAsset? _selectAsset(
    BotRelease release,
    String operatingSystem,
    String architecture,
  ) {
    final operatingSystemAliases = switch (operatingSystem) {
      'darwin' => const ['darwin', 'macos'],
      _ => [operatingSystem],
    };
    final architectureAliases = switch (architecture) {
      'x86_64' => const ['x86_64', 'amd64', 'x64'],
      'arm64' => const ['arm64', 'aarch64'],
      'i386' => const ['i386', '386', 'ia32'],
      _ => [architecture],
    };
    return release.assets.firstWhereOrNull((asset) {
      final name = asset.name.toLowerCase();
      return operatingSystemAliases.any(
            (alias) => _hasAssetToken(name, alias),
          ) &&
          architectureAliases.any((alias) => _hasAssetToken(name, alias));
    });
  }

  bool _hasAssetToken(String assetName, String token) {
    return RegExp(
      '(^|[^a-z0-9])${RegExp.escape(token)}([^a-z0-9]|\$)',
    ).hasMatch(assetName);
  }

  Future<String> _prepareAsset(File downloaded, Directory root) async {
    final name = downloaded.path.toLowerCase();
    if (!name.endsWith('.zip') &&
        !name.endsWith('.tar.gz') &&
        !name.endsWith('.tgz')) {
      if (!path
          .basename(downloaded.path)
          .toLowerCase()
          .startsWith('atri-bot')) {
        throw StateError(
          '下载的文件不是 atri-bot 内核：${path.basename(downloaded.path)}',
        );
      }
      await executables.prepare(downloaded.path);
      return downloaded.path;
    }
    final bytes = await downloaded.readAsBytes();
    final archive = name.endsWith('.zip')
        ? ZipDecoder().decodeBytes(bytes)
        : TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
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

  String _operatingSystem() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    throw UnsupportedError('当前操作系统不支持下载 atri-bot 内核');
  }

  String _architecture() {
    final abi = Abi.current().toString().toLowerCase();
    if (abi.endsWith('_x64')) return 'x86_64';
    if (abi.endsWith('_arm64')) return 'arm64';
    if (abi.endsWith('_ia32')) return 'i386';
    if (abi.endsWith('_arm')) return 'arm';
    if (abi.endsWith('_riscv64')) return 'riscv64';
    if (abi.endsWith('_riscv32')) return 'riscv32';
    throw UnsupportedError('无法识别当前设备架构：$abi');
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
