# icacls / Windows ACL 仕様調査

> 調査基準日: 2026-10-14  
> 対象: Windows 10 / 11、Windows Server 2016 / 2019 / 2022 / 2025を中心とする現行Windows  
> 目的: `chmod-for-windows`でGNU `chmod`に可能な限り近い操作感を実現するため、`icacls.exe`とWindowsアクセス制御の仕様・限界を整理する

## 1. この文書の位置付け

`chmod-for-windows`はGNU `chmod`の完全移植を目的としない。WindowsのSecurity Descriptor / ACLを利用し、Windowsで安全かつ現実的に再現できる範囲までGNU `chmod`に近い操作感を提供することを目的とする。

この文書では、情報を次の4種類に区別する。

- **公式仕様**: Microsoft Learn、Windows Protocols、Windows SDK等のMicrosoft一次資料
- **実装仕様**: Windowsに付属する`icacls /?`など、実行ファイル自身が公開するヘルプ
- **実測・実運用知見**: Microsoft Support/Q&A、国内外の技術記事等。一次仕様と矛盾する場合は一次仕様を優先する
- **本プロジェクト独自仕様**: GNU/POSIXにも`icacls`にも存在しない`chmod-for-windows`固有の設計判断

特に、本プロジェクトの「ディレクトリへの数値MODE `777`をWindows標準のACL継承状態へ戻す復旧操作として扱う」動作は**Windows固有の独自仕様**であり、GNU/POSIXの`chmod 777`とは意味が異なる。

GNU/POSIX側の詳細は[chmod.md](chmod.md)を参照する。

---

## 2. Windowsアクセス制御の基礎

### 2.1 Security Descriptor

Windowsのセキュリティ保護可能なオブジェクトにはSecurity Descriptorが関連付けられる。Security Descriptorは主に次の情報を持つ。

- Owner SID
- Primary Group SID
- DACL (Discretionary Access Control List)
- SACL (System Access Control List)
- 継承保護等を表すControl Bits

DACLは通常のアクセス許可/拒否を制御する。SACLは監査だけではなく、Mandatory Integrity Controlの整合性ラベル等も格納する。

したがって「Windowsの権限 = DACLだけ」ではない。DACLで許可されていても、MIC、SMB共有ACL、EFS、アクセス・トークン、特権等により実際のアクセスが制限される場合がある。

### 2.2 ACE

ACLはACE (Access Control Entry)の列で構成される。代表的なACEは次の通り。

- Allow ACE: SIDへ権限を許可
- Deny ACE: SIDへ権限を拒否
- Inherited ACE: 親コンテナーから継承
- Mandatory Label ACE: SACL内でIntegrity Levelを定義

各Allow/Deny ACEには少なくともSID、Access Mask、継承フラグ等が含まれる。

### 2.3 NULL DACLと空DACLは正反対

これは極めて重要である。

- **NULL DACL / DACLなし**: 通常のDACLアクセスチェック上はEveryoneへFull Access相当
- **空DACL / ACEが0件のDACL**: 通常のDACLアクセスチェック上は誰にも権限を許可しない

よってPOSIXの`000`を「DACLをNULLにする」と近似してはいけない。NULL DACLはむしろ極めて危険な全許可状態になる。

なおOwnerの暗黙権限やWindowsの特権等が別途関与するため、「空DACLならOS内部のあらゆるアクセスが絶対不可能」という意味でもない。

---

## 3. Windowsのアクセスチェック

### 3.1 ACEは順番に評価される

Windowsは対象オブジェクトのDACL内ACEを順に評価する。要求された権限について、適用対象SIDのDenyに遭遇すれば拒否され、必要な権限がAllowで満たされれば許可される。最後まで必要な権限が満たされなければ暗黙的に拒否される。

Windowsの推奨Canonical Orderは概ね次の通り。

1. Explicit Deny
2. Explicit Allow
3. Inherited Deny
4. Inherited Allow

より厳密には、明示ACEを継承ACEより前に置き、継承ACEは親、祖父母……の継承深度順に並び、各レベル内でDenyがAllowより前になる。

