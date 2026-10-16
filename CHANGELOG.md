# 📝 Changelog

このファイルには`chmod-for-windows`の主な変更内容を記録します。

バージョン番号はSemantic Versioningを基本とします。

## [Unreleased]

### Added

- なし

### Documentation

- `v1.0.1`以前から`v1.0.2`への初回移行は`--update`未搭載のため手動bootstrapが必要である点を明確化
- 公開Raw GitHub版を使ったremote>local、same-version no-op/repair、downgrade抑止、hidden `--upgrade`のE2E結果を記録
- 実行中BAT自己書換えについて、親processの後処理を同一括弧blockへ保持する実装上の不変条件を文書化
- サイズ・label配置が大幅に異なるsynthetic future payloadへの自己更新stress test成功を記録

## [v1.0.3] - 2026-10-16

### Fixed

- v1.0.1のfile/directory ACL分離時に`:apply_file_acl`ラベルが欠落し、directory ACL適用後に旧file ACL処理へfall-throughし得た制御フロー回帰を修正
- directoryへ`700`等を適用した際、対象directoryのu/g/o MODE ACEをそのままfuture childへ継承させ、Windows標準の新規child ACLまで制限MODEへ寄せてしまう設計を修正
- `u=rw,go=r`等の複合symbolic MODEについて、`cmd.exe` / batch引数解析上MODE全体の引用が必要なのにhelp/README例が未引用だった問題を修正

### Changed

- 数値`777`以外のdirectory ACLを、対象自身へ有効なMODE ACEとfuture-child用のWindows inheritance templateへ分離
- parent directoryの継承可能ACEを`InheritOnly` templateとして保持し、chmod対象自身のeffective accessへ親ACLを漏らさず、将来childへ通常Windows ACLを継承できる構成へ変更
- directoryでは従来どおり`SYSTEM`と`Administrators`のFull Controlを維持
- 対象directoryにもともと存在する、本プロジェクト管理SID以外のExplicit ACEを可能な範囲で保持
- directory Raw ACL再構成ではWindows標準のWindows PowerShell 5.1 / .NET ACL APIと`SetNamedSecurityInfoW`を内部利用
- file ACL処理、SSH秘密鍵向け`600`等、directory numeric `777`のWindows復旧動作は維持
- `=`または`,`を含む複合symbolic MODEは、`chmod "u=rw,go=r" file`のようにMODE全体を引用する使用方法を正式に明記

### Validation

- Windows Server 2025 / build 26100 / NTFSでdirectory `700`、既存child、新規child、独自parent inheritable ACE、file `600`、`-v`、`-c`、`-R 700`、`-R 777`、symbolic `u+x`、quoted compound symbolic MODEを検証
- 既存childについて、Windowsがauto-inheritance control metadataを更新し得る点を考慮し、access rule signatureが維持されることを確認
- final `chmod.bat`についてCP932 round-trip、CRLF-only、組み込み`--help`を検証
- 実配布v1.0.2 updaterからfinal v1.0.3候補へのE2Eを行い、更新後bytes完全一致、destination DACL SDDL維持、`--version`=`v1.0.3`を確認

### Documentation

- `.docs/v1.0.3.md`を追加し、制御フロー回帰の原因、directory自身とfuture-child ACLの分離、Raw ACL適用方式、依存関係、実機検証結果を記録
- README / AGENTSへv1.0.3のdirectory inheritance設計とWindows PowerShell 5.1内部依存を反映

## [v1.0.2] - 2026-10-16

### Added

- `chmod --update`を追加し、GitHub `main`の公開版へ自己更新できるよう対応
- `--upgrade`を`--update`と同じ処理を行うhidden aliasとして追加（`--help`には非掲載）
- `.update` manifestを追加し、公開versionと`chmod.bat`のSHA-256を配布情報として管理
- `.docs/icacls.md`を追加し、Windows Security Descriptor、DACL/SACL/ACE、継承、Owner、MIC、UAC、特権、File System差、`icacls`全般の仕様・注意点を整理
- `.docs/chmod.md`を追加し、POSIX/GNU `chmod`のnumeric/symbolic MODE、umask、`X`、special bits、recursive、symlink、GNU拡張等を整理
- `.docs/update.md`を追加し、自己更新の取得元、integrity check、ACL保持、rollback、trust modelを整理
- `.docs/README.md`を追加し、仕様調査ドキュメントの索引と情報源優先順位を整理
- ルート`AGENTS.md`を追加し、GNU/POSIXとWindows ACLの仕様を混同しない為の開発・検証・安全ルールを定義

### Changed

- 参照するGNU coreutilsのversion表記を、2026-10時点の公式stable releaseである`9.11`へ訂正
- 自己更新では現在versionより古い公開版へのdowngradeを行わず、同一version/同一SHA-256ならno-opとするよう設計
- 同一versionでも現在の`chmod.bat`が公開SHA-256と異なる場合は、canonical payloadから修復できるよう設計

### Security

- 更新情報とpayloadをHTTPSで取得し、`curl.exe --fail`とprotocol制限を使用
- ダウンロードした`chmod.bat`を`certutil.exe`でSHA-256検証してから適用
- 更新前に現在file dataを一時バックアップし、適用後のbyte比較に失敗した場合はrollback
- `robocopy /COPY:D`によるdata-only overwriteを使用し、既存`chmod.bat`のWindows DACLを維持

### Documentation

- Microsoft LearnとWindows実機`icacls /?`で継承オプション表記に差がある点を記録し、実機検証待ち事項として整理
- `icacls /save`をSecurity Descriptor完全バックアップではなくDACLバックアップとして扱う方針を明確化
- GNU `chmod`互換部分、Windows近似部分、本プロジェクト独自仕様を区別する設計方針を文書化
- Windows Server 2025 / build 26100でv1.0.2自己更新の生成、SHA-256、CP932/CRLF、ACL保持、rollbackを検証

## [v1.0.1] - 2026-10-14

### Fixed

- ディレクトリへ`700`等を適用した際、子要素へ必要なACLが継承されず、移動・作成したファイルへ通常ユーザーからアクセスできなくなる場合がある問題を修正
- ディレクトリへ`777`を適用しても、無効化されたWindows ACL継承が復旧せず通常状態へ戻せない問題を修正
- ディレクトリACL変更後に`SYSTEM`および`Administrators`の管理アクセスが失われ、管理者権限でも復旧しづらくなる問題を修正

### Changed

- ファイルとディレクトリのACL適用処理を分離
- ディレクトリの`u/g/o`相当ACEへ`(OI)(CI)`を付与し、子ファイル・子ディレクトリへ継承するよう変更
- ディレクトリでは`SYSTEM`および`Administrators`へFull Controlを維持するよう変更
- ディレクトリへの数値MODE `777`を、Windows標準のACL継承状態へ戻す復旧操作として扱うよう変更
- `chmod -R 777 DIR`では配下のファイル・ディレクトリもACL継承を再有効化し、通常のWindows ACLへ戻すよう変更
- ファイル単体の数値MODE処理は、SSH秘密鍵等の用途を維持する為、従来どおり明示ACLを設定する動作を維持

### Documentation

- `g`のWindows ACL対応について、書き込み時は`BUILTIN\Users`、読み取り時は`Authenticated Users`も考慮する実装に合わせて説明を修正
- ディレクトリのACL継承と`777`のWindows固有動作をREADMEへ追記

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
