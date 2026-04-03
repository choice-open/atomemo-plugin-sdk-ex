# 更新日志

本项目的所有重要变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)，
本项目遵循 [语义化版本](https://semver.org/spec/v2.0.0.html)。

## [Unreleased]

### Fixed

- 因无法对 display 规则进行解析，当 display 存在规则时，不处理 default 值。

## 0.1.0 - 2026-04-03

### Added

- 对 SDK 公开化，发布至 `hex.pm`
- Github Action 自动发布脚本
- Github Action 在发布的同时，会给事实 commit 打上 tag