`icacls`自身もACEをこのCanonical Orderで保持すると文書化している。

### 3.2 「一番強い権限が勝つ」ではない

Windows権限について「複数グループの中で最も自由な権限が勝つ」と説明されることがあるが、これは一般則としては不正確である。

AllowはユーザーのAccess Tokenに含まれる複数SIDから累積し得る一方、適切な位置にあるDeny ACEはAllowを阻止する。権限は単純な最大値比較ではなく、Access Token、ACE順序、要求Access Mask等を含めて評価される。

本プロジェクトではGNU `chmod`の`-`を近似するために、新しいDeny ACEを安易に作るより、対象Allow ACEの権限を調整/除去する方針を基本とするのが安全である。

### 3.3 Generic RightsとSpecific Rights

Windowsには`GENERIC_READ`、`GENERIC_WRITE`、`GENERIC_EXECUTE`等のGeneric Rightsがある。ファイル/ディレクトリに対しては、これらが複数のSpecific/Standard Rightsへ展開される。

代表例:

- Generic Read: Read Data/List Directory、Read Attributes、Read EA、READ_CONTROL、SYNCHRONIZE等
- Generic Write: Write Data/Add File、Append Data/Add Subdirectory、Write Attributes、Write EA、READ_CONTROL、SYNCHRONIZE等
- Generic Execute: Execute/Traverse、Read Attributes、READ_CONTROL、SYNCHRONIZE等

そのため、Windowsの`R/W/X`はPOSIXの単純な1bitとは意味が広い。

---

## 4. `icacls`の役割

Microsoft Learnは`icacls`を「指定ファイルのDACLを表示/変更し、保存済みDACLを適用するコマンド」と説明している。

一方で`/setintegritylevel`はSACL内のMandatory Label ACEを操作するため、実際にはDACL以外の一部Security Descriptor情報も扱う。

現行Microsoft Learnの適用対象にはWindows 10、Windows 11、Windows Server 2016/2019/2022/2025等が含まれる。

---

## 5. `icacls`構文と全主要オプション

Microsoft Learnが示す主要機能を整理すると次の通り。

| 機能 | 意味 |
|---|---|
| `icacls <name>` | DACLを表示 |
| `/save <ACLfile>` | 一致対象のDACLを保存 |
| `/restore <ACLfile>` | 保存したDACLを指定ディレクトリ配下へ適用 |
| `/setowner <user>` | Ownerを変更 |
| `/findsid <SID>` | 指定SIDを明示的に含むDACLを持つ対象を検索 |
| `/verify` | 非Canonical ACLまたはACE数と長さが不整合なACLを検出 |
| `/reset` | 既定の継承ACLでDACLを置換 |
| `/grant[:r] SID:perm` | Allow権限を付与 |
| `/deny SID:perm` | Deny権限を付与 |
| `/remove SID` | 指定SIDのACEを除去 |
| `/remove:g SID` | 指定SIDのAllowを除去 |
| `/remove:d SID` | 指定SIDのDenyを除去 |
| `/setintegritylevel ...` | Mandatory Integrity Labelを設定 |
| `/substitute oldSID newSID` | DACL内SIDを置換 |
| `/T` | 指定ディレクトリ以下を再帰的に処理 |
| `/C` | ファイルエラー後も処理継続 |
| `/L` | Symlinkの参照先ではなくSymlink自身を対象にする |
| `/Q` | 成功メッセージを抑制 |

### 5.1 `/grant`と`/grant:r`

`/grant SID:perm`は、既にそのSIDへ明示的に付与されているAllow権限へ権限を追加する。

`/grant:r SID:perm`は、そのSIDへ以前付与された**明示的Allow**を置換する。

重要な点:

- `:r`は「そのSIDに関するDACL上のあらゆるACEを完全置換」の意味ではない
- Inherited ACEやDeny ACEまで同じ意味で置換するものではない
- 継承を含む現在の有効権限を単純に`/grant:r`だけで完全制御できるとは限らない

### 5.2 `/deny`

