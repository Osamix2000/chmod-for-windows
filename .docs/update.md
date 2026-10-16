# `--update` 自己更新仕様

> 初版: v1.0.2  
> 調査・検証基準日: 2026-10-16  
> 対象: `chmod-for-windows`の自己更新経路

## 1. 目的

`chmod-for-windows`は単一の`chmod.bat`をPATHへ配置して使う軽量ツールであるため、package managerを別途導入しなくても公開最新版へ更新できるよう`v1.0.2`から自己更新を提供する。

ユーザー向けinterface:

```bat
chmod --update
```

`--upgrade`も同じhandlerへ入るが、これはhidden aliasであり通常の`--help`/READMEには表示しない。

自己更新はGNU `chmod`由来の機能ではなく、`chmod-for-windows`独自機能である。

### 初回bootstrap

`--update`自体が`v1.0.2`で初めて追加されたため、**実際のv1.0.1以前の`chmod.bat`から`chmod --update`を実行してv1.0.2へ移行することはできない**。

したがって:

- v1.0.1以前 → v1.0.2: 最初の1回だけ手動更新
- v1.0.2以降 → 将来version: `chmod --update`を利用可能

とする。

CIで`remote > local`を検証する場合、v1.0.2のupdater codeを保持したままversion markerだけを過去versionへ変更したsynthetic old copyを使用する。これはversion比較・更新経路の検証であり、「実際のv1.0.1にupdaterが存在した」ことを意味しない。

---

## 2. Canonical source

v1.0.2はGitHub `main`を公開sourceとする。

```text
Manifest:
https://raw.githubusercontent.com/Osamix2000/chmod-for-windows/main/.update

Payload:
https://raw.githubusercontent.com/Osamix2000/chmod-for-windows/main/chmod.bat
```

この設計では`main`が常にdeployable stateであることが重要。

`.update`と`chmod.bat`を別commitで順次更新すると、その間にversion/hash不一致状態を公開するため、release時には同じGit tree/commitで整合させる。

`chmod.bat`はCP932 + CRLFのbytes自体が配布物であり、Gitの改行変換でpayload SHA-256が変化しないよう`.gitattributes`で`chmod.bat -text`を指定する。

---

## 3. Manifest

schema 1:

```text
schema=1
version=v1.0.2
sha256=<64 hexadecimal characters>
```

### `schema`

parser互換性を管理する。未知schemaは拒否する。

### `version`

```text
vMAJOR.MINOR.PATCH
```

形式のみ許可する。

### `sha256`

公開`chmod.bat`bytesのSHA-256。

manifest parserは未知keyを将来拡張用として無視できるが、必須keyが欠ける/不正なら更新を停止する。

---

## 4. 使用するWindows標準コマンド

### `curl.exe`

Manifest/Payload取得。

Windowsにはupstream curl由来の`curl.exe`が含まれる。PowerShell 5.1では`curl`が`Invoke-WebRequest` aliasになり得るため、実装では`curl.exe`の実体を明示的に探して使用する。

v1.0.2の主要option:

```text
--fail
--location
--silent
--show-error
--connect-timeout 15
--max-time 60
--retry 2
--proto "=https"
--proto-redir "=https"
```

目的:

- HTTP 4xx/5xxを成功downloadとして採用しない
- redirectを許容しつつHTTPS以外へ落とさない
- 永久hangを避ける
- 一時的network errorへ限定的にretry

### `certutil.exe`

```text
certutil -hashfile FILE SHA256
```

でpayload/current fileのSHA-256を取得する。

`certutil`の人間向け文言はOS languageで変化し得るため、成功メッセージ文字列そのものは判定材料にしない。v1.0.2は出力を一時fileへ保存し、hash lineを抽出して64桁hexであることも検証する。

quoted executable pathを`for /f ('command')`へ直接埋め込むと追加の`cmd.exe`解析層で引用符問題が起き得るため、現行実装は一度一時fileへ標準出力を保存してから読む。

### `robocopy.exe`

backup/apply/rollbackのdata copyに使用。

```text
/COPY:D
```

Microsoft仕様では`D`はDataのみ。`S`(ACL)、`O`(Owner)、`U`(Auditing)をコピーしない。

またRobocopyはUnix的な0=success / nonzero=failureではなく、**8以上がcopy failure**であるため、`errorlevel >= 8`を失敗として扱う。

### `fc.exe`

```text
fc /b candidate target
```

で適用後bytesをbinary比較する。

---

## 5. Tool discovery

通常は以下を優先する。

```text
%SystemRoot%\Sysnative\tool.exe
%SystemRoot%\System32\tool.exe
```

32bit processから64bit System32へ到達する場合のfilesystem redirectionを考慮し、`Sysnative`が存在すれば優先する。

PATH上の同名toolを無条件に信用しない。

---

## 6. 更新判定

### remote < local

更新しない。

```text
現在の方が新しいためdowngradeしない
```

### remote == local / SHA-256一致

最新版としてno-op。

