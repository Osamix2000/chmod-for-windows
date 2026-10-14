# GNU `chmod` / POSIX File Mode 仕様調査

> 調査基準日: 2026-10-15  
> 目的: `chmod-for-windows`が模倣対象とするGNU/POSIXの`chmod`意味論を正確に把握し、Windows ACLへ近似する際の境界を明確にする

## 1. この文書の位置付け

`chmod-for-windows`はGNU coreutils `chmod`の完全移植ではない。

本プロジェクトの目標は、WindowsのSecurity Descriptor / ACLモデルで安全に再現できる範囲まで、GNU `chmod`に近い入力形式・操作感・直感を提供することである。

したがって本書では次を区別する。

- **POSIX仕様**: `chmod` utility / `chmod()` system interfaceが標準として要求する意味
- **GNU coreutils仕様**: POSIXに加えGNUが提供する拡張
- **Linux/POSIX ACL実装知見**: Linux ACLとmode bitsの連動等。POSIX.1-2024本体そのものとは分ける
- **本プロジェクト独自仕様**: Windows ACLへの近似・安全策・復旧動作

Windows側の詳細は[icacls.md](icacls.md)を参照する。

---

## 2. `chmod`の本質

POSIX/GNUの`chmod`はファイルの**file mode bits**を変更する。

典型的なmode bits:

- owner class: `rwx`
- group class: `rwx`
- other class: `rwx`
- set-user-ID
- set-group-ID
- sticky / restricted deletion flag

このモデルはWindows DACLのような「任意個のSIDごとのAllow/Deny ACE列」とは構造が根本的に異なる。

GNUマニュアルも、mode bitsとは別にACL・immutable等のファイルシステム固有属性があり、mode bitsが許可していても実操作が失敗し得ると明記している。

したがってUnix側ですら「`chmod 777` = あらゆるアクセス制御を完全解除」とは限らない。

---

## 3. 基本構文

GNU coreutilsの基本構文:

```text
chmod [OPTION]... {MODE | --reference=RFILE} FILE...
```

代表例:

```sh
chmod 600 file
chmod 755 dir
chmod u+x file
chmod go-rwx file
chmod u=rw,go=r file
chmod -R a+rX dir
```

---

## 4. `u/g/o/a`

GNUでの意味:

| 記号 | 意味 |
|---|---|
| `u` | ファイルのowner |
| `g` | ファイルのgroupに属するユーザー |
| `o` | ownerでもgroup memberでもないother users |
| `a` | all。`ugo`と同じ |

ここで重要なのは、POSIXの`u/g/o`は**ファイル自身が持つowner/groupを基準にした3つのpermission class**である点。

WindowsではユーザーSID、BUILTIN\Users、Authenticated Users、Everyone等が重なり得るため、これと等価な排他的3分類は存在しない。

`chmod-for-windows`の現行近似:

- `u` → 現在コマンドを実行しているWindowsユーザーSID
- `g` → 主にBUILTIN\Users
- `o` → Everyone

これは操作感を近づけるための近似であり、GNU `chmod`のowner/group semanticsそのものではない。

---

## 5. `r/w/x`

### 5.1 通常ファイル

- `r`: file contentsを読む
- `w`: file contentsを書き換える
- `x`: fileを実行対象として扱う

### 5.2 ディレクトリ

ディレクトリの意味は通常ファイルと異なる。

- `r`: directory entriesの一覧を読む
- `w`: directory entriesを作成/削除/renameする能力に関係
- `x`: directoryをsearch/traverseし、その中の名前を解決する能力に関係

典型例として、ファイル自身がwrite-protectedでも、親directoryに適切な`w+x`があればdirectory entryとして削除できる場合がある。

Windowsではdirectory Delete Child等が近いが、完全等価ではない。

---

## 6. 数値MODE

### 6.1 3つのpermission digit

| 値 | bit |
|---:|---|
| `4` | read |
| `2` | write |
| `1` | execute/search |

合計で1桁を構成する。

```text
7 = rwx
6 = rw-
5 = r-x
4 = r--
0 = ---
```

例:

```text
755 = u=rwx,g=rx,o=rx
644 = u=rw,g=r,o=r
600 = u=rw,g=,o=
```

### 6.2 special bits

| 値 | 意味 |
|---:|---|
| `4000` | set-user-ID |
| `2000` | set-group-ID |
| `1000` | sticky / restricted deletion |

例:

```text
4755
2755
1777
```

`chmod-for-windows`では直接対応するWindows ACL semanticsがないため未対応。