`/deny SID:perm`は指定権限のExplicit Deny ACEを追加し、同じ権限が同SIDのExplicit Allowに存在する場合はそこから除去する。

Denyは強力で、グループ経由Allowまで阻止し得る。GNU/POSIXの`chmod`は「モードbitを落とす」のであって「明示Deny」という別概念を作るものではない。したがって、本プロジェクトで`chmod`互換性のためにDenyを多用するべきではない。

### 5.3 `/remove`

実行ファイル内ヘルプとMicrosoft Learnに基づく意味:

- `/remove SID`: DACLからSIDの出現を除去
- `/remove:g SID`: Grant/Allowを除去
- `/remove:d SID`: Denyを除去

### 5.4 `/reset`

`/reset`は**元のACLへ戻すコマンドではない**。

Microsoft Learnの定義は「既定の継承ACLでACLを置換する」である。したがって、対象に独自のExplicit ACEが存在した場合、それを失う可能性がある。

本プロジェクトの`chmod 777 <directory>`はWindows固有の復旧操作として`inheritance enable + reset`を利用するが、これは「変更前のACLへ完全復元」ではなく「親からの通常の継承状態へ戻す」設計である。

元状態へ厳密に戻したい場合は、変更前DACLのバックアップ/復元が必要である。

### 5.5 `/verify`

次のACLを検出する。

- Canonical OrderではないACL
- ACLの長さがACE数と整合しないACL

DACLを直接組み替える処理を実装/デバッグする場合に有用。

### 5.6 `/setowner`

Ownerを変更する。ただしWindows付属`icacls /?`は「所有権変更を強制するものではない。強制的な取得には`takeown.exe`を使用」と明記する。

OwnerとDACLは別概念である。Ownerを変えることと、通常ファイルアクセスのAllow ACEを与えることは同じではない。

### 5.7 `/setintegritylevel`

Low / Medium / HighのMandatory Integrity Labelを設定する。

Integrity Labelは通常のDACLではなくSACL内の`SYSTEM_MANDATORY_LABEL_ACE`として格納される。したがってこの操作は通常のAllow/Deny ACL操作とは別系統である。

Integrity ACEへ`(CI)(OI)`を付け、ディレクトリ配下へ継承させる指定も可能。

### 5.8 `/substitute`

DACL内のSIDを別SIDへ置換する。アカウント移行等の用途が中心で、POSIX `chmod`相当ではない。

### 5.9 `/T`と継承は別物

`/T`は各子要素を明示的に再帰処理するオプション。

一方、`(OI)(CI)`付きACEの追加/変更はWindowsの自動継承機構によって既存の子要素へも伝播し得る。

したがって、次の2つを混同しない。

- `/T`: コマンドが各対象を走査して操作
- inheritable ACE: 親ACL変更に伴うSecurity Descriptor継承/自動伝播

両者は結果が似ることがあるが、意味と副作用は異なる。

### 5.10 `/C`, `/L`, `/Q`

- `/C`: エラーが発生しても他対象の処理を継続
- `/L`: Symlinkのtargetではなくlink自身へ操作
- `/Q`: success出力を抑制

`/C`を使っても「全体として必ず成功扱いになる」とは限らない。Microsoft Learnは`icacls`の詳細な終了コード表を公開していないため、本プロジェクトでは人間向け出力を解析せず、基本的に`errorlevel`の0/nonzeroで扱う方が堅牢である。

---

## 6. `/inheritance`と`/inheritancelevel`の文書差異

2026-10-14時点で重要な文書差異がある。

### Microsoft Learn

現行Webドキュメントは次の形式を掲載している。

```text
/inheritancelevel:e|d|r
```

### Windows付属`icacls /?`

Windows 11等で採取された実行ファイル内ヘルプは次の形式を掲載している。

```text
/inheritance:e|d|r
```

意味はいずれも次の通り。

- `e`: 継承を有効化
- `d`: 継承を無効化し、現在の継承ACEをExplicit ACEとしてコピー
- `r`: 継承を無効化し、継承ACEを除去

国内外のWindows 11実用例でも`/inheritance:e|d|r`が広く実動している。

