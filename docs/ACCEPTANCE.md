# 0.2.1 验收清单

| 要求 | 核对方式与产物 |
|---|---|
| MoonBit 为主 | 根目录 .mbt 为生产实现；Python 仅生成数据与独立对照；不依赖其他语言运行时 |
| 公开仓库和清晰提交 | https://github.com/TangShiJi/mooncddl ，保留历史与实质变更，不强制覆盖历史 |
| 声明核心功能 | RFC 8610 完整基础语言目标；逐章节追踪和行为标准见 STANDARD_CONFORMANCE.md |
| README 可复现 | 固定包版本、导入和泛型示例、CLI、限制与错误语义 |
| 持续集成 | ci.yml 格式、检查、四目标测试、Release 构建、四例、独立对照和报告 |
| 可运行示例 | json_api、cbor_iot、fixture_generation、standard_contract，带行为断言 |
| 核心测试 | 67 个测试/目标、41 JSON 标准夹具、34 XSD 对照、畸形输入与资源边界 |
| 公开发布可安装 | TangShiJi/mooncddl@0.2.1；发布后独立消费者不检出本仓库 |
| OSI 许可与来源 | Apache-2.0；NOTICE 与 Unicode 数据许可；非参考实现移植 |

通过标准按行为判断，不用行数、数量和速度代替功能。全部流程结果、提交及公开地址见 RELEASE_EVIDENCE.md。最终赛事判定由评审方作出。
