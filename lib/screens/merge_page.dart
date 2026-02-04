import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/ffmpeg_service.dart';
import '../utils/file_helper.dart';
import '../utils/permission_helper.dart';
import '../widgets/video_list_item.dart';
import '../widgets/progress_overlay.dart';

/// 视频拼接页面
class MergePage extends StatefulWidget {
  const MergePage({super.key});

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  // 选中的视频列表（可拖拽排序）
  final List<VideoInfo> _videos = [];
  
  // 处理状态
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _errorMessage;
  String? _compatibilityWarning;
  
  // 输出文件路径
  String? _outputPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("视频拼接"),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        actions: [
          if (_videos.isNotEmpty && _outputPath == null)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline),
              label: const Text("清空"),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 主内容
          Column(
            children: [
              // 视频列表（可拖拽排序）
              Expanded(
                child: _videos.isEmpty
                    ? _buildEmptyState()
                    : _buildVideoList(),
              ),
              
              // 底部操作区
              _buildBottomBar(),
            ],
          ),
          
          // 处理进度遮罩
          if (_isProcessing)
            ProgressOverlay(
              progress: _progress,
              message: "正在拼接视频...",
            ),
        ],
      ),
      // 悬浮添加按钮
      floatingActionButton: _videos.isNotEmpty && _outputPath == null
          ? FloatingActionButton.extended(
              onPressed: _addVideos,
              icon: const Icon(Icons.add),
              label: const Text("添加视频"),
            )
          : null,
    );
  }
  
  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.video_library_outlined,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "添加要拼接的视频",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "视频将按添加顺序拼接\n支持拖拽调整顺序",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _addVideos,
            icon: const Icon(Icons.add),
            label: const Text("选择视频"),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _videos.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _videos.removeAt(oldIndex);
          _videos.insert(newIndex, item);
          // 重新检查兼容性
          _checkCompatibility();
        });
      },
      itemBuilder: (context, index) {
        final video = _videos[index];
        return VideoListItem(
          key: ValueKey(video.path),
          video: video,
          index: index + 1,
          onRemove: () => _removeVideo(index),
        );
      },
    );
  }
  
  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 兼容性警告
            if (_compatibilityWarning != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _compatibilityWarning!,
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 错误信息
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _errorMessage = null),
                      color: colorScheme.onErrorContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 成功后的操作
            if (_outputPath != null) ...[
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 48,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "拼接完成！",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareOutput,
                              icon: const Icon(Icons.share),
                              label: const Text("分享"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _clearAll,
                              icon: const Icon(Icons.add),
                              label: const Text("继续拼接"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_videos.length >= 2) ...[
              // 视频数量统计
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "已选择 ${_videos.length} 个视频，共 ${_getTotalDuration()}",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // 开始拼接按钮
              FilledButton.icon(
                onPressed: _canProcess ? _startMerge : null,
                icon: const Icon(Icons.merge_rounded),
                label: const Text("开始拼接"),
              ),
            ] else if (_videos.length == 1) ...[
              Center(
                child: Text(
                  "请至少选择2个视频",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  bool get _canProcess {
    return _videos.length >= 2 && 
           _compatibilityWarning == null &&
           !_isProcessing &&
           _outputPath == null;
  }
  
  String _getTotalDuration() {
    int totalMs = 0;
    for (final video in _videos) {
      totalMs += video.durationMs;
    }
    return VideoInfo(
      path: '',
      durationMs: totalMs,
      width: 0,
      height: 0,
      codec: '',
      bitrate: 0,
      fileSize: 0,
    ).formattedDuration;
  }
  
  Future<void> _addVideos() async {
    // 请求权限
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage = "需要存储权限才能选择视频";
      });
      return;
    }
    
    // 选择视频
    final paths = await FileHelper.pickMultipleVideos();
    if (paths.isEmpty) return;
    
    // 获取视频信息
    for (final path in paths) {
      // 检查是否已添加
      if (_videos.any((v) => v.path == path)) continue;
      
      final info = await FFmpegService.getVideoInfo(path);
      if (info != null) {
        setState(() {
          _videos.add(info);
        });
      }
    }
    
    // 检查兼容性
    await _checkCompatibility();
    
    setState(() {
      _outputPath = null;
    });
  }
  
  void _removeVideo(int index) {
    setState(() {
      _videos.removeAt(index);
    });
    _checkCompatibility();
  }
  
  void _clearAll() {
    setState(() {
      _videos.clear();
      _errorMessage = null;
      _compatibilityWarning = null;
      _outputPath = null;
    });
  }
  
  Future<void> _checkCompatibility() async {
    if (_videos.length < 2) {
      setState(() {
        _compatibilityWarning = null;
      });
      return;
    }
    
    final paths = _videos.map((v) => v.path).toList();
    final warning = await FFmpegService.checkMergeCompatibility(paths);
    
    setState(() {
      _compatibilityWarning = warning;
    });
  }
  
  Future<void> _startMerge() async {
    if (_videos.length < 2) return;
    
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _errorMessage = null;
    });
    
    final paths = _videos.map((v) => v.path).toList();
    
    final result = await FFmpegService.mergeVideos(
      inputPaths: paths,
      onProgress: (progress) {
        setState(() {
          _progress = progress;
        });
      },
    );
    
    setState(() {
      _isProcessing = false;
      if (result.success) {
        _outputPath = result.outputPath;
      } else {
        _errorMessage = result.errorMessage ?? "拼接失败，请重试";
      }
    });
  }
  
  Future<void> _shareOutput() async {
    if (_outputPath == null) return;
    
    try {
      await Share.shareXFiles(
        [XFile(_outputPath!)],
        text: "来自无损视频切割器",
      );
    } catch (e) {
      setState(() {
        _errorMessage = "分享失败: $e";
      });
    }
  }
}
