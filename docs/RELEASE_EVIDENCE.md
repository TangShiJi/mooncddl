# 0.1.0 发布与安装证据

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