### 本プロジェクトでの扱い

現行`chmod.bat`は実行ファイルヘルプ/実機系の形式である`/inheritance:e`と`/inheritance:r`を使用している。

現時点では、Microsoft Learn側の`/inheritancelevel`表記だけを根拠として既存実装を変更しない。Windows 10/11/Serverの実機マトリクスで両形式を確認してから判断する。

---

## 7. Permission表記

### 7.1 Basic Rights

`icacls`が文書化するBasic Rights:

| 記号 | 意味 |
|---|---|
| `N` | No access |
| `F` | Full access |
| `M` | Modify |
| `RX` | Read and execute |
| `R` | Read |
| `W` | Write |
| `D` | Delete |

`N`が内部的にどのようなACE表現へ正規化されるかは、`chmod-for-windows`で依存する前に実機検証すること。

### 7.2 Advanced Rights

| 記号 | 意味 |
|---|---|
| `DE` | Delete |
| `RC` | Read Control |
| `WDAC` | Write DAC |
| `WO` | Write Owner |
| `S` | Synchronize |
| `AS` | Access System Security |
| `MA` | Maximum Allowed |
| `GR` | Generic Read |
| `GW` | Generic Write |
| `GE` | Generic Execute |
| `GA` | Generic All |
| `RD` | Read Data / List Directory |
| `WD` | Write Data / Add File |
| `AD` | Append Data / Add Subdirectory |
| `REA` | Read Extended Attributes |
| `WEA` | Write Extended Attributes |
| `X` | Execute / Traverse |
| `DC` | Delete Child |
| `RA` | Read Attributes |
| `WA` | Write Attributes |

同じbitがファイルとディレクトリで異なる意味を持つものがある。例:

- `RD`: ファイルならRead Data、ディレクトリならList Directory
- `WD`: ファイルならWrite Data、ディレクトリならAdd File
- `AD`: ファイルならAppend Data、ディレクトリならAdd Subdirectory
- `X`: ファイルならExecute、ディレクトリならTraverse

---

## 8. 継承フラグ

| 表示 | 意味 |
|---|---|
| `(I)` | 親から継承されたACE |
| `(OI)` | Object Inherit。非コンテナー子、通常はファイルへ継承 |
| `(CI)` | Container Inherit。子ディレクトリへ継承 |
| `(IO)` | Inherit Only。現在オブジェクトには効かず子への継承用 |
| `(NP)` | No Propagate。直接の子より先へ継承フラグを伝播しない |

### 8.1 `(OI)(CI)`

ディレクトリでファイルとサブディレクトリの両方へ同種権限を伝えたい場合の典型指定。

```bat
icacls "C:\data" /grant *S-1-5-32-545:(OI)(CI)RX
```

ただしWindowsの継承ではGeneric Rights/SIDが子オブジェクト用Specific Rights/SIDへ変換される場合があり、親のACE1件が常に子のACE1件へ単純コピーされるとは限らない。

### 8.2 Automatic Inheritance

Windows APIの`SetNamedSecurityInfo`等でinheritable ACEを変更すると、既存の子オブジェクトへ自動伝播する機構がある。

- Explicit ACEはInherited ACEより前
- 親のinheritable ACE削除により、対応するInherited ACEが子から除去される場合がある
- 子側が`SE_DACL_PROTECTED`なら親DACL継承を防止できる
- もともとNULL DACLだった子が継承を経て空DACLへ変化すると、Full Access状態からNo Access状態へ変化し得る

ACL継承を変更する処理は、単なる表示上の整理ではなくアクセス可否を大きく変える。

---

## 9. SID指定とローカライズ

Microsoft Learnは、数値SIDを指定する場合は先頭に`*`を付けるよう文書化している。

例:

```text
*S-1-1-0
*S-1-5-11
*S-1-5-18
*S-1-5-32-544
*S-1-5-32-545
```

代表的なWell-known SID:

| SID | 主体 |
|---|---|
| `S-1-1-0` | Everyone |
| `S-1-5-11` | Authenticated Users |
| `S-1-5-18` | Local System |
| `S-1-5-32-544` | BUILTIN\Administrators |
| `S-1-5-32-545` | BUILTIN\Users |
| `S-1-3-0` | CREATOR OWNER |

