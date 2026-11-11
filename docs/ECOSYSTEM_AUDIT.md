# MoonBit 生态查重记录

检查日期：2026-11-11。

## 检查方法

1. 读取 mooncakes.io 实时模块列表接口 `/api/v0/modules`，对模块名、用户名和描述进行不区分大小写检索；
2. 检索词包括 `cddl`、`concise data definition language`、`rfc 8610`；
3. 另行检查 `cbor`、`schema`、`validation` 相关结果，区分“编解码器”和“数据契约校验器”；
4. 搜索 GitHub 与公开网页中的 MoonBit CDDL 实现。

## 结论

实时列表共 3,706 个模块，`cddl` 直接命中为 0；未发现以 RFC 8610 CDDL 解析、规则解析与运行时校验为主题的 MoonBit 包。生态中存在 CBOR 编解码和通用序列化包，但它们处理表示转换，不提供 CDDL 契约解析、引用解析、路径诊断和 CBOR 特有类型约束，因此不构成同题重复。

该结论只反映检查时点。申报与验收前可重复调用实时接口，并在出现同类包时更新差异说明。
