# MoonCDDL 项目申报书

**基本信息**

- 项目名称：MoonCDDL：RFC 8610 数据契约解析、校验与一致性工具包
- 参赛者：唐仕吉；联系方式：t1622051617@qq.com / 13384247418
- GitHub 仓库链接：https://github.com/TangShiJi/mooncddl
- 项目方向：MoonBit 协议基础库 / CBOR 与 JSON 数据契约；原创项目，非移植。

**项目简介与生态定位**

CBOR 解码成功不代表消息满足协议：必填整数键、Tag、字节串长度和分组选择仍需业务层检查。JSON Schema 不能直接复用这些 CBOR 契约。MoonCDDL 解析 CDDL，校验保留 CBOR 类型的值与 JSON，使网关、协议库和接口测试共享一份规则。实现采用语法树、作用域替换和有预算的 PEG 组匹配，避免字符串拆分处理泛型与递归。生态查重见 `docs/ECOSYSTEM_AUDIT.md`；自身已发布版本不作为新选题，与编解码包互补。

**通用性与完整预期场景**

1. 网关接收 CBOR 遥测，解码为 `CddlValue`，检查整数键、标识长度、范围和扩展字段；有效消息入库，错误消息携路径诊断进入隔离队列。
2. 协议工具接收 Tag 或嵌入 CBOR 对象，按 `.cbor/.cborseq` 展开并检查内部结构；拒绝截断、尾随字节和契约错误，再交给业务处理。
3. JSON API 入口复用契约校验请求，合法数据进入服务，缺失、多余、类型和范围错误返回报告；CI 用正反例阻止协议变更破坏兼容性。
4. 维护者编辑含泛型、socket 和命名组的 CDDL，执行语法检查、格式往返和固定夹具，产出可审查契约与回归报告。

**核心功能范围与实现路径**

- 最终一致性目标是 **RFC 8610 第 2、3 节及附录 A–E 的完整基础语言**：完整标准语法、组/组选择、泛型、增量/socket、unwrap/枚举、major type/Tag、40 个 prelude 名称及全部 14 个控制符：`.size/.bits/.regexp/.cbor/.cborseq/.within/.and/.lt/.le/.gt/.ge/.eq/.ne/.default`。
- 交付 MoonBit 库、CLI、4 个示例、标准案例、四目标 CI、独立实现对照和 Mooncakes 可安装包。整数覆盖 −2⁶⁴ 至 2⁶⁴−1；binary64 浮点检查半/单精度可表示性；正则采用 XSD 语法与 Unicode 13.0 数据。
- 边界：JSON 使用上述整数域和有限 binary64，越界报错；限制输入、递归与匹配预算。RFC 9165 等后续扩展不属于本次基础语言交付；样例生成不能合成时明确报错；不做网络服务或 CBOR 编码器。

**预期验收产物与行为标准**

Mooncakes 安装后可运行泛型 `pair<a,b>=[a,b]`：接受 `[7,"ok"]`、拒绝 `["bad","ok"]`。`[* uint,uint]` 按 PEG 贪婪语义拒绝 `[1]`；`uint .size 3` 接受 16777215、拒绝 16777216；半精度拒绝 0.1；`.cbor` 拒绝截断/尾随编码；`.regexp` 执行 XSD 类别和集合减法。正反例和命令见 `docs/STANDARD_CONFORMANCE.md`、`fixtures/rfc8610.json`。测试数量、性能与对照差异仅作佐证；发布、外部安装、CI 记录保存在发布证据中。保留不少于 10 个实质提交，兼容修复遵循版本记录。

**原创与参考说明**

依据 [RFC 8610](https://www.rfc-editor.org/rfc/rfc8610.html) 与 [XSD 正则](https://www.w3.org/TR/xmlschema-2/#regexs) 独立实现，非开源项目移植；代码 Apache-2.0。Unicode 数据保留原许可证；Rust `anweiss/cddl` 与 libxml2 仅作外部对照，不复制实现。来源和许可见 `NOTICE`、`third_party/`。
