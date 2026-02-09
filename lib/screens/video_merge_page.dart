import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/ffmpeg_service.dart';

/// 视频合并页面
class VideoMergePage extends StatefulWidget {
  const VideoMergePage({super.key});

  @override
  State<VideoMergePage> createState() => _VideoMergePageState();
}

class _VideoMergePageState extends State<VideoMergePage> {
  // 已选择的视频文件列表
  final List<VideoFile> _videoFiles = [];
  
  // 处理状态
  bool _isProcessing = false;
  String _statusMessage = '';
  
  // 输出文件路径
  String? _outputPath;

  /// 添加视频文件
  Future<void> _addVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            // 获取视频时长
            final duration = await FFmpegService.getVideoDuration(file.path!);
            
            setState(() {
              _videoFiles.add(VideoFile(
                path: file.path!,
                name: file.name,
                size: file.size,
                duration: duration,
              ));
            });
          }
        }
        
        setState(() {
          _outputPath = null; // 清除之前的输出
        });
      }
    } catch (e) {
      _showError('添加文件失败: $e');
    }
  }

  /// 移除视频文件
  void _removeVideo(int index) {
    setState(() {
      _videoFiles.removeAt(index);
      _outputPath = null;
    });
  }

  /// 清空列表
  void _clearAll() {
    setState(() {
      _videoFiles.clear();
      _outputPath = null;
      _statusMessage = '';
    });
  }

  /// 调整顺序（上移）
  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _videoFiles.removeAt(index);
        _videoFiles.insert(index - 1, item);
      });
    }
  }

  /// 调整顺序（下移）
  void _moveDown(int index) {
    if (index < _videoFiles.length - 1) {
      setState(() {
        final item = _videoFiles.removeAt(index);
        _videoFiles.insert(index + 1, item);
      });
    }
  }

  /// 执行合并
  Future<void> _mergeVideos() async {
    if (_videoFiles.isEmpty) {
      _showError('请先添加视频文件');
      return;
    }
    
    if (_videoFiles.length < 2) {
      _showError('至少需要添加2个视频才能合并');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在合并视频...';
      _outputPath = null;
    });

    try {
      // 生成输出路径
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = _videoFiles.first.path.split('.').last;
      final outputPath = '${tempDir.path}/merged_$timestamp.$ext';
      
      // 执行合并
      final result = await FFmpegService.mergeVideos(
        inputPaths: _videoFiles.map((f) => f.path).toList(),
        outputPath: outputPath,
      );
      
      if (result != null) {
        setState(() {
          _outputPath = result;
          _statusMessage = '✅ 合并完成！';
        });
        _showSuccess('视频合并成功！');
      } else {
        _showError('合并失败，请确保所有视频格式一致');
      }
    } catch (e) {
      _showError('合并出错: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 分享输出文件
  Future<void> _shareOutput() async {
    if (_outputPath == null) return;
    
    try {
      await Share.shareXFiles([XFile(_outputPath!)], text: '合并后的视频');
    } catch (e) {
      _showError('分享失败: $e');
    }
  }

  /// 显示错误提示
  void _showError(String message) {
    setState(() {
      _statusMessage = '❌ $message';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// 显示成功提示
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 计算总时长
  double get _totalDuration {
    return _videoFiles.fold(0.0, (sum, file) => sum + file.duration);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频合并'),
        centerTitle: true,
        actions: [
          if (_videoFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAll,
              tooltip: '清空列表',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 文件列表
            Expanded(
              child: _videoFiles.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : _buildVideoList(colorScheme),
            ),
            
            // 底部操作区
            _buildBottomBar(colorScheme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _addVideos,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加视频'),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_rounded,
            size: 80,
            color: colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            '添加多个视频进行无损合并',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加视频',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 80), // 给 FAB 留空间
        ],
      ),
    );
  }

  /// 构建视频列表
  Widget _buildVideoList(ColorScheme colorScheme) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _videoFiles.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _videoFiles.removeAt(oldIndex);
          _videoFiles.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final file = _videoFiles[index];
        return Card(
          key: ValueKey(file.path),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  FFmpegService.formatTime(file.duration),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.folder_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatFileSize(file.size),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 上移按钮
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  onPressed: index > 0 ? () => _moveUp(index) : null,
                  tooltip: '上移',
                ),
                // 下移按钮
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  onPressed: index < _videoFiles.length - 1
                      ? () => _moveDown(index)
                      : null,
                  tooltip: '下移',
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  onPressed: () => _removeVideo(index),
                  tooltip: '移除',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomBar(ColorScheme colorScheme) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 统计信息
          if (_videoFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.video_library_rounded,
                    label: '${_videoFiles.length} 个视频',
                    colorScheme: colorScheme,
                  ),
                  _buildStatItem(
                    icon: Icons.access_time_rounded,
                    label: '总时长 ${FFmpegService.formatTime(_totalDuration)}',
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          
          // 状态显示
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _statusMessage,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          
          // 操作按钮
          Row(
            children: [
              // 合并按钮
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing || _videoFiles.length < 2
                      ? null
                      : _mergeVideos,
                  icon: _isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.merge_rounded),
                  label: Text(_isProcessing ? '处理中...' : '开始合并'),
                ),
              ),
              
              // 分享按钮
              if (_outputPath != null) ...[
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _shareOutput,
                  icon: const Icon(Icons.share_rounded),
                  tooltip: '分享/保存',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// 视频文件数据类
class VideoFile {
  final String path;
  final String name;
  final int size;
  final double duration;

  VideoFile({
    required this.path,
    required this.name,
    required this.size,
    required this.duration,
  });
}
