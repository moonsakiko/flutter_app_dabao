# 📐 项目结构与维护手记

## 核心架构

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter UI 层                       │
│  ┌─────────┐  ┌─────────────┐  ┌──────────────────┐    │
│  │ HomePage │→│VideoCutPage │  │  VideoMergePage  │    │
│  └─────────┘  └──────┬──────┘  └────────┬─────────┘    │
│                      │                   │              │
│                      ▼                   ▼              │
│              ┌───────────────────────────────┐         │
│              │      FFmpegService 服务层      │         │
│              │  cutVideo() / mergeVideos()   │         │
│              └───────────────┬───────────────┘         │
└──────────────────────────────┼──────────────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │ ffmpeg_kit_flutter  │
                    │   (原生 FFmpeg)      │
                    └─────────────────────┘
```

---

## 各文件职责

### `/lib/main.dart`
- **职责**：APP 入口，全局配置
- **修改场景**：改 APP 名称、主题色、字体

### `/lib/screens/home_page.dart`
- **职责**：首页，功能入口
- **修改场景**：添加新功能按钮

### `/lib/screens/video_cut_page.dart`
- **职责**：视频剪切完整流程
- **依赖**：`video_player`, `file_picker`, `FFmpegService`
- **修改场景**：调整剪切 UI、添加预览功能

### `/lib/screens/video_merge_page.dart`
- **职责**：视频合并完整流程
- **依赖**：`file_picker`, `FFmpegService`
- **修改场景**：添加拖拽排序、预览功能

### `/lib/utils/ffmpeg_service.dart`
- **职责**：FFmpeg 命令封装（核心逻辑）
- **关键方法**：
  - `cutVideo()` - 无损剪切
  - `mergeVideos()` - 无损合并
  - `getVideoDuration()` - 获取时长
  - `formatTime()` - 时间格式化
- **修改场景**：调整 FFmpeg 参数、添加新功能（如转码）

---

## 数据流动

### 剪切流程
```
用户选择视频 → FilePicker 返回路径
          ↓
VideoPlayer 加载预览
          ↓
用户拖动滑块选择时间范围 (startTime, endTime)
          ↓
点击"开始剪切"
          ↓
FFmpegService.cutVideo() 执行命令
          ↓
输出到临时目录 → 用户可分享/保存
```

### 合并流程
```
用户添加多个视频 → 存入 _videoFiles 列表
          ↓
用户调整顺序（上移/下移/拖拽）
          ↓
点击"开始合并"
          ↓
生成 list.txt（concat demuxer 格式）
          ↓
FFmpegService.mergeVideos() 执行命令
          ↓
输出到临时目录 → 用户可分享/保存
```

---

## 扩展功能建议

### 如果想添加"视频转码"功能
1. 在 `FFmpegService` 添加 `transcodeVideo()` 方法
2. 使用重编码命令（如 `-c:v libx264 -crf 23`）
3. 新建 `video_transcode_page.dart` 页面
4. 在 `home_page.dart` 添加入口按钮

### 如果想添加"提取音频"功能
1. FFmpeg 命令：`-vn -acodec copy output.aac`
2. 新建对应页面和 UI
