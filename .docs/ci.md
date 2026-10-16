# GitHub Actions / CI 運用方針

この文書は`chmod-for-windows`の常設GitHub Actionsと、workflow変更時のbranch運用をまとめます。

## 基本方針

GitHub Actions関連の追加・変更は、原則として常設branch **`github/actions`** 上で行います。

```text
main
  ↓ branch / sync
 github/actions
  ↓ workflow追加・修正
 GitHub Actionsで検証
  ↓ 全job成功
 mainへ取り込み
```

`main`へ未検証workflowを直接追加しないことを基本とします。

## `github/actions` branch

`github/actions`は特定version専用ではなく、今後のGitHub Actions開発・検証に継続利用するbranchです。

用途:

- 常設CI workflowの追加・変更
- runner / shell / YAML構文の検証
- Windows ACLテストの追加・修正
- release前の新しい検証方法の試作
- mainへ入れる前のActions挙動確認

新しいActions作業を始める際は、必要に応じてmainの最新状態を`github/actions`へ同期してから作業してください。

## 常設workflow

常設CIは`.github/workflows/ci.yml`です。

trigger:

- `main`へのpush
- `github/actions`へのpush
- `main`向けpull request
- `workflow_dispatch`

通常CIはrepositoryへ書き込まず、`contents: read`で実行します。

## Package / CLI job

配布物そのものの破損を早期検出します。

現在の主な検証:

- `chmod.bat`がCP932でround-trip可能
- LF-only改行がなくCRLFを維持
- `CHMOD_VERSION`の形式
- `:apply_file_acl` labelの存在
- `.update`のschema/version
- `.update sha256 == chmod.bat bytes SHA-256`
- `--version`
- `--help`
- quoted compound symbolic MODE (`"u=rw,go=r"`)
- usage errorの終了code

version番号をworkflowへ固定せず、`chmod.bat`と`.update`から現在versionを取得することを原則とします。

## Windows ACL semantics job

`windows-latest`の一時領域で実際にACLを変更し、単なる文字列検査ではなくWindows上の意味を確認します。

現在の主な検証:

- 非再帰`chmod 700 DIR`
- 既存childのaccess rulesを意図せず変更しない
- directoryのSYSTEM / Administrators Full Control
- future-child用`InheritOnly` template
- 新規childが通常のWindows ACLを受ける
- file `600`でSYSTEM / Administratorsを自動追加しない
- custom inheritable parent ACEをtarget自身へ漏らさずfuture childへ継承
- `chmod -R 700 DIR`
- 再帰処理後に作成したfuture childの通常ACL
- `chmod -R 777 DIR`によるWindows標準inheritance復旧

`ls -la`ではなく、Windows ACL API / `Get-Acl` / `icacls`相当の情報を基準にします。

## 常設CIへ入れないもの

release作業専用・一度限りの診断を常設workflowへ混ぜないでください。

例:

- 特定version名を埋め込んだcandidate builder
- 一時diagnose workflow
- source ACLの調査だけを行うworkflow
- docsを書き換えるworkflow
- release payloadを生成・pushするworkflow

必要なら`github/actions`上で一時的に追加し、目的を終えたら削除します。

## 自己更新E2E

`chmod --update`はcanonical sourceとしてmainの`.update` / `chmod.bat`を参照します。

そのため開発branchの通常CIで無条件に`--update`を実行すると、開発中candidateがmain版へ置き換わり、意図したテストにならない場合があります。

自己更新E2Eはrelease時の専用検証として扱います。

最低限:

- 前versionの**実配布updater**を使用
- candidateのmanifest / payloadを固定commit等で明示
- 更新後bytesがcandidateと完全一致
- destination DACLが維持される
- 更新後`--version`がcandidate versionになる

を確認してください。

## 一時workflowの命名

一時workflowを作る場合は、常設workflowと区別できる名前にします。

推奨:

```text
.github/workflows/tmp-<purpose>.yml
```

特定version専用の場合のみversion番号を含めても構いません。

一時workflowをmainへ残さないでください。

## `tmp-v1.0.2-build`について

`tmp-v1.0.2-build`はv1.0.2 / v1.0.3開発時の一時検証branchで、version名が固定されているため今後の標準Actions開発branchには使用しません。

今後は`github/actions`を使用します。

古い一時branch / workflowを参照する場合は、過去の検証資料としてのみ扱ってください。

## mainへ取り込む条件

最低限:

1. `github/actions`上で対象workflowが実際に起動する
2. `Package / CLI`が成功する
3. `Windows ACL semantics`が成功する
4. workflowに不要なwrite permissionがない
5. version固定・一時path・debug output等が常設workflowへ残っていない
6. mainへ取り込んだ後もmain pushのCIが成功する

を確認します。

## workflow変更時の注意

- GitHub ActionsのYAMLはjob生成前に構文エラーになることがあるため、実runの発生まで確認する
- PowerShell 7 (`pwsh`)とWindows PowerShell 5.1 (`powershell.exe`)の挙動を混同しない
- CP932の`chmod.bat`をUTF-8として書き戻さない
- CIが`chmod.bat`を書き換える設計にしない
- permanent CIでrepositoryへのpushを行わない
- runner image更新で挙動差が出た場合は、OS build / runner image versionも記録する

## 2026-10-16 初回常設CI検証

`github/actions`上の初回runで、Windows Server 2025 / build 26100の`windows-latest` runnerにより以下の2 jobが成功しました。

- `Package / CLI`
- `Windows ACL semantics`

この成功を確認したworkflowをmainへ取り込む方針とします。
