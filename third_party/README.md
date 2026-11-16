# 外部数据与测试工具

- Blocks-13.0.0.txt：Unicode 官方数据，保留文件头。来源：https://github.com/unicode-org/unicodetools/blob/main/unicodetools/data/ucd/13.0.0-Update/Blocks.txt
- unicode_data.mbt：Python 3.9 unicodedata (Unicode 13.0.0) 类别与上述 Blocks 的生成结果。生成器 scripts/generate_unicode.py，数据许可 UNICODE-LICENSE.txt。
- 不将生成的 Unicode 表计作手工实现规模。
- anweiss/cddl 0.10.7 (MIT) 与 lxml/libxml2 (BSD/MIT) 仅在 CI 下载/安装作对照，不复制进核心库；核心发布包无需它们。
- CDDL 与 XSD 根据公开标准独立实现，未移植开源项目；规范链接见 NOTICE。