### 6.3 先頭0は必須ではない

GNU `chmod`のnumeric modeは常にoctalとして解釈されるので、C言語のリテラルと異なり先頭`0`は不要。

```text
755 == 0755
55 == 0055
```

ただしGNUでは**5桁以上のnumeric mode**がdirectory setuid/setgid保持挙動へ影響する特殊ケースがあるため、「先頭0は常に完全に意味がない」と一般化してはいけない。

---

## 7. GNU特有のOperator Numeric Mode

GNU coreutilsはnumeric modeの前に`+`, `-`, `=`を付ける拡張を持つ。

例:

```sh
chmod +440 file
chmod -1 file
chmod =600 file
chmod =0,u+r file
```

意味:

- `+NNN`: 指定bitを追加
- `-NNN`: 指定bitを削除
- `=NNN`: 指定bit以外をclearし設定

これはGNU extension。

`chmod-for-windows`の現行numeric parserは通常の絶対MODEを中心としており、このGNU拡張は別途実装検討項目。

---

## 8. Symbolic Mode

基本形式:

```text
[ugoa...][+-=]perms...[,....]
```

`perms`は通常:

```text
r w x X s t
```

またはpermission copyの:

```text
u g o
```

を使用する。

### 8.1 `+`

指定permissionを追加。

```sh
chmod u+x file
chmod go+r file
```

### 8.2 `-`

指定permissionを除去。

```sh
chmod go-w file
chmod a-x file
```

### 8.3 `=`

対象classのpermissionを指定値へ設定し、指定されなかった通常permissionをclearする。

```sh
chmod u=rw,go=r file
chmod go= file
```

Windows ACLでは「bit集合を置換」ではなく複数ACE/継承/SIDが絡むため、`=`の完全再現は特に難しい。

---

## 9. `who`省略とumask

GNU symbolic modeでは`who`を省略した場合、概念的には`a`が対象になるが、**umaskでsetされているpermissionは影響対象から除外される**。

例: umask `002`の場合

```sh
chmod +w file
```

はother writeを追加しない。

一方:

```sh
chmod a+w file
```

はumaskを無視してallへwriteを追加する。

これは現行`chmod-for-windows`との明確な非互換。

現行Windows版はPOSIX `umask`相当がないため、who省略を概ね`a`として扱う。

したがって:

```bat
chmod +x file
```

を概ね:

```bat
chmod a+x file
```

としているが、これはGNUの厳密意味ではない。

将来互換度を高める場合でも、Windows側に自然なumask源がないため、独自設定を導入するかどうかは慎重に判断する。

---

## 10. Permission Copy (`u/g/o`をpermission部に使う)

GNUは既存permission classを別classへコピーできる。

例:

```sh
chmod o+g file
chmod g=u file
chmod o=g file
```

例えば元が`664`なら:

```sh
chmod o+g file
```

で`666`になる。

現行`chmod-for-windows`では未対応。

Windows ACLから擬似u/g/oを求めてコピーすること自体は可能だが、u/g/oが重複SID集合なのでGNUと完全等価にならない点に注意する。

---

## 11. `X` 条件付き実行

GNUの`X`は次の場合だけexecute/searchを操作する。

- 対象がdirectory
- または、対象fileですでに誰かにexecute bitがある

例:

```sh
chmod -R a+rX tree
```

これによりdirectoryへsearch permissionを与えつつ、元から非実行fileへ無差別にexecute bitを付けない。

現行`chmod-for-windows`もこの意味を近似している。

ただしWindows ACLから「誰かがexecuteを持つ」を判定するのはPOSIX mode bitほど単純ではない。

---

## 12. `s` / `t`

### 12.1 set-user-ID (`u+s`)

実行時にprocess effective UIDをfile ownerへ切り替える等のUnix semantics。

### 12.2 set-group-ID (`g+s`)

通常fileでは実行時group identity、directoryでは新規childのgroup inheritance等に関わる。

### 12.3 sticky bit (`+t`)

directoryではrestricted deletion semanticsに使われ、典型的にはworld-writableな`/tmp`で他人のfileを勝手に削除できないようにする。

Windows ACLにこれらと直接等価なmode bitはない。

一部の効果をCreator Owner ACE、Delete/Delete Child等で近似できても、Unix special bitとして実装したことにはならない。

現行`chmod-for-windows`で未対応とするのは妥当。

---

## 13. Directory setuid/setgidとnumeric modeのGNU拡張