表示名はOS言語で変化するため、スクリプト内部では可能な限り数値SIDを利用する方がローカライズに強い。

`chmod-for-windows`が数値SIDを中心に操作する方針は妥当である。

---

## 10. POSIX `rwx`との近似

### 10.1 `r`

ファイルでは主にRead Data、ディレクトリではList Directoryを含むGeneric Readへ近似可能。

ただしWindows Generic ReadにはAttributes、Extended Attributes、READ_CONTROL、SYNCHRONIZE等も含まれ、POSIX `r`より広い。

### 10.2 `w`

ファイルではWrite Data/Append等、ディレクトリではAdd File/Add Subdirectory等へ対応する。

POSIXディレクトリの`w`はエントリ作成/削除と密接に関係する。Windowsでは削除可否に対象自身の`DELETE`または親ディレクトリの`FILE_DELETE_CHILD`が関係する。

そのため本プロジェクトがディレクトリ`w+x`近似に`Delete Child`を加える設計には合理性があるが、完全なPOSIX意味論ではない。

### 10.3 `x`

ファイルではExecute、ディレクトリではTraverseへ近似する。

ただしWindowsでは`SeChangeNotifyPrivilege` (Bypass traverse checking)が既定で一般ユーザーにも付与され、パス途中のディレクトリについて`FILE_TRAVERSE`チェックをスキップできる。これは「フォルダ内容一覧を見られる」という意味ではなく、許可された下位オブジェクトまでパスを通過できるという意味である。

したがって、Windows上のディレクトリ`x`近似はPOSIXのsearch permissionほど強い境界にならない場合がある。

---

## 11. Owner / Administrators / UAC / 特権

### 11.1 Owner

WindowsのOwnerはPOSIX ownerと似た名前を持つが、アクセスモデルは同じではない。

一般的なWindowsセキュリティモデルではOwnerにREAD_CONTROL/WRITE_DAC相当の暗黙権限が関係し、OwnerはDACLを修正できる場合がある。

本プロジェクトの`u`は**実ファイルOwnerではなく現在のWindowsユーザー**としているため、ここは明確な近似である。

### 11.2 Administrators ACEとUAC

Administratorsグループのユーザーでも、UAC環境では通常のExplorerやアプリはフィルター済みStandard Tokenで動作し、昇格時にAdmin Tokenを使用する。

そのためAdministratorsへACEがあることと、非昇格プロセスがその権限を常時利用できることは同じではない。

### 11.3 「管理者 = Unix root」ではない

Windows管理者は所有権取得やACL修復に強い能力を持つが、通常の`CreateFile`等の読み取りが常にDACLを無視するわけではない。

代表的特権:

- `SeTakeOwnershipPrivilege`: 所有権取得に利用
- `SeRestorePrivilege`: ACLに関係なくWRITE_DAC/WRITE_OWNER等の書き込み系アクセスを得られる
- `SeBackupPrivilege`: バックアップ用途の読取アクセスを可能にする
- `SeSecurityPrivilege`: SACL/監査情報へアクセス
- `SeRelabelPrivilege`: Mandatory Integrity Label変更に関係

これらは「プロセスが保持しているだけ」で全アプリが自動的に無制限アクセスするという意味ではない。APIの開き方や特権の有効化が必要な場合がある。

したがって「sudoでメモ帳を起動したからDACLを無視して必ず読める」と考えてはいけない。

### 11.4 本プロジェクトのSYSTEM/Administrators保持

ディレクトリ変更時にSYSTEM/AdministratorsのFull Controlを残すのは、Windowsで管理/復旧経路を失いにくくするための**本プロジェクト安全方針**である。

GNU `chmod 700`の正式意味ではない。

---

## 12. Mandatory Integrity Control (MIC)

MICはDACLより前に評価される追加アクセス制御機構。

オブジェクトのIntegrity LabelはSACL内の`SYSTEM_MANDATORY_LABEL_ACE`に格納される。

