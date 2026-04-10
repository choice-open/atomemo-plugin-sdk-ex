# 更新日志

本项目的所有重要变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)，
本项目遵循 [语义化版本](https://semver.org/spec/v2.0.0.html)。

## [Unreleased]

## 0.2.0 - 2026-04-10

### Added

- 凭证定义增加 `oauth2_grant_type`（`:authorization_code` | `:client_credentials`） 。之前的 OAuth2 凭证默认为 `authorization_code` 。
- OAuth2 凭证增加对 `:client_credentials` 流程的支持，开发者只用实现 `oauth2_get_token` 回调。

## 0.1.1 - 2026-04-03

### Fixed

- 因无法对 display 规则进行解析，当 display 存在规则时，不处理 default 值。

## 0.1.0 - 2026-04-03

### Added

- 对 SDK 公开化，发布至 `hex.pm`
- Github Action 自动发布脚本
- Github Action 在发布的同时，会给事实 commit 打上 tag
