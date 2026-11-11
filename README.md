# MoonCDDL

[![CI](https://github.com/TangShiJi/mooncddl/actions/workflows/ci.yml/badge.svg)](https://github.com/TangShiJi/mooncddl/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Mooncakes](https://img.shields.io/badge/mooncakes.io-0.1.0-orange.svg)](https://mooncakes.io/docs/TangShiJi/mooncddl%400.1.0)

MoonCDDL 是 MoonBit 原生的 CDDL（Concise Data Definition Language）数据契约工具包。它解析 CDDL 规则，并在同一套类型模型上校验 JSON 数据和保留 CBOR 特性的值：字节串、非字符串映射键和语义标签。项目面向协议实现、IoT 网关、WebAuthn/COSE 类数据、API 边界与一致性测试。

项目不是 CBOR 编解码器，也不是 JSON Schema 的重复实现。编解码器解决“字节如何变成值”，MoonCDDL 解决“这个值是否满足协议契约”；JSON Schema 无法自然表达 CBOR 字节串、整数键和 Tag，CDDL 则可同时描述 CBOR 与 JSON 数据结构。

## 已实现能力

- CDDL 词法分析：注释、字符串、十六进制字节串、整数、源位置与资源上限；
- 规则解析与引用解析：预定义类型、字面量、选择、整数范围、数组、映射、出现次数和递归引用；
- CBOR 数据模型：字节串、任意类型映射键与 `#6.n(type)` Tag；
- 约束校验：`.size`、`.lt`、`.le`、`.gt`、`.ge`、`.eq`、`.ne`、`.and`、`.within`；
- 可操作诊断：稳定错误码、JSON-Pointer 风格路径、期望/实际类型与问题数量上限；
- 封闭映射、多余成员、缺失成员、数组顺序和基数检查；
- JSON 文本适配器，无需另写一套 API 校验模型；
- 规范化格式输出与解析—格式化—再解析一致性测试；
- 自动生成最小有效样例，并在返回前用同一规则自校验；
- 原生、Wasm、Wasm GC、JavaScript 四目标检查与测试。

精确支持边界见 [兼容性矩阵](docs/COMPATIBILITY.md)。0.1.0 不声称完整实现 RFC 8610；泛型、socket/plug、嵌入 ABNF/CBOR 和正则控制符属于明确的非目标，遇到未支持控制符会返回错误，不会静默忽略。

## 安装

发布版从 mooncakes.io 安装：

```bash
moon add TangShiJi/mooncddl@0.1.0
```

公开包页面：[TangShiJi/mooncddl@0.1.0](https://mooncakes.io/docs/TangShiJi/mooncddl%400.1.0)。服务端构建状态和独立消费者安装记录见 [发布证据](docs/RELEASE_EVIDENCE.md)。

在包的 `moon.pkg` 中导入：

```moonbit
import {
  "TangShiJi/mooncddl" @cddl,
}
```

## 最小用法

```moonbit
let schema = @cddl.parse_cddl(
  #|request = {
  #|  id: uint,
  #|  title: tstr .size 1..80,
  #|  ? urgent: bool,
  #|}
).unwrap()

let report = @cddl.validate_json(
  schema,
  "{\"id\":42,\"title\":\"restart gateway\",\"urgent\":true}",
).unwrap()

assert_true(report.is_valid())
```

校验 CBOR 解码后的值时，先由所选 CBOR 库完成解码，再构造 `CddlValue`。这一层保留 JSON 不具备的类型：

```moonbit
let value = @cddl.tagged_value(
  1001L,
  @cddl.map_value([
    (@cddl.integer_value(1L), @cddl.bytes_value(device_id)),
    (@cddl.integer_value(2L), @cddl.integer_value(23L)),
  ]),
)
let report = @cddl.validate(schema, value).unwrap()
```

## 可运行样例

```bash
moon run examples/json_api
moon run examples/cbor_iot
moon run examples/fixture_generation
```

- `json_api`：用 CDDL 校验创建任务 API 的 JSON 请求；
- `cbor_iot`：校验含整数键、字节串和 Tag 的 IoT 遥测值；
- `fixture_generation`：生成最小协议夹具并立即自校验。

命令行入口可直接用于脚本和 CI：

```bash
moon run cmd/main -- validate-json 'request = { id: uint }' '{"id":7}'
moon run cmd/main -- format 'request={id:uint}'
moon run cmd/main -- example 'packet = [2*4 uint]'
```

## 验证与复现

```bash
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run --target native examples/json_api
moon run --target native examples/cbor_iot
moon run --target native examples/fixture_generation
moon package --list
```

测试覆盖解析成功/失败、重复和未知规则、选择与范围、基数、封闭映射、精确路径、控制符、Tag、JSON 转换、格式往返、最小样例、递归/容器/问题上限，以及 500 份确定性畸形输入。GitHub Actions 对四个目标执行格式、检查、测试、包内容审计和样例运行。

本机原生 Release 基准对同一已解析遥测规则执行 100,000 次完整映射校验，5 次为 135.91–155.05 ms，中位数 140.91 ms；数据只作为当前实现的回归基线，不宣称跨机器或跨项目优势。复现方法见 [BENCHMARKS.md](docs/BENCHMARKS.md)。

## 工程边界与安全

所有面向不可信输入的入口都接受 `CddlLimits`，限制源大小、Token 数、规则数、递归深度、容器项数和诊断数。解析阶段拒绝重复规则、未知引用、无效范围和未支持控制符；校验阶段不会因选择分支失败而泄漏无关诊断。

0.1.0 采用确定性的顺序组匹配，不实现完整的回溯组消歧；需要高度歧义的复杂 CDDL group choice 时应等待后续兼容版本。该边界在兼容性文档和测试中明确记录。

## 开源与维护

项目为原创实现，依据 RFC 8610 与 RFC 9165 的公开规范设计，不移植任何现有实现。代码采用 [Apache License 2.0](LICENSE)。版本遵循语义化版本；0.1.x 只接受兼容修复，新增语法能力进入后续次版本。贡献方式见 [CONTRIBUTING.md](CONTRIBUTING.md)，安全问题见 [SECURITY.md](SECURITY.md)。

- [验收清单](docs/ACCEPTANCE.md)
- [发布与独立安装证据](docs/RELEASE_EVIDENCE.md)
- [生态查重记录](docs/ECOSYSTEM_AUDIT.md)
- [变更记录](CHANGELOG.md)

## 标准

- [RFC 8610 — CDDL](https://www.rfc-editor.org/rfc/rfc8610.html)
- [RFC 9165 — CDDL Control Operators](https://www.rfc-editor.org/rfc/rfc9165.html)
