# MoonCDDL 项目申报书

**基本信息**

- 项目名称：MoonCDDL：CDDL 数据契约解析、校验与一致性工具包
- 参赛者：唐仕吉
- 联系方式：t1622051617@qq.com / 13384247418
- GitHub 仓库链接：[https://github.com/TangShiJi/mooncddl](https://github.com/TangShiJi/mooncddl)
- 项目方向：MoonBit 数据契约基础库 / CBOR 与 JSON 协议工具链
- 是否为移植项目：否，原创实现；依据 RFC 8610、RFC 9165 公开标准设计

**项目简介与生态定位**

MoonCDDL 为 MoonBit 提供 CDDL 规则解析、引用解析、运行时校验、路径诊断、规范化格式和最小样例生成。现有 CBOR 库主要解决字节编解码，不能回答解码后的值是否符合协议；JSON Schema 又不能自然表达 CBOR 字节串、整数键和 Tag。CDDL 是同时描述 CBOR 与 JSON 数据结构的 IETF 标准，MoonBit 若要实现 IoT、COSE/WebAuthn 和二进制协议，缺少这一契约层就只能在业务代码中重复手写检查。2026-11-11 检查 mooncakes.io 全量 3,706 个模块，未发现 CDDL 同题包。

**项目方向、通用性与预期场景**

1. IoT 网关收到 CBOR 遥测后，将解码结果转为 `CddlValue`，按设备协议检查整数键、设备 ID 字节长度、温度范围、可选字段和扩展字段，再进入存储；
2. WebAuthn/COSE 类工具校验含 Tag、字节串和非字符串键的协议对象，在一致性测试中定位到具体成员路径，而不是只得到“解码失败”；
3. JSON API 在入口处复用同一份 CDDL 校验请求，返回缺失、多余、类型、范围和长度问题，避免再维护第二套 JSON Schema；
4. 协议库 CI 从 CDDL 生成最小有效夹具，执行格式往返和畸形输入测试，验证实现与契约同步。

**核心功能、工程边界与验收**

- 必做：CDDL 有用核心语法、命名引用、选择/范围、数组/映射与基数、CBOR Tag、常用控制符、精确诊断、资源上限、JSON 适配、格式化和自校验样例生成；
- 交付：MoonBit 库、CLI、3 个真实样例、32 项四目标测试、500 份畸形输入、性能基线、CI、Apache-2.0 许可证及 mooncakes.io 可安装版本；
- 验收行为：合法值通过；类型/范围/长度/缺失/多余/Tag 错误返回稳定码和路径；重复/未知规则及未支持控制符明确失败；格式输出幂等；生成样例必须重新校验通过；
- 明确不做：0.1.0 不实现泛型、socket/plug、group choice、嵌入 ABNF/CBOR、正则控制符和完整回溯消歧，不以“完整 RFC 实现”申报。

**原创与参考说明**

项目为原创项目，不移植或复制现有开源实现。实现依据 [RFC 8610](https://www.rfc-editor.org/rfc/rfc8610.html) 与 [RFC 9165](https://www.rfc-editor.org/rfc/rfc9165.html) 的公开标准文本，采用 MoonBit 原生类型、包结构和测试方式独立设计；本项目许可证为 Apache License 2.0。