代表的ポリシー:

- NO_WRITE_UP
- NO_READ_UP
- NO_EXECUTE_UP

通常はNO_WRITE_UPが重要で、低IntegrityプロセスはDACL上Allowされていても高いIntegrityのオブジェクトへ書き込めない場合がある。

`icacls /setintegritylevel`はこの領域を操作する。

DACLだけをバックアップしてもIntegrity Labelはバックアップされない点に注意する。

---

## 13. `/save` / `/restore`の範囲

### 13.1 保存対象

Microsoft Learnは`/save`をDACL保存機能として説明している。

Windows 11等の`icacls /?`内蔵ヘルプはさらに明確に、**SACL、Owner、Integrity Labelは保存されない**と記載する。

したがって`icacls /save`によるバックアップを「Security Descriptor完全バックアップ」と呼んではいけない。

本プロジェクトでは「DACLバックアップ」と表現するのが正確。

### 13.2 ファイル形式

歴史的Microsoft資料および実測では、`/save`ファイルはUnicode/SDDL系表現を含む形式として扱われる。しかし現行Microsoft Learnは保存ファイルの内部フォーマット/encodingを安定APIとして規定していない。

したがって:

- `/save`生成物を直接文字列編集しない
- 内部encoding/行形式へ実装を依存させない
- 復元には原則`icacls /restore`を使用する

### 13.3 `/reset`との違い

- `/restore`: 事前保存したDACLへ戻す
- `/reset`: 現在の親継承を基準に既定のInherited ACLへ置換

用途は全く異なる。

---

## 14. ファイル作成・コピー・移動とACL

今回の`chmod-for-windows`のディレクトリ設計で非常に重要。

### 14.1 新規作成

特定Security Descriptorを明示せず新規ファイル/ディレクトリを作る場合、通常は親からデフォルトSecurity Descriptor/継承可能ACEを受ける。

### 14.2 コピー

Microsoft SupportのWindows説明では、コピー先で新しいオブジェクトが作られるため、通常はコピー先親の権限を継承する。

### 14.3 別ボリュームへの移動

実質コピー+削除になるため、通常は移動先のデフォルトSecurity Descriptorを受ける。

### 14.4 同一ボリューム内の移動/rename

Microsoft Support資料では、同一NTFSボリューム内で別フォルダへ移動した場合、**元の権限を保持する**ことが例外として説明されている。

Windows APIレベルでもrename/moveは「新規作成」と同じではない。

