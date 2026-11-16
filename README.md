# MoonCDDL

[![CI](https://github.com/TangShiJi/mooncddl/actions/workflows/ci.yml/badge.svg)](https://github.com/TangShiJi/mooncddl/actions/workflows/ci.yml)

MoonBit 原生 CDDL 数据契约库：解析规则与泛型、校验 JSON/CBOR 值、路径诊断、格式化。CBOR 编解码器处理字节表示，本库判断值是否满足协议，保留字节串、整数键和 Tag。

## 标准范围

0.2.1 以 **RFC 8610 第 2、3 节及附录 A–E 完整基础语言**为一致性目标，取代 0.1 子集范围。包含标准语法、分组/PEG 组选择、泛型、socket/plug、增量、unwrap/枚举、major/Tag、全部 40 个 prelude 名称和 14 个控制符：

`.size .bits .regexp .cbor .cborseq .within .and .lt .le .gt .ge .eq .ne .default`

[标准追踪和行为案例](docs/STANDARD_CONFORMANCE.md)；[表示域和资源边界](docs/COMPATIBILITY.md)。有限案例不是所有输入的形式化证明。RFC 9165 等后续扩展不在本次基础语言目标内。

## 安装与用法

使用当前 MoonBit 工具链：

```bash
moon add TangShiJi/mooncddl@0.2.1
```

在使用方 moon.pkg：

```moonbit
import {
  "TangShiJi/mooncddl" @cddl,
}
```

```moonbit
let source = "root = pair<uint,tstr> pair<a,b> = [a,b]"
let schema = @cddl.parse_cddl(source).unwrap()
assert_true(@cddl.validate_json(schema, "[7,\"ok\"]").unwrap().is_valid())
assert_false(@cddl.validate_json(schema, "[\"bad\",\"ok\"]").unwrap().is_valid())
```

`check_standard_syntax(source)` 检查标准语法，不检查引用和扩展是否实现；`parse_cddl` 拒绝未知引用与未实现控制符。普通请求可用 `request = { id: uint, title: tstr .size (1..80) }`。

CBOR 值可构造 CddlValue，或调用 decode_cbor / decode_cbor_sequence 再 validate。模型保留完整 CBOR 64 位整数域、字节、非文本键、简单值、浮点和 Tag。内置解码器服务于 .cbor/.cborseq，不提供编码器。

[公开包](https://mooncakes.io/docs/TangShiJi/mooncddl%400.2.1)；[发布与全新消费者安装证据](docs/RELEASE_EVIDENCE.md)。

## 运行示例与 CLI

```bash
moon run --target native examples/json_api
moon run --target native examples/cbor_iot
moon run --target native examples/fixture_generation
moon run --target native examples/standard_contract
moon run --target native cmd/main -- check-syntax 'root = pair<uint,tstr> pair<a,b> = [a,b]'
moon run --target native cmd/main -- validate-json 'request = { id: uint }' '{"id":7}'
moon run --target native cmd/main -- format 'request={id:uint}'
moon run --target native cmd/main -- example 'packet = [2*4 uint]'
```

四例分别为 JSON 请求、含整数键/Tag 遥测、自校验夹具、泛型/unwrap/枚举/位集合契约，均带行为断言。CLI 校验合法退出 0、不匹配 1、规则/输入错误 2；语法/格式失败退出 2。生成器不能合成复杂正则、嵌入 CBOR 等规则时明确报错，成功样例必须自校验。

## 复现检查

```bash
moon info
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native --release cmd/main
moon package --list
python scripts/differential.py --cli <CLI路径> --reference <anweiss-cddl-0.10.7路径>
python -m pip install lxml==6.0.2
python scripts/xsd_differential.py --cli <CLI路径>
```

Windows CLI 为 _build/native/release/build/cmd/main/main.exe；CI 自动定位 Linux 产物。67 个单元测试在四目标分别运行；另有 41 个 JSON 标准夹具、34 个 XSD 对照、500 份畸形规则、256 份 CBOR/正则输入与 200 组数值不变量。覆盖组、cut、泛型、prelude、全部控制符与错误边界。独立实现差异完整保留，不伪称全部一致。

Actions 执行格式、检查、构建、测试、示例和对照，上传报告；发布后执行不检出本仓库的全新消费者安装。[性能](docs/BENCHMARKS.md) 仅作回归基线。

## 兼容与维护

- CBOR 整数 −2⁶⁴ 至 2⁶⁴−1，更大整数用 bignum Tag；binary64 浮点，半/单精度按可表示性检查。
- JSON 整数词法值在上述域精确保留，其他数值有限 binary64；越界报错。附录 E 统一整数/浮点类型。
- XSD 正则，Unicode 13.0 属性/块，XML 1.0 第五版名称字符，不是 PCRE/JS 方言。
- PEG 贪婪组匹配；[* uint,uint] 不回退已消费整数。.default 与 .ne 同义，不填默认值。
- 输入、递归、容器、操作预算超限明确失败。
- 0.1 迁移：.size 1..80 改成 .size (1..80)；多控制符加括号，如 (int .ge 1) .le 5；逆序范围为空集合。

原创实现，代码 [Apache-2.0](LICENSE)，Unicode 数据来源和许可见 [NOTICE](NOTICE)、[third_party](third_party/)。Rust CDDL/libxml2 仅为外部对照，不复制实现。规范：[RFC 8610](https://www.rfc-editor.org/rfc/rfc8610.html)、[XSD](https://www.w3.org/TR/xmlschema-2/#regexs)。

0.2.x 修复兼容问题并增加回归案例；扩展 RFC 独立评审，保留每版 CI/安装记录。问题请附契约、最小值、预期和工具链版本。见 [贡献](CONTRIBUTING.md)、[安全](SECURITY.md)、[验收](docs/ACCEPTANCE.md)、[申报书](docs/PROJECT_APPLICATION.md)、[查重](docs/ECOSYSTEM_AUDIT.md)、[变更](CHANGELOG.md)。