### remote == local / SHA-256不一致

同じversion文字列でもlocal bytesがcanonical payloadと異なるため、公開payloadを取得して修復する。

これは手動編集、途中破損、過去の不完全配布等からのrepair pathになる。

### remote > local

通常update。

---

## 7. DownloadとIntegrity check

処理順序:

1. Manifest取得
2. schema/version/hash形式検証
3. local version/hash取得
4. 更新不要なら終了
5. Payload取得
6. Payload SHA-256計算
7. Manifest SHA-256と完全一致する場合のみ適用へ進む

ManifestとPayloadの取得の間に`main`が更新された場合、hash不一致として安全側へ失敗できる。

---

## 8. Trust model

SHA-256検証が保証するのは:

- download破損の検出
- ManifestとPayloadの不一致検出

である。

**独立したauthenticity/signature検証ではない。**

攻撃者がGitHub repository/mainを変更できる場合、payloadとmanifest hashを同時に置換できるためSHA-256だけでは検出できない。

将来的にtrust modelを強化する候補:

- GitHub Releasesをimmutable release sourceとして利用
- release assetへ独立署名
- pinned public keyによる署名検証
- trusted CIでmanifest/signatureを生成

ただしv1.0.2では単一BAT・Windows標準tool中心という設計を優先し、HTTPS + repo-controlled hashとする。

---

## 9. Apply方式とACL保持

### なぜdelete + renameを避けるか

Windowsではfileを削除して新しいfileを作ると、Security Descriptor/ACLが親から再継承される等、元の`chmod.bat`と異なるsecurity stateになる可能性がある。

特にこのプロジェクト自身がACL操作toolなので、自己更新によってユーザーが設定したACLを壊すのは避ける。

### v1.0.2方式

更新対象fileを残したまま:

```text
robocopy ... /COPY:D
```

でDataだけを上書きする。

CIでは継承を無効化したcustom DACLを対象に、更新前後のSDDL一致を確認した。

---

## 10. 実行中BATの更新

現在実行中の親`chmod.bat`から直接複雑な置換を継続せず、現在fileのcopyを一時runnerとして作る。

概念:

```text
chmod.bat --update
  |
  +-- manifest/payload/backup準備
  |
  +-- TEMP\apply.bat --__apply-update
        |
        +-- candidate hash再確認
        +-- target data上書き
        +-- fc /b verification
        +-- failureならrollback
```

`--__apply-update`はinternal entry pointであり、必要な環境変数/tokenが揃わない直接呼び出しはusage errorとして拒否する。

### CMD自己書換えに関する不変条件

`cmd.exe`の実行中BAT自己書換えは、Microsoftが「任意の位置・任意の書換えでも安全」と保証しているAPIではない。実用上、`cmd.exe`はBATを逐次読み進めるため、実行中fileのサイズや行位置が変化すると後続処理を誤読する危険がある。

v1.0.2では、子runnerを起動してtarget `chmod.bat`を上書きした**後**に親processが必要とする処理を、次のように同一の括弧blockへまとめる。

```bat
(
    "%ComSpec%" /d /c ""%UPDATE_RUNNER%" --__apply-update"
    if errorlevel 1 (
        rem error handling
        exit /b 1
    )
    rem success message / cleanup
    exit /b 0
)
```

CMDの括弧blockは実行前にblock全体がparseされる性質があるため、子runner待機中に親script本体が別bytesへ置換されても、上記block内の後処理を継続できるようにしている。

この構造は**実装上の安全不変条件**とする。

- runner起動後のerror handling / success message / cleanup / `exit /b`をblock外へ安易に移動しない
- 「読みやすくする」目的だけで別labelへの`goto`へ分解しない
- この部分を変更した場合は、同一サイズのupdateだけでなく、サイズ・label位置が大きく変化するfuture payloadへのstress testを行う
- この挙動はWindows Server 2025で実測済みだが、Microsoftによる自己書換えBATの正式な互換性保証とは区別する

2026-10-16のCIでは、実際のv1.0.2 updaterから、サイズ・label配置が大幅に異なるsynthetic `v9.9.9` payloadへ更新するstress testを実施し、親`cmd.exe`がupdate後のcleanup/returnまで正常完走し、target bytesがfuture payloadと一致することを確認した。

---

## 11. Backup / Rollback

更新前に現在の`chmod.bat`dataをTEMPへ保存する。

適用後に:

```text
fc /b candidate installed
```

が失敗した場合、backup dataを`robocopy /COPY:D`で既存targetへ戻し、再度byte比較する。

rollbackでもtarget file自体を削除/再作成しないため、destination DACLを維持する。

なお`icacls /save`は自己更新rollbackには使用しない。ACL自体を変更しないdata-only方式なので、DACL backup/restoreより「Security Descriptorを触らない」ことを優先する。

---

## 12. 権限不足

v1.0.2の`--update`はWindows Sudoによる自動昇格を行わない。

Program Filesや管理者ACLのdirectory等、現在processが`chmod.bat`へ書き込めない場合は更新に失敗し、元fileを可能な限り維持して終了する。

