import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xqmagic/utils/app_settings.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';

/// 设置对话框
///
/// 展示应用设置，支持引擎、显示、音效三大类配置。
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  /// 显示设置对话框的便捷方法
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SettingsDialog(),
    );
  }

  /// Show settings dialog and apply changes to the running engine.
  static Future<void> showAndApply(BuildContext context) async {
    await show(context);
    // After dialog closes, apply settings to the engine if it's running
    if (context.mounted) {
      final vm = context.read<GameViewModel>();
      await vm.syncSettingsToEngine();
    }
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  // Engine settings
  late String _enginePath;
  late String _engineProtocol; // 'uci', 'ucci', 'auto'
  late int _engineDepth;
  late int _engineTime; // seconds
  late int _engineThreads;
  late int _engineHash; // MB
  late int _engineSkillLevel; // 0-20
  late int _multiPV;

  // Display settings
  late double _boardScale;
  late bool _showMoveHints;
  late bool _showCoordinates;
  late String _skinName;

  // Sound settings
  late bool _soundEnabled;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Show dialog to select engine file or manually input path
  Future<void> _selectEnginePath() async {
    // Option 1: Use native file picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Platform.isWindows
          ? ['exe', 'bat', 'cmd']
          : Platform.isMacOS
              ? ['app', '']
              : [''],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      if (mounted) {
        setState(() => _enginePath = result.files.single.path!);
      }
      return;
    }

    // Option 2: Manual input if user cancels file picker
    if (mounted) {
      final controller = TextEditingController(text: _enginePath);
      final manualPath = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('手动输入引擎路径'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '引擎路径',
              hintText: '请输入引擎可执行文件完整路径',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (manualPath != null && manualPath.isNotEmpty) {
        setState(() => _enginePath = manualPath);
      }
      controller.dispose();
    }
  }

  void _loadSettings() {
    final settings = AppSettings.instance;
    _enginePath = settings.enginePath;
    _engineProtocol = settings.engineProtocol;
    _engineDepth = settings.engineDepth;
    _engineTime = 5; // Default 5s, stored as seconds
    _engineThreads = settings.engineThreads;
    _engineHash = settings.engineHash;
    _engineSkillLevel = settings.engineSkillLevel;
    _multiPV = settings.multiPV;

    _boardScale = settings.boardScale;
    _showMoveHints = settings.showMoveHints;
    _showCoordinates = settings.showCoordinates;
    _skinName = settings.skinName;

    _soundEnabled = settings.soundEnabled;
    _volume = settings.volume;
  }

  Future<void> _saveSettings() async {
    final settings = AppSettings.instance;
    await settings.setEnginePath(_enginePath);
    await settings.setEngineProtocol(_engineProtocol);
    await settings.setEngineDepth(_engineDepth);
    await settings.setEngineThreads(_engineThreads);
    await settings.setEngineHash(_engineHash);
    await settings.setEngineSkillLevel(_engineSkillLevel);
    await settings.setMultiPV(_multiPV);

    await settings.setBoardScale(_boardScale);
    await settings.setShowMoveHints(_showMoveHints);
    await settings.setShowCoordinates(_showCoordinates);
    await settings.setSkinName(_skinName);

    await settings.setSoundEnabled(_soundEnabled);
    await settings.setVolume(_volume);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 28),
                  const SizedBox(width: 12),
                  Text('设置', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    _buildEngineSection(context),
                    _buildDisplaySection(context),
                    _buildSoundSection(context),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveSettings,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineSection(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Row(
        children: [
          const Icon(Icons.memory_outlined, size: 22),
          const SizedBox(width: 12),
          Text('引擎设置', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEnginePathField(context),
              const SizedBox(height: 12),
              _buildDropdown<String>(
                context: context,
                label: '通信协议',
                value: _engineProtocol,
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('自动检测')),
                  DropdownMenuItem(value: 'uci', child: Text('UCI')),
                  DropdownMenuItem(value: 'ucci', child: Text('UCCI')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _engineProtocol = v);
                },
                helper: 'UCI: Pikafish 等 / UCCI: 象棋引擎等 / 自动: 先UCI后UCCI',
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context: context,
                label: '分析深度',
                value: _engineDepth.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => setState(() => _engineDepth = v.round()),
                displayValue: '$_engineDepth',
              ),
              const SizedBox(height: 12),
              _buildDropdown<int>(
                context: context,
                label: '分析时间',
                value: _engineTime,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1秒')),
                  DropdownMenuItem(value: 3, child: Text('3秒')),
                  DropdownMenuItem(value: 5, child: Text('5秒')),
                  DropdownMenuItem(value: 10, child: Text('10秒')),
                  DropdownMenuItem(value: 30, child: Text('30秒')),
                ],
                onChanged: (v) => setState(() => _engineTime = v ?? 5),
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context: context,
                label: '线程数',
                value: _engineThreads.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                onChanged: (v) => setState(() => _engineThreads = v.round()),
                displayValue: '$_engineThreads',
              ),
              const SizedBox(height: 12),
              _buildDropdown<int>(
                context: context,
                label: '哈希大小',
                value: _engineHash,
                items: const [
                  DropdownMenuItem(value: 32, child: Text('32 MB')),
                  DropdownMenuItem(value: 64, child: Text('64 MB')),
                  DropdownMenuItem(value: 128, child: Text('128 MB')),
                  DropdownMenuItem(value: 256, child: Text('256 MB')),
                  DropdownMenuItem(value: 512, child: Text('512 MB')),
                  DropdownMenuItem(value: 1024, child: Text('1024 MB')),
                ],
                onChanged: (v) => setState(() => _engineHash = v ?? 256),
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context: context,
                label: 'Skill Level',
                value: _engineSkillLevel.toDouble(),
                min: 0,
                max: 20,
                divisions: 20,
                onChanged: (v) => setState(() => _engineSkillLevel = v.round()),
                displayValue: '$_engineSkillLevel',
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context: context,
                label: 'MultiPV',
                value: _multiPV.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (v) => setState(() => _multiPV = v.round()),
                displayValue: '$_multiPV',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Row(
        children: [
          const Icon(Icons.display_settings_outlined, size: 22),
          const SizedBox(width: 12),
          Text('显示设置', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSlider(
                context: context,
                label: '棋盘缩放',
                value: _boardScale,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (v) => setState(() => _boardScale = v),
                displayValue: '${_boardScale.toStringAsFixed(1)}x',
              ),
              const SizedBox(height: 12),
              _buildSwitch(
                context: context,
                label: '显示走法提示',
                value: _showMoveHints,
                onChanged: (v) => setState(() => _showMoveHints = v),
              ),
              const SizedBox(height: 12),
              _buildSwitch(
                context: context,
                label: '显示坐标',
                value: _showCoordinates,
                onChanged: (v) => setState(() => _showCoordinates = v),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                context: context,
                label: '皮肤名称',
                value: _skinName,
                onChanged: (v) => setState(() => _skinName = v),
                hintText: '请输入皮肤名称',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSection(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Row(
        children: [
          const Icon(Icons.volume_up_outlined, size: 22),
          const SizedBox(width: 12),
          Text('音效设置', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSwitch(
                context: context,
                label: '启用音效',
                value: _soundEnabled,
                onChanged: (v) => setState(() => _soundEnabled = v),
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context: context,
                label: '音量',
                value: _volume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) => setState(() => _volume = v),
                displayValue: '${(_volume * 100).round()}%',
                enabled: _soundEnabled,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build read-only engine path field with file picker button
  Widget _buildEnginePathField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('引擎路径', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _enginePath),
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: '点击右侧按钮选择引擎或输入路径',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _selectEnginePath,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('浏览'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? hintText,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      controller: TextEditingController(text: value),
      onChanged: onChanged,
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
    bool? enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(displayValue, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: displayValue,
          onChanged: enabled ?? true ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        if (helper != null)
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch({
    required BuildContext context,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