GNU coreutilsはdirectoryのsetuid/setgid bitを通常numeric modeで**暗黙に保持する**場合がある。

例えばGNUではdirectoryに対する:

```sh
chmod 755 dir
chmod 0755 dir
```

は既存setuid/setgidを保持する挙動を持つ。

明示的にclearしたい場合は例として:

```sh
chmod a-s dir
chmod -6000 dir
chmod =755 dir
chmod 00755 dir
```

等を利用する。

このdirectory特殊挙動はGNU extensionであり、portable scriptが依存すべきでないとGNU自身が注意している。

Windows版ではspecial bit自体を未対応としているため、numeric parserの互換対象外。

---

## 14. `-R` 再帰処理

```sh
chmod -R MODE directory
```

はdirectory treeを走査し、directoryとcontentsへmode変更を行う。

Windows ACL継承とは同じ概念ではない。

- GNU `-R`: utility自身がtree walkして各file modeを操作
- Windows `(OI)(CI)`: 親ACEを子へ継承/自動伝播するSecurity Descriptor機構

`chmod-for-windows`はこの2つを混同しないこと。

---

## 15. Symlink semantics

### 15.1 基本

多くのUnix系OSではsymlink自身のpermissionを`chmod`で変更できない/意味を持たない。

GNU `chmod`は通常、command line argumentとして指定したsymlinkについてlink targetを操作する。

recursive traversal中に遭遇したsymlinkは既定では無条件に追わない。

### 15.2 GNU `-H/-L/-P`

現行GNUマニュアルの`chmod`個別章:

- `-H`: `-R`時、command-line argumentがdirectoryへのsymlinkなら追う
- `-L`: traversal中に遭遇する全directory symlinkを追う
- `-P`: symlinkを一切traverseしない
- `chmod`個別章では**`-H`が既定**と記載

`-L` + `-R`には、攻撃者がtree traversal途中にsymlinkを差し込んで任意targetを操作させるrace/security riskがあるとGNU自身が警告している。

### 15.3 GNU manual内の表現差

coreutils共通の「Traversing symlinks」説明と各utility個別章でdefault表現が一致しない版がある。

`chmod`実装を参照する場合は:

1. 対象coreutils versionの`chmod`個別マニュアル
2. 対象versionの`src/chmod.c`
3. NEWS/release notes

の順で確認する。

### 15.4 Windowsとの違い

WindowsにはSymlink以外にJunction、Mount Point等のReparse Pointがある。

GNUのsymlink traversal optionをそのままWindows Reparse Pointへ写像してはいけない。

---

## 16. `--dereference`

GNUではcommand line symlinkに対してtargetを操作するのがdefault。

`--dereference`は「symlink自身ではなく参照先へ作用」を明示する。

GNU/coreutilsのversionによってsymlink関連optionが追加・整理されているため、Windows版へ将来導入する際は対象GNU versionを固定してテストする。

---

## 17. `--reference=RFILE`

GNU:

```sh
chmod --reference=reference_file target1 target2
```

でreference fileと同じmodeへ設定する。

referenceがsymlinkの場合は原則targetのmodeを参照する。

Windows版で近似する場合:

- 擬似u/g/o modeを抽出して再適用する方法
- DACLそのものを複製する方法

は意味が全く異なる。

GNU互換という意味では「擬似modeをコピー」が近いが、ACL情報損失が起きる。DACLコピーはWindows ACL複製であってGNU `--reference`互換ではない。

現時点では未対応とするのが安全。

---

## 18. `--preserve-root`

GNUのrecursive utility群には`/`を誤って再帰操作しないためのroot保護がある。

`chmod --preserve-root -R ... /`

のような危険操作を防止する。

WindowsにはPOSIX `/`と同一の単一rootはなく:

- drive root (`C:\`)
- UNC share root (`\\server\share\`)

等がある。

`chmod-for-windows`がdrive/UNC root保護へ近似しているのは妥当。

ただしWindowsのmount point/junctionを介すると別volumeへ到達できるため、root文字列判定だけで全破壊的再帰を防げるわけではない。

---

## 19. `-c/-v/-f`

GNU:

### `-c`, `--changes`

実際にpermissionが変わったfileについてのみverbose表示。

### `-v`, `--verbose`

各fileについてaction/non-actionを表示。

### `-f`, `--silent`, `--quiet`

多くのerror messageを抑制する。

Windows版で表示形式を完全一致させる必要はないが、意味は可能な限り合わせる。

---

## 20. Exit Status

GNU `chmod`:

- `0`: success
- nonzero: failure

GNUマニュアルは`chmod`固有の細かいexit code classを保証していない。

現行`chmod-for-windows`が独自に:

- `0`: success
- `1`: runtime/ACL processing error
- `2`: usage error

と分類するのはWindows wrapperとしての独自仕様。

これはGNU compatibilityを名乗る際に明記しておく。

---

## 21. 誰が`chmod`できるか

GNUマニュアルでは、通常は:

- effective UIDがfile ownerと一致するprocess
- またはappropriate privilegesを持つprocess

がmode変更可能。

WindowsではOwner、WRITE_DAC、Admin/UAC、SeTakeOwnershipPrivilege等が絡み、判定モデルが異なる。

`chmod-for-windows`が「現在ユーザー = u」とすることは、Unixの「ownerだけがchmodできる」というモデルとも一致しない。

---

## 22. Linux ACLとmode bits

LinuxではPOSIX ACL実装が存在するが、これはWindows ACLと同じものではない。

Linux ACLではmode bitsとACL entryの間に対応関係があり、ACL mask entryがgroup class permissionsを表す等の規則がある。

`chmod`でmode bitsを変更すると、Access ACLが存在する場合は対応するACL entry/maskも調整される。

重要:

- Linux ACLはPOSIX.1e draft由来の実装系であり、現行POSIX.1-2024のWindows ACL相当標準というわけではない
- Windows DACLの任意SID/Allow/Deny/canonical orderモデルとは別物
- 「LinuxにもACLがあるからWindows ACLへそのままchmod semanticsを移せる」とは考えない

---

## 23. GNU `chmod`でもmode bitsだけでは全てを決めない

GNUマニュアルは、mode bitsが許可していても以下で操作が失敗し得ると明記する。

例:

- filesystem-specific ACL
- immutable属性
- read-only mount
- SELinux等の追加security mechanism

これはWindows側の:

- DACL
- MIC
- Share ACL
- EFS
- UAC/token
- filesystem/server制約

との関係を考える上で重要。

本プロジェクトは「擬似mode表示 = 有効アクセスの完全な真実」と扱ってはいけない。

---

## 24. GNU/POSIXと`chmod-for-windows`の対応表

| GNU/POSIX | Windows近似 | 現状 |
|---|---|---|
| `u` | current user SID | 対応・近似 |
| `g` | BUILTIN\Users等 | 対応・近似 |
| `o` | Everyone | 対応・近似 |
| `a` | u/g/o全部 | 対応 |
| `r` | Generic Read | 対応・近似 |
| `w` | Generic Write / directory rights | 対応・近似 |
| `x` | Generic Execute / Traverse | 対応・近似 |
| `X` | dirまたは既実行対象のみx | 対応・近似 |
| `+` | Allow rights追加/再構成 | 対応・近似 |
| `-` | Allow rights除去 | 対応・近似 |
| `=` | class rights置換 | 対応・近似 |
| who省略+umask | Windowsに直接対応なし | `a`扱い。非互換 |
| permission copy `g=u`等 | 擬似modeから可能だが不可逆 | 未対応 |
| `s` | 直接対応なし | 未対応 |
| `t` | 直接対応なし | 未対応 |
| special numeric bits | 直接対応なし | 未対応 |
| operator numeric mode | 独自parser実装可能 | 未対応 |
| `--reference` | 擬似modeコピー等 | 未対応 |
| `-R` | tree walk + ACL操作 | 対応・近似 |
| `-H/-L/-P` | Reparse Point policy必要 | 未対応 |
| command-line symlink dereference | Reparse Point semantics | 未対応/要整理 |
| `--preserve-root` | drive/UNC root保護 | 対応・近似 |
| `-c/-v/-f` | wrapper出力制御 | 対応・近似 |

---

## 25. 現行独自仕様: directory `777`

GNU:

```sh
chmod 777 directory
```

は単純に:

```text
u=rwx,g=rwx,o=rwx
```

を意味する。

`chmod-for-windows` v1.0.1ではdirectoryに対するnumeric `777`を、**Windows標準の親ACL継承状態へ戻す復旧操作**として扱う。

これは互換ではなく意図的なWindows UX設計。

理由:

- Windows DACLで`Everyone:F`のようなliteral 777近似を作ると危険
- `700`等で継承を切った後にユーザーが「通常状態へ戻したい」という需要がある
- Windowsの標準運用では親からのACL継承が自然

この独自仕様はREADME/CHANGELOG/AGENTSで常に明示する。

---

## 26. 今後の互換性改善候補

### 優先度高

- `g=u`, `o=g`等のpermission copy
- `--reference`の擬似mode版
- Reparse Point policyを設計した上で`-H/-L/-P`相当
- who省略/umask semanticsをどう扱うか明示的設定として検討

### 優先度中

- GNU operator numeric modes (`+440`, `-1`, `=600`)
- GNU option alias/diagnostic wordingの改善

### 原則非対応/慎重

- setuid/setgid/stickyを「それっぽいWindows ACL」で同名実装すること
- POSIX `000`をExplicit Deny乱用で再現すること
- GNU `--reference`をDACL丸ごとコピーして互換と呼ぶこと

---

## 27. テストすべきGNU互換ケース

将来テストスイートを作る場合:

```text
600
644
700
755
777
+X
u+x
go-rwx
u=rw,go=r
a+rX
g=u
o+g
-R
a=,+rwX
```

Windows固有:

```text
chmod 700 dir -> new child ACL
chmod 700 dir -> moved child ACL
chmod 777 dir -> inheritance reset
chmod -R 777 dir -> subtree reset
SYSTEM/Administrators recovery
UAC standard/elevated difference
```

GNU出力完全一致より、意味論とWindows上の安全性を優先する。

---

## 28. バージョンに関する注意

2026-10時点でGNU公式Webマニュアル検索結果にはCoreutils 9.11表記のページが多く残っている一方、本リポジトリREADMEはGNU coreutils 9.12を参照対象としている。

GNU coreutilsはsymlink option等が近年変化しているため、version-dependentな機能を実装する場合は:

1. 対象release tarball/NEWS
2. 対象tagの`src/chmod.c`
3. 対象versionのmanual

を照合する。

一般的なsymbolic/numeric mode semanticsは長期に安定しているが、symlink traversal等は「最新版なら知っているはず」で断定しない。

---

## 29. 主な資料

GNU:

- GNU Coreutils Manual - chmod invocation  
  https://www.gnu.org/software/coreutils/manual/html_node/chmod-invocation.html
- File permissions  
  https://www.gnu.org/software/coreutils/manual/html_node/File-permissions.html
- Symbolic Modes  
  https://www.gnu.org/software/coreutils/manual/html_node/Symbolic-Modes.html
- Setting Permissions  
  https://www.gnu.org/software/coreutils/manual/html_node/Setting-Permissions.html
- Copying Permissions  
  https://www.gnu.org/software/coreutils/manual/html_node/Copying-Permissions.html
- Conditional Executability  
  https://www.gnu.org/software/coreutils/manual/html_node/Conditional-Executability.html
- Umask and Protection  
  https://www.gnu.org/software/coreutils/manual/html_node/Umask-and-Protection.html
- Numeric Modes  
  https://www.gnu.org/software/coreutils/manual/html_node/Numeric-Modes.html
- Operator Numeric Modes  
  https://www.gnu.org/software/coreutils/manual/html_node/Operator-Numeric-Modes.html
- Directory Setuid and Setgid  
  https://www.gnu.org/software/coreutils/manual/html_node/Directory-Setuid-and-Setgid.html

POSIX / Open Group:

- POSIX.1-2024 / The Open Group Base Specifications Issue 8  
  https://pubs.opengroup.org/onlinepubs/9799919799/
- chmod utility  
  https://pubs.opengroup.org/onlinepubs/9799919799/utilities/chmod.html
- chmod() interface  
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/chmod.html

Linux ACL補助資料:

- `acl(5)`  
  https://man7.org/linux/man-pages/man5/acl.5.html
- `chmod(2)`  
  https://man7.org/linux/man-pages/man2/chmod.2.html

---

## 30. まとめ

`chmod`は単純な「数字をACLへ変換するコマンド」ではない。

GNU/POSIX側には:

- owner/group/other permission class
- umask
- file/directoryで異なるrwx意味
- special mode bits
- existing permission copy
- conditional `X`
- symlink traversal policy
- filesystem ACL等との相互作用

がある。

Windows側には:

- 任意SIDのACE
- Allow/Deny
- canonical order
- inheritance
- Owner
- UAC/token
- privileges
- MIC
- Reparse Point
- Share ACL等

がある。

両者を完全な1対1対応にすることはできない。

本プロジェクトでは「GNU入力を受け取りWindows ACLへ機械的に変換する」より、**GNUの意図を理解した上でWindowsで安全かつ予測可能な近似を行う**ことを設計原則とする。