必要ならユーザーがElevated Command Promptで再実行する。

通常のACL操作で使うWindows Sudo retryと、自己更新のcode replacementはrisk profileが異なるため、初版では自動昇格を分離している。

---

## 13. hidden `--upgrade`

内部互換alias:

```bat
chmod --upgrade
```

は`--update`と同じ`:self_update`へdispatchする。

ルール:

- behaviorを分岐させない
- `--help`へ掲載しない
- READMEの通常option一覧へ掲載しない
- testでaliasが残っていることを確認する

---

## 14. Error / Exit code

既存wrapper方針に合わせる。

- `0`: 最新、downgrade抑止、またはupdate成功
- `1`: network/tool/hash/apply/rollback等の実行時エラー
- `2`: extra argument、internal handler直接呼び出し等のusage error

`curl`、`robocopy`等のnative exit codeをそのまま外部interfaceにはしない。

---

## 15. Windows Server 2025 CI検証

2026-10-16、GitHub Actions `windows-latest`（Windows Server 2025 / build 26100）でv1.0.2候補および公開後Raw GitHub版を検証した。

### 生成・適用・rollback検証

確認項目:

- CP932 decode
- CRLFのみであること
- `--version` = v1.0.2
- `--help`に`--update`が存在
- `--help`に`--upgrade`が存在しない
- `--update` extra argument拒否
- internal apply direct call拒否
- candidate SHA-256と`.update`一致
- data-only update後のbytes一致
- custom DACLの更新前後SDDL一致
- 意図的なpost-copy検証失敗時のrollback
- rollback後bytes一致
- rollback後SDDL一致

### 公開Raw GitHub E2E

公開済み`main`のRaw GitHub payloadを直接取得して次を確認した。

- Raw payload SHA-256がmanifest値と一致
- updater codeを保持したsynthetic v1.0.1 → 公開v1.0.2更新
- v1.0.2 + canonical bytes → no-op
- v1.0.2 + local改変bytes → canonical payloadへrepair
- synthetic v1.0.3 → v1.0.2へのdowngradeを抑止しbytes不変
- hidden `--upgrade` → `--update`と同じ経路で成功

実際のv1.0.1には`--update`実装がないため、「v1.0.1 → v1.0.2」のversion比較テストはv1.0.2 updater codeのversion markerだけを下げたsynthetic copyで行った。bootstrapの事実とは分ける。

### 構造変更stress test

v1.0.2と大きく異なるサイズ/label配置のsynthetic v9.9.9 payloadへ自己更新し、実行中親BATが置換された後も、事前parseされた括弧blockによって成功処理・cleanup・returnまで完走することを確認した。

このテストは「現在の構造が実Windowsで機能する」ことを確認するもので、Microsoftが将来の全cmd.exeで自己書換えを正式保証しているという意味ではない。

検証済みv1.0.2 payload SHA-256:

```text
911d2b664eaf863f832b3c84a0d9facd051c566cc24fe7dbe2b47dba327b1b73
```

---

## 16. Release時チェック

1. `CHMOD_VERSION`を確認
2. CP932 + CRLF + tab indentationを確認
3. `.gitattributes`で`chmod.bat -text`が維持されていることを確認
4. `--help`に公開optionだけが載ることを確認
5. Windows CIを通す
6. final `chmod.bat`bytesからSHA-256を計算
7. `.update` version/hashを同じ値へ設定
8. `chmod.bat`と`.update`を同じGit tree/commitへ入れる
9. Git indexの`chmod.bat` blobとworking-tree raw bytesがGit filter/改行変換で変化していないことを確認
10. 公開後、前versionの**updater搭載版**から実際に`--update`してend-to-end確認
11. 同versionで再度`--update`してno-op確認
12. 同versionの改変copyからrepair確認
13. newer synthetic versionでdowngrade抑止確認
14. updaterの自己書換え構造を変更した場合は、大幅に構造が異なるfuture payloadへのstress testを行う

`v1.0.2`は自己更新初版のため、実際のv1.0.1からのE2Eは存在しない。v1.0.1以前からv1.0.2への移行は手動bootstrapとする。v1.0.2以降のreleaseでは、前versionの実配布updaterから次versionへのE2Eを必須にする。

---

## 17. 一次資料・補助資料

Microsoft:

- curl on Windows  
  https://learn.microsoft.com/en-us/windows/curl/
- certutil (`-hashfile`)  
  https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certutil
- robocopy (`/COPY`, return codes)  
  https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy
- call  
  https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/call

curl upstream:

- curl manpage  
  https://curl.se/docs/manpage.html

CMDの実行中BAT自己書換えについてはMicrosoftが安全な自己更新APIとして正式保証しているわけではないため、国内外の実測/コミュニティ知見も補助的に参照し、最終判断はWindows実機stress testで行う。

GitHub raw contentはrelease transportとして利用しているが、GitHub自体から独立した署名検証ではない点に注意する。
