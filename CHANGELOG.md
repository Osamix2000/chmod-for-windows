# 📝 Changelog

このファイルには`chmod-for-windows`の主な変更内容を記録します。

バージョン番号はSemantic Versioningを基本とします。

## [Unreleased]

### Added

- なし

## [v1.0.0] - 2026-10-06

### Added

- 初回公開版
- Windows ACLをGNU `chmod`風の書式で操作する`chmod.bat`
- 1～3桁の8進数MODE
- 先頭`0`付き4桁MODE
- `+x`、`u+x`、`go-rwx`などのシンボリックMODE
- `u=rw,go=r`のようなカンマ区切りの複数シンボリックMODE
- `X`による条件付き実行権限相当
- `-R, --recursive`による再帰処理
- `-c, --changes`
- `-v, --verbose`
- `-f, --quiet`
- `--silent`
- `--preserve-root`
- `--no-preserve-root`
- `--version`
- `--help`
- Windows形式の`\`とLinux風の`/`の両方を使用できるパス指定
- `/`から`\`への内部パス正規化
- `~`を現在ユーザーの`%userprofile%`へ展開
- `~/.ssh/id_ed25519`および`~\.ssh\id_ed25519`形式への対応
- 空白を含むパスへの対応
- Windows SIDを利用したローカライズ非依存のACL操作
- `u`を現在ユーザーとして扱うPOSIX風ACLマッピング
- `g`を`BUILTIN\Users`および`Authenticated Users`を基準として扱う近似
- `o`を`Everyone`として扱うACLマッピング
- `r`、`w`、`x`からWindows Generic Rightsへの変換
- ディレクトリの`w+x`相当で`Delete Child`を利用する近似
- 現在のWindows ACLから擬似POSIX MODEを取得する処理
- MODE変更前のACLバックアップ
- ACL変更途中で失敗した場合の自動復元
- Windows Sudoが有効な場合の管理者権限での自動再実行
- Sudo再実行の無限ループ防止
- Sudo再実行でも失敗した場合の専用エラー
- ACL自動復元に失敗した場合、追加変更を避ける安全処理
- ドライブおよびUNC共有ルートに対する再帰処理の保護機能
- Windows版coreutils等の`ls -la`表示と実際のNTFS ACLが一致しない場合がある旨の注意表示
- `icacls`による実際のWindows ACL確認方法の案内

### Known limitations

- GNU/LinuxのPOSIX permissionとWindows ACLは構造が異なるため完全互換ではありません。
- `setuid`、`setgid`、`sticky bit`は未対応です。
- `g=u`、`o=g`などの権限コピーMODEは未対応です。
- POSIXの`u`はファイル所有者ですが、本ツールでは現在のWindowsユーザーとして扱います。
- Windows版coreutils等の`ls -la`で表示される`rwx`は、変更後のNTFS ACLをGNU/Linuxと同じ意味では反映しない場合があります。
