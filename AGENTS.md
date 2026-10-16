# AGENTS.md

この文書は`chmod-for-windows`を変更する人・AIエージェント向けの開発ルールです。

## プロジェクトの目的

このプロジェクトはGNU coreutils `chmod`の完全移植ではありません。

Windows Security Descriptor / ACLを利用し、**Windowsで安全かつ予測可能に再現できる範囲までGNU `chmod`に近い操作感を提供する**ことを目的とします。

最優先事項:

1. WindowsのACL/継承を壊してユーザーを締め出さない
2. GNU/POSIXの意味を理解した上で近似する
3. 「完全互換」と誤認させない
4. 復旧可能性を確保する
5. Windows標準コマンドだけで軽量に動作する方針を尊重する

## 必読ドキュメント

変更前に必ず読むこと。

- `README.md`
- `CHANGELOG.md`
- `.docs/icacls.md`
- `.docs/chmod.md`
- `.docs/update.md`

ACL/permission関連の挙動を変更する場合、READMEだけを根拠にせず`.docs`の背景仕様まで確認してください。

## 情報源の優先順位

仕様判断は原則として次の順に優先します。

### Windows

1. Microsoft Learn / Windows SDK / Windows Protocols等の一次資料
2. 対象Windows実機の`icacls /?`等、実行ファイル自身のヘルプ
3. Microsoft Support/Q&A
4. 実機検証
5. 国内外コミュニティ記事

Microsoft Learnと`icacls /?`が食い違う場合は、差異を記録して実機検証してください。

### GNU/POSIX

1. 対象versionのGNU coreutils source / NEWS / release tarball
2. 対象versionのGNU coreutils manual
3. POSIX.1 / The Open Group仕様
4. Linux man-pages等の実装資料
5. コミュニティ記事

version-dependentな挙動を「GNU chmodはこう」と一般化しないでください。

## 事実・近似・独自仕様を分ける

ドキュメントとコードコメントでは必ず次を区別してください。

- Microsoft/GNU/POSIXの正式仕様
- Windows上での近似
- 実測のみ確認済みの挙動
- 未検証事項
- `chmod-for-windows`独自仕様

例:

- GNU `chmod 777 dir` = `u=rwx,g=rwx,o=rwx`
- 本プロジェクトのdirectory numeric `777` = Windows標準ACL継承状態へ戻す復旧操作

この2つを同じ仕様として説明してはいけません。

## `chmod.bat`のファイル形式

`chmod.bat`は以下を維持してください。

- 文字コード: CP932
- 改行: CRLF
- インデント: タブ

GitHub API等で更新する際、UTF-8へ暗黙変換しないでください。

変更後は可能ならblob hashまたはraw bytesを確認し、文字化けやLF化がないことを検証してください。

MarkdownドキュメントはUTF-8を使用します。

## Windows ACL設計ルール

### DACLだけで全アクセスを説明しない

アクセス不能の原因候補には以下も含まれます。

- Owner / WRITE_DAC / WRITE_OWNER
- UAC / filtered token
- Mandatory Integrity Control
- SeTakeOwnershipPrivilege / SeRestorePrivilege / SeBackupPrivilege等
- SMB Share ACL
- EFS
- File System差
- Reparse Point
- WSL metadata

### Deny ACEを安易に使わない

GNU/POSIX mode bitの削除にExplicit Denyという概念はありません。

Deny ACEは:

- group経由Allowを阻止できる
- Canonical OrderでAllowより強く作用しやすい
- Generic Rightsの重複で副作用を起こしやすい

ため、permission削除は原則としてAllow ACEの置換/削除で近似してください。

### NULL DACLを作らない

NULL DACLは「権限なし」ではなく、通常のDACLアクセスチェックでは全許可に近い状態です。

POSIX `000`近似としてNULL DACLを利用してはいけません。

### `u/g/o`は排他的ではない

現行近似:

- `u`: current user SID
- `g`: BUILTIN\Users中心
- `o`: Everyone

WindowsではこれらのSID membershipが重複するため、POSIXのowner/group/otherと完全等価ではありません。

擬似modeの逆算も不可逆であることを前提にしてください。

### directoryとfileを同じACL処理にしない

fileとdirectoryではSpecific Rightsと継承の意味が異なります。

