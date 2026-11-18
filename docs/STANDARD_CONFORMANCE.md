# RFC 8610 一致性目标和验收

## 最终范围和语法验收入口（2026-11-18 复审修订）

最终交付按完整 RFC 8610（2019）验收，不以“有用核心”“常用语法”等子集收口。第 2/3 节及附录 A–E 均纳入目标：语法、名字/泛型解析和数据求值分别检验。RFC 9165 是后续独立扩展，不把未实现该扩展描述为 RFC 8610 语法缺失。资源/数值表示限制必须公开，不得据此默默接受错误数据或将标准功能改为选做。

标准语法输入单独保存为 [52 个正反例](../fixtures/standard-syntax.json)，每例含完整输入、功能类别和预期。它们覆盖规则、增量、socket、泛型、组选择、cut、出现次数、unwrap、枚举、major/Tag、数值/字节/文本词法与非法输入；有限案例不证明所有标准输入均正确。

```bash
moon build --target native --release cmd/main
python scripts/check_standard_syntax.py --cli _build/native/release/build/cmd/main/main.exe
```

语法正例退出 0，语法反例退出 2；超时、崩溃和其他退出码一律失败。报告为 `_build/standard-syntax-report.json`，CI 每次运行并上传。`root = unknown` 的语法可以合法，但可执行解析应拒绝未知名字；不能把语法成功作为完整语义一致性的证明。数据校验的独立正反例仍由 `fixtures/rfc8610.json` 执行。

0.2.1 覆盖目标为 RFC 8610 第 2、3 节及附录 A–E 的完整基础语言。以下是实现追踪，不是有限案例对所有输入的形式化证明。以标准正文判定，表示域/预算见 [兼容边界](COMPATIBILITY.md)。

| 规范 | 实现 | 验收证据 |
|---|---|---|
| 2、3.1–3.4；附录 B/C | standard_syntax、lexer、literal_escapes、parser | standard_syntax_test 正反语法和预算；numeric_conformance_test 标准词法 |
| 2.1、3.2、3.5；附录 A | group_matcher | groups_test 命名/嵌套组、重复、选择、cut、PEG 贪婪 |
| 3.6–3.7、3.9–3.11 | resolution、parser | standard_behavior_test、standard_contract：泛型、枚举、unwrap、增量、socket |
| 2.2.3、3.6；附录 D | prelude、major_types、numbers | numeric_conformance_test：40 名称、major 0–7、64 位边界、float16/32 |
| 3.8.1–3.8.8 | validator、capacity、singleton | standard_behavior_test、acceptance_behavior_test：全部 14 个控制符 |
| 3.8.3；XSD 附录 F | xsd_regex、xsd_unicode | xsd_regex_test、scripts/xsd_differential.py：类别、减法、量词 |
| 3.8.4 | embedded_cbor | embedded_cbor_test：单值/序列、截断、尾随、重复键、UTF-8、全部 major |
| 附录 E | json_adapter、data_equality | acceptance_behavior_test：10.0 作 uint、10 作 float、越界报错 |

## 直接验收的行为

```bash
moon run --target native cmd/main -- check-syntax 'root = pair<uint,tstr> pair<a,b> = [a,b]'
moon run --target native cmd/main -- validate-json 'root = pair<uint,tstr> pair<a,b> = [a,b]' '[7,"ok"]'
moon run --target native cmd/main -- validate-json 'root = pair<uint,tstr> pair<a,b> = [a,b]' '["bad","ok"]'
moon run --target native cmd/main -- validate-json 'root = uint .size 3' '16777215'
moon run --target native cmd/main -- validate-json 'root = uint .size 3' '16777216'
moon run --target native cmd/main -- validate-json 'root = [* uint,uint]' '[1]'
moon run --target native cmd/main -- validate-json 'root = float16' '0.1'
moon run --target native cmd/main -- validate-json 'root = tstr .regexp "[a-z-[aeiou]]+"' '"bcdf"'
```

依次退出 0、0、1、0、1、1、1、0。check-syntax 的 root = [ 退出 2。.cbor/.cborseq 正反例通过完整测试复现：单值必须消费全部字节，序列允许多个项目并按数组契约验证；不把 CBOR 专有值伪装为 JSON。

## 独立对照与差异

fixtures/rfc8610.json 含 41 个带章节/预期的固定案例。运行：

```bash
moon build --target native --release cmd/main
python scripts/differential.py --cli <CLI> --reference <anweiss-cddl-0.10.7>
python -m pip install lxml==6.0.2
python scripts/xsd_differential.py --cli <CLI>
```

[anweiss/cddl 0.10.7](https://github.com/anweiss/cddl/releases/tag/v0.10.7) 与 libxml2 仅用于对照，报告写入 _build 并由 CI 上传。每次执行检查本项目预期，不跳过失败。

Rust 的 7 处差异逐项保留：无 cut 键候选回退（3.5.4）、JSON .bits 支持、嵌套比较、.default 的 .ne 语义（3.8.7）、附录 E 两种数字表示、半精度可表示性（2.2.3）；其余 34 例一致，不以工具行为取代标准。

XSD 共 34 例。本机 libxml2 2.11.9 对 (a?){3}、中文混合 Letter 类、递归减法 [a-z-[d-f-[e]]] 与规范预期不同，完整保留。其他平台可能没有这些差异。这三例按 XSD 附录 F 的可空重复、Unicode 类别和递归集合定义独立断言。

## 最终检查

1. moon info、格式、四目标检查与测试通过。
2. 四个示例、41 个夹具和 34 个 XSD 案例预期通过，差异有说明。
3. moon package --list 审计内容，Apache-2.0 和 Unicode 许可完整。
4. Mooncakes 状态成功，全新目录安装 0.2.1 并编译运行泛型校验。
5. 核对公开提交、CI、版本与发布记录，数量/性能不能替代行为。
