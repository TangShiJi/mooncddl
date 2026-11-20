# 发布与安装证据

## 2026-11-20 复审材料核对

新增独立语法验收：25 个合法输入与 27 个非法输入逐一检查退出码，报告见 `fixtures/reports/standard-syntax-report.json`。对应提交 `1e2740ad9b2397cb4c8235fb69e2ce775d6f05d4` 的 [CI 44262646574](https://github.com/TangShiJi/mooncddl/actions/runs/44262646574) 成功。申报书现直接列出完整 RFC 8610 目标和标准语法正反例；[复审修改说明](REVIEW_RESPONSE.md) 提供集中入口。本次是材料/语法验证工具更新，核心库发布版本仍为 0.2.1。

## 0.2.1：2026-11-16 最终核验

- 当前公开包：[TangShiJi/mooncddl@0.2.1](https://mooncakes.io/docs/TangShiJi/mooncddl%400.2.1)。实时 API 返回 version=0.2.1、build_status=success、yanked=false；原始快照见 `fixtures/reports/mooncakes-0.2.1.json`。
- 发布源码：`c06007c855eff19985fd155969374696d64e9ce9`；[发布工作流 43852167450](https://github.com/TangShiJi/mooncddl/actions/runs/43852167450) 成功。后续仓库提交仅同步 CLI 帮助页版本文字和补充发布证据，核心库与发布源码一致。
- [完整 CI 43852446063](https://github.com/TangShiJi/mooncddl/actions/runs/43852446063) 成功：格式、四目标检查/测试、包审计、四例、Release CLI 和独立对照。每目标 67 项测试通过，共 268 次；畸形输入和不变量循环另计。
- 标准对照：41 个 JSON 行为夹具与 34 个 XSD 案例全部符合本库明确预期；与 Rust 参考工具有 7 处、与该 CI libxml2 有 3 处已解释差异，不宣称所有参考结果相同。原始报告见 `fixtures/reports/differential.json`、`xsd-differential.json`，说明见 `STANDARD_CONFORMANCE.md`。
- 手工生产 MoonBit 有效行数 5856（排除测试、生成 Unicode 表、空行和注释，按新增文本修复前统计）；不使用生成数据凑源码规模。
- 四个本地示例均带断言并成功；四目标检查与 67 项测试本地也通过。工具链 moonc 0.10.20+65efd5b93，2026-11-05 构建。

### 仓库外实际安装

[消费者工作流 43852506719](https://github.com/TangShiJi/mooncddl/actions/runs/43852506719) **成功**。该工作流不检出本仓库，创建全新模块并执行：

```bash
moon add TangShiJi/mooncddl@0.2.1
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run --target native acceptance
```

消费者实际下载公开包，检查标准语法，解析泛型，接受合法 JSON、拒绝非法 JSON，并验证 CBOR 文本保留 U+FEFF。最后输出 `external Mooncakes install passed`。消费者模块没有测试文件，因此其 `moon test` 数量为 0；真正的安装验收断言由 `acceptance/main.mbt` 执行，不能将零测试描述为核心库测试覆盖。

0.2.0 为本次标准扩展的首个公开版本，0.2.1 修正 CBOR 文本 U+FEFF 处理。两个版本均保留历史；推荐安装 0.2.1。一次发布所用临时加密仓库凭据已删除。核心运行不依赖 Python、Rust 或 libxml2。

---

## 0.1.0 历史发布与安装证据

核验日期：2026-11-11。

## Mooncakes 公开发布

- 包名：`TangShiJi/mooncddl@0.1.0`；
- 公开页面：[mooncakes.io/docs/TangShiJi/mooncddl@0.1.0](https://mooncakes.io/docs/TangShiJi/mooncddl%400.1.0)；
- 实时模块 API 返回 `version=0.1.0`、`yanked=false`、`build_status=success`；
- 发布前在当前官方工具链执行格式检查、四目标检查和四目标 32 项测试；
- 发布工作流：[GitHub Actions run 42959713152](https://github.com/TangShiJi/mooncddl/actions/runs/42959713152)。

## 仓库外消费者验证

验证工作流不检出本仓库源码，在 Runner 临时目录执行：

```bash
moon new . --user external-check --name consumer
moon add TangShiJi/mooncddl@0.1.0
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run --target native acceptance
```

消费者只通过 `moon add` 取得公开包，并实际调用 `parse_cddl` 与 `validate_json`。四目标检查/测试及原生运行均成功，记录为 [GitHub Actions run 42989167060](https://github.com/TangShiJi/mooncddl/actions/runs/42989167060)。

用于单次发布的加密仓库 Secret 已在工作流完成后删除，不保留 Mooncakes 凭据。