特にdirectoryでは:

- `(OI)` Object Inherit
- `(CI)` Container Inherit
- Delete Child
- Traverse

等を考慮してください。

### SYSTEM / Administrators

v1.0.1以降、directoryの制限MODEでもSYSTEMとAdministratorsの管理・復旧用Full Controlを維持します。

これはGNU互換ではなくWindows安全策です。

この方針を削除する場合は、管理者での復旧、Windowsサービス、ACL rollbackを含む実機テストが必須です。

### directory `777`

本プロジェクトではnumeric `777`をWindows固有の復旧操作として扱います。

- `chmod 777 dir`: 対象directoryを親からの通常ACL継承状態へ戻す
- `chmod -R 777 dir`: subtreeも通常ACL継承状態へ戻す

`Everyone:F`等を作るliteral POSIX 777として実装し直さないでください。変更する場合は仕様変更として明示的に議論・versioningしてください。

### `/reset`を「元に戻す」と呼ばない

`icacls /reset`は保存済みの元DACLへ復元する機能ではありません。

親由来のdefault/inherited ACLへ置換する処理です。

厳密なrollbackには`icacls /save` / `/restore`等のDACLバックアップを使います。

### `/save`はSecurity Descriptor完全バックアップではない

`icacls /save`が対象とするのはDACLです。

Owner、SACL、Integrity Label等まで完全保存したと説明しないでください。

## `icacls`の文書差異

2026-10時点で:

- Microsoft Learn: `/inheritancelevel:e|d|r`
- Windows実機`icacls /?`: `/inheritance:e|d|r`の報告/実績あり

現行コードは`/inheritance:e` / `/inheritance:r`を使用しています。

Webドキュメント表記だけを見て機械的に置換せず、対象Windows versionsで実機検証してください。

## GNU互換性ルール

### who省略

GNUではwho省略時にumaskの影響があります。

現行Windows版はumask相当がないため概ね`a`扱いです。これは既知の非互換です。

### `X`

GNU semantics:

- directoryならexecute/search対象
- fileなら既に誰かにexecute bitがある場合のみ対象

Windows版でもこの意図を維持してください。

### special bits

以下を「Windowsで似たことができる」という理由だけで同名互換として追加しないでください。

- setuid
- setgid
- sticky bit

追加する場合はGNU semanticsを満たせるかを先に検証してください。

### Symlink / Reparse Point

GNUの`-H/-L/-P`をWindows Symlink/Junction/Mount Pointへ単純コピーしないでください。

再帰処理にReparse Pointを含める変更は、意図しないtree traversalや権限変更の危険があります。

### `--reference`

DACL丸ごとコピーとGNU `--reference`のmode copyは別物です。

互換機能として追加する場合は擬似mode semanticsを優先し、ACL情報損失を明記してください。

## 自己更新機能の不変条件

`v1.0.2`以降の`--update`は配布経路そのものなので、通常のoption追加より厳しく扱います。

### 公開interface

- ユーザー向け公開optionは`--update`
- `--upgrade`は`--update`と完全に同じ処理へdispatchする互換alias
- `--upgrade`はhidden扱いとし、通常の`--help`とREADMEのoption一覧には掲載しない
- hidden aliasを削除・別動作化する場合は明示的な仕様変更として扱う

### `.update`と`chmod.bat`は同一release単位

公開`main`では次の整合性を常に維持してください。

```text
.update version == chmod.bat CHMOD_VERSION
.update sha256 == chmod.bat bytes のSHA-256
```

`chmod.bat`のbytesを変更するcommitでは、配布対象の変更である限り`.update`も**同じtree/commitで**更新してください。

manifestだけ先行、payloadだけ先行という状態を`main`へ作らないでください。

### update source

v1.0.2は次をcanonical sourceとします。

- `https://raw.githubusercontent.com/Osamix2000/chmod-for-windows/main/.update`
- `https://raw.githubusercontent.com/Osamix2000/chmod-for-windows/main/chmod.bat`

そのため`main`は常に自己更新可能なdeployable stateである必要があります。

将来GitHub Releases等へ変更する場合は`.docs/update.md`とtrust modelも更新してください。

### transport / integrity

