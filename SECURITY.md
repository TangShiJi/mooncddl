# Security Policy

MoonCDDL 处理可能来自网络的不可信契约和数据。调用方应按部署环境设置 `CddlLimits`，尤其是源大小、Token、递归、容器和诊断上限。

安全问题请通过 GitHub Security Advisory 私下报告，并附最小输入、受影响版本和预期影响。不要在公开 Issue 中发布可造成资源耗尽的未修复样例。0.1.x 接收资源上限绕过、panic、无限递归和错误接受高风险输入的兼容修复。
