# 🪟 chmod - Windows ACL chmod互換ラッパー

WindowsのACLを、Linux/GNU `chmod`に近い書式で操作する為の軽量なバッチスクリプトです。

`icacls`を直接覚えたり複雑なACL操作を毎回組み立てたりせず、次のような書き方でWindows上のアクセス権を変更できます。

```bat
chmod 600 ~/.ssh/id_ed25519
chmod +x example.sh
chmod "u=rw,go=" "C:/keys/private_key"
chmod -R a+rX "C:/tools"
```

> [!IMPORTANT]
> GNU/LinuxのPOSIX permissionとWindows ACLは構造が異なる為、完全互換ではありません。  
> このプロジェクトは、Windows ACLで再現・近似できる範囲までGNU `chmod`に近い操作感を提供する事を目的としています。

<a id="toc"></a>
## 📚 目次

- [✨ 概要](#overview)
- [🚀 主な機能](#features)
- [📦 インストール](#install)
- [🧭 基本的な使い方](#usage)
- [🔐 SSH秘密鍵](#ssh)
- [🔢 数値MODE](#numeric-mode)
- [🧩 シンボリックMODE](#symbolic-mode)
- [📂 パス指定](#paths)
- [⚙️ オプション](#options)
- [⬆️ 自己更新](#update)
- [🛡️ Windows Sudoによる自動再実行](#sudo)
- [🔄 Windows ACLとの対応](#acl-mapping)
- [🔍 権限の確認方法](#check-permissions)
- [📤 終了コード](#exit-codes)
- [⚠️ 制限事項・注意点](#limitations)
- [🧪 使用例](#examples)
- [✅ 開発・CI](#ci)
- [📝 変更履歴](#changelog)

<a id="overview"></a>
## ✨ 概要

Windowsには`icacls`などのACL操作コマンドがありますが、Linuxの`chmod`と比べると構文やアクセス権モデルが大きく異なります。

`chmod-for-windows`は、Windows標準機能を利用しながら、可能な範囲で次のようなGNU `chmod`風の操作を行えるようにします。

```bat
chmod 600 file
chmod 755 directory
chmod +x example.sh
chmod u+x file
chmod go-rwx private.key
chmod "u=rw,go=r" file
chmod -R a+rX directory
```

ユーザー向けinterfaceは`chmod.bat`単体です。v1.0.3では数値`777`以外のディレクトリACLを安全に再構成するため、Windows標準のWindows PowerShell 5.1を内部的に使用します。PowerShell 7 / `pwsh`は不要です。

GNU coreutils 9.11の`chmod`の書式や挙動を参考にしていますが、GNU `chmod`そのものの移植や完全互換実装ではありません。

<a id="features"></a>
## 🚀 主な機能

- 1～3桁の8進数MODE
- 先頭`0`付き4桁MODE
- `+x`、`u+x`、`go-rwx`などのシンボリックMODE
- `"u=rw,go=r"`のようなカンマ区切りの複数指定
- GNU `chmod`の`X`に近い条件付き実行権限
- `-R`による再帰処理
- `-c, --changes`
- `-v, --verbose`
- `-f, --quiet`
- `--preserve-root`
- `--update`によるGitHubからの自己更新
- `/`と`\`の両方を使用できるパス指定
- `~`を現在ユーザーのホームディレクトリとして展開
- ACL変更前のバックアップ
- 途中失敗時のACL自動復元
- Windows Sudoが利用可能な場合の自動再実行
- SIDを利用したローカライズ非依存のACL操作
- ユーザー操作は`cmd.exe`から完結。数値`777`以外のディレクトリACL処理ではWindows標準のWindows PowerShell 5.1を内部利用
- ディレクトリ自身のMODE ACEとfuture-child用Windows inheritance templateを分離し、親の通常ACLを新規子へ引き継げるよう構成
- ディレクトリへの数値MODE `777`でWindows標準のACL継承状態へ復旧

<a id="install"></a>
## 📦 インストール

1. `chmod.bat`を任意のディレクトリへ配置します。
2. そのディレクトリをユーザーの`PATH`へ追加します。
3. 新しいコマンドプロンプトを開きます。
4. 次のコマンドで確認します。

```bat
chmod --version
```

例えば、次のような配置が使用できます。

```text
%userprofile%\bin\chmod.bat
```

その場合は、ユーザー環境変数`PATH`へ次を追加します。

```text
%userprofile%\bin
```

<a id="usage"></a>
## 🧭 基本的な使い方

基本構文はGNU `chmod`と同様です。

```text
chmod [OPTION] MODE FILE...
```

例:

```bat
chmod 600 file
chmod 644 file
chmod 755 directory
chmod +x example.sh
chmod u+x example.sh
chmod go-rwx private.key
```

複数の対象も指定できます。

```bat
chmod 600 key1 key2 key3
```

<a id="ssh"></a>
## 🔐 SSH秘密鍵

SSH秘密鍵の権限を絞る用途では、次のように使用できます。

```bat
chmod 600 ~/.ssh/id_ed25519
```

Windows形式の区切り文字も使用できます。

```bat
chmod 600 ~\.ssh\id_ed25519
```

`~`は現在のWindowsユーザーの`%userprofile%`へ展開されます。

例えば、

```text
~/.ssh/id_ed25519
```

は内部的に次のようなパスとして扱われます。

```text
C:\Users\UserName\.ssh\id_ed25519
```

<a id="numeric-mode"></a>
## 🔢 数値MODE

1～3桁の8進数MODEと、先頭`0`付き4桁MODEを使用できます。

```bat
chmod 7 file
chmod 77 file
chmod 600 file
chmod 644 file
chmod 755 directory
chmod 0755 directory
```

短いMODEは左側を`0`として扱います。

| 入力 | 内部的な扱い |
|---:|---:|
| `7` | `007` |
| `77` | `077` |
| `600` | `600` |
| `644` | `644` |
| `755` | `755` |
| `0755` | `755` |

`setuid`、`setgid`、`sticky bit`に相当する特殊ビットはWindows ACLに直接対応しない為、次のような指定には対応していません。

```text
4755
2755
1777
```

<a id="symbolic-mode"></a>
## 🧩 シンボリックMODE

GNU `chmod`に近いシンボリックMODEを使用できます。

```bat
chmod +x example.sh
chmod u+x example.sh
chmod go-rwx private.key
chmod "u=rw,go=r" file
chmod a+rX directory
```

> [!IMPORTANT]
> `cmd.exe` / batchの引数解析上、`=`または`,`を含む複合シンボリックMODEは、MODE全体を引用してください。
>
> ```bat
> chmod "u=rw,go=r" file
> chmod "u=rw,go=" private.key
> ```

対応する`who`:

| 指定 | Windows側での扱い |
|---|---|
| `u` | 現在のユーザー |
| `g` | 書き込み時は`BUILTIN\Users`。現在ACLの読み取り時は`Authenticated Users`も考慮 |
| `o` | `Everyone` |
| `a` | `u`、`g`、`o`すべて |

`who`を省略した場合は、WindowsにPOSIX `umask`と同等の仕組みがない為`a`として扱います。

その為、

```bat
chmod +x example.sh
```

は、このツールでは概ね次と同じ意味になります。

```bat
chmod a+x example.sh
```

### 条件付き`X`

`X`はGNU `chmod`に近い動作として、次の場合に実行権限相当を追加します。

- 対象がディレクトリ
- 対象ファイルですでにいずれかの`u/g/o`に実行権限相当がある

例:

```bat
chmod -R a+rX "C:/tools"
```

<a id="paths"></a>
## 📂 パス指定

Windows形式の`\`とLinux風の`/`をどちらも使用できます。

```bat
chmod 600 "C:\keys\private.key"
chmod 600 "C:/keys/private.key"
```

入力された`/`は内部で`\`へ正規化されます。

現在ユーザーのホームディレクトリは`~`で指定できます。

```bat
chmod 600 ~/.ssh/id_ed25519
chmod 600 ~\.ssh\id_ed25519
```

`~user/...`のような他ユーザーのホームディレクトリ指定には対応していません。

空白を含むパスは引用符で囲んでください。

```bat
chmod 600 "~/My Keys/private_key"
```

<a id="options"></a>
## ⚙️ オプション

| オプション | 説明 |
|---|---|
| `-R, --recursive` | ディレクトリ配下を再帰的に変更 |
| `-c, --changes` | 実際にMODEが変化した対象だけ表示 |
| `-v, --verbose` | 変更有無を含め対象ごとに表示 |
| `-f, --quiet` | ほとんどのエラー、警告、補助表示を抑制 |
| `--silent` | `--quiet`と同じ |
| `--preserve-root` | `-R`指定時、ドライブまたはUNC共有のルートを拒否 |
| `--no-preserve-root` | ルート保護を無効化。現在の既定値 |
| `--update` | GitHubの公開版を確認し、必要なら最新版へ自己更新 |
| `--version` | バージョンを表示 |
| `--help` | ヘルプを表示 |

例:

```bat
chmod -R 755 "C:/tools"
chmod -c 644 "C:/work/config.txt"
chmod -v +x example.sh
chmod -R --preserve-root 755 "C:/tools"
```

<a id="update"></a>
## ⬆️ 自己更新

`v1.0.2`以降は、現在の`chmod.bat`をGitHub上の公開版へ更新できます。

```bat
chmod --update
```

> [!NOTE]
> `--update`自体は`v1.0.2`で追加された為、`v1.0.1`以前から`v1.0.2`へ移行する最初の1回だけは手動更新が必要です。`v1.0.2`以降から将来versionへの更新で`--update`を利用できます。

更新処理では、リポジトリ`main`ブランチの`.update`と`chmod.bat`をHTTPSで取得し、公開versionとSHA-256を確認してから現在のファイルを更新します。

主な安全策:

- `curl.exe`でHTTPエラーを失敗扱いにし、HTTPS以外のprotocol/redirectを拒否
- ダウンロードした`chmod.bat`を`certutil.exe`でSHA-256検証
- 現在versionより古い公開版へのdowngradeを行わない
- 同一versionかつ同一SHA-256なら何も変更しない
- 同一versionでもローカル内容が公開版と異なる場合は、公開版から修復可能
- 更新前に現在の`chmod.bat`を一時バックアップ
- `robocopy /COPY:D`でファイル内容だけを差し替え、既存のWindows DACLを維持
- 差し替え後に`fc.exe /b`でbyte単位に検証し、失敗時はバックアップから復旧

自己更新処理自体に必要なコマンドはWindows標準の`curl.exe`、`certutil.exe`、`robocopy.exe`、`fc.exe`で、`--update`自体はPowerShellを必要としません。なお、v1.0.3の数値`777`以外のディレクトリACL処理ではWindows PowerShell 5.1を内部利用します。

> [!IMPORTANT]
> SHA-256はダウンロード破損や`.update`との不一致を検出するためのものです。独立した電子署名ではないため、GitHubリポジトリの`main`自体が改ざんされた場合まで検出できるものではありません。

> [!NOTE]
> `v1.0.2`の自己更新処理は、書き込み権限がない配置先に対してWindows Sudoで自動昇格しません。更新先へ書き込めない場合は、必要に応じて管理者権限のコマンドプロンプトから`chmod --update`を実行してください。

2026-10-16時点で、Windows Server 2025上のCIにより公開Raw GitHub版を使ったversion更新、同version no-op/repair、downgrade抑止、既存DACL保持、rollback、構造が大きく異なるfuture payloadへの自己更新に加え、実配布v1.0.2 updaterからfinal v1.0.3 payloadへの更新、更新後bytes完全一致、destination DACL維持を検証しています。

詳細な設計と保守上の注意点は[`.docs/update.md`](.docs/update.md)を参照してください。

<a id="sudo"></a>
## 🛡️ Windows Sudoによる自動再実行

通常権限でACL変更に失敗した場合、Windows Sudoが有効で利用可能なら管理者権限で自動再実行します。

概念的には次のような再実行を行います。

```text
sudo cmd /d /c "chmod ..."
```

自動再実行には無限ループ防止が組み込まれており、Sudoによる再実行でも失敗した場合はエラーとして終了します。

また、ACL変更途中で失敗した場合は、可能な限り元のACLへ復元してからSudoによる再実行を行います。

ACLの自動復元自体に失敗した場合は、状態が不確定な対象へ追加変更を行わない為、Sudoによる自動再実行を中止します。

Windows Sudoが無効または利用できない場合は、管理者としてコマンドプロンプトを開いて再実行してください。

<a id="acl-mapping"></a>
## 🔄 Windows ACLとの対応

このツールはPOSIX permissionをWindows ACLへ近似変換します。

### `rwx`

| POSIX | Windows ACL |
|---|---|
| `r` | Generic Read |
| `w` | Generic Write |
| `x` | Generic Execute |

ディレクトリの`w+x`相当では、Linuxのディレクトリ操作へ近づける為`Delete Child`も利用します。

### `u/g/o`

| POSIX | Windows側 |
|---|---|
| `u` | 現在のユーザー |
| `g` | 書き込み時は`BUILTIN\Users`。現在ACLの読み取り時は`Authenticated Users`も考慮 |
| `o` | `Everyone` |

> [!NOTE]
> GNU/Linuxの`u`は本来ファイル所有者を意味しますが、このツールでは現在コマンドを実行しているWindowsユーザーを`u`として扱います。

Windowsではユーザーが`Users`、`Authenticated Users`、`Everyone`など複数の主体へ同時に所属する為、POSIXの`owner/group/other`のように完全に排他的な3区分にはなりません。

その為、一部の特殊なMODEはWindows ACL上で近似になります。

### ディレクトリのACL継承

ファイルとディレクトリではWindows ACLの継承モデルが異なる為、`v1.0.1`以降は処理を分離しています。v1.0.3では、この分離時に残っていた制御フロー回帰も修正しています。

`700`、`750`、`755`等の数値`777`以外をディレクトリへ適用する場合、v1.0.3では**対象ディレクトリ自身のMODE ACE**と**将来の子要素用Windows inheritance template**を分離します。

- 対象ディレクトリ自身にはu/g/o MODE相当のACEを有効ACEとして設定
- `SYSTEM`と`Administrators`のFull Controlを管理・復旧用に維持
- 対象ディレクトリの親が持つ継承可能ACEを`InheritOnly` templateとして保持
- 親由来templateは対象自身には効かず、将来作成される子ファイル・子ディレクトリへ通常のWindows ACLとして継承
- 非`-R`では既存子へ明示的な`chmod` tree walkを行わない

この設計により、`chmod 700 DIR`でDIR自身を制限しながら、将来DIR内に作成する通常ファイルまで`700`相当ACLへ固定することを避けます。GNU/POSIXの「ディレクトリ自身のmode」とWindowsの「子へのACL継承」を同一ACEで兼用しないための設計です。

Windows Server 2025 / build 26100の検証では、非再帰変更後も既存childのaccess rule signatureを維持し、新規childは親由来の通常Windows ACLを受けることを確認しています。独自のinheritable ACEを持つ親についても、対象自身のeffective accessへ漏らさずfuture childへ継承できることを確認しています。

詳細は[`.docs/v1.0.3.md`](.docs/v1.0.3.md)を参照してください。

> [!IMPORTANT]
> ディレクトリへ数値MODE `777`を指定した場合は、GNU/Linuxの`chmod 777`をそのまま再現するのではなく、**Windows標準のACL継承状態へ戻す復旧操作**として扱います。
>
> ```bat
> chmod 777 "C:/work"
> ```
>
> 既に配下のファイルやサブディレクトリまでACL継承が無効化されている場合は、次のように`-R`を指定してください。
>
> ```bat
> chmod -R 777 "C:/work"
> ```
>
> `-R 777`では配下のファイル・ディレクトリについてもACL継承を再有効化し、親から継承する通常のWindows ACLへ戻します。

<a id="check-permissions"></a>
## 🔍 権限の確認方法

実際のWindows ACLは`icacls`で確認してください。

```bat
icacls file
```

例えば、

```bat
chmod 600 626.png
icacls 626.png
```

のように確認できます。

> [!WARNING]
> Windows版coreutilsなどの`ls -la`で表示される`rwx`は、NTFS ACLの変更をGNU/Linuxと同じ意味では反映しない場合があります。

その為、

```text
-rwxrwxrwx
```

と表示されたままでも、`chmod`によるWindows ACL変更が失敗したとは限りません。

Windows上の実際のアクセス権を確認する場合は`icacls`の結果を基準にしてください。

<a id="exit-codes"></a>
## 📤 終了コード

| 終了コード | 意味 |
|---:|---|
| `0` | 正常終了 |
| `1` | ACL変更、対象処理、復元、Sudo再実行などの実行時エラー |
| `2` | MODE、オプション、引数などの使用方法エラー |

<a id="limitations"></a>
## ⚠️ 制限事項・注意点

- GNU/LinuxのPOSIX permissionとWindows ACLは完全互換ではありません。
- `setuid`、`setgid`、`sticky bit`には対応していません。
- `g=u`、`o=g`など、`u/g/o`から別の`u/g/o`へ権限をコピーするMODEは現在未対応です。
- `u`はファイル所有者ではなく現在のWindowsユーザーとして扱います。
- `g`と`o`はWindowsグループ/SIDを使用した近似です。
- `=`または`,`を含む複合シンボリックMODEは、`cmd.exe` / batchの引数境界を保つためMODE全体を引用してください。
- v1.0.3の数値`777`以外のディレクトリACL処理には、Windows標準のWindows PowerShell 5.1が必要です。PowerShell 7 / `pwsh`は不要です。
- ディレクトリへの数値MODE `777`はWindows固有の復旧動作として、親からのACL継承を再有効化します。
- ディレクトリではWindowsの管理・復旧経路を保持する為、`SYSTEM`と`Administrators`のFull Controlを維持します。
- Windows ACLをサポートするNTFS等のファイルシステムを前提としています。
- Windows版coreutilsなどの`ls -la`表示は、実際のWindows ACL確認には使用できない場合があります。
- `--update`はGitHubへのHTTPS接続とWindows標準の`curl.exe`、`certutil.exe`、`robocopy.exe`、`fc.exe`を必要とします。
- `--update`のSHA-256検証は、GitHubリポジトリ自体から独立した署名検証ではありません。
- システムディレクトリやドライブ全体へ再帰処理を行うとWindowsの動作へ影響する可能性があります。
- `-R`で重要なパスを操作する場合は`--preserve-root`の使用を推奨します。

<a id="examples"></a>
## 🧪 使用例

### SSH秘密鍵を現在ユーザーだけが読み書きできるようにする

```bat
chmod 600 ~/.ssh/id_ed25519
```

### 実行権限相当を追加する

```bat
chmod +x example.sh
```

### 現在ユーザーだけに実行権限相当を追加する

```bat
chmod u+x example.sh
```

### group/other相当の権限を削除する

```bat
chmod go-rwx private.key
```

### owner相当を読み書き、group/other相当を読み取りへ設定する

```bat
chmod "u=rw,go=r" file
```

### ディレクトリツリーへ読み取りと条件付き実行権限を設定する

```bat
chmod -R a+rX "C:/tools"
```

### ディレクトリをWindows標準のACL継承状態へ戻す

```bat
chmod 777 "C:/work"
```

配下も含めて復旧する場合:

```bat
chmod -R 777 "C:/work"
```

### 最新版へ自己更新する

```bat
chmod --update
```

### MODEが変化した対象だけ表示する

```bat
chmod -c 644 "C:/work/config.txt"
```

### ルート保護を有効にして再帰処理する

```bat
chmod -R --preserve-root 755 "C:/tools"
```

<a id="ci"></a>
## ✅ 開発・CI

GitHub ActionsでCP932/CRLF、manifest整合、CLI基本動作、Windows ACLの主要semanticsを継続検証しています。

Actions関連の追加・変更は原則`github/actions` branchで実検証し、CI成功後にmainへ取り込みます。詳細な開発運用は[`.docs/ci.md`](.docs/ci.md)を参照してください。

<a id="changelog"></a>
## 📝 変更履歴

変更履歴は[CHANGELOG.md](CHANGELOG.md)を参照してください。
