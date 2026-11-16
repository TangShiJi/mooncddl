# Changelog

## 0.2.1 - 2026-11-16

- Preserve leading U+FEFF characters when decoding CBOR text and indefinite text chunks.
- Add a regression case covering decoded content and embedded .cbor/.size behavior.

## 0.2.0 - 2026-11-16

- 将一致性目标改为 RFC 8610 完整基础语言，增加独立标准语法检查与逐章节验收追踪。
- 实现泛型、命名/嵌套组、组选择、cut、socket/plug、增量、unwrap、枚举与完整 prelude。
- 完整 CBOR 64 位整数域、浮点可表示性、全部 major/Tag、标准字节与数值词法。
- 实现全部 14 个 RFC 8610 控制符，包括 XSD 正则、Unicode 13.0、嵌入 CBOR 和序列。
- 修正 PEG 贪婪重复、JSON 附录 E 数字类型、.size 容量和 .default/.ne 语义。
- 严格标准语法：控制范围/连续控制使用括号；逆序范围为空集合；.size 不接受数组/映射。
- 增加 66 项四目标测试、41 个标准 JSON 案例、34 个正则对照、解码/正则畸形输入及第四个示例。
- 扩展 CI 的独立实现对照和报告；保留参考差异和性能退化记录，不用旧数据宣称新版性能。
- 辅助样例生成仍为部分合成工具，不能合成时明确报错。

## 0.1.0 - 2026-11-11

- 实现带源位置和资源限制的 CDDL 词法与解析；
- 实现规则、引用、选择、范围、数组、映射、基数、Tag 和常用控制符；
- 实现 JSON/CBOR 中立值模型、精确路径诊断和封闭映射校验；
- 实现 JSON 适配、规范化格式、最小有效样例生成、CLI 和三个下游样例；
- 增加四目标测试、畸形输入语料、性能基准和 GitHub Actions。
- 发布至 mooncakes.io，并在无源码检出的全新消费者模块中完成安装、四目标检查/测试和原生运行。
