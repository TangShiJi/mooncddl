# 性能回归基线

## 场景

基准先解析一次遥测 CDDL，随后对含 4 个成员的映射执行 100,000 次完整校验。规则包含文本长度、整数范围、可选字段和开放扩展字段，代码位于 `benchmarks/validation`。

## 复现

```bash
moon build --target native --release
moon run --target native --release benchmarks/validation
```

如需排除构建系统启动时间，可直接重复运行生成的原生可执行文件并由操作系统计时。

## 2026-11-11 基线

- 环境：Windows x64，MoonBit native release；
- 样本：100,000 次验证，每次均创建 `ValidationReport`；
- 5 次耗时：155.05、140.91、139.08、135.91、149.96 ms；
- 中位数：140.91 ms，约 709,673 次验证/秒。

这些数字用于发现本项目后续版本的明显退化。它不是与其他语言或实现的公平横向比较；不同 CPU、工具链和输入结构会改变结果。
