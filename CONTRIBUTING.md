# Contributing

提交前运行：

```bash
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
```

语法能力变更必须同步更新 `docs/COMPATIBILITY.md`，并至少增加一个成功用例、一个失败用例和格式往返用例。错误行为应使用已有稳定错误类型，不得静默接受未实现语法。性能敏感改动请运行 `benchmarks/validation` 并说明基线差异。

提交应保持单一目的，提交信息说明行为变化，不用空提交或无意义拆分增加数量。