- `curl.exe`を明示し、PowerShellの`curl` aliasへ依存しない
- HTTP errorを成功扱いにしない
- HTTPS以外のprotocolとredirect先を許可しない
- payload適用前に`.update`のSHA-256と一致することを確認
- 現在versionより古いversionへ自動downgradeしない
- SHA-256はrepo自体から独立したsignatureではないため「署名検証」と表現しない

### ACLを壊さない

自己更新で`chmod.bat`を削除して新規作成しないでください。

v1.0.2では`robocopy /COPY:D`によるdata-only overwriteを使い、既存destinationのDACLを保持します。

変更時は最低限:

- custom/継承無効DACLの更新前後SDDL一致
- 正常更新後bytes一致
- 検証失敗時rollback後bytes一致
- rollback後SDDL一致

をWindows実機で確認してください。

### updater最低テスト

- `--help`に`--update`が存在
- `--help`に`--upgrade`が存在しない
- `--upgrade`が`--update`と同じhandlerへ入る
- extra argumentをusage errorとして拒否
- manifest schema/version/hash不正を拒否
- network failureを安全に終了
- downgradeを行わない
- same version + same hashはno-op
- same version + hash mismatchはcanonical payloadで修復
- SHA-256 mismatchでは適用しない
- destination DACLを維持
- post-copy byte verification failureでrollback
- write permission不足で元fileを破損しない

## 実装ポリシー

- 可能な限りWindows標準コマンドで実装
- 通常処理でPowerShellを必須依存にしない
- SID操作では表示名より数値SIDを優先
- 人間向けローカライズ出力の文字列解析を避ける
- `icacls`等は`%SystemRoot%\System32\...`の明示パスを優先
- ACL操作前にrollback可能な状態を確保
- 途中失敗時は追加変更より復旧を優先
- 復旧に失敗した状態で自動再試行を続けない
- 破壊的再帰ではroot protectionを重視

## 変更時の最低テスト

ACLロジックを変更した場合、最低限以下を一時NTFSディレクトリで確認してください。

### File

- `600`
- `644`
- `+x`
- `u+x`
- `go-rwx`
- `u=rw,go=r`
- SSH private key相当

### Directory

- `700`
- `755`
- `a+rX`
- 新規child file
- 新規child directory
- copyして入れたfile
- 同一volumeからmoveしたfile
- 可能なら別volumeからmoveしたfile

### Recovery

- `chmod 777 dir`
- `chmod -R 777 dir`
- ACL途中失敗時rollback
- Standard User / Elevated Administrator双方

### 確認方法

- `icacls`
- 実際のopen/read/write/create/delete/rename
- `(I)/(OI)/(CI)/(IO)/(NP)`
- Owner

`ls -la`だけでACLテストを合格扱いにしないでください。

## Windows実機マトリクス

重要変更では可能な範囲で:

- Windows 10
- Windows 11
- Windows Server
- NTFS
- ReFS
- local path
- UNC/SMB

を区別してください。

全環境を検証できない場合は、未検証をドキュメントに明記します。

## ドキュメント更新

次の仕様を変更した場合はコードだけで完結させないでください。

- supported MODE
- option
- u/g/o mapping
- inheritance behavior
- recovery behavior
- admin/SYSTEM safety policy
- exit code
- known limitation

最低限README / CHANGELOG / `.docs`の該当箇所を確認してください。

## Versioning

- typo/docsのみ: 通常はversionを上げない
- backward-compatible bug fix: patch
- backward-compatible functionality: minorを検討
- documented semanticsを壊す変更: majorまたは明確なmigrationを検討

versionを自動的に上げず、変更内容に応じて判断してください。

## コミット方針

ユーザーからmainへの直接反映を許可されている場合はmainへコミットして構いません。

ただし:

- 変更前HEADを確認
- 同一pathへのwriteを並列実行しない
- 書き込み後に再取得して検証
- `chmod.bat`のCP932/CRLF維持を確認

を守ってください。

## 最後に

このプロジェクトで重要なのは「Linuxの数字をWindowsへ無理に押し込むこと」ではありません。

GNU/POSIXが何を意味しているのか、Windows Security Modelが何を意味しているのかをそれぞれ理解した上で、**Windows利用者が予測でき、復旧でき、危険な副作用を起こしにくい近似**を選んでください。
