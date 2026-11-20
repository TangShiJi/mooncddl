# MoonCDDL 复审修改说明

对应意见：“申报范围目前仅覆盖 CDDL 子集，未明确完整标准的一致性目标。请明确最终支持范围并提供标准语法的校验案例。”

**最终范围**：本项目以完整 RFC 8610（2019）为最终一致性目标，涵盖第 2、3 节与附录 A–E，包括标准语法/词法、分组匹配、引用/泛型、socket/plug、增量规则、unwrap/枚举、cut、major/Tag、全部 40 个 prelude 名称及 14 个控制符。最终验收不以“常用语法”子集收口。RFC 9165 为后续独立扩展；数值表示和资源预算单独披露，不作为遗漏 RFC 8610 功能的理由。

**已修改的申报书**：[PROJECT_APPLICATION.md](PROJECT_APPLICATION.md) 直接列出范围，以及泛型、组选择、socket/plug、unwrap/枚举、Tag/控制符和畸形语法的完整输入及预期结果；保留个人信息、三种应用场景、工程边界和原创/许可说明。

**独立标准语法证据**：[standard-syntax.json](../fixtures/standard-syntax.json) 有 25 个合法案例和 27 个非法案例，每例均提供原文及预期。泛型、组选择等正例须退出 0；缺失闭括号、非法泛型参数等反例须退出 2。逐例报告为 [standard-syntax-report.json](../fixtures/reports/standard-syntax-report.json)。

```bash
moon build --target native --release cmd/main
python scripts/check_standard_syntax.py --cli _build/native/release/build/cmd/main/main.exe
```

Windows 使用上述路径；其他系统使用构建命令输出的 CLI 路径。任何超时、崩溃或退出码不符均判失败。CI 同样运行该脚本并上传报告。

**范围与证据的区别**：完整标准是交付和验收目标，52 个案例是已实现语法的可复现证据，不能据此推断所有输入均已获得形式化证明。语法检查、名字/泛型解析、数据契约校验分别验收，不以 `check-syntax` 成功替代数据语义一致性。数据正反例另见 [rfc8610.json](../fixtures/rfc8610.json)，逐章追踪与表示边界见 [STANDARD_CONFORMANCE.md](STANDARD_CONFORMANCE.md) 和 [COMPATIBILITY.md](COMPATIBILITY.md)。

**已核实记录**：语法证据对应提交 `1e2740ad9b2397cb4c8235fb69e2ce775d6f05d4`；[CI 44262646574](https://github.com/TangShiJi/mooncddl/actions/runs/44262646574) 成功。公开包 `TangShiJi/mooncddl@0.2.1` 的发布及外部安装记录见 [RELEASE_EVIDENCE.md](RELEASE_EVIDENCE.md)。本次补充复审材料和语法验收工具，未将材料更新冒充新的核心库发布。

重新申报时，应提交最新版申报书，并附此说明及语法案例链接；本仓库更新不会自动替换赛事表单中此前填写的内容。
