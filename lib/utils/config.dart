// ==============================
// 用户自定义配置区 (请在此处修改参数)
// ==============================

/// APP 名称（运行时显示在标题栏）
const String APP_NAME = "无损视频切割器";

/// 最大支持的视频体积（单位：MB）
const int MAX_VIDEO_SIZE_MB = 2048;

/// 是否开启调试日志（发布前请设为 false）
const bool ENABLE_DEBUG_LOG = false;

/// 输出视频的默认文件夹名称（保存在相册中）
const String OUTPUT_FOLDER_NAME = "VideoCutter";

/// 视频切割后的文件名前缀
const String TRIM_FILE_PREFIX = "trimmed_";

/// 视频拼接后的文件名前缀
const String MERGE_FILE_PREFIX = "merged_";

// ==============================
// 以下为内部配置，一般无需修改
// ==============================

/// 支持的视频格式
const List<String> SUPPORTED_VIDEO_FORMATS = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', '3gp'
];

/// 主题颜色（用于 ColorScheme.fromSeed）
const int PRIMARY_COLOR_VALUE = 0xFF6750A4; // 紫罗兰色
