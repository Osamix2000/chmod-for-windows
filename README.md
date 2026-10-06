# 🪟 chmod - Windows ACL chmod互換ラッパー

WindowsのACLを、Linux/GNU `chmod`に近い書式で操作する為の軽量なバッチスクリプトです。

`icacls`を直接覚えたり複雑なACL操作を毎回組み立てたりせず、次のような書き方でWindows上のアクセス権を変更できます。

```bat
chmod 600 ~/.ssh/id_ed25519
chmod +x example.sh
chmod u=rw,go= "C:/keys/private_key"
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
- [🛡️ Windows Sudoによる自動再実行](#sudo)
- [🔄 Windows ACLとの対応](#acl-mapping)
- [🔍 権限の確認方法](#check-permissions)
- [📤 終了コード](#exit-codes)
- [⚠️ 制限事項・注意点](#limitations)
- [🧪 使用例](#examples)
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
chmod go-rwx file
chmod u=rw,go=r file
chmod -R a+rX directory
```

実装は`chmod.bat`単体で、PowerShellを必要としません。

GNU coreutils 9.12の`chmod`の書式や挙動を参考にしていますが、GNU `chmod`そのものの移植や完全互換実装ではありません。

<a id="features"></a>
## 🚀 主な機能

- 1～3桁の8進数MODE
- 先頭`0`付き4桁MODE
- `+x`、`u+x`、`go-rwx`などのシンボリックMODE
- `u=rw,go=r`のようなカンマ区切りの複数指定
- GNU `chmod`の`X`に近い条件付き実行権限
- `-R`による再帰処理
- `-c, --changes`
- `-v, --verbose`
- `-f, --quiet`
- `--preserve-root`
- `/`と`\`の両方を使用できるパス指定
- `~`を現在ユーザーのホームディレクトリとして展開
- ACL変更前のバックアップ
- 途中失敗時のACL自動復元
- Windows Sudoが利用可能な場合の自動再実行
- SIDを利用したローカライズ非依存のACL操作
- `cmd.exe`のみで動作し、PowerShell不要

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
chmod u=rw,go=r file
chmod a+rX directory
```

対応する`who`:

| 指定 | Windows側での扱い |
|---|---|
| `u` | 現在のユーザー |
| `g` | `BUILTIN\Users`および`Authenticated Users`を基準に近似 |
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
chmod 600 "~/My Keys/private.key"
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
| `--version` | バージョンを表示 |
| `--help` | ヘルプを表示 |

例:

```bat
chmod -R 755 "C:/tools"
chmod -c 644 "C:/work/config.txt"
chmod -v +x example.sh
chmod -R --preserve-root 755 "C:/tools"
```

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
| `g` | `BUILTIN\Users`および`Authenticated Users`を基準に近似 |
| `o` | `Everyone` |

> [!NOTE]
> GNU/Linuxの`u`は本来ファイル所有者を意味しますが、このツールでは現在コマンドを実行しているWindowsユーザーを`u`として扱います。

Windowsではユーザーが`Users`、`Authenticated Users`、`Everyone`など複数の主体へ同時に所属する為、POSIXの`owner/group/other`のように完全に排他的な3区分にはなりません。

その為、一部の特殊なMODEはWindows ACL上で近似になります。

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
- Windows ACLをサポートするNTFS等のファイルシステムを前提としています。
- Windows版coreutilsなどの`ls -la`表示は、実際のWindows ACL確認には使用できない場合があります。
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
chmod u=rw,go=r file
```

### ディレクトリツリーへ読み取りと条件付き実行権限を設定する

```bat
chmod -R a+rX "C:/tools"
```

### MODEが変化した対象だけ表示する

```bat
chmod -c 644 "C:/work/config.txt"
```

### ルート保護を有効にして再帰処理する

```bat
chmod -R --preserve-root 755 "C:/tools"
```

<a id="changelog"></a>
## 📝 変更履歴

変更履歴は[CHANGELOG.md](CHANGELOG.md)を参照してください。
