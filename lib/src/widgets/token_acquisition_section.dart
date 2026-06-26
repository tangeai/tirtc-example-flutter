import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../demo_widget_keys.dart';

class ConfigureTokenAcquisitionSection extends StatelessWidget {
  const ConfigureTokenAcquisitionSection({
    super.key,
    required this.source,
    required this.tokenIssuerBaseUrlController,
    required this.tokenController,
    required this.enabled,
    required this.scanSupported,
    required this.validateTokenIssuerBaseUrl,
    required this.validateOneTimeToken,
    required this.onSourceChanged,
    required this.onScanToken,
  });

  final DemoTokenSource source;
  final TextEditingController tokenIssuerBaseUrlController;
  final TextEditingController tokenController;
  final bool enabled;
  final bool scanSupported;
  final FormFieldValidator<String> validateTokenIssuerBaseUrl;
  final FormFieldValidator<String> validateOneTimeToken;
  final ValueChanged<DemoTokenSource> onSourceChanged;
  final VoidCallback onScanToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: ExampleTheme.surfaceDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '连接 Token',
            style: TextStyle(
              color: ExampleTheme.brandText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _TokenSourceChip(
                key: DemoWidgetKeys.tokenSourceIssuerButton,
                label: 'Token 签发服务地址',
                selected: source == DemoTokenSource.issuer,
                enabled: enabled,
                onSelected: () => onSourceChanged(DemoTokenSource.issuer),
              ),
              _TokenSourceChip(
                key: DemoWidgetKeys.tokenSourceOneTimeButton,
                label: '一次性连接 Token',
                selected: source == DemoTokenSource.oneTime,
                enabled: enabled,
                onSelected: () => onSourceChanged(DemoTokenSource.oneTime),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (source == DemoTokenSource.issuer)
            _TokenIssuerBaseUrlField(
              controller: tokenIssuerBaseUrlController,
              enabled: enabled,
              validator: validateTokenIssuerBaseUrl,
            )
          else
            _TokenField(
              controller: tokenController,
              enabled: enabled,
              scanSupported: scanSupported,
              validator: validateOneTimeToken,
              onScanToken: onScanToken,
            ),
        ],
      ),
    );
  }
}

class _TokenSourceChip extends StatelessWidget {
  const _TokenSourceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onSelected() : null,
      selectedColor: ExampleTheme.primary.withAlpha(38),
      backgroundColor: ExampleTheme.inputSurface,
      labelStyle: TextStyle(
        color: selected ? ExampleTheme.primary : ExampleTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? ExampleTheme.primary.withAlpha(90) : ExampleTheme.inputBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _TokenIssuerBaseUrlField extends StatelessWidget {
  const _TokenIssuerBaseUrlField({
    required this.controller,
    required this.enabled,
    required this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: DemoWidgetKeys.tokenIssuerBaseUrlField,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        labelText: 'Token 签发服务地址',
        hintText: '例如 http://127.0.0.1:8966 或 http://openapidemo.tange365.com/tirtc/token/Ue4rIG',
      ),
      validator: validator,
    );
  }
}

class _TokenField extends StatelessWidget {
  const _TokenField({
    required this.controller,
    required this.enabled,
    required this.scanSupported,
    required this.validator,
    required this.onScanToken,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool scanSupported;
  final FormFieldValidator<String> validator;
  final VoidCallback onScanToken;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: DemoWidgetKeys.tokenField,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: '一次性连接 Token',
        hintText: '粘贴 TiRTC DevTools CLI 生成的一次性 Token',
        suffixIcon: scanSupported
            ? IconButton(
                key: DemoWidgetKeys.tokenScanButton,
                onPressed: enabled ? onScanToken : null,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: '扫一扫',
              )
            : null,
      ),
      validator: validator,
    );
  }
}