従って、`

```text
chmod 700 destination
```

後に既存ファイルを同一ボリュームから`destination`へ移動しても、「新規作成したファイルと完全に同じACLへ必ず即時変換される」と仮定してはいけない。

`(OI)(CI)`による継承は新規作成や自動伝播に重要だが、全ての移動操作のSecurity Descriptorを無条件に再生成する仕組みではない。

この挙動はWindowsバージョン、Shell/API、保護されたDACL等を含め実機テスト対象とする。

---

## 15. File System差

### NTFS

ファイル/ディレクトリごとのSecurity Descriptorをサポートする。本プロジェクトの主対象。

### ReFS

現行Microsoft資料ではACLをサポートする。NTFSと同じWindows ACLモデルを利用できる範囲が大きいが、全エッジケースをNTFSと同一と仮定せずテストする。

### FAT / FAT32 / exFAT等

FAT系ではNTFS型のファイル/ディレクトリDACLを利用できない。`chmod-for-windows`が意図するACL意味論を実装できない。

### SMB/remote volume

SMB redirector経由のSecurity Descriptor能力はリモート側ファイルシステム/サーバーに依存する。

さらにSMBアクセスでは**ファイルシステムDACLとは別にShare ACL/Share permission**が存在し得る。

`icacls`でファイルDACLをAllowしても、共有レベルで拒否されていればネットワーク越しアクセスは失敗する。

---

## 16. EFS

NTFS EFSはACLとは別の暗号保護。

DACL上Readを付与しても、暗号化キー/資格情報がないユーザーがEFS暗号化ファイルの平文を読めるとは限らない。

「icacls上は読めるはずなのに開けない」ケースではEFSも確認対象になる。

---

## 17. WSL / DrvFSと`ls -l`/`chmod`

WSLからWindowsドライブをDrvFSで扱う場合、Linux mode表示はNTFS DACLそのものではない。

### metadata無効 (既定)

Windowsユーザーの有効アクセスから`rwx`を算出し、u/g/oへ同じ値として見せる。

WSL側`chmod`も通常のPOSIX modeをNTFS DACLへ完全変換するわけではなく、特定条件ではWindows Read-only属性等へ反映する。

### metadata有効

`$LXUID`, `$LXGID`, `$LXMOD`, `$LXDEV`等のNTFS拡張属性でLinux metadataを保持する。

ただしmetadataで`777`と表示しても、Windows DACLで許可されていないアクセスを新たに獲得できない。

したがって、本プロジェクトの検証で`ls -la`の表示をACLの真実として扱わない。Windows側の実ACL確認は`icacls`等を基準にする。

---

## 18. Symlink / Reparse Point / Junction / Hard Link

### 18.1 Symlink

`icacls /L`はSymlinkのtargetではなくlink自身へ作用する、とMicrosoftが文書化している。

`/L`を指定しない場合のlink targetへの作用と、再帰処理を組み合わせる場合はループ/意図しないtarget操作に注意する。

### 18.2 Junction / Reparse Point

JunctionもReparse Pointだが、`icacls /L`のMicrosoft説明は「symbolic link」と明記している。全種類のReparse Pointが完全に同じ挙動をするとは文書だけで断定しない。実機検証対象。

### 18.3 Hard Link

WindowsのHard Linkは同じファイルへの別Directory Entryであり、Security Descriptorはlink名ではなく基礎ファイルに属する。

従ってHard Linkの1つの名前からACLを変更すると、他のHard Link名から見ても同じACL変更が反映される。

---

## 19. ローカライズと出力解析

- Account Friendly NameはOS言語で変わる
- `icacls`の人間向け成功/エラー文もローカライズされ得る
- 数値SIDは言語非依存
- スクリプトで英語出力文字列を固定解析しない
- 可能なら数値SIDと`errorlevel`を利用する

また`cmd.exe`の括弧ブロックでは`%ERRORLEVEL%`の展開タイミングに注意し、`if errorlevel N`形式を優先する。

---

## 20. `chmod-for-windows`への設計上の含意

| 項目 | GNU/POSIX側 | Windows側 | 本プロジェクトでの扱い |
|---|---|---|---|
| `u` | file owner | 任意SID/Ownerは別概念 | 現在ユーザーSIDへ近似 |
| `g` | file owning group | 任意Group SID | BUILTIN\Users中心に近似 |
| `o` | owner/group以外 | 排他的others概念なし | Everyoneへ近似 |
| `r` | 1bit | Generic Readは複数rights | GR/R相当へ近似 |
| `w` | 1bit | Write Data/Add File等複数 | GW/W + directory操作へ近似 |
| `x` | execute/search | Execute/Traverse。Traverse privilegeの影響あり | GE/Xへ近似 |
| `000` | u/g/o権限なし | empty DACL/Owner/特権等が存在 | Allow ACE調整による近似 |
| `700` dir | ownerのみrwx | SID ACE + inheritance | current user + SYSTEM/Admin安全ACE |
| `777` dir | 全class rwx | 直接対応なし | **Windows標準継承へ戻す独自復旧操作** |
| `-R` | tree walk | `/T`とACL自動継承は別物 | 独自tree処理/継承を慎重に扱う |

### 20.1 u/g/oは排他的ではない

Windowsユーザーは同時にCurrent User、BUILTIN\Users、Authenticated Users、Everyone等へ属する。

したがって本プロジェクトのu/g/oはPOSIXの3つの排他的classではなく、重複するSID集合への近似である。

このためACLから擬似POSIX MODEを逆算しても、完全な可逆変換にはならない。

### 20.2 Denyを原則使わない理由

- POSIX modeにExplicit Deny概念はない
- DenyはグループAllowも阻止する
- Generic rightsが重なることで意図しないRead/Write拒否につながり得る
- Canonical orderにより影響が強い

そのため「権限を外す」操作はAllow ACEの置換/削除を基本とする。

### 20.3 Backupの表現

現在の`icacls /save`ベース処理をドキュメントで「ACL完全バックアップ」と呼ばず、**DACLバックアップ**または「`icacls /save`によるDACLバックアップ」と呼ぶ。

---

## 21. 安全な検証手順

ACL操作テストはOS管理領域ではなく一時NTFSディレクトリで行う。

例:

```bat
mkdir "%TEMP%\chmod-acl-test"
icacls "%TEMP%\chmod-acl-test"
icacls "%TEMP%\chmod-acl-test" /save "%TEMP%\chmod-acl-test.acl"
```

検証時に最低限確認するもの:

1. 変更前`icacls`
2. 変更後`icacls`
3. Owner
4. `(I)/(OI)/(CI)/(IO)/(NP)`
5. 新規作成した子ファイル
6. コピーした子ファイル
7. 同一ボリュームから移動したファイル
8. 別ボリュームから移動したファイル
9. Standard UserでのRead/Write/Delete/Create/Traverse
10. Elevated Administratorでの同操作
11. `chmod 777`復旧後
12. `chmod -R 777`復旧後

可能ならWindows 10、Windows 11、Windows Server、NTFS/ReFS、ローカル/SMBでマトリクス化する。

---

## 22. 未検証/要追加検証

次は仕様だけでは断定しない。

- 現行Windows各ビルドで`/inheritance:`と`/inheritancelevel:`の両方が同一動作するか
- Basic Right `N`の正確な生成ACE/既存ACEへの作用
- ReFSでの`icacls`全オプション互換性
- Junction/Mount Pointに対する`/L`と`/T`の正確な挙動
- `/C`併用時の詳細な最終Exit Code
- 同一ボリュームmoveでExplorer、`move`、MoveFileEx、異なるツール間に差があるか
- ACL自動伝播と`icacls`内部実装の対応関係
- Windows 10/11/Serverでの`/save`内部ファイル形式/encoding差

未検証事項は「一般にそうらしい」だけで実装要件へ昇格させない。

---

## 23. 主な一次資料

Microsoft:

- icacls  
  https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/icacls
- Security Descriptors  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/security-descriptors
- DACLs and ACEs  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/dacls-and-aces
- Order of ACEs in a DACL  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/order-of-aces-in-a-dacl
- How DACLs Control Access to an Object  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/how-dacls-control-access-to-an-object
- ACE Inheritance Rules  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/ace-inheritance-rules
- Automatic Propagation of Inheritable ACEs  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/automatic-propagation-of-inheritable-aces
- File Security and Access Rights  
  https://learn.microsoft.com/en-us/windows/win32/fileio/file-security-and-access-rights
- File Access Rights Constants  
  https://learn.microsoft.com/en-us/windows/win32/fileio/file-access-rights-constants
- Privilege Constants  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants
- Mandatory Integrity Control  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control
- Well-known SIDs  
  https://learn.microsoft.com/en-us/windows/win32/secauthz/well-known-sids
- Permissions when you copy and move files  
  https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/permissions-on-copying-moving-files
- Security Descriptors in File Systems  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/security-descriptors
- ReFS overview  
  https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview
- WSL File Permissions  
  https://learn.microsoft.com/en-us/windows/wsl/file-permissions
- Effective permissions for remote/SMB resources  
  https://learn.microsoft.com/en-us/troubleshoot/windows-server/windows-security/access-checks-windows-apis-return-incorrect-results
- File Encryption / EFS  
  https://learn.microsoft.com/en-us/windows/win32/fileio/file-encryption
- Hard Links / Security Descriptor  
  https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createhardlinktransacteda

実行ファイルヘルプとの差を確認する場合:

```bat
icacls /?
```

国内外のコミュニティ記事は補助資料として参照するが、仕様判断ではMicrosoft一次資料と実機ヘルプを優先する。
