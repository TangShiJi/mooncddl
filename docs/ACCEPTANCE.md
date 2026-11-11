# 0.1.0 验收清单

| 验收项 | 可复现证据 | 状态 |
|---|---|---:|
| MoonBit 为主要实现语言 | 根包、CLI、样例、基准均为 `.mbt` | 通过 |
| 有效源码超过 1000 行 | 生产 MoonBit 源码超过 3000 行（库、CLI、样例、基准），不含测试与文档 | 通过 |
| 10 个以上有效提交 | 每笔提交对应模型、词法、解析、校验、格式化、适配器、生成器、CLI、样例、质量或 CI | 通过 |
| 核心功能可运行 | `moon check --target all --deny-warn` | 通过 |
| 完整核心测试 | `moon test --target all --deny-warn` | 通过 |
| 真实下游场景 | `examples/json_api`、`examples/cbor_iot`、`examples/fixture_generation` | 通过 |
| 畸形输入稳定性 | 500 份确定性畸形输入，不 panic | 通过 |
| 性能证据 | `benchmarks/validation` 与 `BENCHMARKS.md` | 通过 |
| CI | GitHub Actions 执行格式、四目标检查/测试、包审计和样例 | 通过 |
| OSI 许可证 | Apache-2.0 | 通过 |
| mooncakes.io 公开发布 | `TangShiJi/mooncddl@0.1.0` | 发布后核验 |
| 独立消费者安装 | 新建模块执行 `moon add TangShiJi/mooncddl@0.1.0` 后检查/测试 | 发布后核验 |

## 直接行为标准

1. 合法多规则 CDDL 必须得到可查询的 `Schema`；重复规则、未知引用、倒置范围和未支持控制符必须失败；
2. 合法 JSON/CBOR 风格值必须通过；类型、范围、长度、缺失、多余字段和 Tag 错误必须返回具体路径；
3. 选择分支失败只产生聚合诊断，不把尝试分支的噪声泄漏给调用者；
4. 达到递归、容器或诊断上限时必须受控返回，不得无限递归或无界增长；
5. `format_cddl(parse_cddl(x))` 的输出再次格式化必须字节一致；
6. `generate_example` 只返回能被指定规则重新校验通过的值；
7. 公共发布完成后，必须在仓库外的全新目录通过 Mooncakes 依赖解析与编译，才可将发布项标记为通过。
