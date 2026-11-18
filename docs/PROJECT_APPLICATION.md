# MoonCDDL 项目申报书

**基本信息**

- 项目名称：MoonCDDL：RFC 8610 数据契约解析、校验与一致性工具包
- 参赛者：唐仕吉；联系方式：t1622051617@qq.com / 13384247418
- GitHub 仓库链接：https://github.com/TangShiJi/mooncddl
- 项目方向：MoonBit 协议基础库 / CBOR 与 JSON 数据契约；原创项目，非移植。

**项目简介与生态定位**

CBOR 解码成功不能证明整数键、Tag、长度或分组符合协议。MoonCDDL 为 MoonBit 提供 CDDL 契约层，让 JSON 与 CBOR 共用规则，减少业务手写检查。采用语法树、泛型作用域替换和有预算的 PEG 匹配；与编解码库互补。生态检索及自身旧版本披露见 `docs/ECOSYSTEM_AUDIT.md`。

**通用性与完整预期场景**

1. 网关接收 CBOR 遥测，校验整数键、长度和范围；合法入库，错误携路径进入隔离队列。
2. 协议工具接收嵌入 CBOR，按 `.cbor/.cborseq` 展开校验；拒绝截断、尾随及结构错误，再交给业务处理。
3. JSON API 入口复用契约；合法请求进入服务，错误返回诊断；CI 正反例检测协议变更。

**核心功能范围与实现路径**

- **最终支持范围与一致性目标：完整 RFC 8610（2019），不以 CDDL 子集作为最终交付或验收范围。** 第 2、3 节规定的类型与求值行为、附录 A 的匹配语义、附录 B/C 的完整语法与词法、附录 D 的全部 40 个 prelude 名称、附录 E 的 JSON 映射均为必做。覆盖组/组选择、递归、泛型、增量/socket、unwrap/枚举、cut、major type/Tag 及全部 14 个控制符：`.size/.bits/.regexp/.cbor/.cborseq/.within/.and/.lt/.le/.gt/.ge/.eq/.ne/.default`。
- 交付 MoonBit 库、CLI、4 个示例、标准案例、四目标 CI、独立对照和 Mooncakes 包。整数 −2⁶⁴ 至 2⁶⁴−1，浮点 binary64；正则为 XSD/Unicode 13.0。
- 边界：JSON 使用上述整数域和有限 binary64，越界报错；限制输入、递归与匹配预算。RFC 9165 等后续扩展不属于本次基础语言交付；样例生成不能合成时明确报错；不做网络服务或 CBOR 编码器。

**标准语法校验案例与验收标准**

以下为独立、完整的 CDDL 输入；正例必须通过 `check-syntax`，反例必须退出 2：

| 类别 | 输入 | 预期 |
|---|---|---|
| 泛型 | `root = pair<uint,tstr> pair<a,b> = [a,b]` | 通过 |
| 组选择 | `root = [(1,uint) // (2,tstr)]` | 通过 |
| socket/plug | `root = $t / [$$g] $t /= uint $$g //= (tstr)` | 通过 |
| unwrap/枚举 | `root = [~point,&colors] point = [number,number] colors = (red:1,blue:2)` | 通过 |
| Tag/控制符 | `root = #6.18(bstr .cbor [uint])` | 通过 |
| 缺失闭括号 / 非法泛型 | `root = [` / `root = pair<>` | 均拒绝 |

一键复现：构建 CLI 后运行 `python scripts/check_standard_syntax.py --cli <CLI路径>`，逐例检查 `fixtures/standard-syntax.json` 中 52 个正反例并输出报告。语法通过不等于引用可解析或数据合法；后两项另行验收。

数据验收另见 `fixtures/rfc8610.json`：泛型数组接受 `[7,"ok"]`、拒绝错误类型；`.size 3` 的 uint 拒绝 16777216；半精度拒绝 0.1；嵌入 CBOR 拒绝尾随字节。逐章标准与差异说明见 `docs/STANDARD_CONFORMANCE.md`。公开仓库已超过 10 个实质提交，安装/CI 证据见 `docs/RELEASE_EVIDENCE.md`；数量不能替代行为验收。

**原创与参考说明**

依据 [RFC 8610](https://www.rfc-editor.org/rfc/rfc8610.html) 与 [XSD 正则](https://www.w3.org/TR/xmlschema-2/#regexs) 独立实现，非开源项目移植；代码 Apache-2.0。Unicode 数据保留原许可证；Rust `anweiss/cddl` 与 libxml2 仅作外部对照，不复制实现。来源和许可见 `NOTICE`、`third_party/`。
