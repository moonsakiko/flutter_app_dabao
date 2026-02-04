import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/ffmpeg_service.dart';
import '../utils/file_helper.dart';
import '../utils/permission_helper.dart';
import '../widgets/video_picker_card.dart';
import '../widgets/time_range_selector.dart';
import '../widgets/progress_overlay.dart';

/// 视频切割页面
class TrimPage extends StatefulWidget {
  const TrimPage({super.key});

  @override
  State<TrimPage> createState() => _TrimPageState();
}

class _TrimPageState extends State<TrimPage> {
  // 选中的视频信息
  VideoInfo? _videoInfo;
  
  // 时间范围（毫秒）
  int _startMs = 0;
  int _endMs = 0;
  
  // 处理状态
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _errorMessage;
  
  // 输出文件路径
  String? _outputPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("视频切割"),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
      ),
      body: Stack(
        children: [
          // 主内容
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 视频选择卡片
                VideoPickerCard(
                  videoInfo: _videoInfo,
                  onPick: _pickVideo,
                  onClear: _clearVideo,
                ),
                
                const SizedBox(height: 24),
                
                // 时间范围选择器（仅当视频已选择时显示）
                if (_videoInfo != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "选择时间范围",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          TimeRangeSelector(
                            totalDurationMs: _videoInfo!.durationMs,
                            startMs: _startMs,
                            endMs: _endMs,
                            onChanged: (start, end) {
                              setState(() {
                                _startMs = start;
                                _endMs = end;
                              });
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 提示信息
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "无损切割将自动对齐到最近的关键帧",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 开始切割按钮
                  FilledButton.icon(
                    onPressed: _canProcess ? _startTrim : null,
                    icon: const Icon(Icons.content_cut_rounded),
                    label: const Text("开始切割"),
                  ),
                ],
                
                // 错误信息
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
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
                ],
                
                // 成功后的操作按钮
                if (_outputPath != null) ...[
                  const SizedBox(height: 24),
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
                            "切割完成！",
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
                                  onPressed: _clearOutput,
                                  icon: const Icon(Icons.add),
                                  label: const Text("继续切割"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 处理进度遮罩
          if (_isProcessing)
            ProgressOverlay(
              progress: _progress,
              message: "正在切割视频...",
            ),
        ],
      ),
    );
  }
  
  bool get _canProcess {
    return _videoInfo != null && 
           _endMs > _startMs && 
           !_isProcessing &&
           _outputPath == null;
  }
  
  Future<void> _pickVideo() async {
    // 请求权限
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage = "需要存储权限才能选择视频";
      });
      return;
    }
    
    // 选择视频
    final path = await FileHelper.pickVideo();
    if (path == null) return;
    
    // 获取视频信息
    final info = await FFmpegService.getVideoInfo(path);
    if (info == null) {
      setState(() {
        _errorMessage = "无法读取视频信息，请选择其他视频";
      });
      return;
    }
    
    setState(() {
      _videoInfo = info;
      _startMs = 0;
      _endMs = info.durationMs;
      _errorMessage = null;
      _outputPath = null;
    });
  }
  
  void _clearVideo() {
    setState(() {
      _videoInfo = null;
      _startMs = 0;
      _endMs = 0;
      _errorMessage = null;
      _outputPath = null;
    });
  }
  
  Future<void> _startTrim() async {
    if (_videoInfo == null) return;
    
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _errorMessage = null;
    });
    
    final result = await FFmpegService.trimVideo(
      inputPath: _videoInfo!.path,
      startMs: _startMs,
      endMs: _endMs,
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
        _errorMessage = result.errorMessage ?? "切割失败，请重试";
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
  
  void _clearOutput() {
    setState(() {
      _outputPath = null;
      _videoInfo = null;
      _startMs = 0;
      _endMs = 0;
    });
  }
}
